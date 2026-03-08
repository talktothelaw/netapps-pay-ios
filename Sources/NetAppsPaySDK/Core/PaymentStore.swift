// ============================================================
// PAYMENT STORE - Central state management
// ============================================================

import Foundation

protocol PaymentStoreDelegate: AnyObject {
    func storeDidUpdateState(_ store: PaymentStore)
    func store(_ store: PaymentStore, didChangeStatus status: PaymentStatus)
    func store(_ store: PaymentStore, didChangeStep step: PaymentStep)
    func store(_ store: PaymentStore, didComplete result: PaymentResult)
    func store(_ store: PaymentStore, didEncounterError error: PaymentAPIError)
}

final class PaymentStore {
    
    // MARK: - Delegate
    
    weak var delegate: PaymentStoreDelegate?
    
    // MARK: - Configuration
    
    private(set) var config: PaymentConfig?
    
    // MARK: - API Response Data
    
    private(set) var apiTransaction: InitiateTransactionResponse?
    private(set) var apiChannels: [APIPaymentChannel] = []
    
    // MARK: - Transaction Status
    
    private(set) var status: PaymentStatus = .idle {
        didSet {
            if status != oldValue {
                delegate?.store(self, didChangeStatus: status)
            }
        }
    }
    
    private(set) var currentStep: PaymentStep = .channelSelection {
        didSet {
            if currentStep != oldValue {
                delegate?.store(self, didChangeStep: currentStep)
            }
        }
    }
    
    private(set) var selectedChannel: PaymentChannel?
    
    // MARK: - Transaction References
    
    private(set) var merchantRef: String?
    private(set) var transactionRef: String?
    private(set) var transactionId: String?
    private(set) var systemTxRef: String?
    
    // MARK: - Card Data
    
    private(set) var savedCards: [SavedCard] = []
    
    // MARK: - Bank Transfer Data
    
    private(set) var bankTransferProviders: [BankTransferProviderResponse] = []
    private(set) var selectedBankProvider: BankTransferProviderResponse?
    private(set) var bankTransferAccount: InitiateBankTransferResponse?
    
    // MARK: - USSD Data
    
    private(set) var ussdBanks: [USSDBank] = []
    private(set) var selectedUssdBank: USSDBank?
    private(set) var ussdCode: String?
    
    // MARK: - UI State
    
    private(set) var isLoading: Bool = false {
        didSet { delegate?.storeDidUpdateState(self) }
    }
    
    private(set) var error: PaymentAPIError? {
        didSet {
            if let error = error {
                delegate?.store(self, didEncounterError: error)
            }
        }
    }
    
    private(set) var lastTransactionStatus: TransactionStatus?
    
    // MARK: - Computed Properties
    
    /// Whether the transaction is in live mode (vs test mode)
    var isLive: Bool {
        return apiTransaction?.live ?? false
    }
    
    /// The display amount from the API response (major units: naira/dollars),
    /// falling back to converting config amount from minor units.
    var responseAmount: Double {
        if let amount = apiTransaction?.amount {
            return amount
        }
        // Fallback: config.amount is in minor units (kobo/cents), convert to major units
        return Double(config?.amount ?? 0) / 100.0
    }
    
    /// The request amount in minor units (kobo/cents) for API request payloads
    var requestAmount: Int {
        return config?.amount ?? 0
    }
    
    // MARK: - Initialization
    
    func initialize(config: PaymentConfig) {
        self.config = config
        self.status = .idle
        self.currentStep = .channelSelection
        // Pre-fetch WKWebView user agent for 3DS device information
        DeviceInformationPayload.prefetchUserAgent()
    }
    
    func initializeWithAPIResponse(config: PaymentConfig, response: InitiateTransactionResponse) {
        self.config = config
        self.apiTransaction = response
        self.apiChannels = response.channels ?? []
        self.transactionId = response.transactionId ?? ""
        self.systemTxRef = response.systemTxRef ?? ""
        self.merchantRef = response.merchantRef ?? ""
        self.status = .idle
        self.currentStep = .channelSelection
        
        // Auto-select default channel
        selectChannel(config.defaultChannel)
    }
    
    // MARK: - Channel Selection
    
    func selectChannel(_ channel: PaymentChannel) {
        selectedChannel = channel
        currentStep = .paymentDetails
        delegate?.storeDidUpdateState(self)
    }
    
    func setStep(_ step: PaymentStep) {
        currentStep = step
    }
    
    // MARK: - Status Updates
    
    func setLoading(_ loading: Bool) {
        isLoading = loading
    }
    
    func setError(_ error: PaymentAPIError?) {
        self.error = error
    }
    
    func setStatus(_ status: PaymentStatus) {
        self.status = status
    }
    
    func setTransactionStatus(_ status: TransactionStatus) {
        lastTransactionStatus = status
    }
    
    /// Update store with confirmed data from transaction polling response.
    /// Matches the web's approach of using the final polling response for the success/failure payload.
    func updateFromPollingResponse(_ response: TransactionDetailsResponse) {
        if let ref = response.merchantRef { merchantRef = ref }
        if let txRef = response.systemTxRef { systemTxRef = txRef }
        lastTransactionStatus = response.status
    }
    
    // MARK: - Card Data
    
    func setSavedCards(_ cards: [SavedCard]) {
        savedCards = cards
        delegate?.storeDidUpdateState(self)
    }
    
    // MARK: - Bank Transfer Data
    
    func setBankTransferProviders(_ providers: [BankTransferProviderResponse]) {
        bankTransferProviders = providers
        delegate?.storeDidUpdateState(self)
    }
    
    func setSelectedBankProvider(_ provider: BankTransferProviderResponse?) {
        selectedBankProvider = provider
    }
    
    func setBankTransferAccount(_ account: InitiateBankTransferResponse?) {
        bankTransferAccount = account
        delegate?.storeDidUpdateState(self)
    }
    
    // MARK: - USSD Data
    
    func setUssdBanks(_ banks: [USSDBank]) {
        ussdBanks = banks
        delegate?.storeDidUpdateState(self)
    }
    
    func setSelectedUssdBank(_ bank: USSDBank?) {
        selectedUssdBank = bank
    }
    
    func setUssdCode(_ code: String?) {
        ussdCode = code
        delegate?.storeDidUpdateState(self)
    }
    
    // MARK: - Completion
    
    func completePayment(channel: PaymentChannel) {
        status = .success
        currentStep = .result
        
        guard let config = config else { return }
        
        let payload = PaymentSuccessPayload(
            merchantRef: merchantRef ?? "",
            transactionRef: systemTxRef ?? "",
            amount: responseAmount,
            currency: config.currency,
            channel: channel,
            message: "Payment successful"
        )
        delegate?.store(self, didComplete: .success(payload))
    }
    
    func failPayment(message: String, channel: PaymentChannel? = nil) {
        status = .failed
        currentStep = .result
        
        guard let config = config else { return }
        
        let payload = PaymentFailedPayload(
            merchantRef: merchantRef,
            transactionRef: systemTxRef,
            amount: responseAmount,
            currency: config.currency,
            channel: channel ?? selectedChannel,
            message: message
        )
        delegate?.store(self, didComplete: .failed(payload))
    }
    
    func cancelPayment() {
        status = .cancelled
        delegate?.store(self, didComplete: .cancelled)
    }
    
    // MARK: - Available Channels
    
    func getAvailableChannels() -> [PaymentChannel] {
        // If we have API channels, filter by active status
        if !apiChannels.isEmpty {
            let activeChannels = apiChannels
                .filter { $0.isActive == true }
                .compactMap { PaymentChannel.fromAPICode($0.code ?? "") }
            
            if !activeChannels.isEmpty {
                // Further filter by merchant config if provided
                if let configChannels = config?.paymentChannels, !configChannels.isEmpty {
                    let filtered = configChannels.filter { activeChannels.contains($0) }
                    if !filtered.isEmpty { return filtered }
                }
                return activeChannels
            }
        }
        
        // Fall back to merchant config or all channels
        if let channels = config?.paymentChannels, !channels.isEmpty {
            return channels
        }
        return PaymentChannel.allCases
    }
    
    /// Returns the API display name for a channel, falling back to the enum's displayName.
    func getChannelDisplayName(_ channel: PaymentChannel) -> String {
        let channelToApiCodes: [PaymentChannel: [String]] = [
            .card: ["card"],
            .transfer: ["bank_transfer", "transfer"],
            .ussd: ["ussd_code", "ussd"],
            .payattitude: ["ussd_push", "payattitude", "pay_attitude"],
            .moniflow: ["netapps_marketplace", "marketplace"],
        ]
        if let apiCodes = channelToApiCodes[channel] {
            if let match = apiChannels.first(where: { apiCodes.contains(($0.code ?? "").lowercased()) }) {
                return match.name ?? channel.displayName
            }
        }
        return channel.displayName
    }
    
    // MARK: - Reset
    
    func reset() {
        status = .idle
        currentStep = .channelSelection
        selectedChannel = nil
        isLoading = false
        error = nil
        lastTransactionStatus = nil
        savedCards = []
        bankTransferProviders = []
        selectedBankProvider = nil
        bankTransferAccount = nil
        ussdBanks = []
        selectedUssdBank = nil
        ussdCode = nil
        delegate?.storeDidUpdateState(self)
    }
    
    func fullReset() {
        reset()
        config = nil
        apiTransaction = nil
        apiChannels = []
        merchantRef = nil
        transactionRef = nil
        transactionId = nil
        systemTxRef = nil
    }
}
