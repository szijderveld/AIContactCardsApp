//
//  ContentView.swift
//  AIContactCard
//
//  Created by Samu Zijderveld on 07/02/2026.
//

import SwiftUI
import SwiftData

struct ContentView: View {
    var body: some View {
        TabView {
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
    }
}

#Preview {
    ContentView()
        .modelContainer(for: [Person.self, Fact.self, Entry.self], inMemory: true)
}
