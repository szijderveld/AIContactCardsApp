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
    @State private var creditManager = CreditManager()

    let modelContainer: ModelContainer

    init() {
        let schema = Schema([Person.self, Fact.self, Entry.self])
        let config = ModelConfiguration(schema: schema)
        do {
            modelContainer = try ModelContainer(for: schema, configurations: [config])
        } catch {
            // Schema migration failed — delete the old store and retry
            let url = config.url
            let related = [
                url.deletingPathExtension().appendingPathExtension("store-shm"),
                url.deletingPathExtension().appendingPathExtension("store-wal")
            ]
            for file in [url] + related {
                try? FileManager.default.removeItem(at: file)
            }
            modelContainer = try! ModelContainer(for: schema, configurations: [config])
        }
    }

    var body: some Scene {
        WindowGroup {
            RootView()
                .environment(voiceService)
                .environment(aiService)
                .environment(contactSyncService)
                .environment(creditManager)
                .task { await creditManager.fetchBalance() }
                .task { creditManager.startListening() }
                .task { await creditManager.loadProducts() }
        }
        .modelContainer(modelContainer)
    }
}

private struct RootView: View {
    @AppStorage("hasCompletedOnboarding") private var hasCompletedOnboarding = false

    var body: some View {
        if hasCompletedOnboarding {
            ContentView()
        } else {
            OnboardingView()
        }
    }
}
