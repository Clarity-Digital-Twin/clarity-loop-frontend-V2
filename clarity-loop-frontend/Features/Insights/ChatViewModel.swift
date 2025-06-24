import Foundation
import Observation

/// The ViewModel for the on-demand Gemini chat interface.
@Observable
final class ChatViewModel {
    // MARK: - Properties

    var messages: [ChatMessage] = []
    var currentInput = ""
    var isSending = false

    // MARK: - Dependencies

    private let insightAIService: InsightAIServiceProtocol

    // MARK: - Initializer

    init(insightAIService: InsightAIServiceProtocol) {
        self.insightAIService = insightAIService
    }

    // MARK: - Public Methods

    func sendMessage() {
        guard !currentInput.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty else {
            return
        }

        let userMessage = ChatMessage(sender: .user, text: currentInput)
        messages.append(userMessage)
        let tempInput = currentInput
        currentInput = ""

        isSending = true
        messages.append(ChatMessage(sender: .assistant, text: "..."))

        Task {
            do {
                print("💬 ChatViewModel: Sending message: \(tempInput)")
                let response = try await insightAIService.generateChatResponse(
                    userMessage: tempInput,
                    conversationHistory: messages,
                    healthContext: nil
                )

                print("✅ ChatViewModel: Received response")

                // Remove the "..." typing indicator
                _ = messages.popLast()

                let assistantMessage = ChatMessage(sender: .assistant, text: response.narrative)
                messages.append(assistantMessage)

            } catch {
                print("❌ ChatViewModel: Error - \(error)")
                // Remove the "..." typing indicator
                _ = messages.popLast()

                var errorText = "Sorry, I couldn't process your request. Please try again."
                if let apiError = error as? APIError {
                    errorText = "Error: \(apiError.localizedDescription)"
                }

                let errorMessage = ChatMessage(sender: .assistant, text: errorText, isError: true)
                messages.append(errorMessage)
            }
            isSending = false
        }
    }
}
