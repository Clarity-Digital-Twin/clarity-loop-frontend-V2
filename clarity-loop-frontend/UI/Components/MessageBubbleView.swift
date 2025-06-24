import SwiftUI

struct MessageBubbleView: View {
    let message: ChatMessage

    var body: some View {
        HStack {
            if message.sender == .user {
                Spacer()
            }

            VStack(alignment: .leading, spacing: 4) {
                Text(message.text)

                if message.isError {
                    Text("Error")
                        .font(.caption)
                        .foregroundColor(.red)
                }
            }
            .padding(12)
            .background(bubbleColor)
            .foregroundColor(textColor)
            .cornerRadius(16)

            if message.sender == .assistant {
                Spacer()
            }
        }
    }

    private var bubbleColor: Color {
        if message.isError {
            return .red.opacity(0.2)
        }
        return message.sender == .user ? .blue : Color(.systemGray5)
    }

    private var textColor: Color {
        if message.isError {
            return .primary
        }
        return message.sender == .user ? .white : .primary
    }
}
