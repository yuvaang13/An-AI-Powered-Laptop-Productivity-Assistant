import Foundation
import AppKit
import OSLog

struct DecisionResult {
    let isApproved: Bool
    let message: String
    let denialReason: DenialReason
}

enum DenialReason {
    case aiEvaluated
    case serviceUnavailable
    case timeout
    case countdown
}

enum MindGateError: LocalizedError {
    case ollamaConnectionFailed(underlyingError: Error?)
    case ollamaTimeout(duration: TimeInterval)
    case ollamaModelMissing(modelName: String)
    case configurationSaveFailed(path: String, error: Error)
    case configurationLoadFailed(path: String, error: Error)
    case accessibilityPermissionDenied
    case monitoringLoopError(error: Error, retryCount: Int)

    var errorDescription: String? {
        switch self {
        case .ollamaConnectionFailed(let error):
            return "Failed to connect to Ollama: \(error?.localizedDescription ?? "unknown error")"
        case .ollamaTimeout(let duration):
            return "Ollama request timed out after \(Int(duration)) seconds"
        case .ollamaModelMissing(let modelName):
            return "Model '\(modelName)' not found in Ollama"
        case .configurationSaveFailed(let path, let error):
            return "Failed to save configuration at \(path): \(error.localizedDescription)"
        case .configurationLoadFailed(let path, let error):
            return "Failed to load configuration from \(path): \(error.localizedDescription)"
        case .accessibilityPermissionDenied:
            return "Accessibility permission denied"
        case .monitoringLoopError(let error, let retryCount):
            return "Monitoring loop error (retry \(retryCount)): \(error.localizedDescription)"
        }
    }

    var recoverySuggestion: String? {
        switch self {
        case .ollamaConnectionFailed:
            return "Start Ollama with 'ollama serve' and ensure it's running on localhost:11434"
        case .ollamaTimeout:
            return "Increase the request timeout in Settings or check Ollama performance"
        case .ollamaModelMissing(let modelName):
            return "Pull the model with 'ollama pull \(modelName)' or change the model in Settings"
        case .configurationSaveFailed:
            return "Check disk space and file permissions"
        case .configurationLoadFailed:
            return "Configuration will be reset to defaults"
        case .accessibilityPermissionDenied:
            return "Grant Accessibility permission in System Settings > Privacy & Security > Accessibility"
        case .monitoringLoopError:
            return "Monitoring will restart automatically"
        }
    }
}

class ErrorHandler {
    static func handle(_ error: MindGateError, context: String) {
        let logger = Logger(subsystem: "com.mindgate.MindGate", category: "ErrorHandler")
        logger.error("\(context): \(error.localizedDescription)")
    }

    static func userFacingMessage(for error: MindGateError) -> String {
        return error.localizedDescription
    }

    static func shouldRetry(_ error: MindGateError, attemptCount: Int) -> Bool {
        switch error {
        case .ollamaConnectionFailed, .ollamaTimeout:
            return attemptCount < 3
        case .ollamaModelMissing, .accessibilityPermissionDenied:
            return false
        case .configurationSaveFailed, .configurationLoadFailed:
            return attemptCount < 2
        case .monitoringLoopError:
            return attemptCount < 5
        }
    }

    static func postErrorNotification(_ error: MindGateError) {
        NotificationCenter.default.post(name: .mindGateError, object: error)
    }
}

extension Notification.Name {
    static let mindGateError = Notification.Name("MindGateError")
}

class DecisionEngine {
    private let ollamaService: OllamaService
    private let configurationManager: ConfigurationManager
    private var currentApp: NSRunningApplication?
    private var accessTimer: Timer?
    private var grantedAppIdentifier: String?
    private var accessExpiresAt: Date?
    private var ollamaWasAvailable: Bool = false
    private let logger = Logger(subsystem: "com.mindgate.MindGate", category: "DecisionEngine")

    init(ollamaService: OllamaService, configurationManager: ConfigurationManager) {
        self.ollamaService = ollamaService
        self.configurationManager = configurationManager
    }

    func checkOllamaConnection() async -> Bool {
        return await ollamaService.checkConnection()
    }

    func setCurrentApp(_ app: NSRunningApplication) {
        self.currentApp = app
    }

    func evaluateRequest(userInput: String) async throws -> DecisionResult {
        logger.info("User justification received: \"\(userInput)\"")

        let systemPrompt = """
        You are a highly advanced, strict productivity mentor. The user is trying to access a distracting app. Their reason is: '\(userInput)'.
        If this is genuinely essential for immediate work, task tracking, or safety, respond only with the word 'YES'.
        If it is an excuse, mindless scrolling, or procrastination, reply only with the word 'NO'.

        Current productive tasks: \(configurationManager.configuration.settings.productiveTasks.joined(separator: ", "))
        Current productive apps: \(configurationManager.configuration.settings.productiveApps.joined(separator: ", "))
        """

        do {
            let response = try await ollamaService.generateResponse(prompt: systemPrompt)
            logger.info("Ollama raw response: \"\(response)\"")

            let isApproved = Self.parseApproval(from: response)
            let resultMessage: String

            if isApproved {
                resultMessage = "Access approved. Please select a duration."
                logger.info("Decision: APPROVED. Message: \"\(resultMessage)\"")
                return DecisionResult(isApproved: true, message: resultMessage, denialReason: .aiEvaluated)
            } else {
                resultMessage = "Access denied. Stay focused on your work."
                logger.warning("Decision: DENIED. Message: \"\(resultMessage)\"")
                return DecisionResult(isApproved: false, message: resultMessage, denialReason: .aiEvaluated)
            }

        } catch let error as OllamaError {
            logger.error("Error evaluating request with Ollama: \(error.localizedDescription). Defaulting to access denied.")

            let (isServiceUnavailable, errorMessage): (Bool, String)
            switch error {
            case .connectionFailed, .timeout, .serverError:
                isServiceUnavailable = true
                errorMessage = "AI service unavailable. Access denied."
            case .invalidResponseData, .invalidResponse, .invalidURL:
                isServiceUnavailable = true
                errorMessage = "AI service unavailable. Access denied."
            case .modelNotFound(let modelName):
                isServiceUnavailable = true
                errorMessage = "AI model '\(modelName)' not found. Access denied."
            }

            logger.warning("Decision: DENIED. Message: \"\(errorMessage)\" (due to AI service error)")
            logger.warning("Graceful degradation applied: Ollama unavailable, denying access")

            return DecisionResult(
                isApproved: false,
                message: errorMessage,
                denialReason: isServiceUnavailable ? .serviceUnavailable : .aiEvaluated
            )
        } catch {
            logger.error("Unexpected error evaluating request: \(error.localizedDescription)")
            return DecisionResult(
                isApproved: false,
                message: "AI service unavailable. Access denied.",
                denialReason: .serviceUnavailable
            )
        }
    }

    func grantAccess(for duration: TimeInterval) {
        accessTimer?.invalidate()
        grantedAppIdentifier = currentApp.map(Self.identifier)
        accessExpiresAt = Date().addingTimeInterval(duration)

        accessTimer = Timer.scheduledTimer(withTimeInterval: duration, repeats: false) { [weak self] _ in
            self?.revokeAccess()
        }

        logger.info("Access granted for \(duration) seconds.")
    }

    private func revokeAccess() {
        if let app = currentApp {
            app.hide()
        }

        accessTimer?.invalidate()
        accessTimer = nil
        grantedAppIdentifier = nil
        accessExpiresAt = nil
    }

    func hideCurrentApp() {
        if let app = currentApp {
            app.hide()
        }
    }

    func closeCurrentAppOrTab() {
        guard let app = currentApp else { return }

        let bundleID = app.bundleIdentifier ?? ""
        let isBrowser = bundleID.contains("chrome") ||
                       bundleID.contains("safari") ||
                       bundleID.contains("firefox") ||
                       bundleID.contains("brave") ||
                       bundleID.contains("edge")

        if isBrowser {
            closeBrowserTab(bundleID: bundleID)
        } else {
            app.hide()
        }
    }

    private func closeBrowserTab(bundleID: String) {
        let script: String
        if bundleID.contains("chrome") {
            script = "tell application \"Google Chrome\" to close active tab of front window"
        } else if bundleID.contains("safari") {
            script = "tell application \"Safari\" to close current tab of front window"
        } else if bundleID.contains("firefox") {
            script = "tell application \"Firefox\" to close active tab of front window"
        } else if bundleID.contains("brave") {
            script = "tell application \"Brave Browser\" to close active tab of front window"
        } else if bundleID.contains("edge") {
            script = "tell application \"Microsoft Edge\" to close active tab of front window"
        } else {
            script = ""
        }

        if !script.isEmpty {
            var error: NSDictionary?
            NSAppleScript(source: script)?.executeAndReturnError(&error)
            if let error = error {
                logger.error("Failed to close browser tab: \(error)")
            } else {
                logger.info("Closed browser tab")
            }
        }
    }

    func hasActiveAccess(for app: NSRunningApplication) -> Bool {
        guard let grantedAppIdentifier,
              let accessExpiresAt,
              accessExpiresAt > Date() else {
            cancelAccessTimer()
            return false
        }

        return grantedAppIdentifier == Self.identifier(for: app)
    }

    func cancelAccessTimer() {
        accessTimer?.invalidate()
        accessTimer = nil
        grantedAppIdentifier = nil
        accessExpiresAt = nil
    }

    private static func parseApproval(from response: String) -> Bool {
        let normalized = response
            .trimmingCharacters(in: .whitespacesAndNewlines)
            .uppercased()

        if normalized.hasPrefix("YES") {
            return true
        }

        return false
    }

    private static func identifier(for app: NSRunningApplication) -> String {
        if let bundleIdentifier = app.bundleIdentifier, !bundleIdentifier.isEmpty {
            return bundleIdentifier
        }

        return app.localizedName ?? "\(app.processIdentifier)"
    }
}