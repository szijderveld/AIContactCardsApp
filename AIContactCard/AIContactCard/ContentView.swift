//
//  ContentView.swift
//  AIContactCard
//
//  Created by Samu Zijderveld on 07/02/2026.
//

import SwiftUI
import SwiftData

struct ContentView: View {
    @Environment(ContactSyncService.self) private var contactSyncService

    var body: some View {
        TabView {
            RecordView()
                .tabItem {
                    Label("Record", systemImage: "mic.circle.fill")
                }

            ChatView()
                .tabItem {
                    Label("Ask", systemImage: "bubble.left.and.text.bubble.right")
                }

            NavigationStack {
                PeopleListView()
                    .navigationDestination(for: Person.self) { person in
                        PersonDetailView(person: person)
                    }
            }
            .tabItem {
                Label("People", systemImage: "person.2.fill")
            }

            NavigationStack {
                Text("Settings")
                    .navigationTitle("Settings")
            }
            .tabItem {
                Label("Settings", systemImage: "gear")
            }
        }
        .task {
            let granted = await contactSyncService.requestAccess()
            if granted {
                contactSyncService.fetchAllContacts()
            }
        }
    }
}

#Preview {
    ContentView()
        .modelContainer(for: [Person.self, Fact.self, Entry.self], inMemory: true)
        .environment(ContactSyncService())
        .environment(VoiceService())
        .environment(AIService())
}
