// ============================================================
// PAYMENT RESPONSE PAYLOADS
// ============================================================

import Foundation

/// Payload returned on successful payment.
public struct PaymentSuccessPayload {
    public let status: String
    public let merchantRef: String
    public let transactionRef: String
    public let amount: Double
    public let currency: Currency
    public let channel: PaymentChannel
    public let message: String
    public let timestamp: String
    
    init(
        merchantRef: String,
        transactionRef: String,
        amount: Double,
        currency: Currency,
        channel: PaymentChannel,
        message: String
    ) {
        self.status = "success"
        self.merchantRef = merchantRef
        self.transactionRef = transactionRef
        self.amount = amount
        self.currency = currency
        self.channel = channel
        self.message = message
        self.timestamp = ISO8601DateFormatter().string(from: Date())
    }
}

/// Payload returned on failed payment.
public struct PaymentFailedPayload {
    public let status: String
    public let merchantRef: String?
    public let transactionRef: String?
    public let amount: Double
    public let currency: Currency
    public let channel: PaymentChannel?
    public let message: String
    public let errorCode: String?
    public let timestamp: String
    
    init(
        merchantRef: String? = nil,
        transactionRef: String? = nil,
        amount: Double,
        currency: Currency,
        channel: PaymentChannel? = nil,
        message: String,
        errorCode: String? = nil
    ) {
        self.status = "failed"
        self.merchantRef = merchantRef
        self.transactionRef = transactionRef
        self.amount = amount
        self.currency = currency
        self.channel = channel
        self.message = message
        self.errorCode = errorCode
        self.timestamp = ISO8601DateFormatter().string(from: Date())
    }
}

/// Combined payment result.
public enum PaymentResult {
    case success(PaymentSuccessPayload)
    case failed(PaymentFailedPayload)
    case cancelled
}
