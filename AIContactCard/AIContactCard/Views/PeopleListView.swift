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
                ContentUnavailableView(
                    "No People Yet",
                    systemImage: "person.crop.circle.badge.questionmark",
                    description: Text("People you talk about will appear here.")
                )
            } else {
                List(people) { person in
                    NavigationLink(value: person) {
                        VStack(alignment: .leading) {
                            Text(person.name)
                                .font(.headline)
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
