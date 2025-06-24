import Foundation

/// Defines the comprehensive set of errors that can occur within the networking layer.
enum APIError: Error, LocalizedError {
    /// The URL could not be formed. This is a client-side programming error.
    case invalidURL

    /// An error occurred during the network request, wrapping the underlying `URLError`.
    case networkError(URLError)

    /// The server responded with a non-2xx status code.
    /// Includes the status code and an optional descriptive message from the server.
    case serverError(statusCode: Int, message: String?)

    /// The response data could not be decoded into the expected type.
    /// Wraps the underlying decoding error.
    case decodingError(Error)

    /// The request was unauthorized (401). This typically means the session token is invalid or expired.
    case unauthorized

    /// An unknown or uncategorized error occurred.
    case unknown(Error)

    /// Functionality not yet implemented (for mocks and testing).
    case notImplemented

    /// Validation error for invalid input data
    case validationError(String)

    /// HTTP error with status code and response data
    case httpError(statusCode: Int, data: Data)

    /// Missing authentication token
    case missingAuthToken

    /// Invalid response from server
    case invalidResponse

    /// Email verification required (202 response)
    case emailVerificationRequired

    /// Provides a user-friendly description for each error case.
    public var errorDescription: String? {
        switch self {
        case .invalidURL:
            "The URL provided was invalid."
        case let .networkError(error):
            "Network error: \(error.localizedDescription)"
        case let .serverError(statusCode, message):
            "Server error \(statusCode): \(message ?? "No message")"
        case .decodingError:
            "There was a problem decoding the data from the server."
        case .unauthorized:
            "You are not authorized. Please log in again."
        case .unknown:
            "An unknown error occurred."
        case .notImplemented:
            "This functionality is not yet implemented."
        case let .validationError(message):
            "Validation error: \(message)"
        case let .httpError(statusCode, _):
            "HTTP error: \(statusCode)"
        case .missingAuthToken:
            "Authentication token is missing"
        case .invalidResponse:
            "Invalid response from server"
        case .emailVerificationRequired:
            "Email verification required"
        }
    }

    /// Provides user-friendly messages for UI display
    public var userFriendlyMessage: String {
        switch self {
        case .invalidURL:
            return "We encountered a technical issue. Please try again."
        case let .networkError(error):
            if error.code == .notConnectedToInternet || error.code == .dataNotAllowed {
                return "No internet connection. Please check your network settings."
            }
            return "Network connection issue. Please try again."
        case let .serverError(statusCode, message):
            if statusCode >= 500 {
                return "Our servers are experiencing issues. Please try again later."
            }
            return message ?? "Something went wrong. Please try again."
        case .decodingError:
            return "We received an unexpected response. Please try again."
        case .unauthorized:
            return "Your session has expired. Please log in again."
        case .unknown:
            return "An unexpected error occurred. Please try again."
        case .notImplemented:
            return "This feature is coming soon!"
        case let .validationError(message):
            return message
        case let .httpError(statusCode, _):
            if statusCode >= 500 {
                return "Server error. Please try again later."
            } else if statusCode == 404 {
                return "The requested resource was not found."
            }
            return "Request failed. Please try again."
        case .missingAuthToken:
            return "Please log in to continue."
        case .invalidResponse:
            return "We received an invalid response. Please try again."
        case .emailVerificationRequired:
            return "Please verify your email to continue."
        }
    }
}
