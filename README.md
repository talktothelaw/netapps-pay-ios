# NetAppsPay iOS SDK

Accept payments in your iOS app with Card, Bank Transfer, USSD, PayAttitude, and MoniFlow.

## Installation

### Swift Package Manager

Add the SDK via Xcode:

1. **File → Add Package Dependencies…**
2. Enter the repository URL
3. Select **Up to Next Major Version**

Or add it directly in `Package.swift`:

```swift
dependencies: [
    .package(url: "https://gitlab.com/netapps-sdk/netappspay-sdk-ios.git", from: "1.0.0")
]
```


**Requirements**: iOS 13+ &nbsp;|&nbsp; Swift 5.9+ &nbsp;|&nbsp; No external dependencies

## Quick Start

```swift
import NetAppsPaySDK

class CheckoutViewController: UIViewController, PaymentSDKDelegate {

    func startPayment() {
        let config = PaymentConfig(
            publicKey: "pk_live_your_public_key",
            amount: 150000,             // Amount in kobo (₦1,500.00)
            currency: .NGN,
            email: "customer@email.com",
            fullName: "John Doe",
            address1: "123 Main St",
            address2: "",
            phoneNumber: "08100000000",
            narration: "Order #1234",
            paymentChannels: [.card, .transfer, .ussd, .payattitude, .moniflow],
            defaultChannel: .card,
            metadata: ["orderId": "12345"],
            city: "Lagos"
        )

        PaymentSDK.present(from: self, config: config, delegate: self)
    }

    func paymentDidSucceed(with payload: PaymentSuccessPayload) {
        let ref = payload.transactionRef
        let amount = payload.amount
        let channel = payload.channel
        // Verify payment on your server using transactionRef
    }

    func paymentDidFail(with payload: PaymentFailedPayload) {
        let message = payload.message
    }

    func paymentDidCancel() {
        // User dismissed the payment sheet
    }
}
```

## Configuration

### PaymentConfig

| Parameter | Type | Required | Description |
|---|---|---|---|
| `publicKey` | `String` | Yes | Your NetAppsPay public key |
| `amount` | `Int` | Yes | Amount in minor units (kobo). ₦15.00 = `1500` |
| `currency` | `Currency` | Yes | `.NGN` or `.USD` |
| `email` | `String` | Yes | Customer email |
| `fullName` | `String` | Yes | Customer full name |
| `address1` | `String` | Yes | Customer address line 1 |
| `address2` | `String` | Yes | Customer address line 2 |
| `phoneNumber` | `String` | Yes | Customer phone number |
| `narration` | `String` | Yes | Payment description |
| `paymentChannels` | `[PaymentChannel]` | Yes | Channels to display |
| `defaultChannel` | `PaymentChannel` | Yes | Initially selected channel |
| `metadata` | `[String: Any]` | Yes | Custom key-value pairs |
| `city` | `String` | Yes | Customer city |

### Optional Properties

Set these on the config instance after creation:

```swift
var config = PaymentConfig(/* ... */)
config.transactionRef = "your-unique-ref"       // Custom transaction reference
config.businessName = "My Store"                // Merchant display name
config.logoURL = "https://example.com/logo.png" // Merchant logo
config.chargeAllocation = .customer             // .customer (default) or .merchant
config.enableSaveCard = true                    // Allow saving cards for returning customers
config.showTransactionSummary = true            // Show order summary (default: true)
config.customerId = "cust_001"                  // Your internal customer ID
config.productName = "Premium Plan"             // Product name
config.cardHolderName = "John Doe"              // Pre-filled cardholder name
config.postalCode = "100248"                    // Postal code (default: "100248")
config.locality = "NG"                          // Country code (default: "NG")
config.administrativeArea = "Lagos"             // State (default: "Lagos")
config.debugMode = false                         // Enable debug logging
```

## Payment Channels

| Channel | Value | Description |
|---|---|---|
| Card | `.card` | Debit/credit card with 3DS |
| Bank Transfer | `.transfer` | Pay via bank transfer |
| USSD | `.ussd` | USSD code payment |
| PayAttitude | `.payattitude` | Push USSD payment |
| MoniFlow | `.moniflow` | NetApps marketplace |

## Handling Results

### PaymentSDKDelegate

All delegate methods have default (empty) implementations — implement only what you need.

```swift
class MyViewController: UIViewController, PaymentSDKDelegate {

    func paymentDidSucceed(with payload: PaymentSuccessPayload) {
        // payload.transactionRef  — Transaction reference
        // payload.merchantRef     — Your merchant reference
        // payload.amount          — Amount charged (Double)
        // payload.currency        — Currency used
        // payload.channel         — Payment channel used
        // payload.message         — Status message
        // payload.timestamp       — ISO 8601 timestamp
    }

    func paymentDidFail(with payload: PaymentFailedPayload) {
        // payload.message         — Error description
        // payload.transactionRef  — Transaction reference (if available)
        // payload.errorCode       — Error code (if available)
        // payload.channel         — Channel attempted (if available)
    }

    func paymentDidCancel() {
        // User closed the payment sheet
    }

    func paymentDidBecomeReady() {
        // Optional: Payment sheet is loaded and ready
    }
}
```

## Debug Mode

```swift
PaymentSDK.debugMode = true   // Enable debug logging
```

## Full Example

```swift
import UIKit
import NetAppsPaySDK

class PaymentViewController: UIViewController, PaymentSDKDelegate {

    override func viewDidLoad() {
        super.viewDidLoad()

        let payButton = UIButton(type: .system)
        payButton.setTitle("Pay Now", for: .normal)
        payButton.addTarget(self, action: #selector(pay), for: .touchUpInside)
        // ... layout
    }

    @objc private func pay() {
        var config = PaymentConfig(
            publicKey: "pk_live_your_key",
            amount: 500000,
            currency: .NGN,
            email: "lawrence@verydeeptech.com",
            fullName: "Ndubueze Nwoko",
            address1: "123 Main St",
            address2: "",
            phoneNumber: "08100000000",
            narration: "Premium Plan",
            paymentChannels: [.card, .transfer, .ussd],
            defaultChannel: .card,
            metadata: ["plan": "premium", "userId": "u_123"],
            city: "Lagos"
        )
        config.businessName = "My App"
        config.enableSaveCard = true
        config.chargeAllocation = .customer

        PaymentSDK.present(from: self, config: config, delegate: self)
    }

    func paymentDidSucceed(with payload: PaymentSuccessPayload) {
        print("Paid \(payload.amount)")
        // Verify payment on your server using payload.transactionRef
    }

    func paymentDidFail(with payload: PaymentFailedPayload) {
        print("Failed: \(payload.message)")
    }

    func paymentDidCancel() {
        print("Payment cancelled")
    }
}
```

## SwiftUI

```swift
import SwiftUI
import NetAppsPaySDK

struct CheckoutView: View {
    @State private var showPayment = false

    var body: some View {
        Button("Pay ₦1,500") {
            showPayment = true
        }
        .sheet(isPresented: $showPayment) {
            PaymentSheetView()
        }
    }
}

struct PaymentSheetView: UIViewControllerRepresentable {
    func makeUIViewController(context: Context) -> UIViewController {
        let vc = UIViewController()
        DispatchQueue.main.async {
            var config = PaymentConfig(
                publicKey: "pk_live_your_key",
                amount: 150000,
                currency: .NGN,
                email: "customer@email.com",
                fullName: "John Doe",
                address1: "123 Main St",
                address2: "",
                phoneNumber: "08100000000",
                narration: "Order #1234",
                paymentChannels: [.card, .transfer, .ussd],
                defaultChannel: .card,
                metadata: [:],
                city: "Lagos"
            )
            PaymentSDK.present(from: vc, config: config, delegate: context.coordinator)
        }
        return vc
    }

    func updateUIViewController(_ uiViewController: UIViewController, context: Context) {}

    func makeCoordinator() -> Coordinator { Coordinator() }

    class Coordinator: NSObject, PaymentSDKDelegate {
        func paymentDidSucceed(with payload: PaymentSuccessPayload) {
            // Handle success
        }
        func paymentDidFail(with payload: PaymentFailedPayload) {
            // Handle failure
        }
        func paymentDidCancel() {
            // Handle cancel
        }
    }
}
```
