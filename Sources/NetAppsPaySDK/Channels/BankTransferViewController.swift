// ============================================================
// BANK TRANSFER VIEW CONTROLLER - Matches web BankTransfer.tsx
// Test mode: 64×64 bank icon, "Not Available in Test Mode"
// Live mode: StyledSelect bank picker → Generate Account →
//   Account details card (#EDF5FB) → "I Have Transferred" →
//   Polling spinner with countdown → Instructions list
// ============================================================

import UIKit

final class BankTransferViewController: UIViewController {
    
    // MARK: - Properties
    
    private let store: PaymentStore
    private let api: PaymentAPIClient
    private weak var parentVC: PaymentViewController?
    
    private var hasConfirmedTransfer = false
    private var providers: [BankTransferProviderResponse] = []
    private var selectedProvider: BankTransferProviderResponse?
    
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
        label.font = Theme.Fonts.inputLabel // 10px/500
        label.textColor = Theme.Colors.inputLabel // #344054
        label.text = "Select Bank"
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
    
    private lazy var generateButton = PrimaryButton(title: "Generate Account")
    
    private let selectionErrorLabel: UILabel = {
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
    
    // MARK: - UI — Account Details
    
    private let accountStack: UIStackView = {
        let stack = UIStackView()
        stack.axis = .vertical
        stack.spacing = Theme.Spacing.md
        stack.translatesAutoresizingMaskIntoConstraints = false
        stack.isHidden = true
        return stack
    }()
    
    private let accountDetailsCard: UIView = {
        let view = UIView()
        view.backgroundColor = Theme.Colors.backgroundAlt // #EDF5FB
        view.layer.cornerRadius = Theme.CornerRadius.md
        view.translatesAutoresizingMaskIntoConstraints = false
        return view
    }()
    
    private let detailsInnerStack: UIStackView = {
        let stack = UIStackView()
        stack.axis = .vertical
        stack.spacing = Theme.Spacing.sm
        stack.translatesAutoresizingMaskIntoConstraints = false
        return stack
    }()
    
    private let bankNameRow = InfoRow(label: "Bank", value: "--")
    private let accountCopyLabel = CopyableLabel()
    private let accountNameRow = InfoRow(label: "Account Name", value: "--")
    private let amountRow = InfoRow(label: "Amount", value: "--")
    
    private lazy var confirmButton: PrimaryButton = {
        let btn = PrimaryButton(title: "I Have Transferred")
        return btn
    }()
    
    // Polling state
    private let pollingContainer: UIView = {
        let view = UIView()
        view.backgroundColor = Theme.Colors.backgroundAlt
        view.layer.cornerRadius = Theme.CornerRadius.md
        view.isHidden = true
        view.translatesAutoresizingMaskIntoConstraints = false
        return view
    }()
    
    private let pollingStack: UIStackView = {
        let stack = UIStackView()
        stack.axis = .horizontal
        stack.spacing = Theme.Spacing.sm
        stack.alignment = .center
        stack.translatesAutoresizingMaskIntoConstraints = false
        return stack
    }()
    
    private let pollingSpinner: UIActivityIndicatorView = {
        let indicator: UIActivityIndicatorView
        if #available(iOS 13.0, *) {
            indicator = UIActivityIndicatorView(style: .medium)
        } else {
            indicator = UIActivityIndicatorView(style: .gray)
        }
        indicator.color = Theme.Colors.primary
        indicator.hidesWhenStopped = true
        return indicator
    }()
    
    private let pollingLabel: UILabel = {
        let label = UILabel()
        label.font = Theme.Fonts.caption
        label.textColor = Theme.Colors.textLight
        label.text = "Confirming your transfer..."
        return label
    }()
    
    // Instructions
    private let instructionsList = InstructionsList(items: [
        "Transfer the exact amount to the account details above.",
        "After transfer, click \"I Have Transferred\" to verify."
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
        
        // TEST MODE container
        view.addSubview(testModeContainer)
        setupTestModeView()
        
        // SELECTION view
        view.addSubview(selectionStack)
        let selectWrapper = UIView()
        selectWrapper.addSubview(selectBankLabel)
        selectWrapper.addSubview(bankPickerButton)
        selectBankLabel.translatesAutoresizingMaskIntoConstraints = false
        NSLayoutConstraint.activate([
            selectBankLabel.topAnchor.constraint(equalTo: selectWrapper.topAnchor),
            selectBankLabel.leadingAnchor.constraint(equalTo: selectWrapper.leadingAnchor),
            selectBankLabel.trailingAnchor.constraint(equalTo: selectWrapper.trailingAnchor),
            bankPickerButton.topAnchor.constraint(equalTo: selectBankLabel.bottomAnchor, constant: 4),
            bankPickerButton.leadingAnchor.constraint(equalTo: selectWrapper.leadingAnchor),
            bankPickerButton.trailingAnchor.constraint(equalTo: selectWrapper.trailingAnchor),
            bankPickerButton.bottomAnchor.constraint(equalTo: selectWrapper.bottomAnchor),
            bankPickerButton.heightAnchor.constraint(equalToConstant: Theme.Sizes.inputHeight + 4),
        ])
        selectWrapper.translatesAutoresizingMaskIntoConstraints = false
        
        selectionStack.addArrangedSubview(selectWrapper)
        selectionStack.addArrangedSubview(generateButton)
        selectionStack.addArrangedSubview(selectionErrorLabel)
        selectionStack.addArrangedSubview(retryButton)
        
        // ACCOUNT DETAILS view
        view.addSubview(accountStack)
        
        accountDetailsCard.addSubview(detailsInnerStack)
        detailsInnerStack.addArrangedSubview(bankNameRow)
        detailsInnerStack.addArrangedSubview(accountCopyLabel)
        detailsInnerStack.addArrangedSubview(accountNameRow)
        detailsInnerStack.addArrangedSubview(amountRow)
        
        accountStack.addArrangedSubview(accountDetailsCard)
        accountStack.addArrangedSubview(confirmButton)
        
        // Polling container
        pollingContainer.addSubview(pollingStack)
        pollingStack.addArrangedSubview(pollingSpinner)
        pollingStack.addArrangedSubview(pollingLabel)
        accountStack.addArrangedSubview(pollingContainer)
        
        accountStack.addArrangedSubview(instructionsList)
        
        // Actions
        bankPickerButton.addTarget(self, action: #selector(selectBankTapped), for: .touchUpInside)
        generateButton.addTarget(self, action: #selector(generateTapped), for: .touchUpInside)
        confirmButton.addTarget(self, action: #selector(confirmTapped), for: .touchUpInside)
        retryButton.addTarget(self, action: #selector(retryLoadProviders), for: .touchUpInside)
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
            
            accountStack.topAnchor.constraint(equalTo: view.topAnchor),
            accountStack.leadingAnchor.constraint(equalTo: view.leadingAnchor),
            accountStack.trailingAnchor.constraint(equalTo: view.trailingAnchor),
            accountStack.bottomAnchor.constraint(lessThanOrEqualTo: view.bottomAnchor),
            
            detailsInnerStack.topAnchor.constraint(equalTo: accountDetailsCard.topAnchor, constant: Theme.Spacing.md),
            detailsInnerStack.leadingAnchor.constraint(equalTo: accountDetailsCard.leadingAnchor, constant: Theme.Spacing.md),
            detailsInnerStack.trailingAnchor.constraint(equalTo: accountDetailsCard.trailingAnchor, constant: -Theme.Spacing.md),
            detailsInnerStack.bottomAnchor.constraint(equalTo: accountDetailsCard.bottomAnchor, constant: -Theme.Spacing.md),
            
            pollingStack.topAnchor.constraint(equalTo: pollingContainer.topAnchor, constant: Theme.Spacing.md),
            pollingStack.centerXAnchor.constraint(equalTo: pollingContainer.centerXAnchor),
            pollingStack.bottomAnchor.constraint(equalTo: pollingContainer.bottomAnchor, constant: -Theme.Spacing.md),
        ])
    }
    
    private func setupTestModeView() {
        let stack = UIStackView()
        stack.axis = .vertical
        stack.spacing = Theme.Spacing.md
        stack.alignment = .center
        stack.translatesAutoresizingMaskIntoConstraints = false
        
        // 64×64 bank icon (matches web BankIcon SVG)
        let iconBg = UIView()
        iconBg.backgroundColor = UIColor(hex: "#E8F4FD")
        iconBg.layer.cornerRadius = 12
        iconBg.translatesAutoresizingMaskIntoConstraints = false
        
        let bankIconView = BankTransferIconView(frame: CGRect(x: 0, y: 0, width: 64, height: 64))
        bankIconView.translatesAutoresizingMaskIntoConstraints = false
        iconBg.addSubview(bankIconView)
        
        NSLayoutConstraint.activate([
            iconBg.widthAnchor.constraint(equalToConstant: 64),
            iconBg.heightAnchor.constraint(equalToConstant: 64),
            bankIconView.centerXAnchor.constraint(equalTo: iconBg.centerXAnchor),
            bankIconView.centerYAnchor.constraint(equalTo: iconBg.centerYAnchor),
            bankIconView.widthAnchor.constraint(equalToConstant: 40),
            bankIconView.heightAnchor.constraint(equalToConstant: 40),
        ])
        
        let channelName = store.getChannelDisplayName(.transfer)
        
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
            accountStack.isHidden = true
        } else {
            testModeContainer.isHidden = true
            selectionStack.isHidden = false
            loadProviders()
        }
    }
    
    // MARK: - Load Providers
    
    private func loadProviders() {
        parentVC?.showLoading(message: "Loading banks...")
        selectionErrorLabel.isHidden = true
        retryButton.isHidden = true
        
        api.getBankTransferProviders { [weak self] result in
            DispatchQueue.main.async {
                guard let self = self else { return }
                self.parentVC?.hideLoading()
                
                switch result {
                case .success(let providers):
                    self.providers = providers
                    self.store.setBankTransferProviders(providers)
                    self.selectionErrorLabel.isHidden = true
                    self.retryButton.isHidden = true
                    
                case .failure(let error):
                    let msg = error.message.isEmpty
                        ? "Failed to load banks. Please try another channel."
                        : error.message
                    self.selectionErrorLabel.text = msg + "\nYou can also try a different payment channel."
                    self.selectionErrorLabel.isHidden = false
                    self.retryButton.isHidden = false
                }
            }
        }
    }
    
    @objc private func retryLoadProviders() {
        loadProviders()
    }
    
    // MARK: - Bank Selection (Action Sheet like web StyledSelect)
    
    @objc private func selectBankTapped() {
        let options = providers.map { provider in
            let bankName = (provider.bankName ?? provider.providerName).uppercased()
            let successRate = provider.oneTimeAccountSuccessRate ?? 0
            let description: String? = successRate > 0
                ? String(format: "%.1f%% success", successRate)
                : nil
            return ActionSheetOption(
                label: bankName,
                value: provider.providerId,
                description: description
            )
        }
        
        presentActionSheet(
            title: "Select Bank",
            options: options,
            selectedValue: selectedProvider?.providerId
        ) { [weak self] selected in
            guard let self = self,
                  let provider = self.providers.first(where: { $0.providerId == selected.value }) else { return }
            self.selectedProvider = provider
            let displayName = provider.bankName ?? provider.providerName
            self.bankPickerButton.setTitle(displayName, for: .normal)
            self.bankPickerButton.setTitleColor(Theme.Colors.text, for: .normal)
            self.generateButton.isEnabled = true
        }
    }
    
    // MARK: - Generate Account
    
    @objc private func generateTapped() {
        guard let provider = selectedProvider,
              let systemTxRef = store.systemTxRef,
              let config = store.config else { return }
        
        generateButton.setLoading(true)
        parentVC?.showLoading(message: "Generating account...")
        store.setSelectedBankProvider(provider)
        
        let request = InitiateBankTransferRequest(
            providerKey: provider.providerName,
            accountName: "NetApps Payment",
            reference: systemTxRef,
            accountType: "ONE_TIME",
            metadata: nil
        )
        
        api.initiateBankTransfer(request) { [weak self] result in
            DispatchQueue.main.async {
                guard let self = self else { return }
                self.generateButton.setLoading(false)
                self.parentVC?.hideLoading()
                
                switch result {
                case .success(let response):
                    self.store.setBankTransferAccount(response)
                    self.showAccountDetails(response, provider: provider)
                    
                case .failure(let error):
                    self.selectionErrorLabel.text = error.localizedDescription + "\nYou can also try a different payment channel."
                    self.selectionErrorLabel.isHidden = false
                }
            }
        }
    }
    
    // MARK: - Show Account Details
    
    private func showAccountDetails(_ account: InitiateBankTransferResponse, provider: BankTransferProviderResponse) {
        selectionStack.isHidden = true
        accountStack.isHidden = false
        
        bankNameRow.setValue(provider.bankName ?? "")
        accountCopyLabel.configure(title: "Account Number", text: account.accountNumber ?? "")
        accountNameRow.setValue(account.accountName ?? "")
        amountRow.setHighlighted(true)
        
        if let config = store.config {
            let formatted = AmountFormatter.format(amount: store.responseAmount, currency: config.currency)
            amountRow.setValue(formatted)
            confirmButton.setTitle("I Have Transferred \(formatted)", for: .normal)
        }
    }
    
    // MARK: - Confirm Transfer
    
    @objc private func confirmTapped() {
        if store.config != nil {
            confirmButton.setTitle("", for: .normal)
        }
        hasConfirmedTransfer = true
        confirmButton.isHidden = true
        pollingContainer.isHidden = false
        pollingLabel.text = "Confirming your transfer..."
        
        instructionsList.updateItems([
            "Transfer the exact amount to the account details above.",
            "After transfer, click \"I Have Transferred\" to verify.",
            "Please do not close this window while we confirm your payment."
        ])
        
        // Don't show global loading overlay — this channel has its own polling UI
        parentVC?.startPolling(showOverlay: false)
    }
}

// MARK: - Bank Transfer Icon (matches web BankIcon SVG)

private final class BankTransferIconView: UIView {
    override init(frame: CGRect) {
        super.init(frame: frame)
        backgroundColor = .clear
        isOpaque = false
    }
    required init?(coder: NSCoder) { super.init(coder: coder) }
    
    override func draw(_ rect: CGRect) {
        let color = Theme.Colors.primary
        color.setStroke()
        
        let w = rect.width
        let h = rect.height
        
        // Roof triangle
        let roof = UIBezierPath()
        roof.move(to: CGPoint(x: w * 0.5, y: h * 0.1))
        roof.addLine(to: CGPoint(x: w * 0.1, y: h * 0.35))
        roof.addLine(to: CGPoint(x: w * 0.9, y: h * 0.35))
        roof.close()
        roof.lineWidth = 2
        roof.stroke()
        
        // Pillars
        let pillarY1 = h * 0.38
        let pillarY2 = h * 0.7
        for xFrac in [0.2, 0.4, 0.6, 0.8] as [CGFloat] {
            let pillar = UIBezierPath()
            pillar.move(to: CGPoint(x: w * xFrac, y: pillarY1))
            pillar.addLine(to: CGPoint(x: w * xFrac, y: pillarY2))
            pillar.lineWidth = 2
            pillar.lineCapStyle = .round
            pillar.stroke()
        }
        
        // Base
        let base = UIBezierPath(rect: CGRect(x: w * 0.08, y: h * 0.7, width: w * 0.84, height: h * 0.15))
        base.lineWidth = 2
        base.stroke()
    }
}
