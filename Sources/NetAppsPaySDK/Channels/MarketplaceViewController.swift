// ============================================================
// MARKETPLACE VIEW CONTROLLER - Matches web NetAppsMarketplace.tsx
// Test mode: Marketplace hexagon icon, "Not Available in Test Mode"
// Live mode: Hexagonal icon → "Netapps Marketplace" title →
//   description → "Pay {amount}" button → Safari checkout →
//   Waiting state with retry → Instructions list
// ============================================================

import UIKit
import WebKit

final class MarketplaceViewController: UIViewController {
    
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
    
    // MARK: - UI — Idle (default)
    
    private let contentStack: UIStackView = {
        let stack = UIStackView()
        stack.axis = .vertical
        stack.spacing = Theme.Spacing.md
        stack.alignment = .center
        stack.translatesAutoresizingMaskIntoConstraints = false
        return stack
    }()
    
    private let marketplaceIcon: UIImageView = {
        let iv = UIImageView()
        iv.contentMode = .scaleAspectFit
        iv.translatesAutoresizingMaskIntoConstraints = false
        if let url = Bundle.module.url(forResource: "moniflow_logo", withExtension: "png"),
           let data = try? Data(contentsOf: url) {
            iv.image = UIImage(data: data)
        }
        return iv
    }()
    
    private lazy var channelDescription: UILabel = {
        let channelName = store.getChannelDisplayName(.moniflow)
        let label = UILabel()
        label.font = Theme.Fonts.caption // sm
        label.textColor = Theme.Colors.textLight
        label.textAlignment = .center
        label.numberOfLines = 0
        label.text = "Complete your payment securely via \(channelName) checkout."
        return label
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
    
    private lazy var payButton: PrimaryButton = {
        let channelName = store.getChannelDisplayName(.moniflow)
        let title: String
        if let config = store.config {
            title = "Pay \(AmountFormatter.format(amount: store.responseAmount, currency: config.currency))"
        } else {
            title = "Pay with \(channelName)"
        }
        return PrimaryButton(title: title)
    }()
    
    private lazy var idleInstructions: InstructionsList = {
        let channelName = store.getChannelDisplayName(.moniflow)
        return InstructionsList(items: [
            "Click the button to open the \(channelName) checkout.",
            "Complete the payment on the checkout page.",
            "Your payment will be confirmed automatically."
        ])
    }()
    
    // MARK: - UI — Waiting State
    
    private let waitingStack: UIStackView = {
        let stack = UIStackView()
        stack.axis = .vertical
        stack.spacing = Theme.Spacing.md
        stack.alignment = .center
        stack.isHidden = true
        stack.translatesAutoresizingMaskIntoConstraints = false
        return stack
    }()
    
    private let waitingSpinner = SpinnerView(size: 40)
    
    private let waitingTitle: UILabel = {
        let label = UILabel()
        label.font = Theme.Fonts.subtitle
        label.textColor = Theme.Colors.text
        label.text = "Processing..."
        return label
    }()
    
    private let waitingMessage: UILabel = {
        let label = UILabel()
        label.font = Theme.Fonts.caption
        label.textColor = Theme.Colors.textLight
        label.textAlignment = .center
        label.numberOfLines = 0
        label.text = "Waiting for payment confirmation..."
        return label
    }()
    
    private lazy var retryButton = PrimaryButton(title: "Try Again")
    
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
        
        // Content
        view.addSubview(contentStack)
        contentStack.addArrangedSubview(marketplaceIcon)
        contentStack.addArrangedSubview(channelDescription)
        contentStack.addArrangedSubview(errorLabel)
        contentStack.addArrangedSubview(payButton)
        contentStack.addArrangedSubview(idleInstructions)
        
        payButton.addTarget(self, action: #selector(payTapped), for: .touchUpInside)
        
        // Waiting
        view.addSubview(waitingStack)
        waitingStack.addArrangedSubview(waitingSpinner)
        waitingStack.addArrangedSubview(waitingTitle)
        waitingStack.addArrangedSubview(waitingMessage)
        retryButton.isHidden = true
        waitingStack.addArrangedSubview(retryButton)
        retryButton.addTarget(self, action: #selector(retryTapped), for: .touchUpInside)
        
        NSLayoutConstraint.activate([
            testModeContainer.topAnchor.constraint(equalTo: view.topAnchor),
            testModeContainer.leadingAnchor.constraint(equalTo: view.leadingAnchor),
            testModeContainer.trailingAnchor.constraint(equalTo: view.trailingAnchor),
            testModeContainer.bottomAnchor.constraint(equalTo: view.bottomAnchor),
            
            contentStack.topAnchor.constraint(equalTo: view.topAnchor, constant: Theme.Spacing.xl),
            contentStack.leadingAnchor.constraint(equalTo: view.leadingAnchor),
            contentStack.trailingAnchor.constraint(equalTo: view.trailingAnchor),
            contentStack.bottomAnchor.constraint(equalTo: view.bottomAnchor),
            
            marketplaceIcon.widthAnchor.constraint(equalToConstant: 180),
            marketplaceIcon.heightAnchor.constraint(equalToConstant: 69),
            
            payButton.leadingAnchor.constraint(equalTo: contentStack.leadingAnchor),
            payButton.trailingAnchor.constraint(equalTo: contentStack.trailingAnchor),
            
            idleInstructions.leadingAnchor.constraint(equalTo: contentStack.leadingAnchor),
            idleInstructions.trailingAnchor.constraint(equalTo: contentStack.trailingAnchor),
            
            waitingStack.centerXAnchor.constraint(equalTo: view.centerXAnchor),
            waitingStack.centerYAnchor.constraint(equalTo: view.centerYAnchor),
            waitingStack.leadingAnchor.constraint(greaterThanOrEqualTo: view.leadingAnchor, constant: Theme.Spacing.lg),
            waitingStack.trailingAnchor.constraint(lessThanOrEqualTo: view.trailingAnchor, constant: -Theme.Spacing.lg),
        ])
    }
    
    private func setupTestModeView() {
        let stack = UIStackView()
        stack.axis = .vertical
        stack.spacing = Theme.Spacing.md
        stack.alignment = .center
        stack.translatesAutoresizingMaskIntoConstraints = false
        
        let hexIcon = MarketplaceHexIconView(frame: CGRect(x: 0, y: 0, width: 60, height: 75))
        hexIcon.translatesAutoresizingMaskIntoConstraints = false
        NSLayoutConstraint.activate([
            hexIcon.widthAnchor.constraint(equalToConstant: 60),
            hexIcon.heightAnchor.constraint(equalToConstant: 75),
        ])
        
        let channelName = store.getChannelDisplayName(.moniflow)
        
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
        
        stack.addArrangedSubview(hexIcon)
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
            contentStack.isHidden = true
            waitingStack.isHidden = true
        } else {
            testModeContainer.isHidden = true
            contentStack.isHidden = false
        }
    }
    
    // MARK: - Pay
    
    @objc private func payTapped() {
        guard let transactionId = store.transactionId,
              let config = store.config else { return }
        
        payButton.setLoading(true)
        
        let request = InitiateNetAppsMarketplaceRequest(
            beneficiary: config.email,
            metadata: nil
        )
        
        api.initiateNetAppsMarketplace(transactionId: transactionId, request: request) { [weak self] result in
            DispatchQueue.main.async {
                guard let self = self else { return }
                self.payButton.setLoading(false)
                
                switch result {
                case .success(let response):
                    let checkoutUrl = response.data.checkoutUrl
                    
                    // Connect SSE immediately so it's ready for real-time updates.
                    // Polling only starts if/when SSE fails (triggered by postMessage).
                    if let txnId = self.store.transactionId {
                        self.parentVC?.startSSE(transactionId: txnId)
                    }
                    
                    self.openCheckout(url: checkoutUrl)
                    
                case .failure(let error):
                    self.errorLabel.text = error.localizedDescription + "\nYou can also try a different payment channel."
                    self.errorLabel.isHidden = false
                }
            }
        }
    }
    
    private func openCheckout(url: String) {
        guard let checkoutURL = URL(string: url) else {
            errorLabel.text = "Invalid checkout URL. You can also try a different payment channel."
            errorLabel.isHidden = false
            return
        }
        
        let checkoutVC = MarketplaceCheckoutViewController(url: checkoutURL)
        checkoutVC.delegate = self
        checkoutVC.modalPresentationStyle = .pageSheet
        
        present(checkoutVC, animated: true) { [weak self] in
            self?.showWaitingState()
        }
    }
    
    private func showWaitingState() {
        contentStack.isHidden = true
        waitingStack.isHidden = false
        waitingTitle.text = "Processing..."
        waitingMessage.text = "Waiting for payment confirmation..."
        retryButton.isHidden = true
    }
    
    // MARK: - Retry (Smart - checks status first)
    
    @objc private func retryTapped() {
        guard let transactionId = store.transactionId else {
            resetToInitial()
            return
        }
        
        retryButton.isEnabled = false
        waitingMessage.text = "Checking payment status..."
        
        api.getTransaction(transactionId: transactionId) { [weak self] result in
            DispatchQueue.main.async {
                guard let self = self else { return }
                self.retryButton.isEnabled = true
                
                switch result {
                case .success(let response):
                    if response.status.isSuccess {
                        self.parentVC?.showSuccess()
                    } else if response.status.isTerminal {
                        self.resetToInitial()
                    } else {
                        self.waitingMessage.text = "Waiting for payment confirmation..."
                        // Don't show global loading overlay — this channel has its own waiting UI
                        self.parentVC?.startPolling(showOverlay: false)
                    }
                    
                case .failure:
                    self.resetToInitial()
                }
            }
        }
    }
    
    private func resetToInitial() {
        contentStack.isHidden = false
        waitingStack.isHidden = true
        waitingSpinner.stopAnimating()
        payButton.setLoading(false)
    }
}

// MARK: - MarketplaceCheckoutDelegate

extension MarketplaceViewController: MarketplaceCheckoutDelegate {
    func marketplaceCheckoutDidFinish(_ controller: MarketplaceCheckoutViewController) {
        controller.dismiss(animated: true) { [weak self] in
            // User closed checkout without completing payment — just reset
            self?.resetToInitial()
        }
    }
    
    func marketplaceCheckoutDidSucceed(_ controller: MarketplaceCheckoutViewController, paymentData: [String: Any]) {
        controller.dismiss(animated: true) { [weak self] in
            // PostMessage received — now start polling to confirm via backend
            self?.waitingMessage.text = "Confirming payment..."
            // Don't show global loading overlay — this channel has its own waiting UI
            self?.parentVC?.startPolling(showOverlay: false)
        }
    }
}

// MARK: - Marketplace Checkout VC (full-screen WKWebView, no address bar)

protocol MarketplaceCheckoutDelegate: AnyObject {
    func marketplaceCheckoutDidFinish(_ controller: MarketplaceCheckoutViewController)
    func marketplaceCheckoutDidSucceed(_ controller: MarketplaceCheckoutViewController, paymentData: [String: Any])
}

final class MarketplaceCheckoutViewController: UIViewController, WKNavigationDelegate, UIAdaptivePresentationControllerDelegate {
    
    weak var delegate: MarketplaceCheckoutDelegate?
    private let url: URL
    private var webView: WKWebView!
    
    /// JavaScript that force-enables paste on all input/textarea elements,
    /// overriding any `onpaste` handlers or `preventDefault()` calls from external pages.
    static let enablePasteScript = """
    (function() {
        function enablePaste(el) {
            el.onpaste = null;
            el.removeAttribute('onpaste');
            el.removeAttribute('oncopy');
            el.removeAttribute('oncut');
            el.style.webkitUserSelect = 'text';
            el.style.userSelect = 'text';
        }
        function enableAll() {
            document.querySelectorAll('input, textarea').forEach(enablePaste);
        }
        var origAdd = EventTarget.prototype.addEventListener;
        EventTarget.prototype.addEventListener = function(type, fn, opts) {
            if (type === 'paste' || type === 'copy' || type === 'cut') return;
            return origAdd.call(this, type, fn, opts);
        };
        if (document.readyState === 'loading') {
            document.addEventListener('DOMContentLoaded', enableAll);
        } else {
            enableAll();
        }
        new MutationObserver(enableAll).observe(document.documentElement, {
            childList: true, subtree: true
        });
    })();
    """
    
    private let loadingContainer: UIView = {
        let view = UIView()
        view.backgroundColor = Theme.Colors.background
        view.translatesAutoresizingMaskIntoConstraints = false
        return view
    }()
    
    private let spinner: UIActivityIndicatorView = {
        let indicator: UIActivityIndicatorView
        if #available(iOS 13.0, *) {
            indicator = UIActivityIndicatorView(style: .large)
        } else {
            indicator = UIActivityIndicatorView(style: .whiteLarge)
        }
        indicator.color = Theme.Colors.primary
        indicator.translatesAutoresizingMaskIntoConstraints = false
        indicator.hidesWhenStopped = true
        return indicator
    }()
    
    private let loadingLabel: UILabel = {
        let label = UILabel()
        label.text = "Loading checkout..."
        label.font = Theme.Fonts.body
        label.textColor = Theme.Colors.textLight
        label.textAlignment = .center
        label.translatesAutoresizingMaskIntoConstraints = false
        return label
    }()
    
    init(url: URL) {
        self.url = url
        super.init(nibName: nil, bundle: nil)
    }
    
    required init?(coder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }
    
    override func viewDidLoad() {
        super.viewDidLoad()
        view.backgroundColor = Theme.Colors.background
        
        // Detect swipe-to-dismiss (interactive sheet dismiss)
        presentationController?.delegate = self
        
        // Close button at top
        let closeButton = UIButton(type: .system)
        closeButton.setTitle("Done", for: .normal)
        closeButton.setTitleColor(Theme.Colors.primary, for: .normal)
        closeButton.titleLabel?.font = Theme.Fonts.subtitle
        closeButton.translatesAutoresizingMaskIntoConstraints = false
        closeButton.addTarget(self, action: #selector(doneTapped), for: .touchUpInside)
        
        // Drag handle
        let dragHandle = UIView()
        dragHandle.backgroundColor = UIColor.lightGray
        dragHandle.layer.cornerRadius = 2
        dragHandle.translatesAutoresizingMaskIntoConstraints = false
        
        // WebView with postMessage handler
        let config = WKWebViewConfiguration()
        config.preferences.javaScriptEnabled = true
        
        // Add message handler to receive postMessages from marketplace page
        let handler = MarketplaceMessageHandler { [weak self] message in
            self?.handleMarketplaceMessage(message)
        }
        config.userContentController.add(handler, name: "marketplaceHandler")
        
        // Inject JS to forward window.postMessage events to native handler
        let jsSource = """
        window.addEventListener('message', function(event) {
            if (event.data && event.data.type === 'netappspay:payment:success') {
                window.webkit.messageHandlers.marketplaceHandler.postMessage(JSON.stringify(event.data));
            }
        });
        """
        let userScript = WKUserScript(source: jsSource, injectionTime: .atDocumentStart, forMainFrameOnly: false)
        config.userContentController.addUserScript(userScript)
        
        // Inject paste-enabling script for external checkout pages
        let pasteScript = WKUserScript(
            source: Self.enablePasteScript,
            injectionTime: .atDocumentStart,
            forMainFrameOnly: false
        )
        config.userContentController.addUserScript(pasteScript)
        
        let wv = WKWebView(frame: .zero, configuration: config)
        wv.navigationDelegate = self
        wv.translatesAutoresizingMaskIntoConstraints = false
        wv.scrollView.bounces = true
        webView = wv
        
        view.addSubview(dragHandle)
        view.addSubview(closeButton)
        view.addSubview(wv)
        
        // Loading overlay on top of webview
        loadingContainer.addSubview(spinner)
        loadingContainer.addSubview(loadingLabel)
        view.addSubview(loadingContainer)
        
        NSLayoutConstraint.activate([
            dragHandle.topAnchor.constraint(equalTo: view.safeAreaLayoutGuide.topAnchor, constant: 8),
            dragHandle.centerXAnchor.constraint(equalTo: view.centerXAnchor),
            dragHandle.widthAnchor.constraint(equalToConstant: 36),
            dragHandle.heightAnchor.constraint(equalToConstant: 4),
            
            closeButton.topAnchor.constraint(equalTo: view.safeAreaLayoutGuide.topAnchor, constant: 8),
            closeButton.trailingAnchor.constraint(equalTo: view.trailingAnchor, constant: -16),
            
            wv.topAnchor.constraint(equalTo: closeButton.bottomAnchor, constant: 8),
            wv.leadingAnchor.constraint(equalTo: view.leadingAnchor),
            wv.trailingAnchor.constraint(equalTo: view.trailingAnchor),
            wv.bottomAnchor.constraint(equalTo: view.bottomAnchor),
            
            loadingContainer.topAnchor.constraint(equalTo: wv.topAnchor),
            loadingContainer.leadingAnchor.constraint(equalTo: wv.leadingAnchor),
            loadingContainer.trailingAnchor.constraint(equalTo: wv.trailingAnchor),
            loadingContainer.bottomAnchor.constraint(equalTo: wv.bottomAnchor),
            
            spinner.centerXAnchor.constraint(equalTo: loadingContainer.centerXAnchor),
            spinner.centerYAnchor.constraint(equalTo: loadingContainer.centerYAnchor, constant: -16),
            
            loadingLabel.topAnchor.constraint(equalTo: spinner.bottomAnchor, constant: 12),
            loadingLabel.centerXAnchor.constraint(equalTo: loadingContainer.centerXAnchor),
        ])
        
        spinner.startAnimating()
        wv.load(URLRequest(url: url))
    }
    
    @objc private func doneTapped() {
        delegate?.marketplaceCheckoutDidFinish(self)
    }
    
    // MARK: - Swipe-to-dismiss (sheet pulled down without tapping Done)
    
    func presentationControllerDidDismiss(_ presentationController: UIPresentationController) {
        delegate?.marketplaceCheckoutDidFinish(self)
    }
    
    func webView(_ webView: WKWebView, didFinish navigation: WKNavigation!) {
        // Hide loading
        UIView.animate(withDuration: 0.25) {
            self.loadingContainer.alpha = 0
        } completion: { _ in
            self.loadingContainer.isHidden = true
            self.spinner.stopAnimating()
        }
        
        if let url = webView.url?.absoluteString,
           url.contains("callback") || url.contains("success") {
            delegate?.marketplaceCheckoutDidFinish(self)
        }
    }
    
    func webView(_ webView: WKWebView, didFail navigation: WKNavigation!, withError error: Error) {
        loadingContainer.isHidden = true
        spinner.stopAnimating()
        delegate?.marketplaceCheckoutDidFinish(self)
    }
    
    // MARK: - PostMessage Handler
    
    private func handleMarketplaceMessage(_ body: Any) {
        guard let jsonString = body as? String,
              let jsonData = jsonString.data(using: .utf8),
              let dict = try? JSONSerialization.jsonObject(with: jsonData) as? [String: Any],
              let type = dict["type"] as? String,
              type == "netappspay:payment:success" else {
            return
        }
        
        print("[MarketplaceCheckout] Payment success postMessage received: \(dict)")
        delegate?.marketplaceCheckoutDidSucceed(self, paymentData: dict)
    }
}

// MARK: - Marketplace WebView Message Handler

private final class MarketplaceMessageHandler: NSObject, WKScriptMessageHandler {
    private let handler: (Any) -> Void
    
    init(handler: @escaping (Any) -> Void) {
        self.handler = handler
    }
    
    func userContentController(
        _ userContentController: WKUserContentController,
        didReceive message: WKScriptMessage
    ) {
        handler(message.body)
    }
}

// MARK: - Marketplace Hexagonal Tab Icon (matches web MarketplaceTabIcon SVG viewBox 0 0 4 5)
// Used only for the legacy MarketplaceHexIconView (test mode fallback / small icon).

final class MarketplaceHexIconView: UIView {
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

        func sx(_ x: CGFloat) -> CGFloat { return x / 4.0 * w }
        func sy(_ y: CGFloat) -> CGFloat { return y / 5.0 * h }

        let outerPath = UIBezierPath()
        outerPath.move(to: CGPoint(x: sx(1.952), y: sy(0)))
        outerPath.addLine(to: CGPoint(x: sx(3.904), y: sy(1.086)))
        outerPath.addLine(to: CGPoint(x: sx(3.904), y: sy(3.261)))
        outerPath.addLine(to: CGPoint(x: sx(1.952), y: sy(4.347)))
        outerPath.addLine(to: CGPoint(x: sx(0), y: sy(3.261)))
        outerPath.addLine(to: CGPoint(x: sx(0), y: sy(1.086)))
        outerPath.close()
        outerPath.move(to: CGPoint(x: sx(1.952), y: sy(0.389)))
        outerPath.addLine(to: CGPoint(x: sx(3.554), y: sy(1.281)))
        outerPath.addLine(to: CGPoint(x: sx(3.554), y: sy(3.066)))
        outerPath.addLine(to: CGPoint(x: sx(1.952), y: sy(3.958)))
        outerPath.addLine(to: CGPoint(x: sx(0.350), y: sy(3.066)))
        outerPath.addLine(to: CGPoint(x: sx(0.350), y: sy(1.281)))
        outerPath.close()
        outerPath.usesEvenOddFillRule = true
        color.setFill()
        outerPath.fill()

        let leftFace = UIBezierPath()
        leftFace.move(to: CGPoint(x: sx(0.555), y: sy(1.581)))
        leftFace.addLine(to: CGPoint(x: sx(1.924), y: sy(2.302)))
        leftFace.addLine(to: CGPoint(x: sx(1.924), y: sy(3.702)))
        leftFace.addLine(to: CGPoint(x: sx(0.555), y: sy(2.981)))
        leftFace.close()
        leftFace.fill()

        let topFace = UIBezierPath()
        topFace.move(to: CGPoint(x: sx(0.648), y: sy(1.335)))
        topFace.addLine(to: CGPoint(x: sx(1.929), y: sy(0.660)))
        topFace.addLine(to: CGPoint(x: sx(3.149), y: sy(1.339)))
        topFace.addLine(to: CGPoint(x: sx(1.984), y: sy(2.034)))
        topFace.close()
        topFace.fill()

        let brFace = UIBezierPath()
        brFace.move(to: CGPoint(x: sx(2.121), y: sy(2.433)))
        brFace.addLine(to: CGPoint(x: sx(3.038), y: sy(3.125)))
        brFace.addLine(to: CGPoint(x: sx(2.148), y: sy(3.620)))
        brFace.close()
        brFace.fill()

        let rightFace = UIBezierPath()
        rightFace.move(to: CGPoint(x: sx(2.162), y: sy(2.190)))
        rightFace.addLine(to: CGPoint(x: sx(3.256), y: sy(2.959)))
        rightFace.addLine(to: CGPoint(x: sx(3.294), y: sy(1.486)))
        rightFace.close()
        rightFace.fill()
    }
}
