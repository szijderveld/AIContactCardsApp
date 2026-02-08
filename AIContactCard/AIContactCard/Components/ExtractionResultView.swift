//
//  ExtractionResultView.swift
//  AIContactCard
//

import SwiftUI

struct ExtractionResultView: View {
    let result: ExtractionResult
    @Environment(\.dismiss) private var dismiss

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
                        ForEach(result.contacts, id: \.name) { contact in
                            Section {
                                ForEach(contact.facts, id: \.content) { fact in
                                    HStack(alignment: .top, spacing: 8) {
                                        Text(fact.category)
                                            .font(.caption)
                                            .fontWeight(.medium)
                                            .padding(.horizontal, 6)
                                            .padding(.vertical, 2)
                                            .background(.blue.opacity(0.1))
                                            .foregroundStyle(.blue)
                                            .clipShape(Capsule())
                                        Text(fact.content)
                                            .font(.body)
                                    }
                                }
                                if contact.facts.isEmpty {
                                    Text("No facts extracted")
                                        .foregroundStyle(.secondary)
                                }
                            } header: {
                                HStack {
                                    Text(contact.name)
                                    Spacer()
                                    Text(contact.matchedPersonId != nil ? "Matched existing" : "New")
                                        .font(.caption2)
                                        .fontWeight(.medium)
                                        .padding(.horizontal, 6)
                                        .padding(.vertical, 2)
                                        .background(contact.matchedPersonId != nil ? .green.opacity(0.1) : .orange.opacity(0.1))
                                        .foregroundStyle(contact.matchedPersonId != nil ? .green : .orange)
                                        .clipShape(Capsule())
                                }
                            }
                        }
                    }
                }
            }
            .navigationTitle("Extracted Info")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .confirmationAction) {
                    Button("Done") { dismiss() }
                }
            }
        }
    }
}

#Preview {
    ExtractionResultView(result: ExtractionResult(contacts: [
        ExtractedContact(
            name: "John Smith",
            matchedPersonId: nil,
            matchedContactId: nil,
            aliases: ["Johnny"],
            facts: [
                ExtractedFact(category: "work", content: "VP at Goldman Sachs"),
                ExtractedFact(category: "family", content: "Has daughter Emma, age 8")
            ]
        )
    ]))
}
