import UIKit
import NetAppsPaySDK

class ViewController: UIViewController, PaymentSDKDelegate {

    // MARK: - UI
    
    private let scrollView: UIScrollView = {
        let sv = UIScrollView()
        sv.translatesAutoresizingMaskIntoConstraints = false
        return sv
    }()
    
    private let formStack: UIStackView = {
        let stack = UIStackView()
        stack.axis = .vertical
        stack.spacing = 16
        stack.translatesAutoresizingMaskIntoConstraints = false
        return stack
    }()
    
    private let titleLabel: UILabel = {
        let label = UILabel()
        label.text = "NetApps Pay SDK Demo"
        label.font = .systemFont(ofSize: 24, weight: .bold)
        label.textAlignment = .center
        return label
    }()
    
    private lazy var publicKeyField = makeTextField(placeholder: "Public Key (pk_test_...)")
    private lazy var emailField = makeTextField(placeholder: "Email", keyboard: .emailAddress)
    private lazy var nameField = makeTextField(placeholder: "Full Name")
    private lazy var phoneField = makeTextField(placeholder: "Phone Number", keyboard: .phonePad)
    private lazy var amountField = makeTextField(placeholder: "Amount (in Naira)", keyboard: .decimalPad)
    private lazy var transactionRefField = makeTextField(placeholder: "Transaction Ref (optional)")
    
    private let currencySegment: UISegmentedControl = {
        let sc = UISegmentedControl(items: ["NGN", "USD"])
        sc.selectedSegmentIndex = 0
        return sc
    }()
    
    private let testModeSwitch: UISwitch = {
        let sw = UISwitch()
        sw.isOn = true
        return sw
    }()
    
    private let debugSwitch: UISwitch = {
        let sw = UISwitch()
        sw.isOn = true
        return sw
    }()

    private let openPaymentButton: UIButton = {
        let button = UIButton(type: .system)
        button.setTitle("Pay Now", for: .normal)
        button.titleLabel?.font = UIFont.systemFont(ofSize: 18, weight: .semibold)
        button.backgroundColor = UIColor(red: 0.03, green: 0.29, blue: 0.51, alpha: 1)
        button.setTitleColor(.white, for: .normal)
        button.layer.cornerRadius = 12
        button.translatesAutoresizingMaskIntoConstraints = false
        return button
    }()
    
    private let statusLabel: UILabel = {
        let label = UILabel()
        label.font = .systemFont(ofSize: 14)
        label.textColor = .secondaryLabel
        label.textAlignment = .center
        label.numberOfLines = 0
        return label
    }()

    // MARK: - Lifecycle
    
    override func viewDidLoad() {
        super.viewDidLoad()

        view.backgroundColor = .systemBackground
        title = "Payment Demo"
        
        setupUI()
        prefillTestData()

        openPaymentButton.addTarget(self, action: #selector(openPaymentTapped), for: .touchUpInside)
    }
    
    private func setupUI() {
        view.addSubview(scrollView)
        scrollView.addSubview(formStack)
        
        // Test mode row
        let testRow = makeSwitchRow(label: "Test Mode", toggle: testModeSwitch)
        let debugRow = makeSwitchRow(label: "Debug Logging", toggle: debugSwitch)
        
        formStack.addArrangedSubview(titleLabel)
        formStack.addArrangedSubview(publicKeyField)
        formStack.addArrangedSubview(emailField)
        formStack.addArrangedSubview(nameField)
        formStack.addArrangedSubview(phoneField)
        formStack.addArrangedSubview(amountField)
        formStack.addArrangedSubview(transactionRefField)
        formStack.addArrangedSubview(currencySegment)
        formStack.addArrangedSubview(testRow)
        formStack.addArrangedSubview(debugRow)
        formStack.addArrangedSubview(openPaymentButton)
        formStack.addArrangedSubview(statusLabel)
        
        formStack.setCustomSpacing(24, after: titleLabel)
        formStack.setCustomSpacing(24, after: debugRow)
        
        NSLayoutConstraint.activate([
            scrollView.topAnchor.constraint(equalTo: view.safeAreaLayoutGuide.topAnchor),
            scrollView.leadingAnchor.constraint(equalTo: view.leadingAnchor),
            scrollView.trailingAnchor.constraint(equalTo: view.trailingAnchor),
            scrollView.bottomAnchor.constraint(equalTo: view.bottomAnchor),
            
            formStack.topAnchor.constraint(equalTo: scrollView.topAnchor, constant: 24),
            formStack.leadingAnchor.constraint(equalTo: scrollView.leadingAnchor, constant: 24),
            formStack.trailingAnchor.constraint(equalTo: scrollView.trailingAnchor, constant: -24),
            formStack.bottomAnchor.constraint(equalTo: scrollView.bottomAnchor, constant: -24),
            formStack.widthAnchor.constraint(equalTo: scrollView.widthAnchor, constant: -48),
            
            openPaymentButton.heightAnchor.constraint(equalToConstant: 52),
        ])
    }
    
    private func prefillTestData() {
        publicKeyField.text = "pk_live_880c15c51cbc19e38c44f44a54fd628d801b05b2ef8d35e4"
        emailField.text = "john@example.com"
        nameField.text = "John Doe"
        phoneField.text = "08106720418"
        amountField.text = "100"
    }
    
    // MARK: - Helpers
    
    private func makeTextField(placeholder: String, keyboard: UIKeyboardType = .default) -> UITextField {
        let tf = UITextField()
        tf.placeholder = placeholder
        tf.font = .systemFont(ofSize: 16)
        tf.borderStyle = .roundedRect
        tf.keyboardType = keyboard
        tf.autocorrectionType = .no
        tf.translatesAutoresizingMaskIntoConstraints = false
        tf.heightAnchor.constraint(equalToConstant: 44).isActive = true
        return tf
    }
    
    private func makeSwitchRow(label: String, toggle: UISwitch) -> UIView {
        let row = UIStackView()
        row.axis = .horizontal
        row.distribution = .equalSpacing
        let lbl = UILabel()
        lbl.text = label
        lbl.font = .systemFont(ofSize: 16)
        row.addArrangedSubview(lbl)
        row.addArrangedSubview(toggle)
        return row
    }

    // MARK: - Actions
    
    @objc private func openPaymentTapped() {
        let publicKey = publicKeyField.text ?? ""
        let email = emailField.text ?? ""
        let name = nameField.text ?? ""
        let phone = phoneField.text ?? ""
        let amountStr = amountField.text ?? "0"
        let amountNaira = Double(amountStr) ?? 0
        let amountKobo = Int(amountNaira * 100) // Convert to minor units
        let currency: Currency = currencySegment.selectedSegmentIndex == 0 ? .NGN : .USD
        
        guard !publicKey.isEmpty else {
            statusLabel.text = "Please enter a public key"
            statusLabel.textColor = .systemRed
            return
        }
        
        guard !email.isEmpty else {
            statusLabel.text = "Please enter an email"
            statusLabel.textColor = .systemRed
            return
        }
        
        guard amountKobo > 0 else {
            statusLabel.text = "Please enter a valid amount"
            statusLabel.textColor = .systemRed
            return
        }
        
        PaymentSDK.debugMode = debugSwitch.isOn
        
        var config = PaymentConfig(
            publicKey: publicKey,
            amount: amountKobo,
            currency: currency,
            email: email,
            fullName: name,
            address1: "Customer Address Line 1",
            address2: "",
            phoneNumber: phone,
            narration: "Dev Test Payment",
            paymentChannels: [.card, .transfer, .ussd, .payattitude, .moniflow],
            defaultChannel: .card,
            metadata: ["inputAmount": amountNaira, "env": "development"],
            city: "Lagos"
        )
        let txRef = (transactionRefField.text ?? "").trimmingCharacters(in: .whitespacesAndNewlines)
        if !txRef.isEmpty {
            config.transactionRef = txRef
        }
        config.isTest = testModeSwitch.isOn
        config.showTransactionSummary = true
        config.businessName = "Demo Store"
        
        statusLabel.text = "Opening payment..."
        statusLabel.textColor = .secondaryLabel
        
        PaymentSDK.present(from: self, config: config, delegate: self)
    }
    
    // MARK: - PaymentSDKDelegate
    
    func paymentDidSucceed(with payload: PaymentSuccessPayload) {
        statusLabel.text = "✅ Payment successful!\nRef: \(payload.transactionRef)\nAmount: \(payload.amount)"
        statusLabel.textColor = .systemGreen
    }
    
    func paymentDidFail(with payload: PaymentFailedPayload) {
        statusLabel.text = "❌ Payment failed: \(payload.message)"
        statusLabel.textColor = .systemRed
    }
    
    func paymentDidCancel() {
        statusLabel.text = "Payment cancelled by user"
        statusLabel.textColor = .systemOrange
    }
    
    func paymentDidBecomeReady() {
        statusLabel.text = "Payment UI ready"
        statusLabel.textColor = .secondaryLabel
    }
}
