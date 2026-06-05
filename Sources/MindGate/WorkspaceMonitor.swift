import Foundation
import AppKit
import OSLog
import CoreGraphics

@MainActor
class WorkspaceMonitor {
    private weak var windowManager: WindowManager?
    private weak var decisionEngine: DecisionEngine?
    private let accessibilityManager: AccessibilityManager
    private var observer: NSObjectProtocol?
    private var pollTimer: Timer?
    private var lastCheckedApp: NSRunningApplication?
    private var lastCheckedTime: Date?
    private var activePromptIdentifier: String?
    private var activePromptShownAt: Date?
    private var lastActivityTime: Date = Date()
    private weak var configurationManager: ConfigurationManager?
    private var fallbackConfiguration: Configuration
    private var configuration: Configuration {
        configurationManager?.configuration ?? fallbackConfiguration
    }
    private var monitoringRetryCount: Int = 0
    private var lastMonitoringErrorTime: Date?
    private let logger = Logger(subsystem: "com.mindgate.MindGate", category: "WorkspaceMonitor")

    private let pollInterval: TimeInterval = 1.0
    private let debounceInterval: TimeInterval = 0.75
    private let promptRepeatInterval: TimeInterval = 20.0
    private let idleThreshold: TimeInterval = 300.0
    private let maxMonitoringRetries = 5
    private let monitoringRetryWindow: TimeInterval = 60.0

    init(windowManager: WindowManager, decisionEngine: DecisionEngine, configurationManager: ConfigurationManager, accessibilityManager: AccessibilityManager) {
        self.windowManager = windowManager
        self.decisionEngine = decisionEngine
        self.accessibilityManager = accessibilityManager
        self.configurationManager = configurationManager
        self.fallbackConfiguration = configurationManager.configuration
    }

    @MainActor
    func startMonitoring() {
        logger.info("Starting workspace monitoring...")
        stopMonitoring()

        observer = NSWorkspace.shared.notificationCenter.addObserver(
            forName: NSWorkspace.didActivateApplicationNotification,
            object: nil,
            queue: .main
        ) { [weak self] notification in
            guard let self else { return }
            Task { @MainActor in
                self.handleApplicationActivation(notification)
            }
        }

        let timer = Timer(timeInterval: pollInterval, repeats: true) { [weak self] _ in
            guard let self else { return }
            Task { @MainActor in
                self.checkFrontmostApplication(reason: "poll")
            }
        }
        RunLoop.main.add(timer, forMode: .common)
        pollTimer = timer

        checkFrontmostApplication(reason: "startup")
        logger.info("Workspace monitoring started")
    }

    func stopMonitoring() {
        if let observer = observer {
            NSWorkspace.shared.notificationCenter.removeObserver(observer)
            self.observer = nil
        }

        pollTimer?.invalidate()
        pollTimer = nil
    }

    private func handleApplicationActivation(_ notification: Notification) {
        guard let app = notification.userInfo?[NSWorkspace.applicationUserInfoKey] as? NSRunningApplication else {
            return
        }

        lastActivityTime = Date()
        evaluate(app: app, reason: "activation")
    }

    @MainActor
    private func checkFrontmostApplication(reason: String) {
        guard let app = accessibilityManager.getActiveApplication() else {
            logger.debug("No frontmost application available during \(reason)")
            return
        }

        evaluate(app: app, reason: reason)
    }

    @MainActor
    private func evaluate(app: NSRunningApplication, reason: String) {
        if isMindGate(app) {
            return
        }

        let appName = app.localizedName ?? ""
        let bundleID = app.bundleIdentifier ?? ""
        logger.info("Checking app during \(reason): \(appName) (Bundle: \(bundleID))")

        if decisionEngine?.hasActiveAccess(for: app) == true {
            logger.info("Active access window still valid for \(appName)")
            clearActivePrompt()
            return
        }

        if isDistractingApp(app) {
            logger.warning("Distracting app detected: \(appName)")
            presentDistractionPrompt(for: app, reason: "distracting app")
            return
        }

        if isBrowser(app) {
            logger.info("Browser detected: \(appName)")

            let now = Date()
            if let lastTime = lastCheckedTime,
               now.timeIntervalSince(lastTime) < debounceInterval,
               lastCheckedApp?.bundleIdentifier == app.bundleIdentifier {
                logger.debug("Debouncing browser check (too soon)")
                return
            }
            lastCheckedApp = app
            lastCheckedTime = now

            if shouldCheckBrowserContent() {
                if browserContainsRestrictedContent(app: app) {
                    presentDistractionPrompt(for: app, reason: "restricted browser content")
                } else {
                    clearPromptIfNeeded(for: app)
                }
            } else {
                logger.debug("Skipping browser content check (prompt visible)")
                clearPromptIfNeeded(for: app)
            }

            return
        }

        clearPromptIfNeeded(for: app)
    }

    @MainActor
    private func shouldCheckBrowserContent() -> Bool {
        return !(windowManager?.isOrbExpanded == true)
    }

    private func browserContainsRestrictedContent(app: NSRunningApplication) -> Bool {
        if let url = accessibilityManager.getActiveBrowserURL(for: app), !url.isEmpty {
            logger.info("Active browser URL: \(url)")

            if let keyword = matchedRestrictedKeyword(in: url) {
                logger.warning("Restricted keyword detected: \(keyword) in URL: \(url)")
                return true
            }
        }

        let canAccess = accessibilityManager.testAccessibilityForApp(app)
        logger.info("Can access browser windows: \(canAccess)")

        if !canAccess {
            logger.warning("Accessibility permissions not working for browser")
            return false
        }

        let windowTitles = accessibilityManager.getAllWindowTitles(for: app)

        logger.info("Browser window titles: \(windowTitles)")

        for title in windowTitles {
            let lowercasedTitle = title.lowercased()
            if lowercasedTitle.contains("youtube") ||
                lowercasedTitle.contains("youtu.be") ||
                lowercasedTitle.contains("- youtube") {
                logger.warning("YouTube detected in title: \(title)")
                return true
            }

            if let keyword = matchedRestrictedKeyword(in: title) {
                logger.warning("Restricted keyword detected: \(keyword) in title: \(title)")
                return true
            }
        }

        if windowTitles.isEmpty {
            logger.warning("Could not get any window titles for browser")
        }

        return false
    }

    private func presentDistractionPrompt(for app: NSRunningApplication, reason: String) {
        let identifier = appIdentifier(for: app)

        if activePromptIdentifier == identifier,
           let activePromptShownAt,
           Date().timeIntervalSince(activePromptShownAt) < promptRepeatInterval {
            logger.debug("Prompt already active for \(identifier)")
            return
        }

        activePromptIdentifier = identifier
        activePromptShownAt = Date()
        lastActivityTime = Date()
        logger.warning("Presenting MindGate prompt for \(app.localizedName ?? identifier): \(reason)")

        Task { @MainActor in
            self.decisionEngine?.setCurrentApp(app)
            self.windowManager?.targetApp = app
            self.windowManager?.showOrb()
        }
    }

    private func clearPromptIfNeeded(for app: NSRunningApplication) {
        guard let activePromptIdentifier else {
            return
        }

        if activePromptIdentifier == appIdentifier(for: app) {
            logger.info("No restricted content remains for \(app.localizedName ?? activePromptIdentifier)")
            clearActivePrompt()

            Task { @MainActor in
                self.windowManager?.hideOrb()
            }
        }
    }

    private func isDistractingApp(_ app: NSRunningApplication) -> Bool {
        let bundleID = app.bundleIdentifier ?? ""
        let localizedName = app.localizedName ?? ""

        return configuration.settings.distractingApps.contains { configuredName in
            let normalizedConfigured = normalize(configuredName)
            guard !normalizedConfigured.isEmpty else { return false }

            if !bundleID.isEmpty && normalize(bundleID) == normalizedConfigured {
                return true
            }

            if !localizedName.isEmpty && normalize(localizedName).contains(normalizedConfigured) {
                return true
            }

            return false
        }
    }

    private func isBrowser(_ app: NSRunningApplication) -> Bool {
        let bundleID = app.bundleIdentifier ?? ""
        let localizedName = app.localizedName ?? ""

        if configuration.settings.monitoredBrowsers.contains(where: { configuredName in
            let normalizedName = normalize(configuredName)
            if !bundleID.isEmpty && normalize(bundleID) == normalizedName {
                return true
            }
            if !localizedName.isEmpty && normalize(localizedName).contains(normalizedName) {
                return true
            }
            return false
        }) {
            return true
        }

        let values = [bundleID, localizedName].filter { !$0.isEmpty }.map(normalize)

        return values.contains { value in
            value.contains("chrome") ||
            value.contains("safari") ||
            value.contains("firefox") ||
            value.contains("brave") ||
            value.contains("edge")
        }
    }

    func matchedRestrictedKeyword(in text: String) -> String? {
        let normalizedText = text.lowercased()

        return configuration.settings.restrictedKeywords.first { keyword in
            let trimmedKeyword = keyword.trimmingCharacters(in: CharacterSet.whitespacesAndNewlines)
            let normalizedKeyword = trimmedKeyword.lowercased()
            guard !normalizedKeyword.isEmpty else { return false }

            return normalizedText.contains(normalizedKeyword)
        }
    }

    private func normalize(_ value: String) -> String {
        value.trimmingCharacters(in: .whitespacesAndNewlines).lowercased()
    }

    private func appIdentifier(for app: NSRunningApplication) -> String {
        if let bundleIdentifier = app.bundleIdentifier, !bundleIdentifier.isEmpty {
            return bundleIdentifier
        }

        return app.localizedName ?? "\(app.processIdentifier)"
    }

    private func isMindGate(_ app: NSRunningApplication) -> Bool {
        app.processIdentifier == ProcessInfo.processInfo.processIdentifier
    }

    private func clearActivePrompt() {
        activePromptIdentifier = nil
        activePromptShownAt = nil
    }

    private func handleMonitoringError(_ error: Error) {
        logger.error("Monitoring loop error: \(error.localizedDescription)")

        let now = Date()
        if let lastErrorTime = lastMonitoringErrorTime,
           now.timeIntervalSince(lastErrorTime) < monitoringRetryWindow {
            monitoringRetryCount += 1
        } else {
            monitoringRetryCount = 1
        }
        lastMonitoringErrorTime = now

        if monitoringRetryCount >= maxMonitoringRetries {
            logger.error("Maximum monitoring retries (\(self.maxMonitoringRetries)) exceeded within \(self.monitoringRetryWindow) seconds. Stopping monitoring.")
            stopMonitoring()
            return
        }

        logger.warning("Restarting monitoring loop after error (retry \(self.monitoringRetryCount)/\(self.maxMonitoringRetries))")

        DispatchQueue.main.asyncAfter(deadline: .now() + 2.0) { [weak self] in
            self?.startMonitoring()
        }
    }

    deinit {
        Task { @MainActor in
            self.stopMonitoring()
        }
    }
}