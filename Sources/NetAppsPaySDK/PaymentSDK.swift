import UIKit

// MARK: - Payment SDK Delegate

/// Delegate protocol to receive payment lifecycle events.
public protocol PaymentSDKDelegate: AnyObject {
    /// Called when the payment completes successfully.
    func paymentDidSucceed(with payload: PaymentSuccessPayload)
    /// Called when the payment fails.
    func paymentDidFail(with payload: PaymentFailedPayload)
    /// Called when the user closes the payment modal.
    func paymentDidCancel()
    /// Called when the payment UI is ready and displayed.
    func paymentDidBecomeReady()
}

/// Default implementations (all optional).
public extension PaymentSDKDelegate {
    func paymentDidSucceed(with payload: PaymentSuccessPayload) {}
    func paymentDidFail(with payload: PaymentFailedPayload) {}
    func paymentDidCancel() {}
    func paymentDidBecomeReady() {}
}

// MARK: - Payment SDK

/// Entry point for the NetAppsPaySDK.
///
/// Usage:
/// ```swift
/// let config = PaymentConfig(
///     publicKey: "pk_test_xxx",
///     amount: 150000,    // ₦1,500.00
///     currency: .NGN,
///     email: "user@example.com",
///     fullName: "Jane Smith",
///     address1: "123 Main St",
///     address2: "",
///     phoneNumber: "08012345678",
///     narration: "Payment for order",
///     paymentChannels: [.card, .transfer, .ussd, .payattitude, .moniflow],
///     defaultChannel: .card,
///     metadata: ["orderId": "12345"],
///     city: "Lagos"
/// )
/// PaymentSDK.present(from: self, config: config, delegate: self)
/// ```
public final class PaymentSDK {

    // MARK: - Static Properties
    
    /// Enable debug logging.
    public static var debugMode: Bool = true
    
    /// SDK version.
    public static let version = "1.0.7"
    
    private init() {}

    // MARK: - Present Payment
    
    /// Presents the payment screen modally from the given view controller.
    ///
    /// - Parameters:
    ///   - presentingViewController: The view controller from which to present.
    ///   - config: Payment configuration with amount, currency, keys, etc.
    ///   - delegate: Optional delegate to receive payment events.
    public static func present(
        from presentingViewController: UIViewController,
        config: PaymentConfig,
        delegate: PaymentSDKDelegate? = nil
    ) {
        // Validate fullName
        guard !config.fullName.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty else {
            delegate?.paymentDidFail(with: PaymentFailedPayload(
                amount: Double(config.amount),
                currency: config.currency,
                message: "Invalid config: 'fullName' is required. Please supply the customer's full name (e.g. first and last name) in PaymentConfig.fullName before calling present(from:config:delegate:).",
                errorCode: "INVALID_CONFIG"
            ))
            return
        }
        
        // Initialize API client
        PaymentAPIClient.shared.initialize(publicKey: config.publicKey)
        
        // Create payment VC
        let paymentVC = PaymentViewController(config: config)
        paymentVC.sdkDelegate = delegate
        
        let navigationController = UINavigationController(rootViewController: paymentVC)
        navigationController.modalPresentationStyle = .pageSheet
        navigationController.isModalInPresentation = true // Prevents swipe dismiss
        
        // Configure navigation bar appearance
        if #available(iOS 13.0, *) {
            let appearance = UINavigationBarAppearance()
            appearance.configureWithOpaqueBackground()
            appearance.backgroundColor = .white
            appearance.titleTextAttributes = [
                .foregroundColor: Theme.Colors.text,
                .font: Theme.Fonts.semibold(17)
            ]
            navigationController.navigationBar.standardAppearance = appearance
            navigationController.navigationBar.scrollEdgeAppearance = appearance
        }
        
        presentingViewController.present(navigationController, animated: true) {
            delegate?.paymentDidBecomeReady()
        }
    }
    
    /// Convenience: Presents with legacy API (no config - uses a placeholder).
    @available(*, deprecated, message: "Use present(from:config:delegate:) instead")
    public static func present(from presentingViewController: UIViewController) {
        let config = PaymentConfig(
            publicKey: "",
            amount: 0,
            currency: .NGN,
            email: "",
            fullName: "",
            address1: "",
            address2: "",
            phoneNumber: "",
            narration: "Payment",
            paymentChannels: PaymentChannel.allCases,
            defaultChannel: .card,
            metadata: [:],
            city: "Lagos"
        )
        present(from: presentingViewController, config: config)
    }
}
