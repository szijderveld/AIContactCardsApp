//
//  AddPersonSheet.swift
//  AIContactCard
//

import SwiftUI
import SwiftData

struct AddPersonSheet: View {
    @Environment(\.modelContext) private var modelContext
    @Environment(\.dismiss) private var dismiss
    @State private var name = ""

    var body: some View {
        NavigationStack {
            Form {
                TextField("Name", text: $name)
            }
            .navigationTitle("New Person")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Cancel") { dismiss() }
                }
                ToolbarItem(placement: .confirmationAction) {
                    Button("Save") {
                        let person = Person(name: name.trimmingCharacters(in: .whitespaces))
                        modelContext.insert(person)
                        dismiss()
                    }
                    .disabled(name.trimmingCharacters(in: .whitespaces).isEmpty)
                }
            }
        }
    }
}

#Preview {
    AddPersonSheet()
        .modelContainer(for: [Person.self, Fact.self, Entry.self], inMemory: true)
}
