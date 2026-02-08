//
//  AddFactSheet.swift
//  AIContactCard
//

import SwiftUI
import SwiftData

struct AddFactSheet: View {
    @Environment(\.modelContext) private var modelContext
    @Environment(\.dismiss) private var dismiss

    let person: Person
    @State private var category = "work"
    @State private var content = ""

    private let categories = [
        "work", "family", "interests", "location", "education",
        "personality", "relationship", "health", "events",
        "appearance", "preferences", "other"
    ]

    var body: some View {
        NavigationStack {
            Form {
                Picker("Category", selection: $category) {
                    ForEach(categories, id: \.self) { cat in
                        Text(cat.capitalized).tag(cat)
                    }
                }
                TextField("Fact", text: $content)
            }
            .navigationTitle("New Fact")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Cancel") { dismiss() }
                }
                ToolbarItem(placement: .confirmationAction) {
                    Button("Save") {
                        let fact = Fact(
                            category: category,
                            content: content.trimmingCharacters(in: .whitespaces)
                        )
                        fact.person = person
                        modelContext.insert(fact)
                        dismiss()
                    }
                    .disabled(content.trimmingCharacters(in: .whitespaces).isEmpty)
                }
            }
        }
    }
}

#Preview {
    AddFactSheet(person: Person(name: "Jane Doe"))
        .modelContainer(for: [Person.self, Fact.self, Entry.self], inMemory: true)
}
