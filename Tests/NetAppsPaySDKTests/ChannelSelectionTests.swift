// ============================================================
// TESTS: payment channel selection (iOS)
// ============================================================
// Mirrors the web SDK's channelSelection tests so behaviour is identical across
// platforms. Covers the "card disabled" matrix that produced a blank screen.
// ============================================================

import XCTest
@testable import NetAppsPaySDK

final class ChannelSelectionTests: XCTestCase {

    // MARK: - Helpers

    /// Build an APIPaymentChannel quickly.
    private func ch(_ code: String, _ isActive: Bool) -> APIPaymentChannel {
        APIPaymentChannel(id: code, code: code, name: code, description: nil, isActive: isActive, icon: nil)
    }

    /// Build an InitiateTransactionResponse via JSON (it has a custom decoder).
    private func makeResponse(channels: [(String, Bool)]) -> InitiateTransactionResponse {
        let channelsJSON = channels
            .map { "{\"code\":\"\($0.0)\",\"isActive\":\($0.1)}" }
            .joined(separator: ",")
        let json = """
        {"amount":1500.0,"transactionId":"tx_1","systemTxRef":"sys_1","merchantRef":"mr_1","channels":[\(channelsJSON)]}
        """
        // swiftlint:disable:next force_try
        return try! JSONDecoder().decode(InitiateTransactionResponse.self, from: Data(json.utf8))
    }

    private func makeConfig(
        paymentChannels: [PaymentChannel] = [.card, .transfer, .ussd, .payattitude, .moniflow],
        defaultChannel: PaymentChannel? = nil
    ) -> PaymentConfig {
        PaymentConfig(
            publicKey: "pk_test_123",
            amount: 150000,
            currency: .NGN,
            email: "test@example.com",
            fullName: "John Doe",
            address1: "Addr 1",
            address2: "",
            phoneNumber: "08106720418",
            narration: "Test Payment",
            paymentChannels: paymentChannels,
            defaultChannel: defaultChannel,
            metadata: [:],
            city: "Lagos"
        )
    }

    // MARK: - availableChannels

    func testAvailableChannelsReturnsOnlyActiveInOrder() {
        let api = [ch("card", true), ch("bank_transfer", true), ch("ussd_code", false)]
        XCTAssertEqual(PaymentChannel.availableChannels(apiChannels: api, configChannels: nil), [.card, .transfer])
    }

    func testAvailableChannelsExcludesInactiveCard() {
        let api = [ch("card", false), ch("bank_transfer", true), ch("ussd_code", true)]
        XCTAssertEqual(PaymentChannel.availableChannels(apiChannels: api, configChannels: nil), [.transfer, .ussd])
    }

    func testAvailableChannelsEmptyWhenNoneActive() {
        let api = [ch("card", false), ch("bank_transfer", false)]
        XCTAssertEqual(PaymentChannel.availableChannels(apiChannels: api, configChannels: nil), [])
    }

    func testAvailableChannelsIntersectsWithMerchantConfig() {
        let api = [ch("card", true), ch("bank_transfer", true), ch("ussd_code", true)]
        let config: [PaymentChannel] = [.ussd, .card]
        XCTAssertEqual(PaymentChannel.availableChannels(apiChannels: api, configChannels: config), [.ussd, .card])
    }

    func testAvailableChannelsIntersectionDropsBackendDisabled() {
        let api = [ch("card", false), ch("bank_transfer", true)]
        let config: [PaymentChannel] = [.card, .transfer]
        XCTAssertEqual(PaymentChannel.availableChannels(apiChannels: api, configChannels: config), [.transfer])
    }

    func testAvailableChannelsDeduplicates() {
        let api = [ch("transfer", true), ch("bank_transfer", true)] // both → .transfer
        XCTAssertEqual(PaymentChannel.availableChannels(apiChannels: api, configChannels: nil), [.transfer])
    }

    func testAvailableChannelsCollapsesEveryMarketplaceAliasOntoOneTab() {
        let api = [
            ch("moni_flow", true), ch("moniflow", true),
            ch("marketplace", true), ch("netapps_marketplace", true),
            ch("MONI_FLOW", true), ch("Marketplace", true)
        ]
        XCTAssertEqual(PaymentChannel.availableChannels(apiChannels: api, configChannels: nil), [.moniflow])
    }

    func testAvailableChannelsDedupesRepeatedMerchantConfigChannels() {
        let api = [ch("moni_flow", true), ch("card", true)]
        let config: [PaymentChannel] = [.moniflow, .moniflow, .moniflow]
        XCTAssertEqual(PaymentChannel.availableChannels(apiChannels: api, configChannels: config), [.moniflow])
        XCTAssertEqual(PaymentChannel.availableChannels(apiChannels: [], configChannels: config), [.moniflow])
    }

    func testAvailableChannelsPreservesMerchantOrderAndNeverHoistsCard() {
        let api = [ch("moni_flow", true), ch("ussd_code", true), ch("card", true)]
        XCTAssertEqual(
            PaymentChannel.availableChannels(apiChannels: api, configChannels: nil),
            [.moniflow, .ussd, .card]
        )
    }

    func testAvailableChannelsFallsBackToConfigWhenNoBackend() {
        let config: [PaymentChannel] = [.transfer, .ussd]
        XCTAssertEqual(PaymentChannel.availableChannels(apiChannels: [], configChannels: config), [.transfer, .ussd])
    }

    func testAvailableChannelsFallsBackToAllWhenNoBackendNoConfig() {
        XCTAssertEqual(PaymentChannel.availableChannels(apiChannels: [], configChannels: nil), PaymentChannel.allCases)
    }

    // MARK: - resolveDefault

    func testResolveDefaultPicksConfiguredDefaultWhenActive() {
        XCTAssertEqual(PaymentChannel.resolveDefault(available: [.card, .transfer, .ussd], preferred: .card), .card)
        XCTAssertEqual(PaymentChannel.resolveDefault(available: [.card, .transfer, .ussd], preferred: .ussd), .ussd)
    }

    func testResolveDefaultFallsBackToFirstWhenDefaultInactive() {
        // Card is the configured default but is not among active channels.
        XCTAssertEqual(PaymentChannel.resolveDefault(available: [.transfer, .ussd], preferred: .card), .transfer)
    }

    func testResolveDefaultPicksFirstWhenNoPreferred() {
        XCTAssertEqual(PaymentChannel.resolveDefault(available: [.transfer, .ussd, .card], preferred: nil), .transfer)
    }

    func testResolveDefaultDoesNotPreferCardOverEarlierActive() {
        XCTAssertEqual(PaymentChannel.resolveDefault(available: [.transfer, .card], preferred: nil), .transfer)
    }

    func testResolveDefaultReturnsNilWhenNoneActive() {
        XCTAssertNil(PaymentChannel.resolveDefault(available: [], preferred: .card))
        XCTAssertNil(PaymentChannel.resolveDefault(available: [], preferred: nil))
    }

    // MARK: - Store integration via initializeWithAPIResponse

    func testStoreSelectsTransferWhenCardDisabled() {
        let store = PaymentStore()
        let config = makeConfig(defaultChannel: .card)
        let response = makeResponse(channels: [("card", false), ("bank_transfer", true), ("ussd_code", true)])

        store.initializeWithAPIResponse(config: config, response: response)

        XCTAssertEqual(store.selectedChannel, .transfer, "Card disabled → first active channel selected")
        XCTAssertEqual(store.currentStep, .paymentDetails, "Payment form must load immediately")
    }

    func testStoreSelectsConfiguredDefaultWhenActive() {
        let store = PaymentStore()
        let config = makeConfig(defaultChannel: .ussd)
        let response = makeResponse(channels: [("card", true), ("bank_transfer", true), ("ussd_code", true)])

        store.initializeWithAPIResponse(config: config, response: response)

        XCTAssertEqual(store.selectedChannel, .ussd)
        XCTAssertEqual(store.currentStep, .paymentDetails)
    }

    func testStoreSelectsCardOnlyWhenActiveAndConfiguredDefault() {
        let store = PaymentStore()
        let config = makeConfig(defaultChannel: .card)
        let response = makeResponse(channels: [("card", true), ("bank_transfer", true)])

        store.initializeWithAPIResponse(config: config, response: response)

        XCTAssertEqual(store.selectedChannel, .card)
    }

    func testStoreSelectsNothingWhenNoActiveChannels() {
        let store = PaymentStore()
        let config = makeConfig(defaultChannel: .card)
        let response = makeResponse(channels: [("card", false), ("bank_transfer", false)])

        store.initializeWithAPIResponse(config: config, response: response)

        XCTAssertNil(store.selectedChannel, "No active channels → nothing selected (UI shows unavailable state)")
        XCTAssertEqual(store.currentStep, .channelSelection, "Must not advance to payment-details with no channel")
        XCTAssertTrue(store.getAvailableChannels().isEmpty)
    }

    func testStoreSelectsSingleActiveNonCardChannel() {
        let store = PaymentStore()
        let config = makeConfig(defaultChannel: .card)
        let response = makeResponse(channels: [("card", false), ("bank_transfer", false), ("ussd_code", true)])

        store.initializeWithAPIResponse(config: config, response: response)

        XCTAssertEqual(store.selectedChannel, .ussd)
        XCTAssertEqual(store.currentStep, .paymentDetails)
    }

    func testStoreSelectsFirstMerchantChannelWhenNoDefaultConfigured() {
        let store = PaymentStore()
        let config = makeConfig(paymentChannels: [], defaultChannel: nil)
        let response = makeResponse(channels: [("moni_flow", true), ("card", true), ("bank_transfer", true)])

        store.initializeWithAPIResponse(config: config, response: response)

        XCTAssertEqual(store.selectedChannel, .moniflow, "First channel in the merchant's own order wins, not card")
    }

    func testStoreReproducesDuplicateMoniFlowScreenshotAsOneSelectedTab() {
        let store = PaymentStore()
        let config = makeConfig(paymentChannels: [], defaultChannel: nil)
        let response = makeResponse(channels: [
            ("moni_flow", true), ("moniflow", true), ("marketplace", true),
            ("netapps_marketplace", true), ("MONI_FLOW", true), ("card", false)
        ])

        store.initializeWithAPIResponse(config: config, response: response)

        XCTAssertEqual(store.getAvailableChannels(), [.moniflow], "One tab, not six")
        XCTAssertEqual(store.selectedChannel, .moniflow)
    }
}
