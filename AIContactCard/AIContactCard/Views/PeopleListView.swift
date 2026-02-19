//
//  PeopleListView.swift
//  AIContactCard
//

import SwiftUI
import SwiftData

struct PeopleListView: View {
    @Query(sort: \Person.name) private var people: [Person]
    @State private var showingAddPerson = false

    var body: some View {
        Group {
            if people.isEmpty {
                EmptyStateView(
                    icon: "person.crop.circle.badge.questionmark",
                    title: "No People Yet",
                    description: "Record a voice note on the Record tab to get started."
                )
            } else {
                List(people) { person in
                    NavigationLink(value: person) {
                        VStack(alignment: .leading) {
                            HStack(spacing: 6) {
                                Text(person.name)
                                    .font(.headline)
                                if person.contactIdentifier != nil {
                                    Image(systemName: "person.crop.circle.badge.checkmark")
                                        .font(.subheadline)
                                        .foregroundStyle(.secondary)
                                }
                            }
                            Text("\(person.facts.count) facts")
                                .font(.subheadline)
                                .foregroundStyle(.secondary)
                        }
                    }
                }
            }
        }
        .navigationTitle("People")
        .toolbar {
            ToolbarItem(placement: .primaryAction) {
                Button {
                    showingAddPerson = true
                } label: {
                    Image(systemName: "plus")
                }
            }
        }
        .sheet(isPresented: $showingAddPerson) {
            AddPersonSheet()
        }
    }
}

#Preview {
    NavigationStack {
        PeopleListView()
    }
    .modelContainer(for: [Person.self, Fact.self, Entry.self], inMemory: true)
}
