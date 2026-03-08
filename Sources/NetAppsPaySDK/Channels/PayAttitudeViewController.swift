// ============================================================
// PAYATTITUDE VIEW CONTROLLER - Matches web PayAttitude.tsx
// Test mode: 64×64 clock icon, "Not Available in Test Mode"
// Live mode: Phone input → "Pay {amount}" button →
//   Awaiting approval (spinner, "Approve Payment" title,
//   phone last 4 digits, countdown, instructions, cancel btn)
// ============================================================

import UIKit

final class PayAttitudeViewController: UIViewController {
    
    // MARK: - Properties
    
    private let store: PaymentStore
    private let api: PaymentAPIClient
    private weak var parentVC: PaymentViewController?
    
    // MARK: - UI — Test Mode
    
    private let testModeContainer: UIView = {
        let view = UIView()
        view.isHidden = true
        view.translatesAutoresizingMaskIntoConstraints = false
        return view
    }()
    
    // MARK: - UI — Phone Input
    
    private let inputStack: UIStackView = {
        let stack = UIStackView()
        stack.axis = .vertical
        stack.spacing = Theme.Spacing.md
        stack.translatesAutoresizingMaskIntoConstraints = false
        return stack
    }()
    
    private lazy var phoneField = StyledTextField(
        title: "Phone Number",
        placeholder: "08012345678",
        keyboardType: .phonePad
    )
    
    private lazy var payButton: PrimaryButton = {
        let channelName = store.getChannelDisplayName(.payattitude)
        let title: String
        if let config = store.config {
            title = "Pay \(AmountFormatter.format(amount: store.responseAmount, currency: config.currency))"
        } else {
            title = "Pay with \(channelName)"
        }
        return PrimaryButton(title: title)
    }()
    
    private lazy var inputInstructions: InstructionsList = {
        let channelName = store.getChannelDisplayName(.payattitude)
        return InstructionsList(items: [
            "Enter your \(channelName) registered phone number.",
            "You will receive a notification on your phone to approve the payment."
        ])
    }()
    
    private let errorLabel: UILabel = {
        let label = UILabel()
        label.font = Theme.Fonts.caption
        label.textColor = Theme.Colors.error
        label.textAlignment = .center
        label.numberOfLines = 0
        label.isHidden = true
        return label
    }()
    
    // MARK: - UI — Awaiting Approval
    
    private let waitingContainer: UIView = {
        let view = UIView()
        view.isHidden = true
        view.translatesAutoresizingMaskIntoConstraints = false
        return view
    }()
    
    private let waitingStack: UIStackView = {
        let stack = UIStackView()
        stack.axis = .vertical
        stack.spacing = Theme.Spacing.md
        stack.alignment = .center
        stack.translatesAutoresizingMaskIntoConstraints = false
        return stack
    }()
    
    private let waitingSpinner = SpinnerView(size: 40)
    
    private let waitingTitle: UILabel = {
        let label = UILabel()
        label.font = Theme.Fonts.subtitle // lg/semibold
        label.textColor = Theme.Colors.text
        label.textAlignment = .center
        label.text = "Approve Payment"
        return label
    }()
    
    private let waitingMessage: UILabel = {
        let label = UILabel()
        label.font = Theme.Fonts.caption
        label.textColor = Theme.Colors.textLight
        label.textAlignment = .center
        label.numberOfLines = 0
        return label
    }()
    
    // Countdown container
    private let countdownContainer: UIView = {
        let view = UIView()
        view.backgroundColor = Theme.Colors.backgroundAlt
        view.layer.cornerRadius = Theme.CornerRadius.md
        view.translatesAutoresizingMaskIntoConstraints = false
        return view
    }()
    
    private let countdownLabel: UILabel = {
        let label = UILabel()
        label.font = Theme.Fonts.caption
        label.textColor = Theme.Colors.textLight
        label.textAlignment = .center
        label.text = "Time remaining: 5:00"
        return label
    }()
    
    private lazy var waitingInstructions: InstructionsList = {
        let channelName = store.getChannelDisplayName(.payattitude)
        return InstructionsList(items: [
            "Check your phone for the \(channelName) notification.",
            "Enter your \(channelName) PIN to approve the payment.",
            "Do not close this window until payment is confirmed."
        ])
    }()
    
    private lazy var cancelButton = PrimaryButton(title: "Cancel Payment", variant: .outline)
    
    private var countdownTimer: Timer?
    private var remainingSeconds = 300 // 5 minutes like web
    
    // MARK: - Init
    
    init(store: PaymentStore, api: PaymentAPIClient, parentVC: PaymentViewController) {
        self.store = store
        self.api = api
        self.parentVC = parentVC
        super.init(nibName: nil, bundle: nil)
    }
    
    required init?(coder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }
    
    // MARK: - Lifecycle
    
    override func viewDidLoad() {
        super.viewDidLoad()
        setupUI()
        checkTestMode()
    }
    
    deinit {
        countdownTimer?.invalidate()
    }
    
    // MARK: - Setup
    
    private func setupUI() {
        view.backgroundColor = .clear
        
        // Test mode
        view.addSubview(testModeContainer)
        setupTestModeView()
        
        // Input
        view.addSubview(inputStack)
        inputStack.addArrangedSubview(phoneField)
        inputStack.addArrangedSubview(payButton)
        inputStack.addArrangedSubview(errorLabel)
        inputStack.addArrangedSubview(inputInstructions)
        payButton.addTarget(self, action: #selector(payTapped), for: .touchUpInside)
        
        // Waiting
        view.addSubview(waitingContainer)
        waitingContainer.addSubview(waitingStack)
        
        waitingStack.addArrangedSubview(waitingSpinner)
        waitingStack.addArrangedSubview(waitingTitle)
        waitingStack.addArrangedSubview(waitingMessage)
        
        countdownContainer.addSubview(countdownLabel)
        countdownLabel.translatesAutoresizingMaskIntoConstraints = false
        NSLayoutConstraint.activate([
            countdownLabel.topAnchor.constraint(equalTo: countdownContainer.topAnchor, constant: Theme.Spacing.sm),
            countdownLabel.leadingAnchor.constraint(equalTo: countdownContainer.leadingAnchor, constant: Theme.Spacing.md),
            countdownLabel.trailingAnchor.constraint(equalTo: countdownContainer.trailingAnchor, constant: -Theme.Spacing.md),
            countdownLabel.bottomAnchor.constraint(equalTo: countdownContainer.bottomAnchor, constant: -Theme.Spacing.sm),
        ])
        
        waitingStack.addArrangedSubview(countdownContainer)
        waitingStack.addArrangedSubview(waitingInstructions)
        waitingStack.addArrangedSubview(cancelButton)
        cancelButton.addTarget(self, action: #selector(cancelTapped), for: .touchUpInside)
        
        NSLayoutConstraint.activate([
            testModeContainer.topAnchor.constraint(equalTo: view.topAnchor),
            testModeContainer.leadingAnchor.constraint(equalTo: view.leadingAnchor),
            testModeContainer.trailingAnchor.constraint(equalTo: view.trailingAnchor),
            testModeContainer.bottomAnchor.constraint(equalTo: view.bottomAnchor),
            
            inputStack.topAnchor.constraint(equalTo: view.topAnchor),
            inputStack.leadingAnchor.constraint(equalTo: view.leadingAnchor),
            inputStack.trailingAnchor.constraint(equalTo: view.trailingAnchor),
            inputStack.bottomAnchor.constraint(lessThanOrEqualTo: view.bottomAnchor),
            
            waitingContainer.topAnchor.constraint(equalTo: view.topAnchor),
            waitingContainer.leadingAnchor.constraint(equalTo: view.leadingAnchor),
            waitingContainer.trailingAnchor.constraint(equalTo: view.trailingAnchor),
            waitingContainer.bottomAnchor.constraint(equalTo: view.bottomAnchor),
            
            waitingStack.topAnchor.constraint(equalTo: waitingContainer.topAnchor, constant: Theme.Spacing.lg),
            waitingStack.leadingAnchor.constraint(equalTo: waitingContainer.leadingAnchor),
            waitingStack.trailingAnchor.constraint(equalTo: waitingContainer.trailingAnchor),
            waitingStack.bottomAnchor.constraint(lessThanOrEqualTo: waitingContainer.bottomAnchor),
            
            countdownContainer.leadingAnchor.constraint(equalTo: waitingStack.leadingAnchor),
            countdownContainer.trailingAnchor.constraint(equalTo: waitingStack.trailingAnchor),
            cancelButton.leadingAnchor.constraint(equalTo: waitingStack.leadingAnchor),
            cancelButton.trailingAnchor.constraint(equalTo: waitingStack.trailingAnchor),
        ])
        
        // Pre-fill phone if available
        if let phone = store.config?.phoneNumber {
            phoneField.text = phone
        }
    }
    
    private func setupTestModeView() {
        let stack = UIStackView()
        stack.axis = .vertical
        stack.spacing = Theme.Spacing.md
        stack.alignment = .center
        stack.translatesAutoresizingMaskIntoConstraints = false
        
        let iconBg = UIView()
        iconBg.backgroundColor = UIColor(hex: "#E8F4FD")
        iconBg.layer.cornerRadius = 12
        iconBg.translatesAutoresizingMaskIntoConstraints = false
        
        let clockIcon = PayAttitudeIconDrawingView(frame: CGRect(x: 0, y: 0, width: 40, height: 40))
        clockIcon.translatesAutoresizingMaskIntoConstraints = false
        iconBg.addSubview(clockIcon)
        NSLayoutConstraint.activate([
            iconBg.widthAnchor.constraint(equalToConstant: 64),
            iconBg.heightAnchor.constraint(equalToConstant: 64),
            clockIcon.centerXAnchor.constraint(equalTo: iconBg.centerXAnchor),
            clockIcon.centerYAnchor.constraint(equalTo: iconBg.centerYAnchor),
            clockIcon.widthAnchor.constraint(equalToConstant: 40),
            clockIcon.heightAnchor.constraint(equalToConstant: 40),
        ])
        
        let titleLabel = UILabel()
        titleLabel.font = Theme.Fonts.subtitle
        titleLabel.textColor = Theme.Colors.text
        titleLabel.textAlignment = .center
        titleLabel.numberOfLines = 0
        titleLabel.text = "\(store.getChannelDisplayName(.payattitude)) Not Available in Test Mode"
        
        let msgLabel = UILabel()
        msgLabel.font = Theme.Fonts.caption
        msgLabel.textColor = Theme.Colors.textLight
        msgLabel.textAlignment = .center
        msgLabel.numberOfLines = 0
        msgLabel.text = "\(store.getChannelDisplayName(.payattitude)) payments are only available in live mode. To test this payment channel, please use a live API key."
        
        let hintView = TestModeBanner()
        hintView.configure(text: "Tip: Use card payments to test your integration in sandbox mode.")
        
        stack.addArrangedSubview(iconBg)
        stack.addArrangedSubview(titleLabel)
        stack.addArrangedSubview(msgLabel)
        stack.addArrangedSubview(hintView)
        
        testModeContainer.addSubview(stack)
        NSLayoutConstraint.activate([
            stack.centerYAnchor.constraint(equalTo: testModeContainer.centerYAnchor),
            stack.leadingAnchor.constraint(equalTo: testModeContainer.leadingAnchor, constant: Theme.Spacing.xl),
            stack.trailingAnchor.constraint(equalTo: testModeContainer.trailingAnchor, constant: -Theme.Spacing.xl),
        ])
    }
    
    private func checkTestMode() {
        if !store.isLive {
            testModeContainer.isHidden = false
            inputStack.isHidden = true
            waitingContainer.isHidden = true
        } else {
            testModeContainer.isHidden = true
            inputStack.isHidden = false
        }
    }
    
    // MARK: - Pay
    
    @objc private func payTapped() {
        let phone = (phoneField.text ?? "").trimmingCharacters(in: .whitespacesAndNewlines)
        
        guard !phone.isEmpty, phone.count >= 10 else {
            phoneField.setError("Please enter a valid phone number")
            return
        }
        phoneField.setError(nil)
        
        guard let transactionId = store.transactionId else { return }
        
        payButton.setLoading(true)
        
        let request = InitiatePayattitudeRequest(customerPhone: phone, metadata: [:])
        
        api.initiatePayattitude(transactionId: transactionId, request: request) { [weak self] result in
            DispatchQueue.main.async {
                guard let self = self else { return }
                self.payButton.setLoading(false)
                
                switch result {
                case .success(let response):
                    if response.success {
                        self.showWaiting(phone: phone)
                        // Don't show global loading overlay — this channel has its own waiting UI
                        self.parentVC?.startPolling(showOverlay: false)
                    } else {
                        let msg = response.message ?? "Failed to initiate payment"
                        self.errorLabel.text = msg + "\nYou can also try a different payment channel."
                        self.errorLabel.isHidden = false
                    }
                    
                case .failure(let error):
                    let msg = error.message.isEmpty
                        ? "Failed to initiate payment. Please try again."
                        : error.message
                    self.errorLabel.text = msg + "\nYou can also try a different payment channel."
                    self.errorLabel.isHidden = false
                }
            }
        }
    }
    
    private func showWaiting(phone: String) {
        inputStack.isHidden = true
        waitingContainer.isHidden = false
        
        let last4 = String(phone.suffix(4))
        waitingMessage.text = "A payment request has been sent to your phone number ending in ...\(last4). Please check your phone and enter your PIN to approve."
        
        startCountdown()
    }
    
    @objc private func cancelTapped() {
        countdownTimer?.invalidate()
        waitingContainer.isHidden = true
        inputStack.isHidden = false
        // Stop polling when user cancels the waiting state
        parentVC?.stopPollingOnly()
    }
    
    // MARK: - Countdown (matches web InlineCountdown 300s)
    
    private func startCountdown() {
        remainingSeconds = 300
        updateCountdownDisplay()
        countdownTimer = Timer.scheduledTimer(withTimeInterval: 1, repeats: true) { [weak self] _ in
            guard let self = self else { return }
            self.remainingSeconds -= 1
            self.updateCountdownDisplay()
            if self.remainingSeconds <= 0 {
                self.countdownTimer?.invalidate()
                self.cancelTapped()
            }
        }
    }
    
    private func updateCountdownDisplay() {
        let min = remainingSeconds / 60
        let sec = remainingSeconds % 60
        countdownLabel.text = "Time remaining: \(min):\(String(format: "%02d", sec))"
    }
}

// MARK: - PayAttitude Icon (matches web PayAttitudeIcon SVG — clock circle)

private final class PayAttitudeIconDrawingView: UIView {
    override init(frame: CGRect) {
        super.init(frame: frame)
        backgroundColor = .clear
        isOpaque = false
    }
    required init?(coder: NSCoder) { super.init(coder: coder) }
    
    override func draw(_ rect: CGRect) {
        let color = Theme.Colors.primary
        let w = rect.width
        let h = rect.height
        let center = CGPoint(x: w / 2, y: h / 2)
        let radius = min(w, h) / 2 - 3
        
        // Circle
        let circle = UIBezierPath(arcCenter: center, radius: radius, startAngle: 0, endAngle: .pi * 2, clockwise: true)
        circle.lineWidth = 2
        color.setStroke()
        circle.stroke()
        
        // Clock hands
        let hands = UIBezierPath()
        hands.move(to: center)
        hands.addLine(to: CGPoint(x: center.x, y: center.y - radius * 0.55))
        hands.move(to: center)
        hands.addLine(to: CGPoint(x: center.x + radius * 0.35, y: center.y + radius * 0.2))
        hands.lineWidth = 2
        hands.lineCapStyle = .round
        hands.stroke()
    }
}
