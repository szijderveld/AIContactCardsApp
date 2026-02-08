//
//  AIContactCardApp.swift
//  AIContactCard
//
//  Created by Samu Zijderveld on 07/02/2026.
//

import SwiftUI
import SwiftData

@main
struct AIContactCardApp: App {
    var body: some Scene {
        WindowGroup {
            ContentView()
        }
        .modelContainer(for: [Person.self, Fact.self, Entry.self])
    }
}
