//
//  PrivacyPolicyView.swift
//  AIContactCard
//

import SwiftUI

struct PrivacyPolicyView: View {
    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 24) {
                section("Data We Collect") {
                    """
                    • Voice recordings: Temporarily captured for on-device speech recognition. Audio is never sent to external servers.
                    • Transcripts: The text produced by on-device speech recognition is sent to Anthropic's Claude AI for processing.
                    • Contact names: Names from your iPhone Contacts are sent to the AI so it can match people you mention.
                    • Extracted facts: Names, jobs, interests, and other details the AI extracts are stored locally on your device using SwiftData.
                    """
                }

                section("How Your Data Is Used") {
                    """
                    • Transcripts and contact names are sent to Anthropic's Claude API to extract information about people and answer your questions.
                    • Extracted facts are stored only on your device and are never uploaded elsewhere.
                    • We do not use your data for advertising, analytics, or profiling.
                    """
                }

                section("Third-Party Processing") {
                    """
                    • Anthropic (Claude API): Processes transcripts and contact names to extract and query information. Anthropic's usage policy states that API inputs and outputs are not used to train their models. See anthropic.com/privacy for their full policy.
                    • Cloudflare Workers: Our API proxy runs on Cloudflare Workers. Requests pass through Cloudflare infrastructure but are not stored or logged beyond standard request processing.
                    """
                }

                section("Data Retention") {
                    """
                    • On-device data: Facts and people are stored locally until you delete them.
                    • Transcripts sent to Anthropic: Retained per Anthropic's API data retention policy (typically 30 days for trust & safety, not used for training).
                    • We do not maintain our own server-side database of your data.
                    """
                }

                section("Your Rights") {
                    """
                    • Delete your data: You can delete any person or fact within the app at any time. Uninstalling the app removes all local data.
                    • Revoke permissions: You can revoke microphone or contacts access at any time in iOS Settings.
                    • BYOK mode: You can use your own Anthropic API key, in which case your data is governed entirely by your agreement with Anthropic.
                    """
                }

                section("Children's Privacy") {
                    "This app is not directed at children under 13 and we do not knowingly collect data from children."
                }

                section("Changes to This Policy") {
                    "We may update this policy from time to time. Changes will be reflected in app updates. Continued use of the app constitutes acceptance of the updated policy."
                }

                section("Contact") {
                    "If you have questions about this privacy policy or your data, please contact us through the App Store listing or the support link in Settings."
                }

                Text("Last updated: March 2026")
                    .font(.caption)
                    .foregroundStyle(.tertiary)
                    .padding(.top, 8)
            }
            .padding(20)
        }
        .navigationTitle("Privacy Policy")
        .navigationBarTitleDisplayMode(.large)
    }

    private func section(_ title: String, content: () -> String) -> some View {
        VStack(alignment: .leading, spacing: 8) {
            Text(title)
                .font(.headline)
            Text(content())
                .font(.subheadline)
                .foregroundStyle(.secondary)
        }
    }
}

#Preview {
    NavigationStack {
        PrivacyPolicyView()
    }
}
