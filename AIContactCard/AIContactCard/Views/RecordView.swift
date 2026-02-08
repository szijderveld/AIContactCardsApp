//
//  RecordView.swift
//  AIContactCard
//

import SwiftUI
import SwiftData

struct RecordView: View {
    @Environment(VoiceService.self) private var voiceService
    @Environment(\.modelContext) private var modelContext

    @State private var showPermissionAlert = false
    @State private var hasCheckedPermissions = false

    var body: some View {
        NavigationStack {
            VStack(spacing: 24) {
                // Transcript area
                ScrollView {
                    Text(voiceService.transcript.isEmpty ? "Tap the microphone to start recording..." : voiceService.transcript)
                        .foregroundStyle(voiceService.transcript.isEmpty ? .secondary : .primary)
                        .frame(maxWidth: .infinity, alignment: .leading)
                        .padding()
                }
                .frame(maxHeight: .infinity)

                Spacer()

                // Mic button
                Button {
                    Task { await toggleRecording() }
                } label: {
                    Image(systemName: voiceService.isRecording ? "stop.circle.fill" : "mic.circle.fill")
                        .font(.system(size: 72))
                        .foregroundStyle(voiceService.isRecording ? .red : .blue)
                        .symbolEffect(.pulse, isActive: voiceService.isRecording)
                }

                // Save button
                if !voiceService.transcript.isEmpty && !voiceService.isRecording {
                    Button("Save Entry") {
                        saveEntry()
                    }
                    .buttonStyle(.borderedProminent)
                }
            }
            .padding()
            .navigationTitle("Record")
            .alert("Permission Required", isPresented: $showPermissionAlert) {
                Button("OK") {}
            } message: {
                Text(voiceService.errorMessage ?? "Microphone and speech recognition permissions are required.")
            }
        }
    }

    private func toggleRecording() async {
        if voiceService.isRecording {
            voiceService.stopRecording()
            return
        }

        // Check permissions on first use
        if !hasCheckedPermissions {
            let granted = await voiceService.requestPermissions()
            hasCheckedPermissions = true
            guard granted else {
                showPermissionAlert = true
                return
            }
        }

        do {
            try voiceService.startRecording()
        } catch {
            voiceService.errorMessage = "Failed to start recording: \(error.localizedDescription)"
            showPermissionAlert = true
        }
    }

    private func saveEntry() {
        let entry = Entry(transcript: voiceService.transcript)
        modelContext.insert(entry)
        voiceService.transcript = ""
    }
}

#Preview {
    RecordView()
        .environment(VoiceService())
        .modelContainer(for: [Entry.self], inMemory: true)
}
