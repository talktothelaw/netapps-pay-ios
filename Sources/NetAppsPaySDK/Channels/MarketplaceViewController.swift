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
    
    private let marketplaceIcon: MarketplaceLogoView = {
        let view = MarketplaceLogoView(frame: CGRect(x: 0, y: 0, width: 280, height: 107))
        view.translatesAutoresizingMaskIntoConstraints = false
        return view
    }()
    
    private lazy var channelTitle: UILabel = {
        let label = UILabel()
        label.font = Theme.Fonts.subtitle // lg/semibold
        label.textColor = Theme.Colors.text
        label.textAlignment = .center
        label.text = store.getChannelDisplayName(.moniflow)
        return label
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
        contentStack.addArrangedSubview(channelTitle)
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
            
            marketplaceIcon.widthAnchor.constraint(equalToConstant: 280),
            marketplaceIcon.heightAnchor.constraint(equalToConstant: 107),
            
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

// MARK: - Marketplace Logo View (matches web MarketplaceIcon SVG – full MoniFlow branding)
// Uses cached WKWebView snapshot for instant display after first render.

final class MarketplaceLogoView: UIView, WKNavigationDelegate {

    // Class-level cache: once the SVG is rendered, reuse the image everywhere
    private static var cachedLogoImage: UIImage?
    private static var isRendering = false
    private static var pendingViews: [WeakRef<MarketplaceLogoView>] = []

    // Native placeholder: hex icon + "MoniFlow" attributed label (instant)
    private let placeholderStack: UIStackView = {
        let stack = UIStackView()
        stack.axis = .vertical
        stack.spacing = 8
        stack.alignment = .center
        stack.translatesAutoresizingMaskIntoConstraints = false
        return stack
    }()

    // Cached image view (instant if cached)
    private let imageView: UIImageView = {
        let iv = UIImageView()
        iv.contentMode = .scaleAspectFit
        iv.translatesAutoresizingMaskIntoConstraints = false
        iv.isHidden = true
        return iv
    }()

    // Temporary WKWebView used only for rendering (discarded after snapshot)
    private var renderWebView: WKWebView?

    override init(frame: CGRect) {
        super.init(frame: frame)
        setup()
    }

    required init?(coder: NSCoder) {
        super.init(coder: coder)
        setup()
    }

    private func setup() {
        backgroundColor = .clear
        isOpaque = false

        addSubview(imageView)
        addSubview(placeholderStack)

        // Build the native placeholder: hex icon + styled "MoniFlow" text
        let hexIcon = MarketplaceHexIconView(frame: CGRect(x: 0, y: 0, width: 50, height: 62))
        hexIcon.translatesAutoresizingMaskIntoConstraints = false
        NSLayoutConstraint.activate([
            hexIcon.widthAnchor.constraint(equalToConstant: 50),
            hexIcon.heightAnchor.constraint(equalToConstant: 62),
        ])
        placeholderStack.addArrangedSubview(hexIcon)

        let label = UILabel()
        let moni = NSMutableAttributedString(
            string: "Moni",
            attributes: [
                .font: UIFont.systemFont(ofSize: 22, weight: .bold),
                .foregroundColor: UIColor(red: 43/255, green: 40/255, blue: 77/255, alpha: 1),
            ]
        )
        moni.append(NSAttributedString(
            string: "Flow",
            attributes: [
                .font: UIFont.systemFont(ofSize: 22, weight: .bold),
                .foregroundColor: UIColor(red: 0, green: 175/255, blue: 239/255, alpha: 1),
            ]
        ))
        label.attributedText = moni
        label.textAlignment = .center
        placeholderStack.addArrangedSubview(label)

        NSLayoutConstraint.activate([
            imageView.topAnchor.constraint(equalTo: topAnchor),
            imageView.leadingAnchor.constraint(equalTo: leadingAnchor),
            imageView.trailingAnchor.constraint(equalTo: trailingAnchor),
            imageView.bottomAnchor.constraint(equalTo: bottomAnchor),

            placeholderStack.centerXAnchor.constraint(equalTo: centerXAnchor),
            placeholderStack.centerYAnchor.constraint(equalTo: centerYAnchor),
        ])

        // If we already have a cached image, show it immediately
        if let cached = Self.cachedLogoImage {
            showCachedImage(cached)
        } else {
            // Show placeholder and start rendering (only one render at a time)
            placeholderStack.isHidden = false
            imageView.isHidden = true
            requestRender()
        }
    }

    // MARK: - Cached Image

    private func showCachedImage(_ image: UIImage) {
        imageView.image = image
        imageView.isHidden = false
        placeholderStack.isHidden = true
        renderWebView = nil
    }

    // MARK: - Render Request

    private func requestRender() {
        Self.pendingViews.append(WeakRef(self))

        guard !Self.isRendering else { return }
        Self.isRendering = true

        // Create an offscreen WKWebView to render the SVG
        let config = WKWebViewConfiguration()
        let wv = WKWebView(frame: CGRect(x: 0, y: 0, width: 560, height: 214), configuration: config)
        wv.isOpaque = false
        wv.backgroundColor = .clear
        wv.scrollView.backgroundColor = .clear
        wv.scrollView.isScrollEnabled = false
        wv.navigationDelegate = self
        renderWebView = wv

        let html = """
        <!DOCTYPE html>
        <html><head>
        <meta name="viewport" content="width=560,initial-scale=1,maximum-scale=1,user-scalable=no">
        <style>*{margin:0;padding:0;box-sizing:border-box}
        html,body{background:transparent;width:560px;height:214px;overflow:hidden;display:flex;align-items:center;justify-content:center}
        svg{width:560px;height:214px;display:block}</style>
        </head><body>
        \(Self.svgContent)
        </body></html>
        """
        wv.loadHTMLString(html, baseURL: nil)
    }

    // MARK: - WKNavigationDelegate

    func webView(_ webView: WKWebView, didFinish navigation: WKNavigation!) {
        // Small delay to ensure the SVG is fully painted
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.05) { [weak self] in
            let snapshotConfig = WKSnapshotConfiguration()
            snapshotConfig.snapshotWidth = 560 as NSNumber
            webView.takeSnapshot(with: snapshotConfig) { [weak self] image, error in
                guard let image = image else {
                    if PaymentSDK.debugMode {
                        print("[NetAppsPaySDK] Logo snapshot error: \(error?.localizedDescription ?? "unknown")")
                    }
                    Self.isRendering = false
                    return
                }
                // Cache the rendered image
                Self.cachedLogoImage = image
                Self.isRendering = false

                // Notify all pending views
                DispatchQueue.main.async {
                    for ref in Self.pendingViews {
                        ref.value?.showCachedImage(image)
                    }
                    Self.pendingViews.removeAll()
                }
            }
        }
    }

    // The full MoniFlow SVG – identical to web MarketplaceIcon
    static let svgContent = """
    <svg viewBox="0 0 560 214" xmlns="http://www.w3.org/2000/svg" xmlns:xlink="http://www.w3.org/1999/xlink" xml:space="preserve" style="fill-rule:evenodd;clip-rule:evenodd;stroke-linejoin:round;stroke-miterlimit:2;width:100%;height:auto">
      <g transform="matrix(1,0,0,1,-1473.945059,-447.302011)">
        <g transform="matrix(2.0287,0,0,2.0287,-1440.439706,-2268.928969)">
          <path d="M1578,1380L1578,1374C1578,1373 1578,1372 1577,1372C1577,1372 1576,1371 1575,1371L1574,1371L1574,1367L1608,1367L1608,1380L1602,1380C1602,1379 1602,1377 1602,1376C1601,1375 1601,1374 1601,1374C1600,1373 1599,1372 1598,1372C1597,1372 1596,1371 1593,1371L1589,1371L1589,1381L1590,1381C1592,1381 1593,1380 1593,1380C1594,1379 1594,1378 1594,1376L1594,1375L1598,1375L1598,1391L1594,1391C1594,1388 1594,1387 1593,1386C1593,1385 1592,1385 1590,1385L1589,1385L1589,1393C1589,1394 1589,1395 1589,1395C1590,1395 1590,1396 1592,1396L1593,1396L1593,1400L1574,1400L1574,1396L1575,1396C1576,1396 1577,1395 1577,1395C1578,1395 1578,1394 1578,1393L1578,1384C1581,1380 1584,1378 1588,1378C1584,1377 1581,1378 1578,1380ZM1613,1373C1613,1372 1613,1372 1612,1372C1612,1371 1611,1371 1611,1371L1609,1371L1609,1367L1623,1367L1623,1394C1623,1395 1623,1395 1623,1395C1623,1396 1624,1396 1625,1396L1626,1396L1626,1400L1609,1400L1609,1396L1611,1396C1611,1396 1612,1396 1612,1395C1613,1395 1613,1394 1613,1394L1613,1373ZM1642,1376C1646,1376 1650,1377 1652,1379C1655,1381 1656,1385 1656,1388C1656,1392 1655,1395 1652,1398C1650,1400 1646,1401 1642,1401C1637,1401 1634,1400 1631,1398C1629,1396 1628,1392 1628,1388C1628,1385 1629,1381 1631,1379C1634,1377 1637,1376 1642,1376ZM1646,1388C1646,1385 1645,1383 1645,1382C1644,1381 1643,1380 1642,1380C1641,1380 1640,1381 1639,1382C1639,1383 1638,1385 1638,1388C1638,1392 1639,1394 1639,1395C1640,1396 1641,1397 1642,1397C1643,1397 1644,1396 1645,1395C1645,1394 1646,1392 1646,1388ZM1676,1400L1665,1400L1661,1385C1661,1383 1661,1382 1660,1382C1660,1381 1660,1381 1659,1381L1658,1381L1658,1377L1672,1377L1672,1381L1671,1381C1671,1381 1670,1381 1670,1381C1670,1382 1670,1382 1670,1382C1670,1383 1670,1383 1670,1383C1670,1383 1670,1383 1670,1383L1673,1394L1676,1383C1676,1383 1676,1383 1676,1383C1676,1383 1676,1383 1676,1383C1676,1382 1676,1382 1676,1382C1675,1381 1675,1381 1674,1381L1674,1377L1688,1377L1688,1381L1688,1381C1687,1381 1687,1381 1686,1381C1686,1382 1686,1382 1686,1382C1686,1383 1686,1383 1686,1383C1686,1383 1686,1383 1686,1383L1689,1394L1692,1383C1692,1383 1692,1383 1692,1383C1692,1383 1692,1383 1692,1383C1692,1382 1692,1382 1692,1382C1691,1381 1691,1381 1690,1381L1690,1377L1700,1377L1700,1381C1699,1381 1699,1381 1698,1382C1698,1382 1697,1383 1697,1384L1692,1400L1682,1400L1679,1389L1676,1400Z" style="fill:rgb(0,175,239)"/>
        </g>
        <g transform="matrix(1,0,0,1,-528.830537,-801.673623)">
          <path d="M2563,1375L2532,1386L2548,1390C2482,1433 2409,1433 2334,1413C2208,1371 2126,1397 2093,1425C2137,1404 2182,1383 2332,1427C2437,1454 2500,1434 2549,1391L2555,1407L2563,1375Z" style="fill:rgb(43,40,77)"/>
        </g>
        <g transform="matrix(2.0287,0,0,2.0287,-1440.439706,-2268.928969)">
          <path d="M1472,1380L1472,1372L1464,1400L1456,1400L1448,1372L1448,1393C1448,1394 1448,1395 1448,1395C1448,1395 1449,1396 1450,1396L1452,1396L1452,1400L1437,1400L1437,1396L1438,1396C1439,1396 1440,1395 1440,1395C1441,1395 1441,1394 1441,1393L1441,1374C1441,1373 1441,1372 1440,1372C1440,1372 1439,1371 1438,1371L1437,1371L1437,1367L1455,1367L1461,1387L1467,1367L1487,1367L1487,1371L1485,1371C1484,1371 1483,1372 1483,1372C1482,1372 1482,1373 1482,1374L1482,1377C1478,1377 1475,1378 1472,1380ZM1482,1378L1482,1393C1482,1394 1482,1395 1483,1395C1483,1395 1484,1396 1485,1396L1487,1396L1487,1400L1468,1400L1468,1396L1469,1396C1471,1396 1471,1395 1472,1395C1472,1395 1472,1394 1472,1393L1472,1385C1475,1381 1478,1379 1482,1378ZM1551,1394C1551,1395 1551,1395 1551,1395C1551,1396 1552,1396 1553,1396L1554,1396L1554,1400L1538,1400L1538,1396L1539,1396C1540,1396 1540,1396 1540,1395C1541,1395 1541,1394 1541,1394L1541,1385C1541,1384 1541,1383 1540,1382C1540,1381 1539,1381 1538,1381C1536,1381 1536,1381 1535,1382C1534,1383 1534,1384 1534,1386L1534,1394C1534,1394 1534,1395 1534,1395C1535,1396 1535,1396 1536,1396L1537,1396L1537,1400L1521,1400L1521,1396L1522,1396C1523,1396 1523,1396 1524,1395C1524,1395 1524,1394 1524,1394L1524,1383C1524,1382 1524,1382 1524,1382C1523,1381 1523,1381 1522,1381L1521,1381L1521,1377L1534,1377L1534,1380C1535,1379 1536,1378 1537,1377C1539,1376 1541,1376 1542,1376C1545,1376 1548,1377 1549,1378C1550,1379 1551,1382 1551,1385L1551,1394ZM1559,1370C1559,1369 1559,1368 1560,1367C1561,1366 1562,1366 1563,1366C1564,1366 1565,1366 1566,1367C1567,1368 1568,1369 1568,1370C1568,1372 1567,1373 1566,1373C1565,1374 1564,1375 1563,1375C1562,1375 1561,1374 1560,1373C1559,1373 1559,1372 1559,1370ZM1569,1394C1569,1394 1569,1395 1569,1395C1569,1396 1570,1396 1571,1396L1572,1396L1572,1400L1555,1400L1555,1396L1556,1396C1557,1396 1558,1396 1558,1395C1559,1395 1559,1394 1559,1394L1559,1383C1559,1382 1559,1382 1558,1382C1558,1381 1557,1381 1556,1381L1555,1381L1555,1377L1569,1377L1569,1394Z" style="fill:rgb(43,40,77)"/>
        </g>
        <g transform="matrix(1,0,0,1,-528.88881,-787.821591)">
          <path d="M2221,1276L2228,1274L2243,1282L2235,1298L2227,1298L2232,1285L2221,1276ZM2203,1280L2210,1280L2221,1290L2211,1301L2204,1301L2212,1290L2203,1280ZM2187,1281L2193,1281L2201,1290L2192,1298L2186,1298L2193,1291L2187,1281ZM2173,1281L2177,1281L2183,1289L2176,1295L2171,1294L2177,1289L2173,1281ZM2161,1280L2164,1280L2168,1287L2163,1291L2159,1291L2164,1286L2161,1280ZM2150,1278L2152,1278L2156,1284L2151,1287L2148,1286L2153,1283L2150,1278Z" style="fill:rgb(43,40,77)"/>
        </g>
        <g transform="matrix(1,0,0,1,-516.73266,-789.9811)">
          <path d="M2330,1238L2340,1239L2355,1261L2335,1273L2325,1271L2340,1256L2330,1238ZM2295,1239L2305,1237L2326,1254L2309,1271L2299,1273L2309,1254L2295,1239ZM2271,1248L2279,1247L2293,1257L2283,1272L2275,1273L2282,1259L2271,1248ZM2250,1256L2256,1254L2269,1261L2262,1275L2256,1276L2260,1264L2250,1256ZM2236,1265L2240,1264L2247,1268L2244,1276L2240,1276L2242,1269L2236,1265Z" style="fill:rgb(0,175,239)"/>
        </g>
        <g transform="matrix(0.146577,0,0,0.146577,1317.731401,463.539975)">
          <path d="M1998,372L2210,495L2210,739L1998,861L1787,739L1787,495L1998,372Z" style="fill:rgb(43,40,77)"/>
        </g>
        <g transform="matrix(0.086386,0,0,0.086386,1438.001275,500.658132)">
          <path d="M1998,372L2210,495L2210,739L1998,861L1787,739L1787,495L1998,372Z" style="fill:white"/>
        </g>
        <g transform="matrix(0.171894,0,0,0.171894,1327.371109,340.735053)">
          <g transform="matrix(0.337832,0,0,0.337832,1125.271447,963.892818)">
            <path d="M1318,669L1556,804L1776,670L1547,537L1318,669Z"/>
          </g>
          <g transform="matrix(0.337832,0,0,0.337832,1125.271447,963.892818)">
            <path d="M1299,699L1534,837L1526,1098L1299,967L1299,699Z" style="fill:rgb(0,175,239)"/>
          </g>
          <g transform="matrix(0.337832,0,0,0.337832,1125.271447,963.892818)">
            <path d="M1590,823L1794,700L1794,946L1590,823Z" style="fill:rgb(210,211,213)"/>
          </g>
          <g transform="matrix(0.337832,0,0,0.337832,1125.271447,963.892818)">
            <path d="M1575,850L1780,973L1567,1098L1575,850Z" style="fill:rgb(0,175,239)"/>
          </g>
        </g>
        <g transform="matrix(1,0,0,1,-528.830537,-797.640371)">
          <path d="M2123,1418C2171,1406 2208,1414 2265,1430C2283,1435 2359,1455 2380,1457C2451,1463 2504,1447 2542,1403C2493,1441 2432,1453 2369,1443C2356,1441 2294,1425 2279,1421C2181,1396 2158,1405 2123,1418Z" style="fill:rgb(0,175,239)"/>
        </g>
      </g>
    </svg>
    """
}

// MARK: - WeakRef helper

private class WeakRef<T: AnyObject> {
    weak var value: T?
    init(_ value: T) { self.value = value }
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
