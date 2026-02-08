//
//  ExtractionResultView.swift
//  AIContactCard
//

import SwiftUI
import SwiftData

// MARK: - Editable State Models

struct EditableFact: Identifiable {
    let id = UUID()
    var isEnabled: Bool = true
    var category: String
    var content: String
}

enum MatchSelection: Equatable, Hashable {
    case newPerson
    case contact(String) // contactId
    case unresolved
}

struct EditableContact: Identifiable {
    let id = UUID()
    let originalName: String
    let matchedPersonId: String?
    let aliases: [String]
    let matchCandidates: [MatchCandidate]
    var selectedMatch: MatchSelection
    var facts: [EditableFact]
    var needsResolution: Bool

    init(from extracted: ExtractedContact) {
        self.originalName = extracted.name
        self.matchedPersonId = extracted.matchedPersonId
        self.aliases = extracted.aliases
        self.matchCandidates = extracted.matchCandidates
        self.facts = extracted.facts.map { EditableFact(category: $0.category, content: $0.content) }

        // Auto-select logic
        if extracted.matchedPersonId != nil {
            // Matched to existing person in DB — no contact selection needed
            self.selectedMatch = .newPerson
            self.needsResolution = false
        } else if extracted.matchCandidates.count == 1,
                  extracted.matchCandidates[0].confidence == "high" {
            // Single high-confidence match — auto-select
            self.selectedMatch = .contact(extracted.matchCandidates[0].contactId)
            self.needsResolution = false
        } else if extracted.matchCandidates.isEmpty {
            // No candidates — new person
            self.selectedMatch = .newPerson
            self.needsResolution = false
        } else {
            // Multiple candidates or non-high confidence — user must choose
            self.selectedMatch = .unresolved
            self.needsResolution = true
        }
    }
}

// MARK: - ExtractionResultView

struct ExtractionResultView: View {
    let result: ExtractionResult
    let transcript: String
    let existingPeople: [Person]
    let allContacts: [ContactSummary]
    let onSave: () -> Void

    @Environment(\.modelContext) private var modelContext
    @Environment(\.dismiss) private var dismiss

    @State private var editableContacts: [EditableContact] = []

    private static let allCategories = [
        "work", "family", "interests", "location", "education",
        "personality", "relationship", "health", "events",
        "appearance", "preferences", "other"
    ]

    private var enabledFactCount: Int {
        editableContacts.reduce(0) { sum, contact in
            sum + contact.facts.filter(\.isEnabled).count
        }
    }

    private var hasUnresolvedMatches: Bool {
        editableContacts.contains { $0.selectedMatch == .unresolved }
    }

    var body: some View {
        NavigationStack {
            Group {
                if result.contacts.isEmpty {
                    ContentUnavailableView(
                        "Nothing Extracted",
                        systemImage: "person.crop.circle.badge.questionmark",
                        description: Text("No people or facts could be identified from the recording. Try speaking more clearly about a specific person.")
                    )
                } else {
                    List {
                        ForEach($editableContacts) { $contact in
                            contactSection(contact: $contact)
                        }
                    }
                    .safeAreaInset(edge: .bottom) {
                        saveButton
                    }
                }
            }
            .navigationTitle("Review Extraction")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Cancel") { dismiss() }
                }
            }
            .onAppear {
                if editableContacts.isEmpty {
                    editableContacts = result.contacts.map { EditableContact(from: $0) }
                }
            }
        }
    }

    // MARK: - Contact Section

    @ViewBuilder
    private func contactSection(contact: Binding<EditableContact>) -> some View {
        Section {
            // Contact matching
            contactMatchingRow(contact: contact)

            // Facts
            ForEach(contact.facts) { $fact in
                factRow(fact: $fact)
            }

            if contact.wrappedValue.facts.isEmpty {
                Text("No facts extracted")
                    .foregroundStyle(.secondary)
            }
        } header: {
            HStack {
                Text(contact.wrappedValue.originalName)
                Spacer()
                if contact.wrappedValue.matchedPersonId != nil {
                    statusBadge("Existing", color: .green)
                } else {
                    statusBadge("New", color: .orange)
                }
            }
        }
    }

    // MARK: - Contact Matching Row

    @ViewBuilder
    private func contactMatchingRow(contact: Binding<EditableContact>) -> some View {
        let c = contact.wrappedValue

        if c.matchedPersonId != nil {
            // Matched to existing person in DB
            Label("Matched to existing person", systemImage: "person.crop.circle.badge.checkmark")
                .foregroundStyle(.green)
                .font(.subheadline)
        } else if c.matchCandidates.isEmpty {
            // No candidates — new person with option to search
            HStack {
                Label("New Person", systemImage: "person.badge.plus")
                    .font(.subheadline)
                Spacer()
                Menu {
                    ForEach(allContacts, id: \.identifier) { contactSummary in
                        Button {
                            contact.wrappedValue.selectedMatch = .contact(contactSummary.identifier)
                            contact.wrappedValue.needsResolution = false
                        } label: {
                            Text(contactLabel(for: contactSummary))
                        }
                    }
                } label: {
                    Text("Link")
                        .font(.subheadline)
                }
            }
        } else if c.needsResolution || c.selectedMatch == .unresolved {
            // Ambiguous — user must pick
            VStack(alignment: .leading, spacing: 8) {
                Label("Select a match", systemImage: "exclamationmark.triangle.fill")
                    .foregroundStyle(.orange)
                    .font(.subheadline)

                Picker("Match", selection: contact.selectedMatch) {
                    Text("New Person").tag(MatchSelection.newPerson)
                    ForEach(c.matchCandidates, id: \.contactId) { candidate in
                        HStack {
                            Text(candidate.contactName)
                            confidenceBadge(candidate.confidence)
                        }
                        .tag(MatchSelection.contact(candidate.contactId))
                    }
                }
                .pickerStyle(.menu)
                .onChange(of: contact.wrappedValue.selectedMatch) { _, newValue in
                    if newValue != .unresolved {
                        contact.wrappedValue.needsResolution = false
                    }
                }
            }
            .padding(.vertical, 4)
            .listRowBackground(
                c.selectedMatch == .unresolved
                    ? Color.orange.opacity(0.08)
                    : Color.clear
            )
        } else {
            // Resolved — single high-confidence auto-match or user already picked
            if case .contact(let contactId) = c.selectedMatch,
               let candidate = c.matchCandidates.first(where: { $0.contactId == contactId }) {
                HStack {
                    Label("Linked to \(candidate.contactName)", systemImage: "checkmark.circle.fill")
                        .foregroundStyle(.green)
                        .font(.subheadline)
                    Spacer()
                    Menu {
                        Button("New Person") {
                            contact.wrappedValue.selectedMatch = .newPerson
                        }
                        ForEach(c.matchCandidates, id: \.contactId) { other in
                            if other.contactId != contactId {
                                Button(other.contactName) {
                                    contact.wrappedValue.selectedMatch = .contact(other.contactId)
                                }
                            }
                        }
                    } label: {
                        Text("Change")
                            .font(.caption)
                    }
                }
            } else {
                // .newPerson with candidates available
                HStack {
                    Label("New Person", systemImage: "person.badge.plus")
                        .font(.subheadline)
                    Spacer()
                    if !c.matchCandidates.isEmpty {
                        Menu {
                            ForEach(c.matchCandidates, id: \.contactId) { candidate in
                                Button(candidate.contactName) {
                                    contact.wrappedValue.selectedMatch = .contact(candidate.contactId)
                                }
                            }
                        } label: {
                            Text("Link")
                                .font(.caption)
                        }
                    }
                }
            }
        }
    }

    // MARK: - Fact Row

    private func factRow(fact: Binding<EditableFact>) -> some View {
        HStack(alignment: .top, spacing: 10) {
            Button {
                fact.wrappedValue.isEnabled.toggle()
            } label: {
                Image(systemName: fact.wrappedValue.isEnabled ? "checkmark.circle.fill" : "circle")
                    .foregroundStyle(fact.wrappedValue.isEnabled ? .green : .gray)
                    .font(.title3)
            }
            .buttonStyle(.plain)

            VStack(alignment: .leading, spacing: 4) {
                // Category picker
                Menu {
                    ForEach(Self.allCategories, id: \.self) { cat in
                        Button(cat) {
                            fact.wrappedValue.category = cat
                        }
                    }
                } label: {
                    Text(fact.wrappedValue.category)
                        .font(.caption)
                        .fontWeight(.medium)
                        .padding(.horizontal, 6)
                        .padding(.vertical, 2)
                        .background(.blue.opacity(fact.wrappedValue.isEnabled ? 0.1 : 0.05))
                        .foregroundStyle(fact.wrappedValue.isEnabled ? .blue : .gray)
                        .clipShape(Capsule())
                }

                // Editable content
                TextField("Fact", text: fact.content, axis: .vertical)
                    .font(.body)
                    .foregroundStyle(fact.wrappedValue.isEnabled ? .primary : .secondary)
                    .strikethrough(!fact.wrappedValue.isEnabled)
            }
        }
        .opacity(fact.wrappedValue.isEnabled ? 1.0 : 0.6)
    }

    // MARK: - Save Button

    private var saveButton: some View {
        Button {
            persistAndDismiss()
        } label: {
            Text("Save (\(enabledFactCount) facts)")
                .font(.headline)
                .frame(maxWidth: .infinity)
                .padding(.vertical, 12)
        }
        .buttonStyle(.borderedProminent)
        .disabled(hasUnresolvedMatches)
        .padding(.horizontal)
        .padding(.bottom, 8)
    }

    // MARK: - Helpers

    private func statusBadge(_ text: String, color: Color) -> some View {
        Text(text)
            .font(.caption2)
            .fontWeight(.medium)
            .padding(.horizontal, 6)
            .padding(.vertical, 2)
            .background(color.opacity(0.1))
            .foregroundStyle(color)
            .clipShape(Capsule())
    }

    private func confidenceBadge(_ confidence: String) -> some View {
        Text(confidence)
            .font(.caption2)
            .foregroundStyle(confidenceColor(confidence))
    }

    private func confidenceColor(_ confidence: String) -> Color {
        switch confidence {
        case "high": return .green
        case "medium": return .orange
        default: return .red
        }
    }

    private func contactLabel(for contact: ContactSummary) -> String {
        if contact.organization.isEmpty {
            return contact.fullName
        }
        return "\(contact.fullName) (\(contact.organization))"
    }

    // MARK: - Persistence

    private func persistAndDismiss() {
        for contact in editableContacts {
            let person: Person

            if let matchedId = contact.matchedPersonId,
               let existing = existingPeople.first(where: { $0.id.uuidString == matchedId }) {
                person = existing
                for alias in contact.aliases where !person.aliases.contains(alias) {
                    person.aliases.append(alias)
                }
            } else {
                person = Person(name: contact.originalName)
                person.aliases = contact.aliases
                modelContext.insert(person)
            }

            // Set contactIdentifier only if user confirmed a contact match
            if case .contact(let contactId) = contact.selectedMatch {
                person.contactIdentifier = contactId
            }

            // Only save enabled facts with edited values
            for fact in contact.facts where fact.isEnabled {
                let newFact = Fact(category: fact.category, content: fact.content)
                newFact.rawTranscript = transcript
                newFact.person = person
                modelContext.insert(newFact)
            }

            person.updatedAt = Date()
        }

        onSave()
        dismiss()
    }
}

#Preview {
    ExtractionResultView(
        result: ExtractionResult(contacts: [
            ExtractedContact(
                name: "John Smith",
                matchedPersonId: nil,
                matchCandidates: [
                    MatchCandidate(contactId: "abc", contactName: "John Smith (Google)", confidence: "high")
                ],
                aliases: ["Johnny"],
                facts: [
                    ExtractedFact(category: "work", content: "VP at Goldman Sachs"),
                    ExtractedFact(category: "family", content: "Has daughter Emma, age 8")
                ]
            ),
            ExtractedContact(
                name: "Sarah",
                matchedPersonId: nil,
                matchCandidates: [
                    MatchCandidate(contactId: "def", contactName: "Sarah Jones (Meta)", confidence: "medium"),
                    MatchCandidate(contactId: "ghi", contactName: "Sarah Williams (Apple)", confidence: "low")
                ],
                aliases: [],
                facts: [
                    ExtractedFact(category: "work", content: "Product manager")
                ]
            )
        ]),
        transcript: "Test transcript",
        existingPeople: [],
        allContacts: [],
        onSave: {}
    )
    .modelContainer(for: [Person.self, Fact.self, Entry.self], inMemory: true)
}
