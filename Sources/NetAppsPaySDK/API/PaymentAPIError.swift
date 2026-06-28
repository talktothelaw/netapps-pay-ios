// ============================================================
// PAYMENT API ERROR
// ============================================================

import Foundation

/// Strips URLs, file paths, and technical details from error messages
/// so they are safe to display to end users.
private func sanitizeErrorMessage(_ message: String) -> String {
    var sanitized = message
        .replacingOccurrences(of: "https?://[^\\s)\"',]+", with: "", options: .regularExpression)
        .replacingOccurrences(of: "/[a-zA-Z0-9_.\\-/]+", with: "", options: .regularExpression)
        .trimmingCharacters(in: .whitespacesAndNewlines)
    if sanitized.localizedCaseInsensitiveContains("timed out") || sanitized.localizedCaseInsensitiveContains("timeout") {
        return "Request timed out. Please try again."
    }
    if sanitized.isEmpty || sanitized.count < 5 {
        return "Something went wrong. Please try again."
    }
    // Remove trailing colons and collapse extra whitespace
    while sanitized.hasSuffix(":") { sanitized = String(sanitized.dropLast()).trimmingCharacters(in: .whitespaces) }
    sanitized = sanitized.replacingOccurrences(of: "\\s{2,}", with: " ", options: .regularExpression)
    return sanitized
}

/// Error type for all payment API operations.
public class PaymentAPIError: Error, LocalizedError {
    public let message: String
    public let statusCode: Int
    public let errorCode: String?
    public let details: Any?
    public let isNetworkError: Bool
    public let isTimeout: Bool
    
    public var errorDescription: String? { message }
    
    public init(
        message: String,
        statusCode: Int,
        errorCode: String? = nil,
        details: Any? = nil
    ) {
        self.message = sanitizeErrorMessage(message)
        self.statusCode = statusCode
        self.errorCode = errorCode
        self.details = details
        self.isNetworkError = statusCode == 0
        self.isTimeout = statusCode == 408 || errorCode == "TIMEOUT"
    }
    
    // MARK: - Factory Methods
    
    public static func networkError(
        _ message: String = "Network error. Please check your connection."
    ) -> PaymentAPIError {
        PaymentAPIError(message: message, statusCode: 0, errorCode: "NETWORK_ERROR")
    }
    
    public static func timeoutError(
        _ message: String = "Request timed out. Please try again."
    ) -> PaymentAPIError {
        PaymentAPIError(message: message, statusCode: 408, errorCode: "TIMEOUT")
    }
    
    public static func serverError(
        _ message: String = "Server error. Please try again later."
    ) -> PaymentAPIError {
        PaymentAPIError(message: message, statusCode: 500, errorCode: "SERVER_ERROR")
    }
    
    public static func validationError(
        _ message: String,
        details: Any? = nil
    ) -> PaymentAPIError {
        PaymentAPIError(message: message, statusCode: 400, errorCode: "VALIDATION_ERROR", details: details)
    }
    
    public static func unauthorized(
        _ message: String = "Invalid API key."
    ) -> PaymentAPIError {
        PaymentAPIError(message: message, statusCode: 401, errorCode: "UNAUTHORIZED")
    }
    
    public static func decodingError(
        _ message: String = "Failed to parse server response."
    ) -> PaymentAPIError {
        PaymentAPIError(message: message, statusCode: 0, errorCode: "DECODING_ERROR")
    }

    public static func channelsUnavailable(
        _ message: String = "No payment methods are currently available for this transaction. Please try again later or contact support."
    ) -> PaymentAPIError {
        PaymentAPIError(message: message, statusCode: 0, errorCode: "NO_CHANNELS")
    }
}

// MARK: - Error Messages

public struct ErrorMessages {
    public static let networkError = "Unable to connect. Please check your internet connection and try again."
    public static let timeout = "The request is taking longer than expected. Please try again."
    public static let serverError = "Something went wrong on our end. Please try again later."
    public static let invalidConfig = "Invalid payment configuration. Please contact support."
    public static let invalidCard = "Invalid card details. Please check and try again."
    public static let expiredSession = "Your session has expired. Please start a new payment."
    public static let transactionFailed = "Transaction failed. Please try again or use a different payment method."
    public static let pollingTimeout = "Payment confirmation timed out. Please check your payment status or try again."
}
