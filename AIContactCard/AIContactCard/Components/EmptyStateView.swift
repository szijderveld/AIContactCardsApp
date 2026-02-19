//
//  EmptyStateView.swift
//  AIContactCard
//

import SwiftUI

struct EmptyStateView: View {
    let icon: String
    let title: String
    let description: String
    var actionLabel: String? = nil
    var action: (() -> Void)? = nil

    var body: some View {
        ContentUnavailableView {
            Label(title, systemImage: icon)
        } description: {
            Text(description)
        } actions: {
            if let actionLabel, let action {
                Button(actionLabel, action: action)
                    .buttonStyle(.borderedProminent)
            }
        }
    }
}

#Preview {
    EmptyStateView(
        icon: "person.crop.circle.badge.questionmark",
        title: "No People Yet",
        description: "Record a voice note on the Record tab to get started.",
        actionLabel: "Get Started",
        action: {}
    )
}
