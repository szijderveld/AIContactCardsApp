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
    @State private var voiceService = VoiceService()

    var body: some Scene {
        WindowGroup {
            ContentView()
                .environment(voiceService)
        }
        .modelContainer(for: [Person.self, Fact.self, Entry.self])
    }
}
