// ============================================================
// TRANSACTION POLLER — SSE-first, polling fallback
// ============================================================
//
// Strategy (mirrors the web useTransactionPolling hook):
//   1. Connect to SSE endpoint for real-time status updates.
//   2. If SSE is healthy (receiving pings / status events), do NOT poll.
//      Server sends a ping every 5s; if nothing arrives for 15s
//      (3 missed pings), the connection is considered dead.
//   3. If SSE disconnects or no ping within PING_TIMEOUT:
//      a. Try reconnecting with exponential backoff (2s, 4s, 8s…)
//         up to MAX_RECONNECT_ATTEMPTS times.
//      b. If all reconnects fail, ALWAYS fall back to interval polling.
//   4. On terminal status, fire delegate and stop everything.
//
// The delegate interface is unchanged — consumers don't know
// whether updates come from SSE or polling.
// ============================================================

import Foundation

protocol TransactionPollerDelegate: AnyObject {
    func poller(_ poller: TransactionPoller, didUpdateStatus status: TransactionStatus, response: TransactionDetailsResponse)
    func poller(_ poller: TransactionPoller, didComplete response: TransactionDetailsResponse)
    func poller(_ poller: TransactionPoller, didFailWithError error: PaymentAPIError)
}

final class TransactionPoller: NSObject, URLSessionDataDelegate {
    
    // MARK: - Properties
    
    weak var delegate: TransactionPollerDelegate?
    
    private let api: PaymentAPIClient
    private let pollInterval: TimeInterval
    private let maxAttempts: Int
    private let maxDuration: TimeInterval
    private let initialDelay: TimeInterval
    
    // State
    private var transactionId: String?   // for GET /transactions/:id polling
    private var systemTxRef: String?     // for SSE /sse/:systemTxRef/subscribe
    private var pollCount: Int = 0
    private var consecutiveNetworkErrors: Int = 0
    private var reconnectCount: Int = 0
    
    private(set) var isPolling: Bool = false
    private(set) var lastStatus: TransactionStatus?
    private var pollingRequested: Bool = false // true after startPolling called
    
    // Timers
    private var pollTimer: Timer?
    private var maxDurationTimer: Timer?
    private var pingTimeoutTimer: Timer?
    
    // SSE
    private var sseTask: URLSessionDataTask?
    private var sseSession: URLSession?
    private var sseConnected: Bool = false
    private var pollingActive: Bool = false
    private var sseBuffer: String = "" // accumulate partial SSE chunks
    private var sseIntentionallyClosed: Bool = false // prevents double handleSSELost
    private var consecutivePingTimeouts: Int = 0     // tracks reconnect-but-still-no-data loops
    private var sseAbandonedForGood: Bool = false    // once true, never attempt SSE again
    
    // MARK: - Init
    
    init(
        api: PaymentAPIClient = .shared,
        interval: TimeInterval = APIConfig.Polling.interval,
        maxAttempts: Int = APIConfig.Polling.maxAttempts,
        maxDuration: TimeInterval = APIConfig.Polling.maxDuration,
        initialDelay: TimeInterval = APIConfig.Polling.initialDelay
    ) {
        self.api = api
        self.pollInterval = interval
        self.maxAttempts = maxAttempts
        self.maxDuration = maxDuration
        self.initialDelay = initialDelay
        super.init()
    }
    
    // MARK: - Public: Start SSE Early (at init time)
    
    func startSSE(systemTxRef: String, transactionId: String) {
        stopPolling()
        
        self.systemTxRef = systemTxRef
        self.transactionId = transactionId
        self.pollCount = 0
        self.consecutiveNetworkErrors = 0
        self.reconnectCount = 0
        self.isPolling = true
        self.pollingRequested = false
        self.sseBuffer = ""
        self.sseIntentionallyClosed = false
        self.consecutivePingTimeouts = 0
        self.sseAbandonedForGood = false
        
        // Max duration timeout (absolute limit)
        DispatchQueue.main.async { [weak self] in
            guard let self = self else { return }
            self.maxDurationTimer = Timer.scheduledTimer(
                withTimeInterval: self.maxDuration,
                repeats: false
            ) { [weak self] _ in
                guard let self = self else { return }
                self.stopPolling()
                let error = PaymentAPIError.timeoutError(ErrorMessages.pollingTimeout)
                self.delegate?.poller(self, didFailWithError: error)
            }
        }
        
        if PaymentSDK.debugMode {
            print("[NetAppsPaySDK] Connecting SSE early (init phase) with systemTxRef: \(systemTxRef)")
        }
        connectSSE(systemTxRef: systemTxRef)
    }
    
    // MARK: - Public: Start Polling (checks SSE first)
    
    func startPolling(systemTxRef: String, transactionId: String) {
        pollingRequested = true
        
        // If SSE is already connected — it's handling updates, skip polling
        if sseConnected {
            if PaymentSDK.debugMode {
                print("[NetAppsPaySDK] SSE already connected — no polling needed")
            }
            return
        }
        
        // SSE not connected — reset reconnect counter and try SSE fresh
        if PaymentSDK.debugMode {
            print("[NetAppsPaySDK] SSE not connected — attempting SSE before polling")
        }
        reconnectCount = 0
        
        // If startSSE wasn't called earlier, set up fresh
        if !isPolling {
            self.systemTxRef = systemTxRef
            self.transactionId = transactionId
            self.pollCount = 0
            self.consecutiveNetworkErrors = 0
            self.isPolling = true
            self.sseBuffer = ""
            self.sseIntentionallyClosed = false
            
            DispatchQueue.main.async { [weak self] in
                guard let self = self else { return }
                self.maxDurationTimer = Timer.scheduledTimer(
                    withTimeInterval: self.maxDuration,
                    repeats: false
                ) { [weak self] _ in
                    guard let self = self else { return }
                    self.stopPolling()
                    let error = PaymentAPIError.timeoutError(ErrorMessages.pollingTimeout)
                    self.delegate?.poller(self, didFailWithError: error)
                }
            }
        }
        
        connectSSE(systemTxRef: systemTxRef)
    }
    
    // MARK: - Public: Stop
    
    func stopPolling() {
        isPolling = false
        
        // SSE
        sseIntentionallyClosed = true
        sseTask?.cancel()
        sseTask = nil
        sseSession?.invalidateAndCancel()
        sseSession = nil
        sseConnected = false
        sseBuffer = ""
        
        // Ping timeout
        pingTimeoutTimer?.invalidate()
        pingTimeoutTimer = nil
        
        // Poll timer
        pollTimer?.invalidate()
        pollTimer = nil
        pollingActive = false
        
        // Duration timer
        maxDurationTimer?.invalidate()
        maxDurationTimer = nil
        
        transactionId = nil
        systemTxRef = nil
    }
    
    // MARK: - Handle Response (from SSE or poll)
    
    private func handleTransactionResponse(_ response: TransactionDetailsResponse) {
        guard isPolling else { return }
        
        let status = response.status
        lastStatus = status
        delegate?.poller(self, didUpdateStatus: status, response: response)
        
        if status.isSuccess || status.isTerminal {
            stopPolling()
            delegate?.poller(self, didComplete: response)
        }
    }
    
    // ================================================================
    // SSE
    // ================================================================
    
    private func connectSSE(systemTxRef: String) {
        // If SSE was permanently abandoned, go straight to polling
        if sseAbandonedForGood {
            startIntervalPolling()
            return
        }
        
        // Close any existing SSE
        sseIntentionallyClosed = true    // prevent delegate callback from triggering handleSSELost
        sseTask?.cancel()
        sseTask = nil
        sseSession?.invalidateAndCancel()
        sseSession = nil
        sseConnected = false
        sseBuffer = ""
        pingTimeoutTimer?.invalidate()
        pingTimeoutTimer = nil
        sseIntentionallyClosed = false   // new connection — delegate callbacks are valid again
        
        let publicKey = api.getPublicKey()
        guard !publicKey.isEmpty else {
            if PaymentSDK.debugMode {
                print("[NetAppsPaySDK] No public key — skipping SSE, using polling")
            }
            startIntervalPolling()
            return
        }
        
        let sseURL = APIConfig.sseSubscribeURL(systemTxRef: systemTxRef, publicKey: publicKey)
        
        if PaymentSDK.debugMode {
            print("[NetAppsPaySDK] SSE connecting: \(sseURL)")
        }
        
        var request = URLRequest(url: sseURL)
        request.setValue("text/event-stream", forHTTPHeaderField: "Accept")
        request.setValue(UUID().uuidString, forHTTPHeaderField: "X-Idempotency-Key")
        request.timeoutInterval = maxDuration // keep-alive for the full duration
        
        let config = URLSessionConfiguration.default
        config.timeoutIntervalForRequest = maxDuration
        config.timeoutIntervalForResource = maxDuration
        
        let session = URLSession(configuration: config, delegate: self, delegateQueue: .main)
        sseSession = session
        
        let task = session.dataTask(with: request)
        sseTask = task
        task.resume()
    }
    
    // MARK: - URLSessionDataDelegate (SSE streaming)
    
    func urlSession(_ session: URLSession, dataTask: URLSessionDataTask, didReceive response: URLResponse, completionHandler: @escaping (URLSession.ResponseDisposition) -> Void) {
        guard isPolling else {
            completionHandler(.cancel)
            return
        }
        
        if let httpResponse = response as? HTTPURLResponse, httpResponse.statusCode == 200 {
            if PaymentSDK.debugMode {
                print("[NetAppsPaySDK] SSE connected (HTTP 200)")
            }
            sseConnected = true
            reconnectCount = 0
            // NOTE: do NOT reset consecutivePingTimeouts here — only reset when real data arrives
            
            // SSE is live — stop interval polling if it was running
            stopIntervalPollingOnly()
            resetPingTimeout()
        }
        
        completionHandler(.allow)
    }
    
    func urlSession(_ session: URLSession, dataTask: URLSessionDataTask, didReceive data: Data) {
        guard isPolling else { return }
        guard let chunk = String(data: data, encoding: .utf8) else { return }
        
        // Real data received — SSE is healthy, reset ping-timeout counter
        consecutivePingTimeouts = 0
        resetPingTimeout()
        
        // Accumulate and process SSE lines
        sseBuffer += chunk
        processSSEBuffer()
    }
    
    func urlSession(_ session: URLSession, task: URLSessionTask, didCompleteWithError error: Error?) {
        guard isPolling else { return }
        
        // Intentional close (ping timeout, reconnect, or stopPolling) — don't double-trigger handleSSELost
        // Mirrors web: `if (abortController.signal.aborted) return;`
        if sseIntentionallyClosed { return }
        
        if PaymentSDK.debugMode {
            print("[NetAppsPaySDK] SSE disconnected: \(error?.localizedDescription ?? "completed")")
        }
        
        sseConnected = false
        pingTimeoutTimer?.invalidate()
        pingTimeoutTimer = nil
        
        handleSSELost()
    }
    
    // MARK: - SSE Buffer Processing
    
    private func processSSEBuffer() {
        // SSE protocol: events separated by double newlines
        while let range = sseBuffer.range(of: "\n\n") {
            let eventBlock = String(sseBuffer[sseBuffer.startIndex..<range.lowerBound])
            sseBuffer = String(sseBuffer[range.upperBound...])
            
            parseSSEEvent(eventBlock)
        }
    }
    
    private func parseSSEEvent(_ block: String) {
        // Mirrors web: process ALL data regardless of event type
        // event: / id: / retry: lines — ignored, we process ALL data
        var dataLines: [String] = []
        
        for line in block.components(separatedBy: "\n") {
            if line.hasPrefix("data:") {
                dataLines.append(line.replacingOccurrences(of: "data:", with: "").trimmingCharacters(in: .whitespaces))
            } else if line.hasPrefix(":") {
                // SSE comment / keep-alive — ping timeout already reset
                continue
            }
            // event: / id: / retry: lines — ignored, we process ALL data
        }
        
        guard !dataLines.isEmpty else { return }
        let dataString = dataLines.joined(separator: "\n")
        
        // Plain-text keepalive from server — just reset ping timer (already done)
        if dataString.trimmingCharacters(in: .whitespacesAndNewlines).lowercased() == "keepalive" {
            return
        }
        
        // Try to parse JSON — same structure as GET /transactions/:id
        guard let jsonData = dataString.data(using: .utf8),
              let json = try? JSONSerialization.jsonObject(with: jsonData) as? [String: Any] else {
            return
        }
        
        // Status update — decode as TransactionDetailsResponse
        if json["status"] != nil {
            do {
                let responseData = try JSONSerialization.data(withJSONObject: json)
                let decoder = JSONDecoder()
                let response = try decoder.decode(TransactionDetailsResponse.self, from: responseData)
                handleTransactionResponse(response)
            } catch {
                if PaymentSDK.debugMode {
                    print("[NetAppsPaySDK] SSE parse error: \(error)")
                }
            }
        }
    }
    
    // MARK: - Ping Timeout
    
    private func resetPingTimeout() {
        pingTimeoutTimer?.invalidate()
        
        pingTimeoutTimer = Timer.scheduledTimer(
            withTimeInterval: APIConfig.SSE.pingTimeout,
            repeats: false
        ) { [weak self] _ in
            guard let self = self, self.isPolling else { return }
            
            self.consecutivePingTimeouts += 1
            
            if PaymentSDK.debugMode {
                print("[NetAppsPaySDK] SSE ping timeout — \(APIConfig.SSE.pingTimeout)s with no data (consecutive: \(self.consecutivePingTimeouts))")
            }
            
            // Close SSE connection
            self.sseIntentionallyClosed = true
            self.sseConnected = false
            self.sseTask?.cancel()
            self.sseTask = nil
            self.sseSession?.invalidateAndCancel()
            self.sseSession = nil
            self.pingTimeoutTimer?.invalidate()
            self.pingTimeoutTimer = nil
            self.sseIntentionallyClosed = false
            
            // If we reconnected but still got no ping ≥2 times, SSE is broken → abandon permanently
            if self.consecutivePingTimeouts >= 2 {
                if PaymentSDK.debugMode {
                    print("[NetAppsPaySDK] SSE still dead after reconnect — abandoning SSE, switching to polling")
                }
                self.sseAbandonedForGood = true
                self.startIntervalPolling()
            } else {
                self.handleSSELost()
            }
        }
    }
    
    // MARK: - SSE Lost — Reconnect or Poll
    
    private func handleSSELost() {
        guard isPolling, let systemTxRef = systemTxRef else { return }
        
        reconnectCount += 1
        
        if reconnectCount <= APIConfig.SSE.maxReconnectAttempts {
            // Exponential backoff: 2s, 4s, 8s, 16s, 32s ...
            let delay = APIConfig.SSE.reconnectBaseDelay * pow(2.0, Double(reconnectCount - 1))
            
            if PaymentSDK.debugMode {
                print("[NetAppsPaySDK] SSE reconnect \(reconnectCount)/\(APIConfig.SSE.maxReconnectAttempts) in \(delay)s")
            }
            
            DispatchQueue.main.asyncAfter(deadline: .now() + delay) { [weak self] in
                guard let self = self, self.isPolling else { return }
                self.connectSSE(systemTxRef: systemTxRef)
            }
        } else {
            // All reconnects exhausted → always fall back to interval polling
            if PaymentSDK.debugMode {
                print("[NetAppsPaySDK] SSE reconnects exhausted → interval polling fallback")
            }
            startIntervalPolling()
        }
    }
    
    // ================================================================
    // INTERVAL POLLING (fallback)
    // ================================================================
    
    private func startIntervalPolling() {
        guard isPolling, !pollingActive else { return }
        
        if PaymentSDK.debugMode {
            print("[NetAppsPaySDK] Starting interval polling (every \(pollInterval)s)")
        }
        
        pollingActive = true
        
        // Immediate first poll
        poll()
        
        DispatchQueue.main.async { [weak self] in
            guard let self = self, self.isPolling else { return }
            self.pollTimer = Timer.scheduledTimer(
                withTimeInterval: self.pollInterval,
                repeats: true
            ) { [weak self] _ in
                self?.poll()
            }
        }
    }
    
    private func stopIntervalPollingOnly() {
        pollTimer?.invalidate()
        pollTimer = nil
        pollingActive = false
    }
    
    // MARK: - Poll
    
    private func poll() {
        guard isPolling, let transactionId = transactionId else { return }
        
        api.getTransaction(transactionId: transactionId) { [weak self] result in
            guard let self = self, self.isPolling else { return }
            
            DispatchQueue.main.async {
                switch result {
                case .success(let response):
                    self.consecutiveNetworkErrors = 0
                    self.pollCount += 1
                    self.handleTransactionResponse(response)
                    
                    // Max attempts guard
                    if self.pollCount >= self.maxAttempts && self.isPolling {
                        self.stopPolling()
                        let error = PaymentAPIError.timeoutError("Maximum polling attempts reached")
                        self.delegate?.poller(self, didFailWithError: error)
                    }
                    
                case .failure(let error):
                    self.consecutiveNetworkErrors += 1
                    
                    if PaymentSDK.debugMode {
                        print("[NetAppsPaySDK] Polling error: \(error.message)")
                    }
                    
                    if self.consecutiveNetworkErrors > 3 && error.isNetworkError {
                        self.stopPolling()
                        self.delegate?.poller(self, didFailWithError: error)
                    }
                }
            }
        }
    }
    
    deinit {
        stopPolling()
    }
}
