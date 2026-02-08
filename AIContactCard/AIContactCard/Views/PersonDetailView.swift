//
//  PersonDetailView.swift
//  AIContactCard
//

import SwiftUI
import SwiftData

struct PersonDetailView: View {
    let person: Person
    @Environment(ContactSyncService.self) private var contactSyncService
    @State private var showingAddFact = false

    private var groupedFacts: [(String, [Fact])] {
        let grouped = Dictionary(grouping: person.facts, by: \.category)
        return grouped.sorted { $0.key < $1.key }
    }

    private var linkedContact: ContactSummary? {
        guard let id = person.contactIdentifier else { return nil }
        return contactSyncService.allContacts.first { $0.identifier == id }
    }

    var body: some View {
        List {
            // Linked contact header
            Section {
                if let contact = linkedContact {
                    HStack(spacing: 12) {
                        Image(systemName: "person.crop.circle.badge.checkmark")
                            .font(.title2)
                            .foregroundStyle(.green)
                        VStack(alignment: .leading, spacing: 2) {
                            Text("Linked to \(contact.fullName)")
                                .font(.subheadline)
                                .fontWeight(.medium)
                            if !contact.organization.isEmpty {
                                Text(contact.organization)
                                    .font(.caption)
                                    .foregroundStyle(.secondary)
                            }
                        }
                        Spacer()
                        Button("Unlink") {
                            person.contactIdentifier = nil
                        }
                        .font(.caption)
                        .foregroundStyle(.red)
                    }
                } else {
                    HStack(spacing: 12) {
                        Image(systemName: "person.crop.circle.badge.questionmark")
                            .font(.title2)
                            .foregroundStyle(.secondary)
                        Text("Not linked to a contact")
                            .font(.subheadline)
                            .foregroundStyle(.secondary)
                        Spacer()
                        Menu {
                            ForEach(contactSyncService.allContacts, id: \.identifier) { contact in
                                Button {
                                    person.contactIdentifier = contact.identifier
                                } label: {
                                    if contact.organization.isEmpty {
                                        Text(contact.fullName)
                                    } else {
                                        Text("\(contact.fullName) (\(contact.organization))")
                                    }
                                }
                            }
                        } label: {
                            Text("Link")
                                .font(.caption)
                        }
                    }
                }
            }

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
    .environment(ContactSyncService())
    .modelContainer(for: [Person.self, Fact.self, Entry.self], inMemory: true)
}
