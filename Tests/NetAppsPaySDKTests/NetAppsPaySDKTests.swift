import XCTest
@testable import NetAppsPaySDK

final class NetAppsPaySDKTests: XCTestCase {

    // MARK: - Test Helpers
    
    /// Creates a PaymentConfig with all required fields for testing.
    private func makeConfig(
        publicKey: String = "pk_test_123",
        amount: Int = 150000,
        currency: Currency = .NGN,
        email: String = "test@example.com",
        fullName: String = "John Doe",
        address1: String = "Customer Address Line 1",
        address2: String = "",
        phoneNumber: String = "08106720418",
        narration: String = "Test Payment",
        paymentChannels: [PaymentChannel] = [.card, .transfer, .ussd, .payattitude, .moniflow],
        defaultChannel: PaymentChannel = .card,
        metadata: [String: Any] = ["env": "test"],
        city: String = "Lagos"
    ) -> PaymentConfig {
        PaymentConfig(
            publicKey: publicKey,
            amount: amount,
            currency: currency,
            email: email,
            fullName: fullName,
            address1: address1,
            address2: address2,
            phoneNumber: phoneNumber,
            narration: narration,
            paymentChannels: paymentChannels,
            defaultChannel: defaultChannel,
            metadata: metadata,
            city: city
        )
    }

    // MARK: - PaymentConfig Tests
    
    func testPaymentConfigCreation() {
        let config = makeConfig()
        
        XCTAssertEqual(config.publicKey, "pk_test_123")
        XCTAssertEqual(config.amount, 150000)
        XCTAssertEqual(config.currency, .NGN)
        XCTAssertEqual(config.email, "test@example.com")
        XCTAssertEqual(config.fullName, "John Doe")
        XCTAssertEqual(config.address1, "Customer Address Line 1")
        XCTAssertEqual(config.address2, "")
        XCTAssertEqual(config.phoneNumber, "08106720418")
        XCTAssertEqual(config.narration, "Test Payment")
        XCTAssertEqual(config.paymentChannels.count, 5)
        XCTAssertEqual(config.defaultChannel, .card)
        XCTAssertEqual(config.city, "Lagos")
        XCTAssertEqual(config.chargeAllocation, .customer)
        XCTAssertFalse(config.isTest)
        XCTAssertEqual(config.enableSaveCard, false)
    }
    
    func testPaymentConfigBuildCustomerDetails() {
        var config = makeConfig(
            email: "user@test.com",
            fullName: "Jane Smith"
        )
        config.locality = "NG"
        config.customerId = "cust_001"
        
        let details = config.buildCustomerDetails()
        XCTAssertEqual(details.firstName, "Jane")
        XCTAssertEqual(details.lastName, "Smith")
        XCTAssertEqual(details.email, "user@test.com")
        XCTAssertEqual(details.locality, "NG")
        XCTAssertEqual(details.customerId, "cust_001")
        XCTAssertEqual(details.city, "Lagos")
        XCTAssertEqual(details.phone, "08106720418")
        XCTAssertEqual(details.address1, "Customer Address Line 1")
    }
    
    // MARK: - Currency Tests
    
    func testCurrencyRawValues() {
        XCTAssertEqual(Currency.NGN.rawValue, "NGN")
        XCTAssertEqual(Currency.USD.rawValue, "USD")
    }
    
    // MARK: - PaymentChannel Tests
    
    func testPaymentChannelDisplayNames() {
        XCTAssertEqual(PaymentChannel.card.displayName, "Card")
        XCTAssertEqual(PaymentChannel.transfer.displayName, "Bank Transfer")
        XCTAssertEqual(PaymentChannel.ussd.displayName, "USSD Payment")
        XCTAssertEqual(PaymentChannel.payattitude.displayName, "Push USSD Payment")
        XCTAssertEqual(PaymentChannel.moniflow.displayName, "MoniFlow")
    }
    
    func testPaymentChannelShortNames() {
        XCTAssertEqual(PaymentChannel.card.shortName, "Card")
        XCTAssertEqual(PaymentChannel.transfer.shortName, "Bank")
        XCTAssertEqual(PaymentChannel.ussd.shortName, "USSD")
        XCTAssertEqual(PaymentChannel.payattitude.shortName, "Push")
        XCTAssertEqual(PaymentChannel.moniflow.shortName, "MoniFlow")
    }
    
    func testPaymentChannelRawValues() {
        XCTAssertEqual(PaymentChannel.card.rawValue, "card")
        XCTAssertEqual(PaymentChannel.moniflow.rawValue, "moni_flow")
    }
    
    func testPaymentChannelFromAPICode() {
        XCTAssertEqual(PaymentChannel.fromAPICode("card"), .card)
        XCTAssertEqual(PaymentChannel.fromAPICode("bank_transfer"), .transfer)
        XCTAssertEqual(PaymentChannel.fromAPICode("ussd_code"), .ussd)
        XCTAssertEqual(PaymentChannel.fromAPICode("ussd_push"), .payattitude)
        XCTAssertEqual(PaymentChannel.fromAPICode("MONI_FLOW"), .moniflow)
        XCTAssertEqual(PaymentChannel.fromAPICode("NETAPPS_MARKETPLACE"), .moniflow)
        XCTAssertNil(PaymentChannel.fromAPICode("unknown_channel"))
    }
    
    // MARK: - TransactionStatus Tests
    
    func testTransactionStatusHelpers() {
        XCTAssertTrue(TransactionStatus.success.isSuccess)
        XCTAssertTrue(TransactionStatus.successful.isSuccess)
        XCTAssertFalse(TransactionStatus.pending.isSuccess)
        
        XCTAssertTrue(TransactionStatus.pending.isPending)
        XCTAssertTrue(TransactionStatus.initiated.isPending)
        XCTAssertTrue(TransactionStatus.processing.isPending)
        XCTAssertFalse(TransactionStatus.success.isPending)
        
        XCTAssertTrue(TransactionStatus.failed.isTerminal)
        XCTAssertTrue(TransactionStatus.cancelled.isTerminal)
        XCTAssertTrue(TransactionStatus.expired.isTerminal)
        XCTAssertFalse(TransactionStatus.pending.isTerminal)
    }
    
    // MARK: - ExpirationMonth Tests
    
    func testExpirationMonthFromInt() {
        XCTAssertEqual(ExpirationMonth.from(month: 1), .january)
        XCTAssertEqual(ExpirationMonth.from(month: 6), .june)
        XCTAssertEqual(ExpirationMonth.from(month: 12), .december)
        XCTAssertNil(ExpirationMonth.from(month: 0))
        XCTAssertNil(ExpirationMonth.from(month: 13))
    }
    
    // MARK: - AmountFormatter Tests
    
    func testAmountFormatNGN() {
        XCTAssertEqual(AmountFormatter.format(amount: 1500.0, currency: .NGN), "₦1,500.00")
        XCTAssertEqual(AmountFormatter.format(amount: 1.0, currency: .NGN), "₦1.00")
        XCTAssertEqual(AmountFormatter.format(amount: 0, currency: .NGN), "₦0.00")
        XCTAssertEqual(AmountFormatter.format(amount: 10000.0, currency: .NGN), "₦10,000.00")
    }
    
    func testAmountFormatUSD() {
        XCTAssertEqual(AmountFormatter.format(amount: 99.99, currency: .USD), "$99.99")
    }
    
    func testCurrencySymbol() {
        XCTAssertEqual(AmountFormatter.currencySymbol(for: .NGN), "₦")
        XCTAssertEqual(AmountFormatter.currencySymbol(for: .USD), "$")
    }
    
    // MARK: - DeviceFingerprint Tests
    
    func testDeviceFingerprintFormat() {
        let fp = DeviceFingerprint.generate()
        // Should be UUID format: xxxxxxxx-xxxx-7xxx-yxxx-xxxxxxxxxxxx
        let parts = fp.split(separator: "-")
        XCTAssertEqual(parts.count, 5, "UUID should have 5 parts")
        XCTAssertEqual(parts[0].count, 8)
        XCTAssertEqual(parts[1].count, 4)
        XCTAssertEqual(parts[2].count, 4)
        XCTAssertEqual(parts[3].count, 4)
        XCTAssertEqual(parts[4].count, 12)
        
        // Version should be 7
        let version = String(parts[2]).first
        XCTAssertEqual(version, "7", "UUID v7 should start third segment with '7'")
    }
    
    func testDeviceFingerprintUniqueness() {
        let fp1 = DeviceFingerprint.generate()
        let fp2 = DeviceFingerprint.generate()
        XCTAssertNotEqual(fp1, fp2, "Each fingerprint should be unique")
    }
    
    // MARK: - PaymentAPIError Tests
    
    func testPaymentAPIErrorFactory() {
        let networkErr = PaymentAPIError.networkError()
        XCTAssertTrue(networkErr.isNetworkError)
        XCTAssertEqual(networkErr.statusCode, 0)
        
        let timeoutErr = PaymentAPIError.timeoutError()
        XCTAssertTrue(timeoutErr.isTimeout)
        XCTAssertEqual(timeoutErr.statusCode, 408)
        
        let serverErr = PaymentAPIError.serverError()
        XCTAssertEqual(serverErr.statusCode, 500)
        
        let validationErr = PaymentAPIError.validationError("Bad input")
        XCTAssertEqual(validationErr.statusCode, 400)
        XCTAssertEqual(validationErr.message, "Bad input")
        
        let authErr = PaymentAPIError.unauthorized()
        XCTAssertEqual(authErr.statusCode, 401)
    }
    
    // MARK: - PaymentStore Tests
    
    func testPaymentStoreInitialization() {
        let store = PaymentStore()
        XCTAssertNil(store.config)
        XCTAssertEqual(store.status, .idle)
        XCTAssertEqual(store.currentStep, .channelSelection)
    }
    
    func testPaymentStoreChannelSelection() {
        let store = PaymentStore()
        let config = makeConfig()
        store.initialize(config: config)
        
        store.selectChannel(.card)
        XCTAssertEqual(store.selectedChannel, .card)
        XCTAssertEqual(store.currentStep, .paymentDetails)
    }
    
    func testPaymentStoreAvailableChannels() {
        let store = PaymentStore()
        let config = makeConfig(paymentChannels: [.card, .transfer])
        store.initialize(config: config)
        
        let channels = store.getAvailableChannels()
        XCTAssertEqual(channels.count, 2)
        XCTAssertTrue(channels.contains(.card))
        XCTAssertTrue(channels.contains(.transfer))
    }
    
    func testPaymentStoreReset() {
        let store = PaymentStore()
        store.selectChannel(.card)
        store.setStatus(.processing)
        store.reset()
        
        XCTAssertEqual(store.status, .idle)
        XCTAssertEqual(store.currentStep, .channelSelection)
        XCTAssertNil(store.selectedChannel)
    }
    
    // MARK: - AnyCodable Tests
    
    func testAnyCodableEncoding() throws {
        let value = AnyCodable("test")
        let data = try JSONEncoder().encode(value)
        let decoded = try JSONDecoder().decode(AnyCodable.self, from: data)
        XCTAssertEqual(decoded.value as? String, "test")
    }
    
    func testAnyCodableInt() throws {
        let value = AnyCodable(42)
        let data = try JSONEncoder().encode(value)
        let decoded = try JSONDecoder().decode(AnyCodable.self, from: data)
        XCTAssertEqual(decoded.value as? Int, 42)
    }
    
    // MARK: - PaymentSDK Tests
    
    // `PaymentSDK.version` and the podspec's `s.version` are two hand-maintained
    // copies of the same number, and CocoaPods resolves `s.source` by the git tag
    // of that version. Asserting a hardcoded literal here just goes stale on every
    // release (it sat at "1.0.0" while the SDK shipped 1.0.7); compare the two
    // sources instead. CI additionally checks the git tag against both.
    func testPaymentSDKVersionMatchesPodspec() throws {
        let repoRoot = URL(fileURLWithPath: #filePath)
            .deletingLastPathComponent()
            .deletingLastPathComponent()
            .deletingLastPathComponent()
        let podspecURL = repoRoot.appendingPathComponent("NetAppsPaySDK.podspec")
        let podspec = try String(contentsOf: podspecURL, encoding: .utf8)

        let pattern = #"s\.version\s*=\s*"([^"]+)""#
        let range = NSRange(podspec.startIndex..., in: podspec)
        let match = try XCTUnwrap(
            NSRegularExpression(pattern: pattern).firstMatch(in: podspec, range: range),
            "Could not find s.version in \(podspecURL.path)"
        )
        let podspecVersion = String(podspec[Range(match.range(at: 1), in: podspec)!])

        XCTAssertEqual(
            PaymentSDK.version, podspecVersion,
            "PaymentSDK.version must match NetAppsPaySDK.podspec s.version"
        )
    }
    
    func testPaymentSDKDebugMode() {
        PaymentSDK.debugMode = true
        XCTAssertTrue(PaymentSDK.debugMode)
        PaymentSDK.debugMode = false
        XCTAssertFalse(PaymentSDK.debugMode)
    }
    
    // MARK: - PaymentViewController Tests
    
    func testPaymentViewControllerCanBeInstantiated() {
        let config = makeConfig()
        let viewController = PaymentViewController(config: config)
        XCTAssertNotNil(viewController)
    }
    
    // MARK: - APIConfig Tests
    
    func testAPIConfigURLs() {
        let url = APIConfig.fullURL(for: "/transactions/initiate")
        XCTAssertEqual(url.absoluteString, "https://payment-gateway.netapps.ng/api/v1/transactions/initiate")
        
        let txUrl = APIConfig.transactionURL(id: "abc123")
        XCTAssertEqual(txUrl.absoluteString, "https://payment-gateway.netapps.ng/api/v1/transactions/abc123")
    }
    
    func testPollingConfig() {
        XCTAssertEqual(APIConfig.Polling.interval, 5.0)
        XCTAssertEqual(APIConfig.Polling.maxDuration, 600.0)
        XCTAssertEqual(APIConfig.Polling.maxAttempts, 120)
        XCTAssertEqual(APIConfig.Polling.initialDelay, 2.0)
    }
}

