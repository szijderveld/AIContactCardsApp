//
//  PersonDetailView.swift
//  AIContactCard
//

import SwiftUI
import SwiftData

struct PersonDetailView: View {
    let person: Person
    @Environment(\.modelContext) private var modelContext
    @Environment(ContactSyncService.self) private var contactSyncService
    @State private var showingAddFact = false
    @State private var editingFact: Fact?
    @State private var isEditingName = false
    @State private var editedFirst = ""
    @State private var editedMiddle = ""
    @State private var editedLast = ""

    private var groupedFacts: [(String, [Fact])] {
        let grouped = Dictionary(grouping: person.facts, by: \.category)
        return grouped.sorted { $0.key < $1.key }
    }

    private var linkedContact: ContactSummary? {
        guard let id = person.contactIdentifier else { return nil }
        return contactSyncService.allContacts.first { $0.identifier == id }
    }

    private var initials: String {
        let first = person.firstName.prefix(1)
        let last = person.lastName.prefix(1)
        if !last.isEmpty {
            return (first + last).uppercased()
        }
        return String(person.firstName.prefix(2)).uppercased()
    }

    var body: some View {
        List {
            // Header with avatar
            Section {
                HStack(spacing: 14) {
                    Text(initials)
                        .font(.system(size: 18, weight: .semibold, design: .rounded))
                        .foregroundStyle(.white)
                        .frame(width: 52, height: 52)
                        .background(Theme.accent, in: Circle())

                    VStack(alignment: .leading, spacing: 4) {
                        if let contact = linkedContact {
                            HStack(spacing: 6) {
                                Image(systemName: "link")
                                    .font(.caption)
                                    .foregroundStyle(Theme.success)
                                Text(contact.fullName)
                                    .font(.subheadline)
                                    .foregroundStyle(Theme.textSecondary)
                            }
                            if !contact.organization.isEmpty {
                                Text(contact.organization)
                                    .font(.caption)
                                    .foregroundStyle(Theme.textTertiary)
                            }
                        } else {
                            Text("Not linked to a contact")
                                .font(.subheadline)
                                .foregroundStyle(Theme.textTertiary)
                        }
                    }

                    Spacer()

                    if linkedContact != nil {
                        Button("Unlink") {
                            person.contactIdentifier = nil
                        }
                        .font(.caption)
                        .foregroundStyle(Theme.destructive)
                    } else {
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
                                .fontWeight(.medium)
                                .foregroundStyle(Theme.accent)
                                .padding(.horizontal, 10)
                                .padding(.vertical, 4)
                                .background(Theme.accentLight, in: Capsule())
                        }
                    }
                }

                if isEditingName {
                    VStack(spacing: 8) {
                        HStack(spacing: 8) {
                            TextField("First", text: $editedFirst)
                                .textContentType(.givenName)
                            TextField("Middle", text: $editedMiddle)
                                .textContentType(.middleName)
                                .frame(maxWidth: 100)
                            TextField("Last", text: $editedLast)
                                .textContentType(.familyName)
                        }
                        .font(.subheadline)

                        HStack {
                            Button("Cancel") {
                                isEditingName = false
                            }
                            .foregroundStyle(Theme.textSecondary)

                            Spacer()

                            Button("Save") {
                                saveName()
                            }
                            .fontWeight(.semibold)
                            .foregroundStyle(Theme.accent)
                            .disabled(editedFirst.trimmingCharacters(in: .whitespaces).isEmpty)
                        }
                        .font(.subheadline)
                    }
                }
            }

            // Summary
            if !person.summary.isEmpty {
                Section("Summary") {
                    Text(person.summary)
                        .font(.subheadline)
                        .foregroundStyle(Theme.textSecondary)
                }
            }

            // Facts
            if person.facts.isEmpty {
                EmptyStateView(
                    icon: "text.badge.plus",
                    title: "No Facts Yet",
                    description: "Record a voice note mentioning this person to add facts automatically."
                )
                .listRowBackground(Color.clear)
            } else {
                ForEach(groupedFacts, id: \.0) { category, facts in
                    Section {
                        ForEach(facts) { fact in
                            Text(fact.content)
                                .font(.subheadline)
                                .foregroundStyle(Theme.textPrimary)
                                .contentShape(Rectangle())
                                .onTapGesture { editingFact = fact }
                                .swipeActions(edge: .trailing, allowsFullSwipe: true) {
                                    Button(role: .destructive) {
                                        deleteFact(fact)
                                    } label: {
                                        Label("Delete", systemImage: "trash")
                                    }
                                }
                        }
                    } header: {
                        Label(category.capitalized, systemImage: categoryIcon(category))
                    }
                }
            }
        }
        .navigationTitle(person.fullName)
        .toolbar {
            ToolbarItem(placement: .primaryAction) {
                HStack(spacing: 16) {
                    Button {
                        editedFirst = person.firstName
                        editedMiddle = person.middleName
                        editedLast = person.lastName
                        isEditingName = true
                    } label: {
                        Image(systemName: "pencil")
                    }
                    .tint(Theme.accent)

                    Button {
                        showingAddFact = true
                    } label: {
                        Image(systemName: "plus")
                            .fontWeight(.semibold)
                    }
                    .tint(Theme.accent)
                }
            }
        }
        .sheet(isPresented: $showingAddFact) {
            AddFactSheet(person: person)
        }
        .sheet(item: $editingFact) { fact in
            EditFactSheet(fact: fact)
        }
    }

    private func saveName() {
        let first = editedFirst.trimmingCharacters(in: .whitespaces)
        guard !first.isEmpty else { return }
        person.firstName = first
        person.middleName = editedMiddle.trimmingCharacters(in: .whitespaces)
        person.lastName = editedLast.trimmingCharacters(in: .whitespaces)
        person.updatedAt = Date()
        isEditingName = false
    }

    private func deleteFact(_ fact: Fact) {
        person.facts.removeAll { $0.id == fact.id }
        modelContext.delete(fact)
    }

    private func categoryIcon(_ category: String) -> String {
        switch category {
        case "work": return "briefcase.fill"
        case "family": return "house.fill"
        case "interests": return "star.fill"
        case "location": return "mappin"
        case "education": return "graduationcap.fill"
        case "personality": return "face.smiling"
        case "relationship": return "heart.fill"
        case "health": return "heart.text.square"
        case "events": return "calendar"
        case "appearance": return "person.fill"
        case "preferences": return "hand.thumbsup.fill"
        default: return "tag.fill"
        }
    }
}

#Preview {
    let person = Person(firstName: "Jane", lastName: "Doe")
    return NavigationStack {
        PersonDetailView(person: person)
    }
    .environment(ContactSyncService())
    .modelContainer(for: [Person.self, Fact.self, Entry.self], inMemory: true)
}
