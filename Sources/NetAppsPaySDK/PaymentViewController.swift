import UIKit

/// Main payment view controller - coordinates all payment flows.
/// Matches web PaymentModal.tsx layout: bottom sheet on mobile,
/// drag handle, close X button, transaction summary, channel tabs,
/// payment form, NetappsPay footer logo, confirm close dialog.
public final class PaymentViewController: UIViewController {
    
    // MARK: - Properties
    
    weak var sdkDelegate: PaymentSDKDelegate?
    
    private let store = PaymentStore()
    private let api = PaymentAPIClient.shared
    private let poller = TransactionPoller()
    private let config: PaymentConfig
    
    // MARK: - UI Components
    
    // Drag handle (visible on mobile/bottom sheet)
    private let dragHandle: UIView = {
        let view = UIView()
        view.backgroundColor = Theme.Colors.dragHandle // #E0E0E0
        view.layer.cornerRadius = 2
        view.translatesAutoresizingMaskIntoConstraints = false
        return view
    }()
    
    // Close button (X icon, top-right, red)
    private let closeButton: UIButton = {
        let button = UIButton(type: .system)
        button.translatesAutoresizingMaskIntoConstraints = false
        // Draw a red X icon
        let config: Any
        if #available(iOS 13.0, *) {
            let img = UIImage(systemName: "xmark")?.withConfiguration(
                UIImage.SymbolConfiguration(pointSize: 16, weight: .bold)
            )
            button.setImage(img, for: .normal)
        } else {
            button.setTitle("✕", for: .normal)
            button.titleLabel?.font = Theme.Fonts.bold(16)
        }
        button.tintColor = Theme.Colors.error  // Red X
        return button
    }()
    
    private let scrollView: UIScrollView = {
        let sv = UIScrollView()
        sv.translatesAutoresizingMaskIntoConstraints = false
        sv.showsVerticalScrollIndicator = false
        sv.alwaysBounceVertical = true
        return sv
    }()
    
    private let contentStack: UIStackView = {
        let stack = UIStackView()
        stack.axis = .vertical
        stack.spacing = Theme.Spacing.sm // tighter spacing like web
        stack.translatesAutoresizingMaskIntoConstraints = false
        return stack
    }()
    
    private lazy var summaryView: TransactionSummaryView = {
        let view = TransactionSummaryView()
        return view
    }()
    
    private lazy var channelTabsView: ChannelTabsView = {
        let view = ChannelTabsView()
        view.delegate = self
        return view
    }()
    
    private let channelContainerView: UIView = {
        let view = UIView()
        view.translatesAutoresizingMaskIntoConstraints = false
        return view
    }()
    
    // Footer: NetappsPay logo
    private let footerView: UIView = {
        let view = UIView()
        view.translatesAutoresizingMaskIntoConstraints = false
        return view
    }()
    
    private let footerLabel: UILabel = {
        let label = UILabel()
        label.text = "Secured by NetappsPAY"
        label.font = Theme.Fonts.regular(10)
        label.textColor = Theme.Colors.textMuted
        label.textAlignment = .center
        label.translatesAutoresizingMaskIntoConstraints = false
        return label
    }()
    
    // Confirm close dialog overlay
    private lazy var confirmCloseOverlay: UIView = {
        let view = UIView()
        view.backgroundColor = UIColor.black.withAlphaComponent(0.5)
        view.isHidden = true
        view.translatesAutoresizingMaskIntoConstraints = false
        return view
    }()
    
    private lazy var loadingOverlay: LoadingOverlayView = {
        let view = LoadingOverlayView()
        view.translatesAutoresizingMaskIntoConstraints = false
        view.isHidden = true
        return view
    }()
    
    private lazy var statusView: StatusDisplayView = {
        let view = StatusDisplayView()
        view.translatesAutoresizingMaskIntoConstraints = false
        view.isHidden = true
        view.delegate = self
        return view
    }()
    
    private var currentChannelVC: UIViewController?
    private var cachedChannelVCs: [PaymentChannel: UIViewController] = [:]
    private var cachedChannelBottomConstraints: [PaymentChannel: NSLayoutConstraint] = [:]
    private var lastSelectedChannel: PaymentChannel?
    
    // MARK: - Init
    
    init(config: PaymentConfig) {
        self.config = config
        super.init(nibName: nil, bundle: nil)
        modalPresentationStyle = .pageSheet
    }
    
    required init?(coder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }
    
    // MARK: - Lifecycle
    
    public override func viewDidLoad() {
        super.viewDidLoad()
        
        setupUI()
        setupStore()
        initiateTransaction()
    }
    
    // MARK: - Setup
    
    private func setupUI() {
        view.backgroundColor = Theme.Colors.background
        
        // Remove navigation bar title, use our own close button
        navigationItem.title = nil
        navigationItem.leftBarButtonItem = nil
        navigationController?.navigationBar.isHidden = true
        
        // Drag handle at top center
        view.addSubview(dragHandle)
        
        // Close button top-right
        closeButton.addTarget(self, action: #selector(closeTapped), for: .touchUpInside)
        view.addSubview(closeButton)
        
        // Scroll content
        view.addSubview(scrollView)
        scrollView.addSubview(contentStack)
        
        contentStack.addArrangedSubview(summaryView)
        contentStack.addArrangedSubview(channelTabsView)
        contentStack.addArrangedSubview(channelContainerView)
        
        // Footer
        footerView.addSubview(footerLabel)
        contentStack.addArrangedSubview(footerView)
        
        // Loading / Status overlays
        view.addSubview(loadingOverlay)
        view.addSubview(statusView)
        view.addSubview(confirmCloseOverlay)
        
        // Ensure close button is above the scroll content
        view.bringSubviewToFront(closeButton)
        
        NSLayoutConstraint.activate([
            // Drag handle: 36x4, centered, 12px from safe area top
            dragHandle.topAnchor.constraint(equalTo: view.safeAreaLayoutGuide.topAnchor, constant: 8),
            dragHandle.centerXAnchor.constraint(equalTo: view.centerXAnchor),
            dragHandle.widthAnchor.constraint(equalToConstant: 36),
            dragHandle.heightAnchor.constraint(equalToConstant: 4),
            
            // Close button: top-right with padding
            closeButton.topAnchor.constraint(equalTo: view.safeAreaLayoutGuide.topAnchor, constant: 10),
            closeButton.trailingAnchor.constraint(equalTo: view.trailingAnchor, constant: -10),
            closeButton.widthAnchor.constraint(equalToConstant: 30),
            closeButton.heightAnchor.constraint(equalToConstant: 30),
            
            // Scroll view below drag handle
            scrollView.topAnchor.constraint(equalTo: dragHandle.bottomAnchor, constant: 12),
            scrollView.leadingAnchor.constraint(equalTo: view.leadingAnchor),
            scrollView.trailingAnchor.constraint(equalTo: view.trailingAnchor),
            scrollView.bottomAnchor.constraint(equalTo: view.bottomAnchor),
            
            // Content stack: 20px horizontal padding (matching web's modal 20px padding)
            contentStack.topAnchor.constraint(equalTo: scrollView.topAnchor),
            contentStack.leadingAnchor.constraint(equalTo: scrollView.leadingAnchor, constant: 20),
            contentStack.trailingAnchor.constraint(equalTo: scrollView.trailingAnchor, constant: -20),
            contentStack.bottomAnchor.constraint(equalTo: scrollView.bottomAnchor, constant: -24),
            contentStack.widthAnchor.constraint(equalTo: scrollView.widthAnchor, constant: -40),
            
            // Footer label
            footerLabel.topAnchor.constraint(equalTo: footerView.topAnchor, constant: 16),
            footerLabel.centerXAnchor.constraint(equalTo: footerView.centerXAnchor),
            footerLabel.bottomAnchor.constraint(equalTo: footerView.bottomAnchor),
            
            // Loading overlay
            loadingOverlay.topAnchor.constraint(equalTo: view.topAnchor),
            loadingOverlay.leadingAnchor.constraint(equalTo: view.leadingAnchor),
            loadingOverlay.trailingAnchor.constraint(equalTo: view.trailingAnchor),
            loadingOverlay.bottomAnchor.constraint(equalTo: view.bottomAnchor),
            
            // Status overlay
            statusView.topAnchor.constraint(equalTo: view.topAnchor),
            statusView.leadingAnchor.constraint(equalTo: view.leadingAnchor),
            statusView.trailingAnchor.constraint(equalTo: view.trailingAnchor),
            statusView.bottomAnchor.constraint(equalTo: view.bottomAnchor),
            
            // Confirm close overlay
            confirmCloseOverlay.topAnchor.constraint(equalTo: view.topAnchor),
            confirmCloseOverlay.leadingAnchor.constraint(equalTo: view.leadingAnchor),
            confirmCloseOverlay.trailingAnchor.constraint(equalTo: view.trailingAnchor),
            confirmCloseOverlay.bottomAnchor.constraint(equalTo: view.bottomAnchor),
        ])
        
        // Configure summary initially with placeholder amount (real amount comes from API)
        summaryView.configure(
            businessName: config.businessName ?? config.narration ?? "Payment",
            narration: config.narration,
            productName: config.fullName,
            amount: "..."
        )
    }
    
    private func setupStore() {
        store.delegate = self
        store.initialize(config: config)
        poller.delegate = self
        
        // Allow cancel during loading
        loadingOverlay.onCancel = { [weak self] in
            self?.hideLoading()
            self?.showConfirmCloseDialog()
        }
    }
    
    // MARK: - Confirm Close Dialog (matches web ConfirmDialog)
    
    private func showConfirmCloseDialog() {
        confirmCloseOverlay.subviews.forEach { $0.removeFromSuperview() }
        confirmCloseOverlay.isHidden = false
        
        // Blur effect
        let blur = UIVisualEffectView(effect: UIBlurEffect(style: .dark))
        blur.alpha = 0.4
        blur.translatesAutoresizingMaskIntoConstraints = false
        confirmCloseOverlay.addSubview(blur)
        
        // Dialog card
        let dialog = UIView()
        dialog.backgroundColor = .white
        dialog.layer.cornerRadius = 16
        Theme.Shadows.apply(to: dialog.layer, style: Theme.Shadows.lg)
        dialog.translatesAutoresizingMaskIntoConstraints = false
        confirmCloseOverlay.addSubview(dialog)
        
        // Warning icon (orange circle with !)
        let iconView = UIView()
        iconView.backgroundColor = UIColor(hex: "#FFF3E0")
        iconView.layer.cornerRadius = 24
        iconView.translatesAutoresizingMaskIntoConstraints = false
        
        let exclamation = UILabel()
        exclamation.text = "!"
        exclamation.font = Theme.Fonts.bold(24)
        exclamation.textColor = UIColor(hex: "#FF9800")
        exclamation.textAlignment = .center
        exclamation.translatesAutoresizingMaskIntoConstraints = false
        iconView.addSubview(exclamation)
        
        let titleLabel = UILabel()
        titleLabel.text = "Cancel Payment?"
        titleLabel.font = Theme.Fonts.bold(18)
        titleLabel.textColor = UIColor(hex: "#1A1A2E")
        titleLabel.textAlignment = .center
        titleLabel.translatesAutoresizingMaskIntoConstraints = false
        
        let messageLabel = UILabel()
        messageLabel.text = "Are you sure you want to cancel this payment? Your progress will be lost."
        messageLabel.font = Theme.Fonts.body
        messageLabel.textColor = UIColor(hex: "#666666")
        messageLabel.textAlignment = .center
        messageLabel.numberOfLines = 0
        messageLabel.translatesAutoresizingMaskIntoConstraints = false
        
        // Continue Payment button (primary styled)
        let continueBtn = PrimaryButton(title: "Continue Payment", variant: .primary)
        continueBtn.addTarget(self, action: #selector(cancelCloseTapped), for: .touchUpInside)
        
        // Yes, Cancel button (danger outlined)
        let cancelBtn = PrimaryButton(title: "Yes, Cancel", variant: .danger)
        cancelBtn.addTarget(self, action: #selector(confirmCloseTapped), for: .touchUpInside)
        
        let buttonStack = UIStackView(arrangedSubviews: [continueBtn, cancelBtn])
        buttonStack.axis = .vertical
        buttonStack.spacing = 10
        buttonStack.translatesAutoresizingMaskIntoConstraints = false
        
        dialog.addSubview(iconView)
        dialog.addSubview(titleLabel)
        dialog.addSubview(messageLabel)
        dialog.addSubview(buttonStack)
        
        NSLayoutConstraint.activate([
            blur.topAnchor.constraint(equalTo: confirmCloseOverlay.topAnchor),
            blur.leadingAnchor.constraint(equalTo: confirmCloseOverlay.leadingAnchor),
            blur.trailingAnchor.constraint(equalTo: confirmCloseOverlay.trailingAnchor),
            blur.bottomAnchor.constraint(equalTo: confirmCloseOverlay.bottomAnchor),
            
            dialog.centerXAnchor.constraint(equalTo: confirmCloseOverlay.centerXAnchor),
            dialog.centerYAnchor.constraint(equalTo: confirmCloseOverlay.centerYAnchor),
            dialog.widthAnchor.constraint(equalToConstant: 280),
            
            iconView.topAnchor.constraint(equalTo: dialog.topAnchor, constant: 28),
            iconView.centerXAnchor.constraint(equalTo: dialog.centerXAnchor),
            iconView.widthAnchor.constraint(equalToConstant: 48),
            iconView.heightAnchor.constraint(equalToConstant: 48),
            
            exclamation.centerXAnchor.constraint(equalTo: iconView.centerXAnchor),
            exclamation.centerYAnchor.constraint(equalTo: iconView.centerYAnchor),
            
            titleLabel.topAnchor.constraint(equalTo: iconView.bottomAnchor, constant: 16),
            titleLabel.leadingAnchor.constraint(equalTo: dialog.leadingAnchor, constant: 24),
            titleLabel.trailingAnchor.constraint(equalTo: dialog.trailingAnchor, constant: -24),
            
            messageLabel.topAnchor.constraint(equalTo: titleLabel.bottomAnchor, constant: 8),
            messageLabel.leadingAnchor.constraint(equalTo: dialog.leadingAnchor, constant: 24),
            messageLabel.trailingAnchor.constraint(equalTo: dialog.trailingAnchor, constant: -24),
            
            buttonStack.topAnchor.constraint(equalTo: messageLabel.bottomAnchor, constant: 24),
            buttonStack.leadingAnchor.constraint(equalTo: dialog.leadingAnchor, constant: 24),
            buttonStack.trailingAnchor.constraint(equalTo: dialog.trailingAnchor, constant: -24),
            buttonStack.bottomAnchor.constraint(equalTo: dialog.bottomAnchor, constant: -24),
        ])
        
        // Animate in
        dialog.transform = CGAffineTransform(scaleX: 0.9, y: 0.9)
        dialog.alpha = 0
        UIView.animate(withDuration: 0.25, delay: 0, usingSpringWithDamping: 0.7, initialSpringVelocity: 0.5, options: [], animations: {
            dialog.transform = .identity
            dialog.alpha = 1
        })
    }
    
    @objc private func cancelCloseTapped() {
        UIView.animate(withDuration: 0.2, animations: {
            self.confirmCloseOverlay.alpha = 0
        }) { _ in
            self.confirmCloseOverlay.isHidden = true
            self.confirmCloseOverlay.alpha = 1
        }
    }
    
    @objc private func confirmCloseTapped() {
        confirmCloseOverlay.isHidden = true
        poller.stopPolling()
        dismiss(animated: true) { [weak self] in
            self?.sdkDelegate?.paymentDidCancel()
            self?.store.cancelPayment()
        }
    }
    
    // MARK: - Transaction Initiation
    
    private func initiateTransaction() {
        showLoading(message: "Initializing payment...")
        store.setStatus(.initializing)
        
        let request = InitiateTransactionRequest(
            merchantRef: config.transactionRef ?? DeviceFingerprint.generate(),
            amount: config.amount,
            currency: config.currency.rawValue,
            paymentChannelCode: config.defaultChannel.rawValue.uppercased(),
            chargeAllocation: config.chargeAllocation.rawValue,
            narration: config.narration,
            customerDetails: config.buildCustomerDetails(),
            deviceFingerprint: DeviceFingerprint.generate()
        )
        
        api.initiateTransaction(request) { [weak self] result in
            DispatchQueue.main.async {
                guard let self = self else { return }
                self.hideLoading()
                
                switch result {
                case .success(let response):
                    guard let txId = response.transactionId, !txId.isEmpty else {
                        let msg = "API returned success but missing transactionId. " +
                            "systemTxRef=\(response.systemTxRef ?? "nil"), " +
                            "merchantRef=\(response.merchantRef ?? "nil"), " +
                            "status=\(response.status?.rawValue ?? "nil"), " +
                            "message=\(response.message ?? "nil"), " +
                            "amount=\(response.amount)"
                        if PaymentSDK.debugMode {
                            print("[NetAppsPaySDK] \(msg)")
                        }
                        self.showError(PaymentAPIError.decodingError(msg))
                        return
                    }
                    
                    // Update summary with API response data
                    let isTest = response.live == false
                    self.summaryView.configure(
                        businessName: response.businessName ?? self.config.businessName ?? self.config.narration ?? "Payment",
                        narration: self.config.narration,
                        productName: self.config.fullName,
                        amount: AmountFormatter.format(amount: response.amount, currency: self.config.currency),
                        logoURL: response.channelSpecificData?["businessImage"] as? String,
                        isTest: isTest
                    )
                    
                    self.store.initializeWithAPIResponse(config: self.config, response: response)
                    self.setupChannelTabs()
                    
                    // Connect SSE immediately on init success (for all channels)
                    if let systemTxRef = self.store.systemTxRef, let txnId = self.store.transactionId {
                        if PaymentSDK.debugMode {
                            print("[NetAppsPaySDK] Connecting SSE on init success with systemTxRef: \(systemTxRef)")
                        }
                        self.poller.startSSE(systemTxRef: systemTxRef, transactionId: txnId)
                    }
                    
                case .failure(let error):
                    if PaymentSDK.debugMode {
                        print("[NetAppsPaySDK] initiateTransaction FAILED: \(error.message) (status: \(error.statusCode), code: \(error.errorCode ?? "nil"))")
                    }
                    self.showError(error)
                }
            }
        }
    }
    
    // MARK: - Channel Management
    
    private func setupChannelTabs() {
        let channels = store.getAvailableChannels()
        channelTabsView.configure(channels: channels, selected: store.selectedChannel, store: store)
        
        // Always show the channel VC — either the pre-selected default or the first available
        let initialChannel = store.selectedChannel ?? channels.first
        if let channel = initialChannel {
            selectPaymentChannel(channel)
        }
    }
    
    func selectPaymentChannel(_ channel: PaymentChannel) {
        store.selectChannel(channel)
        channelTabsView.setSelected(channel)
        
        guard let transactionId = store.transactionId else { return }
        
        // Only call selectChannel API when switching to a different channel
        if lastSelectedChannel != channel {
            lastSelectedChannel = channel
            api.selectChannel(SelectChannelRequest(
                transactionId: transactionId,
                channelCode: channel.rawValue.uppercased()
            )) { result in
                DispatchQueue.main.async {
                    if case .failure(let error) = result {
                        if PaymentSDK.debugMode {
                            print("[NetAppsPaySDK] Channel selection error: \(error.message)")
                        }
                    }
                }
            }
        }
        
        showChannelViewController(for: channel)
    }
    
    private func showChannelViewController(for channel: PaymentChannel) {
        // Deactivate current channel's bottom constraint and hide it
        if let current = currentChannelVC,
           let currentChannel = cachedChannelVCs.first(where: { $0.value === current })?.key {
            cachedChannelBottomConstraints[currentChannel]?.isActive = false
            current.view.isHidden = true
        }
        
        // Reuse cached VC or create a new one
        let channelVC: UIViewController
        if let cached = cachedChannelVCs[channel] {
            channelVC = cached
            channelVC.view.isHidden = false
            channelVC.view.alpha = 0
            // Re-activate this channel's bottom constraint
            cachedChannelBottomConstraints[channel]?.isActive = true
        } else {
            switch channel {
            case .card:
                channelVC = CardPaymentViewController(store: store, api: api, parentVC: self)
            case .transfer:
                channelVC = BankTransferViewController(store: store, api: api, parentVC: self)
            case .ussd:
                channelVC = USSDPaymentViewController(store: store, api: api, parentVC: self)
            case .payattitude:
                channelVC = PayAttitudeViewController(store: store, api: api, parentVC: self)
            case .moniflow:
                channelVC = MarketplaceViewController(store: store, api: api, parentVC: self)
            }
            
            addChild(channelVC)
            channelContainerView.addSubview(channelVC.view)
            channelVC.view.translatesAutoresizingMaskIntoConstraints = false
            channelVC.view.alpha = 0
            
            let bottomConstraint = channelVC.view.bottomAnchor.constraint(equalTo: channelContainerView.bottomAnchor)
            NSLayoutConstraint.activate([
                channelVC.view.topAnchor.constraint(equalTo: channelContainerView.topAnchor),
                channelVC.view.leadingAnchor.constraint(equalTo: channelContainerView.leadingAnchor),
                channelVC.view.trailingAnchor.constraint(equalTo: channelContainerView.trailingAnchor),
                bottomConstraint,
            ])
            channelVC.didMove(toParent: self)
            cachedChannelVCs[channel] = channelVC
            cachedChannelBottomConstraints[channel] = bottomConstraint
        }
        
        currentChannelVC = channelVC
        
        // Force layout update so the outer scrollView recalculates content size
        view.setNeedsLayout()
        view.layoutIfNeeded()
        
        // Fade in animation matching web transition
        UIView.animate(withDuration: 0.25) {
            channelVC.view.alpha = 1
        }
    }
    
    // MARK: - Loading / Error / Status
    
    func showLoading(message: String = "Processing...") {
        loadingOverlay.show(message: message)
    }
    
    func hideLoading() {
        loadingOverlay.hide()
    }
    
    func showError(_ error: PaymentAPIError) {
        store.setError(error)
        let displayMessage = error.message.isEmpty
            ? "An error occurred. Please try again."
            : error.message
        statusView.showError(
            message: displayMessage,
            retryAction: { [weak self] in
                self?.statusView.isHidden = true
                self?.initiateTransaction()
            },
            closeAction: { [weak self] in
                self?.statusView.isHidden = true
                self?.dismiss(animated: true) {
                    self?.store.cancelPayment()
                }
            }
        )
    }
    
    func showSuccess() {
        guard let config = store.config else { return }
        let amount = AmountFormatter.format(amount: store.responseAmount, currency: config.currency)
        statusView.showSuccess(amount: amount) { [weak self] in
            self?.dismiss(animated: true) {
                if let channel = self?.store.selectedChannel {
                    self?.store.completePayment(channel: channel)
                }
            }
        }
    }
    
    func showFailure(message: String) {
        guard let config = store.config else { return }
        let amount = AmountFormatter.format(amount: store.responseAmount, currency: config.currency)
        statusView.showFailure(message: message, amount: amount) { [weak self] in
            guard let self = self else { return }
            self.poller.stopPolling()
            self.dismiss(animated: true) {
                self.store.failPayment(message: message, channel: self.store.selectedChannel)
            }
        }
    }
    
    func startSSE(transactionId: String) {
        guard let systemTxRef = store.systemTxRef else { return }
        poller.startSSE(systemTxRef: systemTxRef, transactionId: transactionId)
    }
    
    func startPolling(showOverlay: Bool = true) {
        guard let transactionId = store.transactionId,
              let systemTxRef = store.systemTxRef else { return }
        store.setStatus(.verifying)
        if showOverlay {
            showLoading(message: "Verifying payment...")
        }
        poller.startPolling(systemTxRef: systemTxRef, transactionId: transactionId)
    }
    
    func stopPollingOnly() {
        poller.stopPolling()
    }
    
    // MARK: - Actions
    
    @objc private func closeTapped() {
        // If on result screen, close directly
        if !statusView.isHidden {
            poller.stopPolling()
            dismiss(animated: true) { [weak self] in
                self?.sdkDelegate?.paymentDidCancel()
                self?.store.cancelPayment()
            }
        } else {
            showConfirmCloseDialog()
        }
    }
}

// MARK: - ChannelTabsViewDelegate

extension PaymentViewController: ChannelTabsViewDelegate {
    func channelTabsView(_ view: ChannelTabsView, didSelect channel: PaymentChannel) {
        selectPaymentChannel(channel)
    }
}

// MARK: - PaymentStoreDelegate

extension PaymentViewController: PaymentStoreDelegate {
    func storeDidUpdateState(_ store: PaymentStore) {}
    
    func store(_ store: PaymentStore, didChangeStatus status: PaymentStatus) {
        if PaymentSDK.debugMode {
            print("[NetAppsPaySDK] Status: \(status)")
        }
    }
    
    func store(_ store: PaymentStore, didChangeStep step: PaymentStep) {
        if PaymentSDK.debugMode {
            print("[NetAppsPaySDK] Step: \(step)")
        }
    }
    
    func store(_ store: PaymentStore, didComplete result: PaymentResult) {
        switch result {
        case .success(let payload):
            sdkDelegate?.paymentDidSucceed(with: payload)
        case .failed(let payload):
            sdkDelegate?.paymentDidFail(with: payload)
        case .cancelled:
            sdkDelegate?.paymentDidCancel()
        }
    }
    
    func store(_ store: PaymentStore, didEncounterError error: PaymentAPIError) {
        if PaymentSDK.debugMode {
            print("[NetAppsPaySDK] Error: \(error.message)")
        }
    }
}

// MARK: - TransactionPollerDelegate

extension PaymentViewController: TransactionPollerDelegate {
    func poller(_ poller: TransactionPoller, didUpdateStatus status: TransactionStatus, response: TransactionDetailsResponse) {
        store.setTransactionStatus(status)
    }
    
    func poller(_ poller: TransactionPoller, didComplete response: TransactionDetailsResponse) {
        hideLoading()
        
        // Update store with the confirmed data from polling (matches web's completePayment/failPayment)
        store.updateFromPollingResponse(response)
        
        if response.status.isSuccess {
            showSuccess()
        } else {
            showFailure(message: response.narration ?? ErrorMessages.transactionFailed)
        }
    }
    
    func poller(_ poller: TransactionPoller, didFailWithError error: PaymentAPIError) {
        hideLoading()
        showFailure(message: error.message)
    }
}

// MARK: - StatusDisplayViewDelegate

extension PaymentViewController: StatusDisplayViewDelegate {
    func statusDisplayViewDidTapAction(_ view: StatusDisplayView) {
        // Handled by the closure in showSuccess/showFailure
    }
}
