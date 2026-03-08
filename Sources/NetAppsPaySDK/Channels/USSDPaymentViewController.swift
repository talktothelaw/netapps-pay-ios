// ============================================================
// USSD PAYMENT VIEW CONTROLLER - Matches web USSDPayment.tsx
// Test mode: 64×64 USSD icon, "Not Available in Test Mode"
// Live mode: Select bank → Generate code → Code display in
//   #EDF5FB card with monospace font + copy button →
//   "I Have Dialed the Code" → Polling with countdown →
//   Instructions list
// ============================================================

import UIKit

final class USSDPaymentViewController: UIViewController {
    
    // MARK: - Properties
    
    private let store: PaymentStore
    private let api: PaymentAPIClient
    private weak var parentVC: PaymentViewController?
    
    private var banks: [USSDBank] = []
    private var selectedBank: USSDBank?
    private var hasDialedCode = false
    
    // MARK: - UI — Test Mode
    
    private let testModeContainer: UIView = {
        let view = UIView()
        view.isHidden = true
        view.translatesAutoresizingMaskIntoConstraints = false
        return view
    }()
    
    // MARK: - UI — Bank Selection
    
    private let selectionStack: UIStackView = {
        let stack = UIStackView()
        stack.axis = .vertical
        stack.spacing = Theme.Spacing.md
        stack.translatesAutoresizingMaskIntoConstraints = false
        return stack
    }()
    
    private let selectBankLabel: UILabel = {
        let label = UILabel()
        label.font = Theme.Fonts.inputLabel
        label.textColor = Theme.Colors.inputLabel
        label.text = "Select Your Bank"
        return label
    }()
    
    private let bankPickerButton: UIButton = {
        let button = UIButton(type: .system)
        button.setTitle("Choose a bank...", for: .normal)
        button.titleLabel?.font = Theme.Fonts.body
        button.backgroundColor = .clear
        button.setTitleColor(UIColor(hex: "#AAAAAA"), for: .normal)
        button.contentHorizontalAlignment = .left
        button.contentEdgeInsets = UIEdgeInsets(top: 0, left: 12, bottom: 0, right: 12)
        button.layer.cornerRadius = Theme.CornerRadius.md // 8px
        button.layer.borderWidth = 1
        button.layer.borderColor = Theme.Colors.border.cgColor
        button.translatesAutoresizingMaskIntoConstraints = false
        return button
    }()
    
    private lazy var generateButton = PrimaryButton(title: "Generate USSD Code")
    
    private let selectionInstructions = InstructionsList(items: [
        "Select your bank to generate a USSD code.",
        "Dial the code on your phone to complete payment."
    ])
    
    private let errorLabel: UILabel = {
        let label = UILabel()
        label.font = Theme.Fonts.caption
        label.textColor = Theme.Colors.error
        label.textAlignment = .center
        label.numberOfLines = 0
        label.isHidden = true
        return label
    }()
    
    private lazy var retryButton: PrimaryButton = {
        let btn = PrimaryButton(title: "Retry", variant: .outline)
        btn.isHidden = true
        return btn
    }()
    
    // MARK: - UI — Code Display
    
    private let codeStack: UIStackView = {
        let stack = UIStackView()
        stack.axis = .vertical
        stack.spacing = Theme.Spacing.md
        stack.isHidden = true
        stack.translatesAutoresizingMaskIntoConstraints = false
        return stack
    }()
    
    // Code card (backgroundAlt bg, centered code in monospace)
    private let codeCard: UIView = {
        let view = UIView()
        view.backgroundColor = Theme.Colors.backgroundAlt
        view.layer.cornerRadius = Theme.CornerRadius.md
        view.translatesAutoresizingMaskIntoConstraints = false
        return view
    }()
    
    private let bankLabel: UILabel = {
        let label = UILabel()
        label.font = Theme.Fonts.caption
        label.textColor = Theme.Colors.textMuted
        label.textAlignment = .center
        return label
    }()
    
    private let ussdCodeDisplay: UILabel = {
        let label = UILabel()
        label.font = UIFont.monospacedSystemFont(ofSize: 24, weight: .bold)
        label.textColor = Theme.Colors.text
        label.textAlignment = .center
        return label
    }()
    
    private let copyCodeButton: UIButton = {
        let button = UIButton(type: .system)
        button.setTitle("Copy Code", for: .normal)
        button.titleLabel?.font = Theme.Fonts.caption
        button.setTitleColor(Theme.Colors.primary, for: .normal)
        button.layer.borderWidth = 1
        button.layer.borderColor = Theme.Colors.primary.cgColor
        button.layer.cornerRadius = Theme.CornerRadius.md
        button.contentEdgeInsets = UIEdgeInsets(top: 8, left: 16, bottom: 8, right: 16)
        return button
    }()
    
    private let dialCodeButton: UIButton = {
        let button = UIButton(type: .system)
        button.setTitle("Dial Code", for: .normal)
        button.titleLabel?.font = Theme.Fonts.caption
        button.setTitleColor(.white, for: .normal)
        button.backgroundColor = Theme.Colors.primary
        button.layer.cornerRadius = Theme.CornerRadius.md
        button.contentEdgeInsets = UIEdgeInsets(top: 8, left: 16, bottom: 8, right: 16)
        return button
    }()
    
    private let amountLabel: UILabel = {
        let label = UILabel()
        label.font = Theme.Fonts.subtitle
        label.textColor = Theme.Colors.textLight
        label.textAlignment = .center
        return label
    }()
    
    private lazy var dialedButton = PrimaryButton(title: "I Have Dialed the Code")
    
    // Polling container
    private let pollingContainer: UIView = {
        let view = UIView()
        view.backgroundColor = Theme.Colors.backgroundAlt
        view.layer.cornerRadius = Theme.CornerRadius.md
        view.isHidden = true
        view.translatesAutoresizingMaskIntoConstraints = false
        return view
    }()
    
    private let pollingInnerStack: UIStackView = {
        let stack = UIStackView()
        stack.axis = .horizontal
        stack.spacing = Theme.Spacing.sm
        stack.alignment = .center
        stack.translatesAutoresizingMaskIntoConstraints = false
        return stack
    }()
    
    private let pollingSpinner: UIActivityIndicatorView = {
        let ind: UIActivityIndicatorView
        if #available(iOS 13.0, *) {
            ind = UIActivityIndicatorView(style: .medium)
        } else {
            ind = UIActivityIndicatorView(style: .gray)
        }
        ind.color = Theme.Colors.primary
        ind.hidesWhenStopped = true
        return ind
    }()
    
    private let pollingLabel: UILabel = {
        let label = UILabel()
        label.font = Theme.Fonts.caption
        label.textColor = Theme.Colors.textLight
        label.text = "Confirming payment..."
        return label
    }()
    
    private let codeInstructions = InstructionsList(items: [
        "Dial the USSD code above on your registered phone.",
        "Follow the prompts to complete the payment.",
        "Click \"I Have Dialed the Code\" after completing the transaction."
    ])
    
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
    
    // MARK: - Setup
    
    private func setupUI() {
        view.backgroundColor = .clear
        
        // Test mode
        view.addSubview(testModeContainer)
        setupTestModeView()
        
        // Selection
        view.addSubview(selectionStack)
        let selectWrapper = UIView()
        selectWrapper.translatesAutoresizingMaskIntoConstraints = false
        selectWrapper.addSubview(selectBankLabel)
        selectWrapper.addSubview(bankPickerButton)
        selectBankLabel.translatesAutoresizingMaskIntoConstraints = false
        NSLayoutConstraint.activate([
            selectBankLabel.topAnchor.constraint(equalTo: selectWrapper.topAnchor),
            selectBankLabel.leadingAnchor.constraint(equalTo: selectWrapper.leadingAnchor),
            bankPickerButton.topAnchor.constraint(equalTo: selectBankLabel.bottomAnchor, constant: 4),
            bankPickerButton.leadingAnchor.constraint(equalTo: selectWrapper.leadingAnchor),
            bankPickerButton.trailingAnchor.constraint(equalTo: selectWrapper.trailingAnchor),
            bankPickerButton.bottomAnchor.constraint(equalTo: selectWrapper.bottomAnchor),
            bankPickerButton.heightAnchor.constraint(equalToConstant: Theme.Sizes.inputHeight + 4),
        ])
        
        selectionStack.addArrangedSubview(selectWrapper)
        selectionStack.addArrangedSubview(generateButton)
        selectionStack.addArrangedSubview(errorLabel)
        selectionStack.addArrangedSubview(retryButton)
        selectionStack.addArrangedSubview(selectionInstructions)
        
        // Code display
        view.addSubview(codeStack)
        
        // Code card internal layout
        let buttonRow = UIStackView(arrangedSubviews: [copyCodeButton, dialCodeButton])
        buttonRow.axis = .horizontal
        buttonRow.spacing = Theme.Spacing.sm
        buttonRow.alignment = .center
        
        let codeCardStack = UIStackView(arrangedSubviews: [bankLabel, ussdCodeDisplay, buttonRow])
        codeCardStack.axis = .vertical
        codeCardStack.spacing = Theme.Spacing.sm
        codeCardStack.alignment = .center
        codeCardStack.translatesAutoresizingMaskIntoConstraints = false
        codeCard.addSubview(codeCardStack)
        
        NSLayoutConstraint.activate([
            codeCardStack.topAnchor.constraint(equalTo: codeCard.topAnchor, constant: Theme.Spacing.lg),
            codeCardStack.leadingAnchor.constraint(equalTo: codeCard.leadingAnchor, constant: Theme.Spacing.md),
            codeCardStack.trailingAnchor.constraint(equalTo: codeCard.trailingAnchor, constant: -Theme.Spacing.md),
            codeCardStack.bottomAnchor.constraint(equalTo: codeCard.bottomAnchor, constant: -Theme.Spacing.lg),
        ])
        
        codeStack.addArrangedSubview(codeCard)
        codeStack.addArrangedSubview(amountLabel)
        codeStack.addArrangedSubview(dialedButton)
        
        // Polling
        pollingContainer.addSubview(pollingInnerStack)
        pollingInnerStack.addArrangedSubview(pollingSpinner)
        pollingInnerStack.addArrangedSubview(pollingLabel)
        codeStack.addArrangedSubview(pollingContainer)
        codeStack.addArrangedSubview(codeInstructions)
        
        // Actions
        bankPickerButton.addTarget(self, action: #selector(selectBankTapped), for: .touchUpInside)
        generateButton.addTarget(self, action: #selector(generateTapped), for: .touchUpInside)
        retryButton.addTarget(self, action: #selector(retryLoadBanks), for: .touchUpInside)
        copyCodeButton.addTarget(self, action: #selector(copyTapped), for: .touchUpInside)
        dialCodeButton.addTarget(self, action: #selector(dialCodeTapped), for: .touchUpInside)
        dialedButton.addTarget(self, action: #selector(dialedTapped), for: .touchUpInside)
        generateButton.isEnabled = false
        
        NSLayoutConstraint.activate([
            testModeContainer.topAnchor.constraint(equalTo: view.topAnchor),
            testModeContainer.leadingAnchor.constraint(equalTo: view.leadingAnchor),
            testModeContainer.trailingAnchor.constraint(equalTo: view.trailingAnchor),
            testModeContainer.bottomAnchor.constraint(equalTo: view.bottomAnchor),
            
            selectionStack.topAnchor.constraint(equalTo: view.topAnchor),
            selectionStack.leadingAnchor.constraint(equalTo: view.leadingAnchor),
            selectionStack.trailingAnchor.constraint(equalTo: view.trailingAnchor),
            selectionStack.bottomAnchor.constraint(lessThanOrEqualTo: view.bottomAnchor),
            
            codeStack.topAnchor.constraint(equalTo: view.topAnchor),
            codeStack.leadingAnchor.constraint(equalTo: view.leadingAnchor),
            codeStack.trailingAnchor.constraint(equalTo: view.trailingAnchor),
            codeStack.bottomAnchor.constraint(lessThanOrEqualTo: view.bottomAnchor),
            
            pollingInnerStack.topAnchor.constraint(equalTo: pollingContainer.topAnchor, constant: Theme.Spacing.md),
            pollingInnerStack.centerXAnchor.constraint(equalTo: pollingContainer.centerXAnchor),
            pollingInnerStack.bottomAnchor.constraint(equalTo: pollingContainer.bottomAnchor, constant: -Theme.Spacing.md),
        ])
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
        
        let ussdIcon = USSDPaymentIconView(frame: CGRect(x: 0, y: 0, width: 44, height: 44))
        ussdIcon.translatesAutoresizingMaskIntoConstraints = false
        iconBg.addSubview(ussdIcon)
        NSLayoutConstraint.activate([
            iconBg.widthAnchor.constraint(equalToConstant: 64),
            iconBg.heightAnchor.constraint(equalToConstant: 64),
            ussdIcon.centerXAnchor.constraint(equalTo: iconBg.centerXAnchor),
            ussdIcon.centerYAnchor.constraint(equalTo: iconBg.centerYAnchor),
            ussdIcon.widthAnchor.constraint(equalToConstant: 44),
            ussdIcon.heightAnchor.constraint(equalToConstant: 44),
        ])
        
        let channelName = store.getChannelDisplayName(.ussd)
        
        let titleLabel = UILabel()
        titleLabel.font = Theme.Fonts.subtitle
        titleLabel.textColor = Theme.Colors.text
        titleLabel.textAlignment = .center
        titleLabel.numberOfLines = 0
        titleLabel.text = "\(channelName) Not Available in Test Mode"
        
        let msgLabel = UILabel()
        msgLabel.font = Theme.Fonts.caption
        msgLabel.textColor = Theme.Colors.textLight
        msgLabel.textAlignment = .center
        msgLabel.numberOfLines = 0
        msgLabel.text = "\(channelName) payments are only available in live mode. To test this payment channel, please use a live API key."
        
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
    
    // MARK: - Test Mode Check
    
    private func checkTestMode() {
        let isLive = store.isLive
        if !isLive {
            testModeContainer.isHidden = false
            selectionStack.isHidden = true
            codeStack.isHidden = true
        } else {
            testModeContainer.isHidden = true
            selectionStack.isHidden = false
            loadBanks()
        }
    }
    
    // MARK: - Load Banks
    
    private func loadBanks() {
        parentVC?.showLoading(message: "Loading banks...")
        errorLabel.isHidden = true
        retryButton.isHidden = true
        
        api.getUSSDBank { [weak self] result in
            DispatchQueue.main.async {
                guard let self = self else { return }
                self.parentVC?.hideLoading()
                
                switch result {
                case .success(let banks):
                    self.banks = banks
                    self.store.setUssdBanks(banks)
                    self.errorLabel.isHidden = true
                    self.retryButton.isHidden = true
                    
                case .failure(let error):
                    let msg = error.message.isEmpty
                        ? "Failed to load banks. Please try another channel."
                        : error.message
                    self.errorLabel.text = msg + "\nYou can also try a different payment channel."
                    self.errorLabel.isHidden = false
                    self.retryButton.isHidden = false
                }
            }
        }
    }
    
    @objc private func retryLoadBanks() {
        loadBanks()
    }
    
    // MARK: - Bank Selection
    
    @objc private func selectBankTapped() {
        let options = banks.filter { $0.ussdSupported }.map { bank in
            ActionSheetOption(label: bank.name, value: bank.code)
        }
        
        presentActionSheet(
            title: "Select Bank",
            options: options,
            selectedValue: selectedBank?.code
        ) { [weak self] selected in
            guard let self = self,
                  let bank = self.banks.first(where: { $0.code == selected.value }) else { return }
            self.selectedBank = bank
            self.bankPickerButton.setTitle(bank.name, for: .normal)
            self.bankPickerButton.setTitleColor(Theme.Colors.text, for: .normal)
            self.generateButton.isEnabled = true
            self.store.setSelectedUssdBank(bank)
        }
    }
    
    // MARK: - Generate USSD Code
    
    @objc private func generateTapped() {
        guard let bank = selectedBank,
              let transactionId = store.transactionId else { return }
        
        generateButton.setLoading(true)
        
        let request = InitiateUSSDCodeRequest(bankCode: bank.code, metadata: nil)
        
        api.initiateUSSDCode(transactionId: transactionId, request: request) { [weak self] result in
            DispatchQueue.main.async {
                guard let self = self else { return }
                self.generateButton.setLoading(false)
                
                switch result {
                case .success(let response):
                    if let code = response.data.ussdCode {
                        self.showUSSDCode(code)
                    } else {
                        self.errorLabel.text = (response.message ?? "") + "\nYou can also try a different payment channel."
                        self.errorLabel.isHidden = false
                    }
                    
                case .failure(let error):
                    self.errorLabel.text = error.localizedDescription + "\nYou can also try a different payment channel."
                    self.errorLabel.isHidden = false
                }
            }
        }
    }
    
    private func showUSSDCode(_ code: String) {
        store.setUssdCode(code)
        
        selectionStack.isHidden = true
        codeStack.isHidden = false
        
        bankLabel.text = "Bank: \(selectedBank?.name ?? "")"
        ussdCodeDisplay.text = code
        
        if let config = store.config {
            amountLabel.text = "Amount: \(AmountFormatter.format(amount: store.responseAmount, currency: config.currency))"
        }
    }
    
    @objc private func copyTapped() {
        guard let code = ussdCodeDisplay.text else { return }
        UIPasteboard.general.string = code
        copyCodeButton.setTitle("Copied!", for: .normal)
        DispatchQueue.main.asyncAfter(deadline: .now() + 2) { [weak self] in
            self?.copyCodeButton.setTitle("Copy Code", for: .normal)
        }
    }
    
    @objc private func dialCodeTapped() {
        guard let code = ussdCodeDisplay.text,
              let url = URL(string: "tel:\(code)") else { return }
        UIApplication.shared.open(url)
    }
    
    @objc private func dialedTapped() {
        hasDialedCode = true
        dialedButton.isHidden = true
        pollingContainer.isHidden = false
        // Don't show global loading overlay — this channel has its own polling UI
        parentVC?.startPolling(showOverlay: false)
    }
}

// MARK: - USSD Payment Icon (matches web USSDIcon SVG — phone)

private final class USSDPaymentIconView: UIView {
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
        
        // Phone body
        let phoneRect = CGRect(x: w * 0.25, y: h * 0.05, width: w * 0.5, height: h * 0.9)
        let phone = UIBezierPath(roundedRect: phoneRect, cornerRadius: 4)
        phone.lineWidth = 2
        color.setStroke()
        phone.stroke()
        
        // Speaker line
        let speaker = UIBezierPath()
        speaker.move(to: CGPoint(x: w * 0.38, y: h * 0.15))
        speaker.addLine(to: CGPoint(x: w * 0.62, y: h * 0.15))
        speaker.lineWidth = 1.5
        speaker.lineCapStyle = .round
        speaker.stroke()
        
        // Home button
        let circleCenter = CGPoint(x: w * 0.5, y: h * 0.85)
        let circle = UIBezierPath(arcCenter: circleCenter, radius: 2.5, startAngle: 0, endAngle: .pi * 2, clockwise: true)
        color.setFill()
        circle.fill()
    }
}
