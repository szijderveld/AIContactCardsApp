//
//  RecordView.swift
//  AIContactCard
//

import SwiftUI
import SwiftData

struct RecordView: View {
    @Environment(VoiceService.self) private var voiceService
    @Environment(AIService.self) private var aiService
    @Environment(\.modelContext) private var modelContext

    @Query private var people: [Person]

    @State private var showPermissionAlert = false
    @State private var hasCheckedPermissions = false
    @State private var isProcessing = false
    @State private var extractionResult: ExtractionResult?
    @State private var errorMessage: String?
    @State private var showResult = false
    @State private var showError = false

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
                .disabled(isProcessing)

                // Process button
                if !voiceService.transcript.isEmpty && !voiceService.isRecording {
                    Button("Process with AI") {
                        Task { await processTranscript() }
                    }
                    .buttonStyle(.borderedProminent)
                    .disabled(isProcessing)
                }
            }
            .padding()
            .navigationTitle("Record")
            .overlay {
                if isProcessing {
                    ZStack {
                        Color.black.opacity(0.3)
                            .ignoresSafeArea()
                        VStack(spacing: 12) {
                            ProgressView()
                                .controlSize(.large)
                            Text("Extracting contacts...")
                                .font(.headline)
                        }
                        .padding(24)
                        .background(.regularMaterial, in: RoundedRectangle(cornerRadius: 16))
                    }
                }
            }
            .alert("Permission Required", isPresented: $showPermissionAlert) {
                Button("OK") {}
            } message: {
                Text(voiceService.errorMessage ?? "Microphone and speech recognition permissions are required.")
            }
            .alert("Processing Failed", isPresented: $showError) {
                Button("Retry") {
                    Task { await processTranscript() }
                }
                Button("Cancel", role: .cancel) {}
            } message: {
                Text(errorMessage ?? "An unknown error occurred.")
            }
            .sheet(isPresented: $showResult) {
                voiceService.transcript = ""
                extractionResult = nil
            } content: {
                if let result = extractionResult {
                    ExtractionResultView(result: result)
                }
            }
        }
    }

    private func toggleRecording() async {
        if voiceService.isRecording {
            voiceService.stopRecording()
            return
        }

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

    private func processTranscript() async {
        let transcript = voiceService.transcript
        guard !transcript.isEmpty else { return }

        // Save the Entry to SwiftData
        let entry = Entry(transcript: transcript)
        modelContext.insert(entry)

        isProcessing = true
        errorMessage = nil

        do {
            let result = try await aiService.extract(
                transcript: transcript,
                people: people,
                contacts: []
            )
            persistExtraction(result, transcript: transcript)
            extractionResult = result
            isProcessing = false
            showResult = true
        } catch {
            isProcessing = false
            errorMessage = error.localizedDescription
            showError = true
        }
    }

    private func persistExtraction(_ result: ExtractionResult, transcript: String) {
        for contact in result.contacts {
            let person: Person

            if let matchedId = contact.matchedPersonId,
               let existing = people.first(where: { $0.id.uuidString == matchedId }) {
                person = existing
                // Merge aliases
                for alias in contact.aliases where !person.aliases.contains(alias) {
                    person.aliases.append(alias)
                }
            } else {
                person = Person(name: contact.name)
                person.aliases = contact.aliases
                modelContext.insert(person)
            }

            for extractedFact in contact.facts {
                let fact = Fact(category: extractedFact.category, content: extractedFact.content)
                fact.rawTranscript = transcript
                fact.person = person
                modelContext.insert(fact)
            }

            person.updatedAt = Date()
        }
    }
}

#Preview {
    RecordView()
        .environment(VoiceService())
        .environment(AIService())
        .modelContainer(for: [Person.self, Fact.self, Entry.self], inMemory: true)
}
