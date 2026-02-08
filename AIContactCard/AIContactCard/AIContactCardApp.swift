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
    @State private var aiService = AIService()
    @State private var contactSyncService = ContactSyncService()

    var body: some Scene {
        WindowGroup {
            ContentView()
                .environment(voiceService)
                .environment(aiService)
                .environment(contactSyncService)
        }
        .modelContainer(for: [Person.self, Fact.self, Entry.self])
    }
}
