// ============================================================
// API CONFIGURATION
// ============================================================

import Foundation

struct APIConfig {
    static let baseURL = "https://payment-gateway.netapps.ng"
    static let apiVersion = "/api/v1"
    static let timeout: TimeInterval = 30
    
    // MARK: - Endpoints
    
    struct Endpoints {
        static let initiateTransaction = "/transactions/initiate"
        static let getTransaction = "/transactions"           // + /:id
        static let getTransactionByRef = "/transactions/ref"   // + /:systemTxRef
        static let selectChannel = "/transactions/select-channel"
        static let bankTransferProviders = "/payments/bank-transfer/providers/performance"
        static let initiateBankTransfer = "/payments/bank-transfer/initiate"
        // Card
        static let processCard = "/payments/card"              // + /:transactionId/process
        static let authenticateCard = "/payments/card"         // + /:transactionId/authenticate
        static let savedCards = "/payments/card"               // + /:transactionId/saved-cards
        static let deleteSavedCard = "/payments/card"          // + /:transactionId/saved-cards/:cardId
        static let testCards = "/payments/card"                // + /:transactionId/test-cards
        // USSD
        static let ussdBanks = "/payments/ussd/banks/ussd-code"
        static let ussdInitiateCode = "/payments/ussd"         // + /:transactionId/initiate/code
        static let ussdInitiatePayattitude = "/payments/ussd"  // + /:transactionId/initiate/push
        // Netapps Marketplace
        static let netappsMarketplaceInitiate = "/payments/netapps"  // + /:transactionId/initiate
    }
    
    // MARK: - Polling
    
    struct Polling {
        static let initialDelay: TimeInterval = 2.0
        static let interval: TimeInterval = 5.0
        static let maxDuration: TimeInterval = 600.0  // 10 minutes
        static let maxAttempts = 120
    }
    
    // MARK: - SSE
    
    struct SSE {
        static let pingTimeout: TimeInterval = 15.0       // No keepalive for 15s (3 missed 5s pings) → disconnected
        static let reconnectBaseDelay: TimeInterval = 2.0  // Initial reconnect delay (doubles each attempt)
        static let maxReconnectAttempts = 5                // Try 5 times before polling fallback
    }
    
    // MARK: - SSE URL Builder
    
    static func sseSubscribeURL(systemTxRef: String, publicKey: String) -> URL {
        let encoded = publicKey.addingPercentEncoding(withAllowedCharacters: .urlQueryAllowed) ?? publicKey
        return URL(string: "\(baseURL)\(apiVersion)/transactions/sse/\(systemTxRef)/subscribe?publicKey=\(encoded)")!
    }
    
    // MARK: - URL Builders
    
    static func fullURL(for endpoint: String) -> URL {
        URL(string: "\(baseURL)\(apiVersion)\(endpoint)")!
    }
    
    static func transactionURL(id: String) -> URL {
        fullURL(for: "\(Endpoints.getTransaction)/\(id)")
    }
}
