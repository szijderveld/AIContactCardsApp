//
//  PersonDetailView.swift
//  AIContactCard
//

import SwiftUI
import SwiftData

struct PersonDetailView: View {
    let person: Person
    @State private var showingAddFact = false

    private var groupedFacts: [(String, [Fact])] {
        let grouped = Dictionary(grouping: person.facts, by: \.category)
        return grouped.sorted { $0.key < $1.key }
    }

    var body: some View {
        List {
            if !person.summary.isEmpty {
                Section("Summary") {
                    Text(person.summary)
                }
            }

            if person.facts.isEmpty {
                Section {
                    Text("No facts recorded yet.")
                        .foregroundStyle(.secondary)
                }
            } else {
                ForEach(groupedFacts, id: \.0) { category, facts in
                    Section(category) {
                        ForEach(facts) { fact in
                            Text(fact.content)
                        }
                    }
                }
            }
        }
        .navigationTitle(person.name)
        .toolbar {
            ToolbarItem(placement: .primaryAction) {
                Button {
                    showingAddFact = true
                } label: {
                    Image(systemName: "plus")
                }
            }
        }
        .sheet(isPresented: $showingAddFact) {
            AddFactSheet(person: person)
        }
    }
}

#Preview {
    let person = Person(name: "Jane Doe")
    return NavigationStack {
        PersonDetailView(person: person)
    }
    .modelContainer(for: [Person.self, Fact.self, Entry.self], inMemory: true)
}
