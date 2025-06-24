import SwiftUI
#if canImport(UIKit) && DEBUG
    import UIKit
#endif

struct ChatView: View {
    @State private var viewModel: ChatViewModel?
    @Environment(\.apiClient) private var apiClient

    var body: some View {
        VStack {
            if let viewModel {
                ScrollView {
                    ScrollViewReader { proxy in
                        VStack(spacing: 12) {
                            ForEach(viewModel.messages) { message in
                                MessageBubbleView(message: message)
                            }
                        }
                        .onChange(of: viewModel.messages.count) { _, _ in
                            // Scroll to the bottom when a new message arrives
                            if let lastMessage = viewModel.messages.last {
                                withAnimation {
                                    proxy.scrollTo(lastMessage.id, anchor: .bottom)
                                }
                            }
                        }
                    }
                }

                HStack {
                    TextField("Ask about your health...", text: Binding(
                        get: { viewModel.currentInput },
                        set: { viewModel.currentInput = $0 }
                    ))
                    .textFieldStyle(.roundedBorder)

                    Button(action: viewModel.sendMessage) {
                        Image(systemName: "arrow.up.circle.fill")
                            .font(.title)
                    }
                    .disabled(viewModel.isSending || viewModel.currentInput.isEmpty)
                }
                .padding()
            } else {
                ProgressView("Loading...")
            }
        }
        .navigationTitle("AI Assistant")
        .task {
            if viewModel == nil {
                // Use the shared APIClient from environment instead of creating a new one
                let insightAIService = InsightAIService(apiClient: apiClient)
                viewModel = ChatViewModel(insightAIService: insightAIService)
            }
        }
    }
}

#Preview {
    NavigationStack {
        ChatView()
    }
}
