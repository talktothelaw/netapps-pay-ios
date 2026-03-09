// ============================================================
// PAYMENT API CLIENT - URLSession-based
// ============================================================

import Foundation

final class PaymentAPIClient {
    
    // MARK: - Properties
    
    private let session: URLSession
    private var publicKey: String = ""
    private(set) var isInitialized: Bool = false
    
    private let decoder: JSONDecoder = {
        let d = JSONDecoder()
        return d
    }()
    
    private let encoder: JSONEncoder = {
        let e = JSONEncoder()
        return e
    }()
    
    // MARK: - Singleton
    
    static let shared = PaymentAPIClient()
    
    private init() {
        let config = URLSessionConfiguration.default
        config.timeoutIntervalForRequest = APIConfig.timeout
        config.timeoutIntervalForResource = APIConfig.timeout * 2
        self.session = URLSession(configuration: config)
    }
    
    // MARK: - Initialization
    
    func initialize(publicKey: String) {
        self.publicKey = publicKey
        self.isInitialized = true
    }
    
    func getPublicKey() -> String {
        return publicKey
    }
    
    // MARK: - Generic Request
    
    private func request<T: Decodable>(
        method: String,
        endpoint: String,
        body: (any Encodable)? = nil,
        customIdempotencyKey: String? = nil,
        completion: @escaping (Result<T, PaymentAPIError>) -> Void
    ) {
        let url = APIConfig.fullURL(for: endpoint)
        var urlRequest = URLRequest(url: url)
        urlRequest.httpMethod = method
        urlRequest.setValue("application/json", forHTTPHeaderField: "Content-Type")
        urlRequest.setValue("application/json", forHTTPHeaderField: "Accept")
        
        // Auth header
        if !publicKey.isEmpty {
            urlRequest.setValue(publicKey, forHTTPHeaderField: "X-Public-Key")
        }
        
        // Idempotency key for POST
        if method == "POST" {
            let key = customIdempotencyKey ?? UUID().uuidString
            urlRequest.setValue(key, forHTTPHeaderField: "X-Idempotency-Key")
        }
        
        // Body
        if let body = body {
            do {
                let bodyData = try Self.encodeAny(body, encoder: encoder)
                urlRequest.httpBody = bodyData
            } catch {
                if PaymentSDK.debugMode {
                    print("[NetAppsPaySDK] Encoding error: \(error)")
                }
                completion(.failure(.validationError("Failed to encode request body")))
                return
            }
        }
        
        if PaymentSDK.debugMode {
            print("[NetAppsPaySDK] \(method) \(url.absoluteString)")
            if let bodyData = urlRequest.httpBody, let bodyStr = String(data: bodyData, encoding: .utf8) {
                print("[NetAppsPaySDK] Body: \(bodyStr)")
            }
        }
        
        session.dataTask(with: urlRequest) { [weak self] data, response, error in
            guard let self = self else { return }
            
            // Network error
            if let error = error {
                if PaymentSDK.debugMode {
                    print("[NetAppsPaySDK] Network error: \(error.localizedDescription)")
                }
                let nsError = error as NSError
                if nsError.code == NSURLErrorTimedOut {
                    completion(.failure(.timeoutError()))
                } else {
                    completion(.failure(.networkError()))
                }
                return
            }
            
            guard let httpResponse = response as? HTTPURLResponse,
                  let data = data else {
                completion(.failure(.networkError()))
                return
            }
            
            if PaymentSDK.debugMode {
                print("[NetAppsPaySDK] Response \(httpResponse.statusCode)")
                if let bodyStr = String(data: data, encoding: .utf8) {
                    print("[NetAppsPaySDK] Data: \(bodyStr.prefix(500))")
                }
            }
            
            // HTTP error handling
            let statusCode = httpResponse.statusCode
            guard (200...299).contains(statusCode) else {
                let apiError = self.parseHTTPError(statusCode: statusCode, data: data)
                completion(.failure(apiError))
                return
            }
            
            // Decode response
            do {
                let decoded = try self.decoder.decode(T.self, from: data)
                completion(.success(decoded))
            } catch let decodingError as DecodingError {
                if PaymentSDK.debugMode {
                    let detail: String
                    switch decodingError {
                    case .keyNotFound(let key, let ctx):
                        detail = "Missing key '\(key.stringValue)' at path: \(ctx.codingPath.map(\.stringValue).joined(separator: "."))"
                    case .valueNotFound(let type, let ctx):
                        detail = "Null value for type \(type) at path: \(ctx.codingPath.map(\.stringValue).joined(separator: "."))"
                    case .typeMismatch(let type, let ctx):
                        detail = "Type mismatch: expected \(type) at path: \(ctx.codingPath.map(\.stringValue).joined(separator: "."))"
                    case .dataCorrupted(let ctx):
                        detail = "Data corrupted at path: \(ctx.codingPath.map(\.stringValue).joined(separator: "."))"
                    @unknown default:
                        detail = decodingError.localizedDescription
                    }
                    print("[NetAppsPaySDK] Decoding error: \(detail)")
                    if let bodyStr = String(data: data, encoding: .utf8) {
                        print("[NetAppsPaySDK] Raw response: \(bodyStr)")
                    }
                }
                completion(.failure(.decodingError()))
            } catch {
                if PaymentSDK.debugMode {
                    print("[NetAppsPaySDK] Unexpected decoding error: \(error)")
                }
                completion(.failure(.decodingError()))
            }
        }.resume()
    }
    
    /// Smart request that discovers the actual JSON structure and decodes T from it.
    /// Tries: direct body → body["data"] → body["data"]["data"] → any nested dict.
    private func requestWithDataFallback<T: Decodable>(
        method: String,
        endpoint: String,
        body: (any Encodable)? = nil,
        customIdempotencyKey: String? = nil,
        completion: @escaping (Result<T, PaymentAPIError>) -> Void
    ) {
        let url = APIConfig.fullURL(for: endpoint)
        var urlRequest = URLRequest(url: url)
        urlRequest.httpMethod = method
        urlRequest.setValue("application/json", forHTTPHeaderField: "Content-Type")
        urlRequest.setValue("application/json", forHTTPHeaderField: "Accept")
        
        if !publicKey.isEmpty {
            urlRequest.setValue(publicKey, forHTTPHeaderField: "X-Public-Key")
        }
        
        if method == "POST" {
            let key = customIdempotencyKey ?? UUID().uuidString
            urlRequest.setValue(key, forHTTPHeaderField: "X-Idempotency-Key")
        }
        
        if let body = body {
            do {
                let bodyData = try Self.encodeAny(body, encoder: encoder)
                urlRequest.httpBody = bodyData
            } catch {
                completion(.failure(.validationError("Failed to encode request body")))
                return
            }
        }
        
        if PaymentSDK.debugMode {
            print("[NetAppsPaySDK] \(method) \(url.absoluteString)")
            if let bodyData = urlRequest.httpBody, let bodyStr = String(data: bodyData, encoding: .utf8) {
                print("[NetAppsPaySDK] Body: \(bodyStr)")
            }
        }
        
        session.dataTask(with: urlRequest) { [weak self] data, response, error in
            guard let self = self else { return }
            
            if let error = error {
                if PaymentSDK.debugMode {
                    print("[NetAppsPaySDK] Network error: \(error.localizedDescription)")
                }
                let nsError = error as NSError
                if nsError.code == NSURLErrorTimedOut {
                    completion(.failure(.timeoutError()))
                } else {
                    completion(.failure(.networkError()))
                }
                return
            }
            
            guard let httpResponse = response as? HTTPURLResponse,
                  let data = data else {
                completion(.failure(.networkError()))
                return
            }
            
            let rawString = String(data: data, encoding: .utf8) ?? "<binary>"
            
            if PaymentSDK.debugMode {
                print("[NetAppsPaySDK] Response \(httpResponse.statusCode)")
                print("[NetAppsPaySDK] Full response body: \(rawString)")
            }
            
            let statusCode = httpResponse.statusCode
            guard (200...299).contains(statusCode) else {
                let apiError = self.parseHTTPError(statusCode: statusCode, data: data)
                completion(.failure(apiError))
                return
            }
            
            // Build list of JSON Data candidates to try decoding from
            var candidates: [(label: String, data: Data)] = [
                ("direct", data)
            ]
            
            // Parse raw JSON to discover structure
            if let json = try? JSONSerialization.jsonObject(with: data) as? [String: Any] {
                if PaymentSDK.debugMode {
                    print("[NetAppsPaySDK] Top-level keys: \(json.keys.sorted())")
                }
                
                // Try body["data"] (common wrapper pattern)
                if let nested = json["data"] {
                    if let nestedDict = nested as? [String: Any] {
                        if let nestedData = try? JSONSerialization.data(withJSONObject: nestedDict) {
                            candidates.append(("data", nestedData))
                        }
                        // Try body["data"]["data"] (double wrapper)
                        if let deepNested = nestedDict["data"] as? [String: Any],
                           let deepData = try? JSONSerialization.data(withJSONObject: deepNested) {
                            candidates.append(("data.data", deepData))
                        }
                    }
                    // body["data"] could be an array
                    if let nestedArray = nested as? [Any],
                       let nestedData = try? JSONSerialization.data(withJSONObject: nestedArray) {
                        candidates.append(("data[]", nestedData))
                    }
                }
                
                // Try body["result"] (another common pattern)
                if let resultObj = json["result"] as? [String: Any],
                   let resultData = try? JSONSerialization.data(withJSONObject: resultObj) {
                    candidates.append(("result", resultData))
                }
                
                // Try body["response"] 
                if let respObj = json["response"] as? [String: Any],
                   let respData = try? JSONSerialization.data(withJSONObject: respObj) {
                    candidates.append(("response", respData))
                }
            }
            
            // Try each candidate
            for candidate in candidates {
                if let decoded = try? self.decoder.decode(T.self, from: candidate.data) {
                    if PaymentSDK.debugMode && candidate.label != "direct" {
                        print("[NetAppsPaySDK] Successfully decoded from path: \(candidate.label)")
                    }
                    completion(.success(decoded))
                    return
                }
            }
            
            // All candidates failed
            if PaymentSDK.debugMode {
                print("[NetAppsPaySDK] Could not decode response. Raw: \(String(rawString.prefix(500)))")
                for candidate in candidates {
                    do {
                        let _ = try self.decoder.decode(T.self, from: candidate.data)
                    } catch {
                        print("[NetAppsPaySDK] Decode attempt '\(candidate.label)' failed: \(error)")
                    }
                }
            }
            completion(.failure(.decodingError()))
        }.resume()
    }
    
    private func parseHTTPError(statusCode: Int, data: Data) -> PaymentAPIError {
        struct ErrorBody: Decodable {
            let message: String?
            let code: String?
        }
        
        let errorBody = try? decoder.decode(ErrorBody.self, from: data)
        
        switch statusCode {
        case 401:
            return .unauthorized(errorBody?.message ?? "Invalid API key.")
        case 400:
            return .validationError(errorBody?.message ?? "Invalid request", details: nil)
        case 500...599:
            return .serverError(errorBody?.message ?? "Server error. Please try again later.")
        default:
            return PaymentAPIError(
                message: errorBody?.message ?? "An error occurred",
                statusCode: statusCode,
                errorCode: errorBody?.code
            )
        }
    }
    
    // MARK: - Transaction Methods
    
    func initiateTransaction(
        _ request: InitiateTransactionRequest,
        completion: @escaping (Result<InitiateTransactionResponse, PaymentAPIError>) -> Void
    ) {
        // API may return flat response OR wrapped in { data: { ... } }
        self.requestWithDataFallback(
            method: "POST",
            endpoint: APIConfig.Endpoints.initiateTransaction,
            body: request,
            completion: completion
        )
    }
    
    func getTransaction(
        transactionId: String,
        completion: @escaping (Result<TransactionDetailsResponse, PaymentAPIError>) -> Void
    ) {
        requestWithDataFallback(
            method: "GET",
            endpoint: "\(APIConfig.Endpoints.getTransaction)/\(transactionId)",
            completion: completion
        )
    }
    
    func getTransactionByRef(
        systemTxRef: String,
        completion: @escaping (Result<TransactionByRefResponse, PaymentAPIError>) -> Void
    ) {
        requestWithDataFallback(
            method: "GET",
            endpoint: "\(APIConfig.Endpoints.getTransactionByRef)/\(systemTxRef)",
            completion: completion
        )
    }
    
    func selectChannel(
        _ selectRequest: SelectChannelRequest,
        completion: @escaping (Result<SelectChannelResponse, PaymentAPIError>) -> Void
    ) {
        request(
            method: "POST",
            endpoint: APIConfig.Endpoints.selectChannel,
            body: selectRequest,
            completion: completion
        )
    }
    
    // MARK: - Bank Transfer Methods
    
    func getBankTransferProviders(
        completion: @escaping (Result<[BankTransferProviderResponse], PaymentAPIError>) -> Void
    ) {
        request(
            method: "GET",
            endpoint: APIConfig.Endpoints.bankTransferProviders,
            completion: completion
        )
    }
    
    func initiateBankTransfer(
        _ bankRequest: InitiateBankTransferRequest,
        completion: @escaping (Result<InitiateBankTransferResponse, PaymentAPIError>) -> Void
    ) {
        request(
            method: "POST",
            endpoint: APIConfig.Endpoints.initiateBankTransfer,
            body: bankRequest,
            customIdempotencyKey: bankRequest.reference,
            completion: completion
        )
    }
    
    // MARK: - Card Payment Methods
    
    func processCard(
        transactionId: String,
        request cardRequest: ProcessCardRequest,
        completion: @escaping (Result<ProcessCardResponse, PaymentAPIError>) -> Void
    ) {
        request(
            method: "POST",
            endpoint: "\(APIConfig.Endpoints.processCard)/\(transactionId)/process",
            body: cardRequest
        ) { (result: Result<APIDataWrapper<ProcessCardResponse>, PaymentAPIError>) in
            switch result {
            case .success(let wrapper):
                completion(.success(wrapper.data))
            case .failure(let error):
                completion(.failure(error))
            }
        }
    }
    
    func authenticateCard(
        transactionId: String,
        request authRequest: AuthenticateCardRequest,
        completion: @escaping (Result<AuthenticateCardResponse, PaymentAPIError>) -> Void
    ) {
        request(
            method: "POST",
            endpoint: "\(APIConfig.Endpoints.authenticateCard)/\(transactionId)/authenticate",
            body: authRequest
        ) { (result: Result<APIDataWrapper<AuthenticateCardResponse>, PaymentAPIError>) in
            switch result {
            case .success(let wrapper):
                completion(.success(wrapper.data))
            case .failure(let error):
                completion(.failure(error))
            }
        }
    }
    
    func getSavedCards(
        transactionId: String,
        completion: @escaping (Result<[SavedCard], PaymentAPIError>) -> Void
    ) {
        request(
            method: "GET",
            endpoint: "\(APIConfig.Endpoints.savedCards)/\(transactionId)/saved-cards"
        ) { (result: Result<SavedCardsResponseWrapper, PaymentAPIError>) in
            switch result {
            case .success(let wrapper):
                completion(.success(wrapper.data))
            case .failure(let error):
                completion(.failure(error))
            }
        }
    }
    
    func processSavedCard(
        transactionId: String,
        request cardRequest: ProcessSavedCardRequest,
        completion: @escaping (Result<ProcessCardResponse, PaymentAPIError>) -> Void
    ) {
        request(
            method: "POST",
            endpoint: "\(APIConfig.Endpoints.processCard)/\(transactionId)/process",
            body: cardRequest
        ) { (result: Result<APIDataWrapper<ProcessCardResponse>, PaymentAPIError>) in
            switch result {
            case .success(let wrapper):
                completion(.success(wrapper.data))
            case .failure(let error):
                completion(.failure(error))
            }
        }
    }
    
    func deleteSavedCard(
        transactionId: String,
        cardId: String,
        completion: @escaping (Result<Void, PaymentAPIError>) -> Void
    ) {
        let endpoint = "\(APIConfig.Endpoints.deleteSavedCard)/\(transactionId)/saved-cards/\(cardId)"
        let url = APIConfig.fullURL(for: endpoint)
        var urlRequest = URLRequest(url: url)
        urlRequest.httpMethod = "DELETE"
        urlRequest.setValue("application/json", forHTTPHeaderField: "Content-Type")
        urlRequest.setValue(publicKey, forHTTPHeaderField: "X-Public-Key")
        
        session.dataTask(with: urlRequest) { _, response, error in
            if let error = error {
                completion(.failure(.networkError(error.localizedDescription)))
                return
            }
            guard let httpResponse = response as? HTTPURLResponse,
                  (200...299).contains(httpResponse.statusCode) else {
                completion(.failure(.serverError()))
                return
            }
            completion(.success(()))
        }.resume()
    }
    
    func getTestCards(
        transactionId: String,
        completion: @escaping (Result<[TestCard], PaymentAPIError>) -> Void
    ) {
        request(
            method: "GET",
            endpoint: "\(APIConfig.Endpoints.testCards)/\(transactionId)/test-cards"
        ) { (result: Result<TestCardsResponseWrapper, PaymentAPIError>) in
            switch result {
            case .success(let wrapper):
                completion(.success(wrapper.data))
            case .failure(let error):
                completion(.failure(error))
            }
        }
    }
    
    // MARK: - USSD Methods
    
    func getUSSDBank(
        completion: @escaping (Result<[USSDBank], PaymentAPIError>) -> Void
    ) {
        request(
            method: "GET",
            endpoint: APIConfig.Endpoints.ussdBanks
        ) { (result: Result<USSDBanksResponseWrapper, PaymentAPIError>) in
            switch result {
            case .success(let wrapper):
                completion(.success(wrapper.data.banks))
            case .failure(let error):
                completion(.failure(error))
            }
        }
    }
    
    func initiateUSSDCode(
        transactionId: String,
        request ussdRequest: InitiateUSSDCodeRequest,
        completion: @escaping (Result<InitiateUSSDCodeResponse, PaymentAPIError>) -> Void
    ) {
        request(
            method: "POST",
            endpoint: "\(APIConfig.Endpoints.ussdInitiateCode)/\(transactionId)/initiate/code",
            body: ussdRequest,
            completion: completion
        )
    }
    
    func initiatePayattitude(
        transactionId: String,
        request payRequest: InitiatePayattitudeRequest,
        completion: @escaping (Result<InitiatePayattitudeResponse, PaymentAPIError>) -> Void
    ) {
        request(
            method: "POST",
            endpoint: "\(APIConfig.Endpoints.ussdInitiatePayattitude)/\(transactionId)/initiate/push",
            body: payRequest,
            completion: completion
        )
    }
    
    // MARK: - Netapps Marketplace
    
    func initiateNetAppsMarketplace(
        transactionId: String,
        request marketplaceRequest: InitiateNetAppsMarketplaceRequest,
        completion: @escaping (Result<InitiateNetAppsMarketplaceResponse, PaymentAPIError>) -> Void
    ) {
        request(
            method: "POST",
            endpoint: "\(APIConfig.Endpoints.netappsMarketplaceInitiate)/\(transactionId)/initiate",
            body: marketplaceRequest,
            completion: completion
        )
    }
}

// MARK: - AnyEncodable Helper

private struct AnyEncodable: Encodable {
    private let _encode: (Encoder) throws -> Void
    
    init(_ wrapped: any Encodable) {
        self._encode = { encoder in
            try wrapped.encode(to: encoder)
        }
    }
    
    func encode(to encoder: Encoder) throws {
        try _encode(encoder)
    }
}

extension PaymentAPIClient {
    /// Encode any Encodable value using JSONSerialization round-trip
    /// to avoid Swift existential encoding issues.
    fileprivate static func encodeAny(_ value: any Encodable, encoder: JSONEncoder) throws -> Data {
        // Use AnyEncodable wrapper
        return try encoder.encode(AnyEncodable(value))
    }
}
