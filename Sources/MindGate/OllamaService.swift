import Foundation
import OSLog

enum OllamaError: LocalizedError, Equatable {
    case invalidURL
    case invalidResponse
    case serverError(Int)
    case invalidResponseData
    case connectionFailed
    case timeout
    case modelNotFound(String)

    var errorDescription: String? {
        switch self {
        case .invalidURL:
            return "Invalid Ollama URL"
        case .invalidResponse:
            return "Invalid response from Ollama"
        case .serverError(let code):
            return "Ollama server error: \(code)"
        case .invalidResponseData:
            return "Invalid response data from Ollama"
        case .connectionFailed:
            return "Failed to connect to Ollama. Make sure Ollama is running on localhost:11434"
        case .timeout:
            return "Ollama request timed out"
        case .modelNotFound(let modelName):
            return "Model '\(modelName)' not found in Ollama installation"
        }
    }

    static func == (lhs: OllamaError, rhs: OllamaError) -> Bool {
        switch (lhs, rhs) {
        case (.invalidURL, .invalidURL),
             (.invalidResponse, .invalidResponse),
             (.invalidResponseData, .invalidResponseData),
             (.connectionFailed, .connectionFailed),
             (.timeout, .timeout):
            return true
        case (.serverError(let lhsCode), .serverError(let rhsCode)):
            return lhsCode == rhsCode
        case (.modelNotFound(let lhsName), .modelNotFound(let rhsName)):
            return lhsName == rhsName
        default:
            return false
        }
    }
}

class OllamaService {
    private let session: URLSession
    private let configurationManager: ConfigurationManager
    private let logger = Logger(subsystem: "com.mindgate.MindGate", category: "OllamaService")
    private var currentTimeout: TimeInterval = 10

    init(configurationManager: ConfigurationManager) {
        self.configurationManager = configurationManager

        let config = URLSessionConfiguration.default
        config.httpMaximumConnectionsPerHost = 2
        config.timeoutIntervalForRequest = 30
        config.timeoutIntervalForResource = 60
        self.session = URLSession(configuration: config)
    }

    func generateResponse(prompt: String) async throws -> String {
        let startTime = Date()
        logger.info("Generating response for prompt...")

        let rawURL = configurationManager.configuration.settings.ollamaURL
        guard let url = URL(string: rawURL) else {
            logger.error("Invalid Ollama URL: \(rawURL)")
            throw OllamaError.invalidURL
        }

        let modelName = configurationManager.configuration.settings.ollamaModel.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !modelName.isEmpty else {
            logger.error("Ollama model name is empty")
            throw OllamaError.invalidResponse
        }

        currentTimeout = TimeInterval(configurationManager.configuration.settings.ollamaTimeout)
        if currentTimeout < 1 || currentTimeout > 300 {
            currentTimeout = 10
        }

        var request = URLRequest(url: url)
        request.httpMethod = "POST"
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")
        request.timeoutInterval = currentTimeout

        let requestBody: [String: Any] = [
            "model": modelName,
            "prompt": prompt,
            "stream": false,
            "options": [
                "temperature": 0.7,
                "top_p": 0.9
            ]
        ]

        request.httpBody = try JSONSerialization.data(withJSONObject: requestBody)

        do {
            let (data, response) = try await session.data(for: request)

            guard let httpResponse = response as? HTTPURLResponse else {
                logger.error("Invalid response from Ollama server.")
                throw OllamaError.invalidResponse
            }

            guard httpResponse.statusCode == 200 else {
                logger.error("Ollama server returned status code: \(httpResponse.statusCode)")
                if let responseString = String(data: data, encoding: .utf8) {
                    logger.error("Response body: \(responseString)")
                }
                throw OllamaError.serverError(httpResponse.statusCode)
            }

            guard let json = try JSONSerialization.jsonObject(with: data) as? [String: Any],
                  let responseText = json["response"] as? String else {
                logger.error("Failed to decode Ollama response JSON. Data: \(String(data: data, encoding: .utf8) ?? "nil")")
                throw OllamaError.invalidResponseData
            }

            let trimmedResponse = responseText.trimmingCharacters(in: .whitespacesAndNewlines)
            if trimmedResponse.isEmpty {
                logger.error("Ollama response 'response' field is empty after trimming")
                throw OllamaError.invalidResponseData
            }

            let elapsed = Date().timeIntervalSince(startTime) * 1000
            logger.info("Successfully received response from Ollama in \(Int(elapsed))ms")
            return trimmedResponse
        } catch let error as OllamaError {
            let elapsed = Date().timeIntervalSince(startTime) * 1000
            if error == .connectionFailed || error == .timeout {
                logger.error("Ollama request failed after \(Int(elapsed))ms: \(error.localizedDescription)")
            }
            throw error
        } catch {
            let elapsed = Date().timeIntervalSince(startTime) * 1000
            logger.error("Network error calling Ollama after \(Int(elapsed))ms: \(error.localizedDescription)")
            throw OllamaError.connectionFailed
        }
    }

    func generateResponseStream(prompt: String) -> AsyncThrowingStream<String, Error> {
        let modelName = configurationManager.configuration.settings.ollamaModel.trimmingCharacters(in: .whitespacesAndNewlines)
        let rawURL = configurationManager.configuration.settings.ollamaURL
        let timeout = TimeInterval(configurationManager.configuration.settings.ollamaTimeout)

        return AsyncThrowingStream { continuation in
            Task {
                do {
                    guard let url = URL(string: rawURL) else {
                        continuation.finish(throwing: OllamaError.invalidURL)
                        return
                    }

                    var request = URLRequest(url: url)
                    request.httpMethod = "POST"
                    request.setValue("application/json", forHTTPHeaderField: "Content-Type")
                    request.timeoutInterval = timeout

                    let requestBody: [String: Any] = [
                        "model": modelName,
                        "prompt": prompt,
                        "stream": true,
                        "options": [
                            "temperature": 0.7,
                            "top_p": 0.9
                        ]
                    ]

                    request.httpBody = try JSONSerialization.data(withJSONObject: requestBody)

                    let (asyncBytes, response) = try await session.bytes(for: request)

                    guard let httpResponse = response as? HTTPURLResponse else {
                        continuation.finish(throwing: OllamaError.invalidResponse)
                        return
                    }

                    guard httpResponse.statusCode == 200 else {
                        continuation.finish(throwing: OllamaError.serverError(httpResponse.statusCode))
                        return
                    }

                    var buffer = ""
                    for try await line in asyncBytes.lines {
                        buffer += line
                        if let data = line.data(using: .utf8),
                           let json = try? JSONSerialization.jsonObject(with: data) as? [String: Any],
                           let token = json["response"] as? String {
                            continuation.yield(token)
                        }
                    }

                    continuation.finish()
                } catch let error as OllamaError {
                    continuation.finish(throwing: error)
                } catch {
                    continuation.finish(throwing: OllamaError.connectionFailed)
                }
            }
        }
    }

    func checkConnection() async -> Bool {
        logger.info("Checking Ollama connection...")

        let rawURL = configurationManager.configuration.settings.ollamaURL
        var tagsURL = rawURL
        if tagsURL.hasSuffix("/api/generate") {
            tagsURL = String(tagsURL.dropLast("/api/generate".count))
        }
        guard let url = URL(string: "\(tagsURL)/api/tags") else {
            logger.error("Invalid Ollama URL for connection check.")
            return false
        }

        var request = URLRequest(url: url)
        request.httpMethod = "GET"
        request.timeoutInterval = 5

        do {
            let (_, response) = try await session.data(for: request)

            guard let httpResponse = response as? HTTPURLResponse else {
                logger.warning("Invalid response during connection check.")
                return false
            }

            let success = httpResponse.statusCode == 200
            if success {
                logger.info("Ollama connection successful.")
            } else {
                logger.warning("Ollama connection check failed with status code: \(httpResponse.statusCode)")
            }
            return success
        } catch {
            logger.error("Ollama connection check request failed: \(error.localizedDescription)")
            return false
        }
    }

    func verifyModelAvailability() async throws -> Bool {
        logger.info("Verifying model availability...")

        let rawURL = configurationManager.configuration.settings.ollamaURL
        var tagsURL = rawURL
        if tagsURL.hasSuffix("/api/generate") {
            tagsURL = String(tagsURL.dropLast("/api/generate".count))
        }
        guard let url = URL(string: "\(tagsURL)/api/tags") else {
            logger.error("Invalid Ollama URL for model check.")
            return false
        }

        var request = URLRequest(url: url)
        request.httpMethod = "GET"
        request.timeoutInterval = 30

        do {
            let (data, response) = try await session.data(for: request)

            guard let httpResponse = response as? HTTPURLResponse, httpResponse.statusCode == 200 else {
                logger.warning("Failed to query available models - non-200 status")
                return false
            }

            guard let json = try JSONSerialization.jsonObject(with: data) as? [String: Any],
                  let models = json["models"] as? [[String: Any]] else {
                logger.warning("Failed to parse models list from /api/tags")
                return false
            }

            let modelName = configurationManager.configuration.settings.ollamaModel.trimmingCharacters(in: .whitespacesAndNewlines)
            let modelExists = models.contains { model in
                (model["name"] as? String) == modelName
            }

            if !modelExists {
                let warningMessage = "Model not available: \(modelName)"
                logger.warning("\(warningMessage)")
                NotificationCenter.default.post(
                    name: .ollamaModelMissing,
                    object: nil,
                    userInfo: ["modelName": modelName]
                )
            }

            return modelExists
        } catch {
            logger.warning("Failed to query available models: \(error.localizedDescription)")
            return false
        }
    }
}