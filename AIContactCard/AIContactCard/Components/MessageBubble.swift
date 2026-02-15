//
//  MessageBubble.swift
//  AIContactCard
//

import SwiftUI

enum MessageRole {
    case user
    case assistant
}

struct ChatMessage: Identifiable {
    let id = UUID()
    let role: MessageRole
    let content: String
    let timestamp = Date()
}

struct MessageBubble: View {
    let message: ChatMessage

    var body: some View {
        HStack {
            if message.role == .user {
                Spacer(minLength: 60)
            }

            Text(message.content)
                .padding(12)
                .background(backgroundColor)
                .foregroundStyle(foregroundColor)
                .clipShape(RoundedRectangle(cornerRadius: 16))

            if message.role == .assistant {
                Spacer(minLength: 60)
            }
        }
    }

    private var backgroundColor: Color {
        message.role == .user ? .blue : Color(.systemGray5)
    }

    private var foregroundColor: Color {
        message.role == .user ? .white : .primary
    }
}

#Preview {
    VStack(spacing: 12) {
        MessageBubble(message: ChatMessage(role: .user, content: "What do you know about Sarah?"))
        MessageBubble(message: ChatMessage(role: .assistant, content: "Sarah works at Google as a product manager. She has a daughter named Emma who is 8 years old."))
    }
    .padding()
}
