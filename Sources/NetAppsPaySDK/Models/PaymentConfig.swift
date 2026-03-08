// ============================================================
// PAYMENT CONFIGURATION - Input from Merchant
// ============================================================

import Foundation

/// Currency types supported by the payment gateway.
public enum Currency: String, Codable {
    case NGN
    case USD
}

/// Payment channels available.
public enum PaymentChannel: String, Codable, CaseIterable {
    case card
    case ussd
    case transfer
    case payattitude
    case moniflow = "netapps_marketplace"
    
    /// Fallback display name (used only when API channel names are unavailable).
    public var displayName: String {
        switch self {
        case .card: return "Card"
        case .ussd: return "USSD Payment"
        case .transfer: return "Bank Transfer"
        case .payattitude: return "Push USSD Payment"
        case .moniflow: return "MoniFlow"
        }
    }
    
    /// Fallback short name (used only when API channel names are unavailable).
    public var shortName: String {
        switch self {
        case .card: return "Card"
        case .ussd: return "USSD"
        case .transfer: return "Bank"
        case .payattitude: return "Push"
        case .moniflow: return "MoniFlow"
        }
    }
    
    /// Maps API channel codes to internal PaymentChannel cases.
    public static func fromAPICode(_ code: String) -> PaymentChannel? {
        switch code.lowercased() {
        case "card": return .card
        case "bank_transfer", "transfer": return .transfer
        case "ussd_code", "ussd": return .ussd
        case "ussd_push", "payattitude", "pay_attitude": return .payattitude
        case "netapps_marketplace", "marketplace", "moniflow": return .moniflow
        default: return nil
        }
    }
}

/// Determines who bears the transaction charge.
public enum ChargeAllocation: String, Codable {
    case merchant = "MERCHANT"
    case customer = "CUSTOMER"
}

/// Customer details passed to the API.
public struct CustomerDetails: Codable {
    public let locality: String
    public let city: String
    public let email: String
    public let phone: String
    public let firstName: String
    public let lastName: String
    public let address1: String
    public let address2: String
    public let postalCode: String
    public let customerId: String
    public let administrativeArea: String
    
    public init(
        locality: String,
        email: String,
        firstName: String,
        lastName: String,
        customerId: String,
        city: String = "Lagos",
        phone: String = "",
        address1: String = "",
        address2: String = "",
        postalCode: String = "100248",
        administrativeArea: String = "Lagos"
    ) {
        self.locality = locality
        self.city = city
        self.email = email
        self.phone = phone
        self.firstName = firstName
        self.lastName = lastName
        self.address1 = address1
        self.address2 = address2
        self.postalCode = postalCode
        self.customerId = customerId
        self.administrativeArea = administrativeArea
    }
}

/// Configuration provided by the merchant to initiate a payment.
public struct PaymentConfig {
    // Required – must be provided at init
    public let publicKey: String
    public let amount: Int               // Amount in minor units (kobo/cents)
    public let currency: Currency
    public let email: String
    public let fullName: String
    public let address1: String
    public let address2: String
    public let phoneNumber: String
    public let narration: String
    public let paymentChannels: [PaymentChannel]
    public let defaultChannel: PaymentChannel
    public let metadata: [String: Any]
    public let city: String
    
    // Optional transaction details
    public var transactionRef: String?
    public var productName: String?
    public var cardHolderName: String?
    
    // Customer details (optional – defaults applied)
    public var customerId: String?
    public var postalCode: String?
    public var locality: String?            // Country code e.g. "NG"
    public var administrativeArea: String?  // State e.g. "Lagos"
    
    // Payment options
    public var chargeAllocation: ChargeAllocation = .customer
    
    // UI customization
    public var businessName: String?
    public var logoURL: String?
    
    // Feature flags
    public var enableSaveCard: Bool = false
    public var showTransactionSummary: Bool = true
    
    // Mode
    public var isTest: Bool = false
    public var debugMode: Bool = false
    
    public init(
        publicKey: String,
        amount: Int,
        currency: Currency,
        email: String,
        fullName: String,
        address1: String,
        address2: String,
        phoneNumber: String,
        narration: String,
        paymentChannels: [PaymentChannel],
        defaultChannel: PaymentChannel,
        metadata: [String: Any],
        city: String
    ) {
        self.publicKey = publicKey
        self.amount = amount
        self.currency = currency
        self.email = email
        self.fullName = fullName
        self.address1 = address1
        self.address2 = address2
        self.phoneNumber = phoneNumber
        self.narration = narration
        self.paymentChannels = paymentChannels
        self.defaultChannel = defaultChannel
        self.metadata = metadata
        self.city = city
    }
    
    /// Build `CustomerDetails` from the config fields.
    internal func buildCustomerDetails() -> CustomerDetails {
        let names = fullName.split(separator: " ", maxSplits: 1)
        let firstName = names.first.map(String.init) ?? fullName
        let lastName = names.count > 1 ? String(names[1]) : ""
        
        return CustomerDetails(
            locality: locality ?? "NG",
            email: email,
            firstName: firstName,
            lastName: lastName,
            customerId: customerId ?? email,
            city: city,
            phone: phoneNumber,
            address1: address1,
            address2: address2,
            postalCode: postalCode ?? "100248",
            administrativeArea: administrativeArea ?? "Lagos"
        )
    }
}
