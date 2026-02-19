//
//  OnboardingView.swift
//  AIContactCard
//

import SwiftUI

struct OnboardingView: View {
    @AppStorage("hasCompletedOnboarding") private var hasCompletedOnboarding = false
    @Environment(VoiceService.self) private var voiceService
    @Environment(ContactSyncService.self) private var contactSyncService

    @State private var currentPage = 0
    @State private var micGranted: Bool?
    @State private var contactsGranted: Bool?

    private let totalPages = 5

    var body: some View {
        VStack(spacing: 0) {
            TabView(selection: $currentPage) {
                introPage(
                    icon: "waveform.circle.fill",
                    title: "Your Voice-First Memory",
                    description: "Speak naturally about the people you meet. Talk about their interests, job, family — anything you want to remember."
                )
                .tag(0)

                introPage(
                    icon: "brain.head.profile",
                    title: "AI Extracts & Organizes",
                    description: "AI listens to your words and automatically pulls out names, facts, and details — organized into tidy contact cards."
                )
                .tag(1)

                introPage(
                    icon: "person.2.circle.fill",
                    title: "Ask About Anyone",
                    description: "Forgot where someone works or what they like? Just ask. Your AI memory has the answers."
                )
                .tag(2)

                permissionPage(
                    icon: "mic.fill",
                    title: "Microphone & Speech",
                    description: "The app needs microphone access to hear you and speech recognition to understand what you say. All processing stays on your device.",
                    granted: micGranted
                )
                .tag(3)

                permissionPage(
                    icon: "person.crop.rectangle.stack.fill",
                    title: "Contacts Access",
                    description: "Linking to your contacts helps the AI match people you mention with contacts you already have.",
                    granted: contactsGranted
                )
                .tag(4)
            }
            .tabViewStyle(.page(indexDisplayMode: .always))
            .animation(.easeInOut, value: currentPage)

            Button(action: handleButtonTap) {
                Text(buttonLabel)
                    .font(.headline)
                    .foregroundStyle(.white)
                    .frame(maxWidth: .infinity)
                    .padding()
                    .background(Color.accentColor)
                    .clipShape(RoundedRectangle(cornerRadius: 14))
            }
            .padding(.horizontal, 24)
            .padding(.bottom, 40)
        }
    }

    // MARK: - Pages

    private func introPage(icon: String, title: String, description: String) -> some View {
        VStack(spacing: 24) {
            Spacer()
            Image(systemName: icon)
                .font(.system(size: 80))
                .foregroundStyle(.accent)
            Text(title)
                .font(.title.bold())
                .multilineTextAlignment(.center)
            Text(description)
                .font(.body)
                .foregroundStyle(.secondary)
                .multilineTextAlignment(.center)
                .padding(.horizontal, 32)
            Spacer()
            Spacer()
        }
    }

    private func permissionPage(icon: String, title: String, description: String, granted: Bool?) -> some View {
        VStack(spacing: 24) {
            Spacer()
            Image(systemName: icon)
                .font(.system(size: 80))
                .foregroundStyle(.accent)
            Text(title)
                .font(.title.bold())
                .multilineTextAlignment(.center)
            Text(description)
                .font(.body)
                .foregroundStyle(.secondary)
                .multilineTextAlignment(.center)
                .padding(.horizontal, 32)

            if let granted {
                HStack(spacing: 8) {
                    Image(systemName: granted ? "checkmark.circle.fill" : "exclamationmark.circle.fill")
                        .foregroundStyle(granted ? .green : .orange)
                    Text(granted ? "Permission granted" : "Not granted — you can enable later in Settings")
                        .font(.subheadline)
                        .foregroundStyle(granted ? .green : .orange)
                }
                .padding(.top, 8)
            }

            Spacer()
            Spacer()
        }
    }

    // MARK: - Button

    private var buttonLabel: String {
        switch currentPage {
        case 0, 1:
            return "Continue"
        case 2:
            return "Get Started"
        case 3:
            return micGranted == nil ? "Enable Microphone" : "Continue"
        case 4:
            return contactsGranted == nil ? "Enable Contacts" : "Start Using App"
        default:
            return "Continue"
        }
    }

    private func handleButtonTap() {
        switch currentPage {
        case 0, 1, 2:
            withAnimation { currentPage += 1 }
        case 3:
            if micGranted == nil {
                Task {
                    let granted = await voiceService.requestPermissions()
                    micGranted = granted
                }
            } else {
                withAnimation { currentPage += 1 }
            }
        case 4:
            if contactsGranted == nil {
                Task {
                    let granted = await contactSyncService.requestAccess()
                    contactsGranted = granted
                    if granted {
                        contactSyncService.fetchAllContacts()
                    }
                }
            } else {
                hasCompletedOnboarding = true
            }
        default:
            break
        }
    }
}
