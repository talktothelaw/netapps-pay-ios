// ============================================================
// 3DS POPUP VIEW CONTROLLER
// Presents the 3DS challenge HTML in an auto-sized popup card
// that wraps the WebView content height so it looks native.
// Includes a header ("Secure Verification" + Cancel) and a
// "Secured by NetappsPAY" footer.
// ============================================================

import UIKit
import WebKit

protocol ThreeDSPopupDelegate: AnyObject {
    /// 3DS flow completed (navigation hit payment-complete / callback)
    func threeDSPopupDidComplete()
    /// User tapped Cancel
    func threeDSPopupDidCancel()
    /// JS postMessage received from the embedded HTML
    func threeDSPopupDidReceiveMessage(_ message: Any, type: String)
}

final class ThreeDSPopupViewController: UIViewController {

    // MARK: - Constants

    /// Header (title + cancel) height
    private let headerHeight: CGFloat = 52
    /// Separator line thickness
    private let separatorHeight: CGFloat = 1
    /// Footer ("Secured by …") height including padding
    private let footerHeight: CGFloat = 36
    /// Extra breathing room below the webView content
    private let extraBottomPadding: CGFloat = 20
    /// Minimum card height so spinner is visible while loading
    private let minimumCardHeight: CGFloat = 300
    /// Horizontal inset from screen edges
    private let horizontalInset: CGFloat = 20

    // MARK: - Properties

    weak var delegate: ThreeDSPopupDelegate?

    private let html: String
    private let type: String          // "DEVICE_COLLECTION" or "3DS_CHALLENGE"
    private var webView: WKWebView!

    /// Dynamic height constraint adjusted after content loads
    private var cardHeightConstraint: NSLayoutConstraint!

    // MARK: - UI Elements

    /// Semi-transparent backdrop
    private let backdropView: UIView = {
        let v = UIView()
        v.backgroundColor = UIColor.black.withAlphaComponent(0.45)
        v.translatesAutoresizingMaskIntoConstraints = false
        return v
    }()

    /// White card that holds header + webView + footer
    private let cardView: UIView = {
        let v = UIView()
        v.backgroundColor = .white
        v.layer.cornerRadius = 16
        v.clipsToBounds = true
        v.translatesAutoresizingMaskIntoConstraints = false
        return v
    }()

    /// Light header bar
    private let headerView: UIView = {
        let v = UIView()
        v.backgroundColor = UIColor(hex: "#F7F8FA")
        v.translatesAutoresizingMaskIntoConstraints = false
        return v
    }()

    private let headerTitle: UILabel = {
        let lbl = UILabel()
        lbl.text = "Secure Verification"
        lbl.font = UIFont.systemFont(ofSize: 16, weight: .semibold)
        lbl.textColor = UIColor(hex: "#1A1A2E")
        lbl.translatesAutoresizingMaskIntoConstraints = false
        return lbl
    }()

    private let cancelButton: UIButton = {
        let btn = UIButton(type: .system)
        btn.setTitle("Cancel", for: .normal)
        btn.titleLabel?.font = UIFont.systemFont(ofSize: 15, weight: .medium)
        btn.setTitleColor(UIColor(hex: "#E74C3C"), for: .normal)
        btn.translatesAutoresizingMaskIntoConstraints = false
        return btn
    }()

    private let separatorLine: UIView = {
        let v = UIView()
        v.backgroundColor = UIColor(hex: "#E0E0E0")
        v.translatesAutoresizingMaskIntoConstraints = false
        return v
    }()

    /// Activity indicator while the page loads
    private let activityIndicator: UIActivityIndicatorView = {
        let ai: UIActivityIndicatorView
        if #available(iOS 13.0, *) {
            ai = UIActivityIndicatorView(style: .large)
        } else {
            ai = UIActivityIndicatorView(style: .whiteLarge)
            ai.color = .gray
        }
        ai.hidesWhenStopped = true
        ai.translatesAutoresizingMaskIntoConstraints = false
        return ai
    }()

    /// Secured-by footer
    private let footerLabel: UILabel = {
        let lbl = UILabel()
        lbl.text = "🔒 Secured by NetappsPAY"
        lbl.font = UIFont.systemFont(ofSize: 11, weight: .regular)
        lbl.textColor = UIColor(hex: "#8E8E93")
        lbl.textAlignment = .center
        lbl.translatesAutoresizingMaskIntoConstraints = false
        return lbl
    }()

    // MARK: - PostMessage Bridge

    /// Bridge script that:
    /// 1. Forwards all postMessage calls to native via paymentSDK handler
    /// 2. Intercepts form submissions to the returnUrl and notifies native
    /// 3. Observes DOM mutations for success indicators (AJAX-based 3DS flows)
    private static let postMessageBridgeScript = """
    (function() {
        // ── 1. Forward postMessages to native ──
        var origPostMessage = window.postMessage.bind(window);
        window.postMessage = function(message, targetOrigin, transfer) {
            try {
                if (window.webkit && window.webkit.messageHandlers && window.webkit.messageHandlers.paymentSDK) {
                    window.webkit.messageHandlers.paymentSDK.postMessage(message);
                }
            } catch(e) {}
            return origPostMessage(message, targetOrigin, transfer);
        };
        window.addEventListener('message', function(event) {
            try {
                if (window.webkit && window.webkit.messageHandlers && window.webkit.messageHandlers.paymentSDK) {
                    window.webkit.messageHandlers.paymentSDK.postMessage(event.data);
                }
            } catch(e) {}
        });

        // ── 2. Intercept form submissions to returnUrl ──
        document.addEventListener('submit', function(e) {
            var form = e.target;
            if (form && form.action && form.action.indexOf('payment-complete') !== -1) {
                try {
                    window.webkit.messageHandlers.paymentSDK.postMessage({
                        type: 'payment-complete',
                        source: '3ds-form-submit'
                    });
                } catch(ex) {}
            }
        }, true);

        // ── 3. Watch for success text in the DOM (AJAX-based flows) ──
        var completionSent = false;
        function checkForCompletion() {
            if (completionSent) return;
            var body = document.body;
            if (!body) return;
            var text = body.innerText || body.textContent || '';
            var lower = text.toLowerCase();
            if (
                (lower.indexOf('payment successful') !== -1) ||
                (lower.indexOf('transaction approved') !== -1) ||
                (lower.indexOf('payment complete') !== -1) ||
                (lower.indexOf('authentication successful') !== -1) ||
                (lower.indexOf('verification successful') !== -1)
            ) {
                completionSent = true;
                try {
                    window.webkit.messageHandlers.paymentSDK.postMessage({
                        type: 'payment-complete',
                        source: '3ds-content-detect'
                    });
                } catch(ex) {}
            }
        }
        // Use MutationObserver to watch for DOM changes
        if (typeof MutationObserver !== 'undefined') {
            var observer = new MutationObserver(function() { checkForCompletion(); });
            var startObserving = function() {
                if (document.body) {
                    observer.observe(document.body, { childList: true, subtree: true, characterData: true });
                    checkForCompletion();
                } else {
                    setTimeout(startObserving, 100);
                }
            };
            startObserving();
        }
        // Also poll every 2s as a fallback
        setInterval(checkForCompletion, 2000);
    })();
    """

    // MARK: - Init

    init(html: String, type: String) {
        self.html = html
        self.type = type
        super.init(nibName: nil, bundle: nil)

        modalPresentationStyle = .overFullScreen
        modalTransitionStyle = .crossDissolve
    }

    required init?(coder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }

    // MARK: - Lifecycle

    override func viewDidLoad() {
        super.viewDidLoad()
        view.backgroundColor = .clear
        setupLayout()
        setupWebView()
        cancelButton.addTarget(self, action: #selector(cancelTapped), for: .touchUpInside)

        activityIndicator.startAnimating()
        webView.loadHTMLString(wrapHtmlForMobile(html), baseURL: nil)
    }

    // MARK: - Layout

    private func setupLayout() {
        // -- Backdrop --
        view.addSubview(backdropView)
        NSLayoutConstraint.activate([
            backdropView.topAnchor.constraint(equalTo: view.topAnchor),
            backdropView.leadingAnchor.constraint(equalTo: view.leadingAnchor),
            backdropView.trailingAnchor.constraint(equalTo: view.trailingAnchor),
            backdropView.bottomAnchor.constraint(equalTo: view.bottomAnchor),
        ])
        let tap = UITapGestureRecognizer(target: self, action: #selector(cancelTapped))
        backdropView.addGestureRecognizer(tap)

        // -- Card --
        view.addSubview(cardView)

        let isDeviceCollection = type == "DEVICE_COLLECTION"
        if isDeviceCollection {
            // Invisible — only runs JS
            NSLayoutConstraint.activate([
                cardView.widthAnchor.constraint(equalToConstant: 1),
                cardView.heightAnchor.constraint(equalToConstant: 1),
                cardView.centerXAnchor.constraint(equalTo: view.centerXAnchor),
                cardView.centerYAnchor.constraint(equalTo: view.centerYAnchor),
            ])
            cardView.isHidden = true
            return // skip the rest of the layout for device-collection
        }

        // Card centred horizontally with insets; centred vertically with auto-height
        cardHeightConstraint = cardView.heightAnchor.constraint(equalToConstant: minimumCardHeight)
        cardHeightConstraint.priority = .defaultHigh // can be overridden by max-height

        NSLayoutConstraint.activate([
            cardView.leadingAnchor.constraint(equalTo: view.leadingAnchor, constant: horizontalInset),
            cardView.trailingAnchor.constraint(equalTo: view.trailingAnchor, constant: -horizontalInset),
            cardView.centerYAnchor.constraint(equalTo: view.centerYAnchor),
            cardHeightConstraint,
            // Never taller than safe-area minus 40pt top/bottom
            cardView.topAnchor.constraint(greaterThanOrEqualTo: view.safeAreaLayoutGuide.topAnchor, constant: 20),
            cardView.bottomAnchor.constraint(lessThanOrEqualTo: view.safeAreaLayoutGuide.bottomAnchor, constant: -20),
        ])

        // Shadow on the card layer (applied outside clipsToBounds via a wrapper isn't
        // needed because the backdrop already darkens the background)

        // -- Header --
        cardView.addSubview(headerView)
        headerView.addSubview(headerTitle)
        headerView.addSubview(cancelButton)
        cardView.addSubview(separatorLine)

        NSLayoutConstraint.activate([
            headerView.topAnchor.constraint(equalTo: cardView.topAnchor),
            headerView.leadingAnchor.constraint(equalTo: cardView.leadingAnchor),
            headerView.trailingAnchor.constraint(equalTo: cardView.trailingAnchor),
            headerView.heightAnchor.constraint(equalToConstant: headerHeight),

            headerTitle.centerYAnchor.constraint(equalTo: headerView.centerYAnchor),
            headerTitle.leadingAnchor.constraint(equalTo: headerView.leadingAnchor, constant: 16),

            cancelButton.centerYAnchor.constraint(equalTo: headerView.centerYAnchor),
            cancelButton.trailingAnchor.constraint(equalTo: headerView.trailingAnchor, constant: -16),

            separatorLine.topAnchor.constraint(equalTo: headerView.bottomAnchor),
            separatorLine.leadingAnchor.constraint(equalTo: cardView.leadingAnchor),
            separatorLine.trailingAnchor.constraint(equalTo: cardView.trailingAnchor),
            separatorLine.heightAnchor.constraint(equalToConstant: separatorHeight),
        ])

        // -- Footer --
        cardView.addSubview(footerLabel)
        NSLayoutConstraint.activate([
            footerLabel.bottomAnchor.constraint(equalTo: cardView.bottomAnchor, constant: -8),
            footerLabel.centerXAnchor.constraint(equalTo: cardView.centerXAnchor),
            footerLabel.heightAnchor.constraint(equalToConstant: 20),
        ])

        // -- Activity Indicator (centered in the webView area) --
        cardView.addSubview(activityIndicator)
        NSLayoutConstraint.activate([
            activityIndicator.centerXAnchor.constraint(equalTo: cardView.centerXAnchor),
            activityIndicator.centerYAnchor.constraint(equalTo: cardView.centerYAnchor, constant: headerHeight / 2),
        ])
    }

    // MARK: - WebView setup

    /// JavaScript that force-enables paste on all input/textarea elements,
    /// overriding any `onpaste` handlers or `preventDefault()` calls from external pages.
    private static let enablePasteScript = """
    (function() {
        function enablePaste(el) {
            el.onpaste = null;
            el.removeAttribute('onpaste');
            el.removeAttribute('oncopy');
            el.removeAttribute('oncut');
            el.style.webkitUserSelect = 'text';
            el.style.userSelect = 'text';
            el.readOnly = false;
        }
        function enableAll() {
            document.querySelectorAll('input, textarea').forEach(enablePaste);
        }
        // Intercept addEventListener to prevent paste-blocking
        var origAdd = EventTarget.prototype.addEventListener;
        EventTarget.prototype.addEventListener = function(type, fn, opts) {
            if (type === 'paste' || type === 'copy' || type === 'cut') return;
            return origAdd.call(this, type, fn, opts);
        };
        // Initial pass
        if (document.readyState === 'loading') {
            document.addEventListener('DOMContentLoaded', enableAll);
        } else {
            enableAll();
        }
        // Watch for dynamically added elements
        new MutationObserver(enableAll).observe(document.documentElement, {
            childList: true, subtree: true
        });
    })();
    """

    private func setupWebView() {
        let config = WKWebViewConfiguration()
        config.preferences.javaScriptEnabled = true

        let handler = PopupMessageHandler { [weak self] message in
            guard let self = self else { return }
            
            // Check for completion signals (matching the web's EmbeddableFrame logic)
            if self.isCompletionMessage(message) {
                self.handleCompletionDetected()
                return
            }
            
            self.delegate?.threeDSPopupDidReceiveMessage(message, type: self.type)
        }
        config.userContentController.add(handler, name: "paymentSDK")

        let bridgeScript = WKUserScript(
            source: Self.postMessageBridgeScript,
            injectionTime: .atDocumentStart,
            forMainFrameOnly: false
        )
        config.userContentController.addUserScript(bridgeScript)

        // Inject paste-enabling script for external verification pages
        let pasteScript = WKUserScript(
            source: Self.enablePasteScript,
            injectionTime: .atDocumentStart,
            forMainFrameOnly: false
        )
        config.userContentController.addUserScript(pasteScript)

        let wv = WKWebView(frame: .zero, configuration: config)
        wv.navigationDelegate = self
        wv.scrollView.bounces = false
        wv.scrollView.isScrollEnabled = true
        wv.isOpaque = false
        wv.backgroundColor = .white
        wv.translatesAutoresizingMaskIntoConstraints = false

        cardView.addSubview(wv)
        NSLayoutConstraint.activate([
            wv.topAnchor.constraint(equalTo: separatorLine.bottomAnchor),
            wv.leadingAnchor.constraint(equalTo: cardView.leadingAnchor),
            wv.trailingAnchor.constraint(equalTo: cardView.trailingAnchor),
            wv.bottomAnchor.constraint(equalTo: footerLabel.topAnchor, constant: -4),
        ])
        webView = wv
    }

    // MARK: - Mobile-Responsive HTML Wrapping

    /// Wraps the 3DS HTML with viewport meta tag and responsive CSS
    /// so the content renders properly on mobile screens.
    private func wrapHtmlForMobile(_ rawHtml: String) -> String {
        let hasViewport = rawHtml.range(of: "viewport", options: .caseInsensitive) != nil
        let viewportMeta = hasViewport ? "" :
            "<meta name=\"viewport\" content=\"width=device-width, initial-scale=1.0, maximum-scale=1.0, user-scalable=no\">"

        let responsiveCss = """
        <style>
            html, body {
                width: 100% !important;
                max-width: 100vw !important;
                overflow-x: hidden !important;
                -webkit-text-size-adjust: 100% !important;
            }
            body {
                margin: 0 !important;
                padding: 8px !important;
                box-sizing: border-box !important;
            }
            img, table, form, div {
                max-width: 100% !important;
            }
            iframe {
                width: 100% !important;
                min-height: 350px !important;
                border: none !important;
            }
            input, select, textarea, button {
                max-width: 100% !important;
                box-sizing: border-box !important;
                font-size: 16px !important;
            }
            table {
                table-layout: fixed !important;
                word-wrap: break-word !important;
            }
        </style>
        """

        let headPattern = try? NSRegularExpression(pattern: "<head[^>]*>", options: .caseInsensitive)
        let htmlPattern = try? NSRegularExpression(pattern: "<html[^>]*>", options: .caseInsensitive)
        let range = NSRange(rawHtml.startIndex..., in: rawHtml)

        if let match = headPattern?.firstMatch(in: rawHtml, range: range) {
            let insertIdx = rawHtml.index(rawHtml.startIndex, offsetBy: match.range.location + match.range.length)
            var result = rawHtml
            result.insert(contentsOf: viewportMeta + "\n" + responsiveCss, at: insertIdx)
            return result
        } else if let match = htmlPattern?.firstMatch(in: rawHtml, range: range) {
            let insertIdx = rawHtml.index(rawHtml.startIndex, offsetBy: match.range.location + match.range.length)
            var result = rawHtml
            result.insert(contentsOf: "<head>" + viewportMeta + "\n" + responsiveCss + "</head>", at: insertIdx)
            return result
        } else {
            return "<html><head>\(viewportMeta)\n\(responsiveCss)</head><body>\(rawHtml)</body></html>"
        }
    }

    // MARK: - Auto-size card to content

    private func resizeCardToFitContent() {
        webView.evaluateJavaScript("document.body.scrollHeight") { [weak self] result, _ in
            guard let self = self, let contentHeight = result as? CGFloat else { return }

            let chrome = self.headerHeight + self.separatorHeight + self.footerHeight + self.extraBottomPadding
            let idealHeight = contentHeight + chrome

            // Cap to available screen space
            let safeArea = self.view.safeAreaLayoutGuide.layoutFrame.height
            let maxHeight = safeArea - 40 // 20pt top + 20pt bottom
            let finalHeight = max(self.minimumCardHeight, min(idealHeight, maxHeight))

            guard abs(finalHeight - self.cardHeightConstraint.constant) > 1 else { return }

            UIView.animate(withDuration: 0.25, delay: 0, options: .curveEaseOut) {
                self.cardHeightConstraint.constant = finalHeight
                self.view.layoutIfNeeded()
            }
        }
    }

    // MARK: - Actions

    @objc private func cancelTapped() {
        dismiss(animated: true) { [weak self] in
            self?.delegate?.threeDSPopupDidCancel()
        }
    }
    
    // MARK: - Completion Detection
    
    /// Prevent firing completion more than once
    private var completionFired = false
    
    /// Central handler: dismiss popup and notify delegate once we detect 3DS is done
    private func handleCompletionDetected() {
        guard !completionFired else { return }
        completionFired = true
        
        dismiss(animated: true) { [weak self] in
            self?.delegate?.threeDSPopupDidComplete()
        }
    }
    
    /// Inspect a postMessage payload for known completion signals
    /// (mirrors the web's EmbeddableFrame message handler)
    private func isCompletionMessage(_ message: Any) -> Bool {
        // Dictionary / JSON object messages
        if let dict = message as? [String: Any] {
            // { type: "payment-complete" }  or  { status: "complete" }
            if let type = dict["type"] as? String,
               type.lowercased().contains("payment-complete") { return true }
            if let status = dict["status"] as? String,
               status.lowercased() == "complete" { return true }
            // { source: "payment-iframe", status: "success" }
            if let source = dict["source"] as? String, source == "payment-iframe",
               let status = dict["status"] as? String, status == "success" { return true }
            // { source: "3ds-form-submit" } or { source: "3ds-content-detect" }
            if let source = dict["source"] as? String,
               source.hasPrefix("3ds-") { return true }
            // Cardinal: { MessageType: "profile.completed" }
            if let mt = dict["MessageType"] as? String,
               mt == "profile.completed" { return true }
        }
        // String messages
        if let str = message as? String {
            let lower = str.lowercased()
            if lower == "complete" || lower == "payment-complete" { return true }
            // Try JSON parse
            if let data = str.data(using: .utf8),
               let json = try? JSONSerialization.jsonObject(with: data) as? [String: Any] {
                return isCompletionMessage(json)
            }
        }
        return false
    }
}

// MARK: - WKNavigationDelegate

extension ThreeDSPopupViewController: WKNavigationDelegate {

    func webView(_ webView: WKWebView, didFinish navigation: WKNavigation!) {
        activityIndicator.stopAnimating()

        // Check for completion URL first
        if let url = webView.url?.absoluteString,
           url.contains("payment-complete") || url.contains("callback") {
            handleCompletionDetected()
            return
        }

        // Inject viewport meta into navigated pages that lack one
        webView.evaluateJavaScript("""
            (function() {
                if (!document.querySelector('meta[name=viewport]')) {
                    var meta = document.createElement('meta');
                    meta.name = 'viewport';
                    meta.content = 'width=device-width, initial-scale=1.0, maximum-scale=1.0, user-scalable=no';
                    document.head.appendChild(meta);
                }
            })();
        """, completionHandler: nil)

        // Auto-size the popup card to the actual content height
        // Give the page a moment to finish rendering
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.3) { [weak self] in
            self?.resizeCardToFitContent()
        }
    }

    func webView(_ webView: WKWebView, didFail navigation: WKNavigation!, withError error: Error) {
        activityIndicator.stopAnimating()
    }

    func webView(
        _ webView: WKWebView,
        decidePolicyFor navigationAction: WKNavigationAction,
        decisionHandler: @escaping (WKNavigationActionPolicy) -> Void
    ) {
        if let url = navigationAction.request.url?.absoluteString,
           url.contains("payment-complete") || url.contains("callback") || url.contains("return_url") {
            decisionHandler(.cancel)
            handleCompletionDetected()
            return
        }
        decisionHandler(.allow)
    }
}

// MARK: - Private message handler

private final class PopupMessageHandler: NSObject, WKScriptMessageHandler {
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
