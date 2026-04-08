// ============================================================
// API REQUEST & RESPONSE MODELS
// ============================================================

import Foundation
import UIKit
import WebKit

// MARK: - Transaction Status

/// Server-side transaction status values.
public enum TransactionStatus: String, Codable {
    case initiated = "INITIATED"
    case pending = "PENDING"
    case processing = "PROCESSING"
    case success = "SUCCESS"
    case successful = "SUCCESSFUL"
    case failed = "FAILED"
    case cancelled = "CANCELLED"
    case expired = "EXPIRED"
    case unknown = "UNKNOWN"
    
    public init(from decoder: Decoder) throws {
        let container = try decoder.singleValueContainer()
        let rawValue = try container.decode(String.self)
        self = TransactionStatus(rawValue: rawValue.uppercased())
            ?? TransactionStatus(rawValue: rawValue)
            ?? .unknown
    }
    
    public var isSuccess: Bool {
        self == .success || self == .successful
    }
    
    public var isPending: Bool {
        self == .initiated || self == .pending || self == .processing || self == .unknown
    }
    
    public var isTerminal: Bool {
        self == .failed || self == .cancelled || self == .expired
    }
}

// MARK: - Payment Status (Client-side)

public enum PaymentStatus: String {
    case idle
    case initializing
    case processing
    case verifying
    case success
    case failed
    case cancelled
}

// MARK: - Payment Step

public enum PaymentStep: String {
    case channelSelection = "channel-selection"
    case paymentDetails = "payment-details"
    case processing
    case otpVerification = "otp-verification"
    case pinVerification = "pin-verification"
    case threeDSecure = "3dsecure"
    case result
}

// MARK: - Card Payment Stage

public enum CardPaymentStage: String, Codable {
    case deviceCollection = "DEVICE_COLLECTION"
    case cardAuthentication3D = "CARD_AUTHENTICATION_3D"
    case pending = "PENDING"
    case completed = "COMPLETED"
    case failed = "FAILED"
}

// MARK: - Expiration Month

public enum ExpirationMonth: String, Codable {
    case january = "JANUARY"
    case february = "FEBRUARY"
    case march = "MARCH"
    case april = "APRIL"
    case may = "MAY"
    case june = "JUNE"
    case july = "JULY"
    case august = "AUGUST"
    case september = "SEPTEMBER"
    case october = "OCTOBER"
    case november = "NOVEMBER"
    case december = "DECEMBER"
    
    public static func from(month: Int) -> ExpirationMonth? {
        switch month {
        case 1: return .january
        case 2: return .february
        case 3: return .march
        case 4: return .april
        case 5: return .may
        case 6: return .june
        case 7: return .july
        case 8: return .august
        case 9: return .september
        case 10: return .october
        case 11: return .november
        case 12: return .december
        default: return nil
        }
    }
}

// MARK: - Initiate Transaction

struct InitiateTransactionRequest: Encodable {
    let merchantRef: String
    let amount: Int
    let currency: String
    let paymentChannelCode: String
    let chargeAllocation: String
    let narration: String
    let customerDetails: CustomerDetails
    let deviceFingerprint: String
}

struct APIPaymentChannel: Decodable {
    let id: String?
    let code: String?
    let name: String?
    let description: String?
    let isActive: Bool?
    let icon: String?
}

struct InitiateTransactionResponse: Decodable {
    let systemTxRef: String?
    let merchantRef: String?
    let status: TransactionStatus?
    let amount: Double
    let currency: String?
    let message: String?
    let transactionId: String?
    let processRef: String?
    let redirectUrl: String?
    let initInstruction: String?
    let channelSpecificData: [String: AnyCodable]?
    let channels: [APIPaymentChannel]?
    let live: Bool?
    
    private enum CodingKeys: String, CodingKey {
        case systemTxRef, merchantRef, status, amount, currency, message
        case transactionId, processRef, redirectUrl, initInstruction
        case channelSpecificData, channels, live
        // snake_case alternatives
        case system_tx_ref, merchant_ref, transaction_id
        case process_ref, redirect_url, init_instruction
        case channel_specific_data
    }
    
    init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        // Try camelCase first, then snake_case
        systemTxRef = (try? container.decodeIfPresent(String.self, forKey: .systemTxRef))
            ?? (try? container.decodeIfPresent(String.self, forKey: .system_tx_ref))
        merchantRef = (try? container.decodeIfPresent(String.self, forKey: .merchantRef))
            ?? (try? container.decodeIfPresent(String.self, forKey: .merchant_ref))
        status = try? container.decodeIfPresent(TransactionStatus.self, forKey: .status)
        currency = try? container.decodeIfPresent(String.self, forKey: .currency)
        message = try? container.decodeIfPresent(String.self, forKey: .message)
        transactionId = (try? container.decodeIfPresent(String.self, forKey: .transactionId))
            ?? (try? container.decodeIfPresent(String.self, forKey: .transaction_id))
        processRef = (try? container.decodeIfPresent(String.self, forKey: .processRef))
            ?? (try? container.decodeIfPresent(String.self, forKey: .process_ref))
        redirectUrl = (try? container.decodeIfPresent(String.self, forKey: .redirectUrl))
            ?? (try? container.decodeIfPresent(String.self, forKey: .redirect_url))
        initInstruction = (try? container.decodeIfPresent(String.self, forKey: .initInstruction))
            ?? (try? container.decodeIfPresent(String.self, forKey: .init_instruction))
        channelSpecificData = (try? container.decodeIfPresent([String: AnyCodable].self, forKey: .channelSpecificData))
            ?? (try? container.decodeIfPresent([String: AnyCodable].self, forKey: .channel_specific_data))
        channels = try? container.decodeIfPresent([APIPaymentChannel].self, forKey: .channels)
        live = try? container.decodeIfPresent(Bool.self, forKey: .live)
        
        // amount can be Int or Double from the API
        if let doubleAmount = try? container.decode(Double.self, forKey: .amount) {
            amount = doubleAmount
        } else {
            amount = 0
        }
    }
}

// MARK: - Transaction Details

struct TransactionDetailsResponse: Decodable {
    let createdAt: String?
    let updatedAt: String?
    let id: String
    let businessId: String?
    let businessCustomerId: String?
    let settlementBatchId: String?
    let merchantRef: String?
    let systemTxRef: String?
    let amount: Double
    let amountToDebit: Double?
    let currency: String?
    let chargeAllocation: String?
    let systemFee: Double?
    let providerFee: Double?
    let vatAmount: Double?
    let amountSettled: Double?
    let paymentChannelCode: String?
    let selectedChannel: String?
    let status: TransactionStatus
    let processRef: String?
    let processorId: String?
    let narration: String?
    let paymentDetails: [String: AnyCodable]?
    let providerRawResponse: [String: AnyCodable]?
    let customerDetails: [String: AnyCodable]?
    let deviceFingerprint: String?
    let ipAddress: String?
    let notificationSent: Bool?
    let completionTime: String?
    let modifiable: Bool?
    let completed: Bool?
    
    private enum CodingKeys: String, CodingKey {
        case createdAt, updatedAt, id, businessId, businessCustomerId
        case settlementBatchId, merchantRef, systemTxRef, amount, amountToDebit
        case currency, chargeAllocation, systemFee, providerFee, vatAmount
        case amountSettled, paymentChannelCode, selectedChannel, status
        case processRef, processorId, narration, paymentDetails
        case providerRawResponse, customerDetails, deviceFingerprint
        case ipAddress, notificationSent, completionTime, modifiable, completed
    }
    
    init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        createdAt = try container.decodeIfPresent(String.self, forKey: .createdAt)
        updatedAt = try container.decodeIfPresent(String.self, forKey: .updatedAt)
        id = try container.decode(String.self, forKey: .id)
        businessId = try container.decodeIfPresent(String.self, forKey: .businessId)
        businessCustomerId = try container.decodeIfPresent(String.self, forKey: .businessCustomerId)
        settlementBatchId = try container.decodeIfPresent(String.self, forKey: .settlementBatchId)
        merchantRef = try container.decodeIfPresent(String.self, forKey: .merchantRef)
        systemTxRef = try container.decodeIfPresent(String.self, forKey: .systemTxRef)
        currency = try container.decodeIfPresent(String.self, forKey: .currency)
        chargeAllocation = try container.decodeIfPresent(String.self, forKey: .chargeAllocation)
        paymentChannelCode = try container.decodeIfPresent(String.self, forKey: .paymentChannelCode)
        selectedChannel = try container.decodeIfPresent(String.self, forKey: .selectedChannel)
        status = (try? container.decode(TransactionStatus.self, forKey: .status)) ?? .unknown
        processRef = try container.decodeIfPresent(String.self, forKey: .processRef)
        processorId = try container.decodeIfPresent(String.self, forKey: .processorId)
        narration = try container.decodeIfPresent(String.self, forKey: .narration)
        paymentDetails = try container.decodeIfPresent([String: AnyCodable].self, forKey: .paymentDetails)
        providerRawResponse = try container.decodeIfPresent([String: AnyCodable].self, forKey: .providerRawResponse)
        customerDetails = try container.decodeIfPresent([String: AnyCodable].self, forKey: .customerDetails)
        deviceFingerprint = try container.decodeIfPresent(String.self, forKey: .deviceFingerprint)
        ipAddress = try container.decodeIfPresent(String.self, forKey: .ipAddress)
        notificationSent = try container.decodeIfPresent(Bool.self, forKey: .notificationSent)
        completionTime = try container.decodeIfPresent(String.self, forKey: .completionTime)
        modifiable = try container.decodeIfPresent(Bool.self, forKey: .modifiable)
        completed = try container.decodeIfPresent(Bool.self, forKey: .completed)
        
        // All monetary fields: decode as Double (API may send Int or Double)
        amount = (try? container.decode(Double.self, forKey: .amount)) ?? 0
        amountToDebit = try? container.decodeIfPresent(Double.self, forKey: .amountToDebit)
        systemFee = try? container.decodeIfPresent(Double.self, forKey: .systemFee)
        providerFee = try? container.decodeIfPresent(Double.self, forKey: .providerFee)
        vatAmount = try? container.decodeIfPresent(Double.self, forKey: .vatAmount)
        amountSettled = try? container.decodeIfPresent(Double.self, forKey: .amountSettled)
    }
}

// MARK: - Select Channel

struct SelectChannelRequest: Encodable {
    let transactionId: String
    let channelCode: String
}

struct SelectChannelResponse: Decodable {
    let status: String?
    let message: String?
    let data: SelectChannelData?
    
    struct SelectChannelData: Decodable {
        let bankName: String?
        let accountNumber: String?
        let accountName: String?
        let expiresAt: String?
        let ussdCode: String?
        let ussdString: String?
    }
}

// MARK: - Bank Transfer

struct BankTransferProviderResponse: Decodable {
    let providerId: String
    let providerName: String
    let bankName: String?
    let oneTimeAccountSuccessRate: Double?
    let averageTimeToTransactionNotificationMs: Int?
    let totalAssignedOneTimeAccounts: Int?
    let totalCompletedOneTimeAccounts: Int?
}

struct InitiateBankTransferRequest: Encodable {
    let providerKey: String
    let accountName: String
    let reference: String
    let accountType: String
    let metadata: [String: AnyCodable]?
}

struct InitiateBankTransferResponse: Decodable {
    let accountId: String?
    let accountName: String?
    let accountType: String?
    let accountNumber: String?
    let reference: String?
    let metadata: [String: AnyCodable]?
    let status: String?
}

// MARK: - Card Payment

struct CardDataPayload: Encodable {
    let cardHolderName: String
    let cardNumber: String
    let expirationMonth: String  // "JANUARY", "FEBRUARY", etc.
    let expirationYear: Int
    let cvv: String
}

struct AmountDataPayload: Encodable {
    let authorizedAmount: Int
    let totalAmount: Int
    let currency: String
}

struct DeviceInformationPayload: Encodable {
    let userAgentBrowserValue: String
    let httpAcceptBrowserValue: String
    let httpBrowserColorDepth: String
    let httpBrowserJavaEnabled: Bool
    let httpBrowserJavaScriptEnabled: Bool
    let httpBrowserLanguage: String
    let httpBrowserScreenHeight: String
    let httpBrowserScreenWidth: String
    let httpBrowserTimeDifference: String
    let httpAcceptContent: String
    
    /// Cached WKWebView user agent string (populated at SDK init)
    static var cachedUserAgent: String?
    
    /// Pre-fetch the WKWebView user agent. Call from main thread early in the SDK lifecycle.
    static func prefetchUserAgent() {
        guard cachedUserAgent == nil else { return }
        let webView = WKWebView(frame: .zero)
        webView.evaluateJavaScript("navigator.userAgent") { result, _ in
            if let ua = result as? String {
                cachedUserAgent = ua
            }
        }
    }
    
    static func `default`() -> DeviceInformationPayload {
        let screen = UIScreen.main.bounds
        let locale = Locale.current
        let timeZone = TimeZone.current
        let offsetMinutes = timeZone.secondsFromGMT() / 60
        
        // Use cached WKWebView user agent (matches what 3DS WebView will send),
        // falling back to a standard iOS Safari user agent string.
        let userAgent = cachedUserAgent
            ?? "Mozilla/5.0 (iPhone; CPU iPhone OS 17_0 like Mac OS X) AppleWebKit/605.1.15 (KHTML, like Gecko) Version/17.0 Mobile/15E148 Safari/604.1"
        
        let acceptHeader = "text/html,application/xhtml+xml,application/xml;q=0.9,*/*;q=0.8"
        
        return DeviceInformationPayload(
            userAgentBrowserValue: userAgent,
            httpAcceptBrowserValue: acceptHeader,
            httpBrowserColorDepth: "32",
            httpBrowserJavaEnabled: false,
            httpBrowserJavaScriptEnabled: true,
            httpBrowserLanguage: locale.languageCode ?? "en",
            httpBrowserScreenHeight: "\(Int(screen.height))",
            httpBrowserScreenWidth: "\(Int(screen.width))",
            httpBrowserTimeDifference: "\(offsetMinutes)",
            httpAcceptContent: acceptHeader
        )
    }
}

struct ProcessCardRequest: Encodable {
    let cardData: CardDataPayload
    let amountData: AmountDataPayload
    let deviceInformation: DeviceInformationPayload
    let saveCard: Bool
}

struct EmbeddableContent: Decodable {
    let embedableType: String?  // "DEVICE_COLLECTION" or "3DS_CHALLENGE"
    let url: String?
    let accessToken: String?
    let html: String
}

struct ProcessCardResponse: Decodable {
    let transactionId: String?
    let clientReference: String?
    let amount: Double?
    let currency: String?
    let status: String?
    let stage: CardPaymentStage?
    let message: String?
    let cardToken: String?
    let cardMaskedNumber: String?
    let authenticationRequired: Bool?
    let embedable: EmbeddableContent?
}

struct ConsumerAuthenticationInfo: Encodable {
    let deviceChannel: String
    let referenceId: String
    let transactionMode: String
    let returnUrl: String
}

struct AuthenticateCardRequest: Encodable {
    let clientReferenceInformationCode: String
    let consumerAuthenticationInformation: ConsumerAuthenticationInfo
}

struct AuthenticateCardResponse: Decodable {
    let transactionId: String?
    let stage: CardPaymentStage?
    let authenticationRequired: Bool?
    let message: String?
    let embedable: EmbeddableContent?
}

struct TransactionByRefResponse: Decodable {
    let systemTxRef: String?
    let merchantRef: String?
    let amount: Double?
    let currency: String?
    let status: TransactionStatus
    let completed: Bool?
    let message: String?
    let completionTime: String?
}

// MARK: - USSD

public struct USSDBank: Decodable {
    public let code: String
    public let name: String
    public let ussdSupported: Bool
}

struct USSDBanksResponseWrapper: Decodable {
    let success: Bool
    let data: USSDBanksData
    
    struct USSDBanksData: Decodable {
        let banks: [USSDBank]
    }
}

struct InitiateUSSDCodeRequest: Encodable {
    let bankCode: String
    let metadata: [String: AnyCodable]?
}

struct InitiateUSSDCodeResponse: Decodable {
    let success: Bool
    let message: String
    let data: USSDCodeData
    
    struct USSDCodeData: Decodable {
        let transactionReference: String
        let status: String
        let statusMessage: String
        let ussdCode: String?
    }
}

struct InitiatePayattitudeRequest: Encodable {
    let customerPhone: String
    let metadata: [String: AnyCodable]?
}

struct InitiatePayattitudeResponse: Decodable {
    let success: Bool
    let message: String?
    let data: PayattitudeData?
    
    struct PayattitudeData: Decodable {
        let transactionReference: String?
        let status: String?
        let statusMessage: String?
    }
}

// MARK: - Saved Cards

public struct SavedCard: Decodable {
    public let id: String
    public let cardToken: String
    public let maskedPan: String
    public let cardHolderName: String
    public let cardType: String  // "VISA", "MASTERCARD", "VERVE", etc.
    public let expiryMonth: Int
    public let expiryYear: Int
    public let isActive: Bool
    public let isDefault: Bool
    public let createdAt: String?
    public let updatedAt: String?
}

struct SavedCardsResponseWrapper: Decodable {
    let success: Bool?
    let message: String?
    let data: [SavedCard]
    let traceId: String?
    let responseCode: Int?
}

struct ProcessSavedCardRequest: Encodable {
    let cardToken: String
    let cvv: String
    let amountData: AmountDataPayload
    let deviceInformation: DeviceInformationPayload
}

// MARK: - Netapps Marketplace

struct InitiateNetAppsMarketplaceRequest: Encodable {
    let beneficiary: String
    let metadata: [String: AnyCodable]?
}

struct InitiateNetAppsMarketplaceResponse: Decodable {
    let success: Bool
    let data: MarketplaceData
    
    struct MarketplaceData: Decodable {
        let checkoutUrl: String
        let reference: String
        let expiresAt: Int
    }
}

// MARK: - Test Cards

public struct TestCard: Decodable {
    public let cardNumber: String
    public let cardType: String
    public let expirationMonth: Int
    public let expirationYear: Int
    public let flowType: String
    public let description: String
    public let cvv: String?
    public let cardHolderName: String?
}

struct TestCardsResponseWrapper: Decodable {
    let success: Bool?
    let message: String?
    let data: [TestCard]
    let traceId: String?
    let responseCode: Int?
}

// MARK: - Generic API Wrapper (for responses wrapped in { success, data })

struct APIDataWrapper<T: Decodable>: Decodable {
    let success: Bool?
    let data: T
}

// MARK: - AnyCodable Helper

/// Lightweight type-erased Codable wrapper for arbitrary JSON values.
public struct AnyCodable: Codable {
    public let value: Any
    
    public init(_ value: Any) {
        self.value = value
    }
    
    public init(from decoder: Decoder) throws {
        let container = try decoder.singleValueContainer()
        if container.decodeNil() {
            value = NSNull()
        } else if let bool = try? container.decode(Bool.self) {
            value = bool
        } else if let int = try? container.decode(Int.self) {
            value = int
        } else if let double = try? container.decode(Double.self) {
            value = double
        } else if let string = try? container.decode(String.self) {
            value = string
        } else if let array = try? container.decode([AnyCodable].self) {
            value = array.map { $0.value }
        } else if let dict = try? container.decode([String: AnyCodable].self) {
            value = dict.mapValues { $0.value }
        } else {
            throw DecodingError.dataCorruptedError(in: container, debugDescription: "Unsupported type")
        }
    }
    
    public func encode(to encoder: Encoder) throws {
        var container = encoder.singleValueContainer()
        if value is NSNull {
            try container.encodeNil()
        } else if let bool = value as? Bool {
            try container.encode(bool)
        } else if let int = value as? Int {
            try container.encode(int)
        } else if let double = value as? Double {
            try container.encode(double)
        } else if let string = value as? String {
            try container.encode(string)
        } else if let array = value as? [Any] {
            try container.encode(array.map { AnyCodable($0) })
        } else if let dict = value as? [String: Any] {
            try container.encode(dict.mapValues { AnyCodable($0) })
        } else {
            throw EncodingError.invalidValue(value, .init(codingPath: encoder.codingPath, debugDescription: "Unsupported type"))
        }
    }
}
