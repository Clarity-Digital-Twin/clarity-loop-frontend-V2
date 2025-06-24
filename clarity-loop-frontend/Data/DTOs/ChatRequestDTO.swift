import Foundation

// MARK: - Chat Request DTO

/// Request DTO for chat interaction with health AI
struct ChatRequestDTO: Codable {
    /// The user's message
    let message: String
    
    /// Optional context for the conversation
    let context: ChatContext?
}

/// Context for maintaining conversation state
struct ChatContext: Codable {
    /// Optional conversation ID for maintaining context
    let conversationId: String?
    
    /// Optional focus timeframe for health data context
    let focusTimeframe: String?
    
    enum CodingKeys: String, CodingKey {
        case conversationId = "conversation_id"
        case focusTimeframe = "focus_timeframe"
    }
}

// MARK: - Chat Response DTO

/// Response DTO for chat interaction
struct ChatResponseDTO: Codable {
    /// The AI's response message
    let response: String
    
    /// Conversation ID for maintaining context
    let conversationId: String
    
    /// Suggested follow-up questions
    let followUpQuestions: [String]?
    
    /// Relevant health data context
    let relevantData: [String: AnyCodable]?
    
    enum CodingKeys: String, CodingKey {
        case response
        case conversationId = "conversation_id"
        case followUpQuestions = "follow_up_questions"
        case relevantData = "relevant_data"
    }
}