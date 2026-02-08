//
//  AIService.swift
//  AIContactCard
//

import Foundation

// MARK: - Response Structs

struct ExtractionResult: Codable {
    let contacts: [ExtractedContact]
}

struct ExtractedContact: Codable {
    let name: String
    let matchedPersonId: String?
    let matchedContactId: String?
    let aliases: [String]
    let facts: [ExtractedFact]
}

struct ExtractedFact: Codable {
    let category: String
    let content: String
}

// MARK: - ContactSummary

struct ContactSummary: Codable {
    let identifier: String
    let fullName: String
    let nickname: String
    let organization: String
    let jobTitle: String
    let emails: [String]
    let phones: [String]
}

// MARK: - AIService

@Observable
class AIService {
    static let model = "claude-sonnet-4-5-20250929"

    func extract(transcript: String, people: [Person], contacts: [ContactSummary]) async throws -> ExtractionResult {
        let peopleJSON = formatPeopleForExtraction(people)
        let contactsJSON = formatContacts(contacts)

        let prompt = """
        You are a contact information extractor. The user has spoken about people they know.
        Extract structured data about every person mentioned.

        EXISTING PEOPLE IN DATABASE (match these before creating new entries):
        \(peopleJSON)

        IPHONE CONTACTS (match by name/company if a mentioned person corresponds to one):
        \(contactsJSON)

        Return ONLY valid JSON with no markdown formatting, no backticks, no explanation:
        {
          "contacts": [
            {
              "name": "Full Name",
              "matched_person_id": "existing-person-uuid-if-matched-or-null",
              "matched_contact_id": "apple-contact-identifier-if-matched-or-null",
              "aliases": ["nickname1", "nickname2"],
              "facts": [
                { "category": "work", "content": "VP at Goldman Sachs" },
                { "category": "family", "content": "Has daughter Emma, age 8" }
              ]
            }
          ]
        }

        CATEGORIES: work, family, interests, location, education, personality, relationship, health, events, appearance, preferences, other

        RULES:
        - One atomic fact per entry — never combine multiple facts into one
        - Match existing people/contacts by name similarity before creating new entries
        - If "Jerry" is mentioned and a contact "Jeremy Smith" at Goldman exists, match them
        - Include context clues like when or where info was learned if mentioned
        - Be conservative with matching — only match when confident
        - If a person is mentioned but no facts are given about them, still include them with an empty facts array
        - Preserve the user's phrasing as much as possible in fact content
        - If unsure about a name spelling, use your best guess

        TRANSCRIPT:
        \"\"\"
        \(transcript)
        \"\"\"
        """

        let messages: [[String: Any]] = [
            ["role": "user", "content": prompt]
        ]

        let outputSchema: [String: Any] = [
            "type": "object",
            "properties": [
                "contacts": [
                    "type": "array",
                    "items": [
                        "type": "object",
                        "properties": [
                            "name": ["type": "string"],
                            "matched_person_id": ["type": ["string", "null"]],
                            "matched_contact_id": ["type": ["string", "null"]],
                            "aliases": ["type": "array", "items": ["type": "string"]],
                            "facts": [
                                "type": "array",
                                "items": [
                                    "type": "object",
                                    "properties": [
                                        "category": ["type": "string"],
                                        "content": ["type": "string"]
                                    ],
                                    "required": ["category", "content"]
                                ]
                            ]
                        ],
                        "required": ["name", "aliases", "facts"]
                    ]
                ]
            ],
            "required": ["contacts"],
            "additionalProperties": false
        ]

        let data = try await APIClient.sendStructured(
            messages: messages,
            outputSchema: outputSchema
        )

        // Structured outputs: response JSON is in content[0].text
        let text = try extractResponseText(from: data)
        guard let textData = text.data(using: .utf8) else {
            throw APIError.invalidResponse
        }
        let decoder = JSONDecoder()
        decoder.keyDecodingStrategy = .convertFromSnakeCase
        return try decoder.decode(ExtractionResult.self, from: textData)
    }

    func query(question: String, people: [Person], contacts: [ContactSummary]) async throws -> String {
        let peopleJSON = formatPeopleForQuery(people)
        let contactsJSON = formatContacts(contacts)

        let prompt = """
        You are a personal contact assistant. The user will ask a question about people they know.
        Answer using ONLY the information provided below. Be conversational, concise, and helpful.

        If you don't have enough information to fully answer, say so honestly.
        If the question is about a specific person, give all relevant facts you have.
        If the question is a search (e.g. "who works in finance"), scan ALL people and contacts.
        If asked about someone not in the data, say you don't have information about them.

        Do not make up or infer facts that aren't explicitly stated in the data below.

        STORED PEOPLE AND THEIR FACTS:
        \(peopleJSON)

        IPHONE CONTACTS (basic info from the user's phone):
        \(contactsJSON)

        QUESTION: \(question)
        """

        let messages: [[String: Any]] = [
            ["role": "user", "content": prompt]
        ]

        let data = try await APIClient.send(messages: messages)
        return try extractResponseText(from: data)
    }

    // MARK: - Response Parsing

    /// Extract content[0].text from a Claude API response
    private func extractResponseText(from data: Data) throws -> String {
        guard let json = try JSONSerialization.jsonObject(with: data) as? [String: Any],
              let content = json["content"] as? [[String: Any]],
              let first = content.first,
              let text = first["text"] as? String else {
            throw APIError.invalidResponse
        }
        return text
    }

    // MARK: - Prompt Formatting

    private func formatPeopleForExtraction(_ people: [Person]) -> String {
        let items = people.map { person -> [String: Any] in
            [
                "id": person.id.uuidString,
                "name": person.name,
                "aliases": person.aliases
            ]
        }
        return jsonString(from: items)
    }

    private func formatPeopleForQuery(_ people: [Person]) -> String {
        let items = people.map { person -> [String: Any] in
            var dict: [String: Any] = [
                "name": person.name,
                "summary": person.summary,
                "facts": person.facts.map { ["category": $0.category, "content": $0.content] }
            ]
            if let contactId = person.contactIdentifier {
                dict["linked_contact"] = contactId
            }
            return dict
        }
        return jsonString(from: items)
    }

    private func formatContacts(_ contacts: [ContactSummary]) -> String {
        let items = contacts.map { contact -> [String: Any] in
            [
                "id": contact.identifier,
                "name": contact.fullName,
                "nickname": contact.nickname,
                "organization": contact.organization,
                "jobTitle": contact.jobTitle
            ]
        }
        return jsonString(from: items)
    }

    private func jsonString(from object: Any) -> String {
        guard let data = try? JSONSerialization.data(withJSONObject: object, options: [.sortedKeys]),
              let string = String(data: data, encoding: .utf8) else {
            return "[]"
        }
        return string
    }
}
