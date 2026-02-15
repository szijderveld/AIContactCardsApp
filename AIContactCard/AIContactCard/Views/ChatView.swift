//
//  ChatView.swift
//  AIContactCard
//

import SwiftUI
import SwiftData

struct ChatView: View {
    @Environment(AIService.self) private var aiService
    @Environment(VoiceService.self) private var voiceService
    @Environment(ContactSyncService.self) private var contactSyncService

    @Query private var people: [Person]

    @State private var messages: [ChatMessage] = []
    @State private var inputText = ""
    @State private var isLoading = false
    @State private var hasCheckedPermissions = false
    @State private var showPermissionAlert = false

    var body: some View {
        NavigationStack {
            VStack(spacing: 0) {
                messageList
                inputBar
            }
            .navigationTitle("Ask")
            .alert("Permission Required", isPresented: $showPermissionAlert) {
                Button("OK") {}
            } message: {
                Text(voiceService.errorMessage ?? "Microphone and speech recognition permissions are required.")
            }
        }
    }

    // MARK: - Message List

    private var messageList: some View {
        ScrollViewReader { proxy in
            ScrollView {
                if messages.isEmpty {
                    emptyState
                } else {
                    LazyVStack(spacing: 12) {
                        ForEach(messages) { message in
                            MessageBubble(message: message)
                        }

                        if isLoading {
                            HStack {
                                ProgressView()
                                    .padding(12)
                                    .background(Color(.systemGray5))
                                    .clipShape(RoundedRectangle(cornerRadius: 16))
                                Spacer(minLength: 60)
                            }
                        }

                        Color.clear
                            .frame(height: 1)
                            .id("bottom")
                    }
                    .padding()
                }
            }
            .onChange(of: messages.count) {
                withAnimation {
                    proxy.scrollTo("bottom")
                }
            }
        }
    }

    private var emptyState: some View {
        ContentUnavailableView {
            Label("Ask About Your People", systemImage: "bubble.left.and.text.bubble.right")
        } description: {
            Text("Ask questions about people you've recorded notes about.")
        } actions: {
            VStack(alignment: .leading, spacing: 8) {
                Text("Try asking:")
                    .font(.subheadline)
                    .foregroundStyle(.secondary)
                exampleButton("What do you know about Sarah?")
                exampleButton("Who works in finance?")
                exampleButton("Tell me about John's family")
            }
        }
        .padding(.top, 60)
    }

    private func exampleButton(_ text: String) -> some View {
        Button {
            inputText = text
        } label: {
            Text(text)
                .font(.subheadline)
                .padding(.horizontal, 12)
                .padding(.vertical, 6)
                .background(Color(.systemGray6))
                .clipShape(RoundedRectangle(cornerRadius: 8))
        }
    }

    // MARK: - Input Bar

    private var inputBar: some View {
        HStack(alignment: .bottom, spacing: 8) {
            // Mic button
            Button {
                Task { await toggleRecording() }
            } label: {
                Image(systemName: voiceService.isRecording ? "stop.circle.fill" : "mic.fill")
                    .font(.title2)
                    .foregroundStyle(voiceService.isRecording ? .red : .blue)
                    .frame(width: 36, height: 36)
            }
            .disabled(isLoading)

            // Text field
            TextField("Ask about someone...", text: $inputText, axis: .vertical)
                .lineLimit(1...4)
                .textFieldStyle(.plain)
                .padding(.horizontal, 12)
                .padding(.vertical, 8)
                .background(Color(.systemGray6))
                .clipShape(RoundedRectangle(cornerRadius: 20))
                .onChange(of: voiceService.transcript) {
                    if voiceService.isRecording {
                        inputText = voiceService.transcript
                    }
                }

            // Send button
            Button {
                Task { await sendMessage() }
            } label: {
                Image(systemName: "arrow.up.circle.fill")
                    .font(.title2)
                    .foregroundStyle(canSend ? .blue : .gray)
                    .frame(width: 36, height: 36)
            }
            .disabled(!canSend)
        }
        .padding(.horizontal)
        .padding(.vertical, 8)
        .background(.bar)
    }

    private var canSend: Bool {
        !inputText.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
            && !isLoading
            && !voiceService.isRecording
    }

    // MARK: - Actions

    private func sendMessage() async {
        let question = inputText.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !question.isEmpty else { return }

        let userMessage = ChatMessage(role: .user, content: question)
        messages.append(userMessage)
        inputText = ""
        isLoading = true

        do {
            let response = try await aiService.query(
                question: question,
                people: people,
                contacts: contactSyncService.allContacts
            )
            let assistantMessage = ChatMessage(role: .assistant, content: response)
            messages.append(assistantMessage)
        } catch {
            let errorText = "Sorry, I couldn't process your question. \(error.localizedDescription)"
            let errorMessage = ChatMessage(role: .assistant, content: errorText)
            messages.append(errorMessage)
        }

        isLoading = false
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
}

#Preview {
    ChatView()
        .environment(VoiceService())
        .environment(AIService())
        .environment(ContactSyncService())
        .modelContainer(for: [Person.self, Fact.self, Entry.self], inMemory: true)
}
