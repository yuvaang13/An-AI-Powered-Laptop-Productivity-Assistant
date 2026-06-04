import Foundation
import ApplicationServices
import AppKit
import OSLog
import CoreGraphics

class AccessibilityManager {
    private let logger = Logger(subsystem: "com.mindgate.MindGate", category: "AccessibilityManager")

    func hasAccessibilityPermissions() -> Bool {
        return AXIsProcessTrusted()
    }

    func requestAccessibilityPermissions() {
        let options = [kAXTrustedCheckOptionPrompt.takeRetainedValue() as String: true]
        AXIsProcessTrustedWithOptions(options as CFDictionary)
    }

    func getActiveApplication() -> NSRunningApplication? {
        return NSWorkspace.shared.frontmostApplication
    }

    func getActiveBrowserURL(for application: NSRunningApplication) -> String? {
        guard let script = browserURLScript(for: application) else {
            return nil
        }

        var error: NSDictionary?
        let result = NSAppleScript(source: script)?.executeAndReturnError(&error)

        if let error {
            logger.error("❌ AccessibilityManager: Could not read browser URL for \(application.localizedName ?? "Unknown"): \(error)")
        }

        return result?.stringValue
    }

    func getWindowTitle(for application: NSRunningApplication) -> String? {
        let appElement = AXUIElementCreateApplication(application.processIdentifier)
        var windowRef: AnyObject?
        let result = AXUIElementCopyAttributeValue(appElement, kAXFocusedWindowAttribute as CFString, &windowRef)

        guard result == .success,
              let windowRef else {
            return nil
        }

        let window = windowRef as! AXUIElement

        var titleRef: AnyObject?
        let titleResult = AXUIElementCopyAttributeValue(window, kAXTitleAttribute as CFString, &titleRef)

        guard titleResult == .success,
              let title = titleRef as? String else {
            return nil
        }

        return title
    }

    func getAllWindowTitles(for application: NSRunningApplication) -> [String] {
        let appElement = AXUIElementCreateApplication(application.processIdentifier)
        var windowsRef: AnyObject?
        let result = AXUIElementCopyAttributeValue(appElement, kAXWindowsAttribute as CFString, &windowsRef)

        logger.debug("🔧 AXUIElementCopyAttributeValue result: \(result.rawValue)")

        guard result == .success else {
            logger.error("❌ AccessibilityManager: AXUIElementCopyAttributeValue failed with error \(result.rawValue) for app: \(application.localizedName ?? "Unknown")")
            return []
        }
        
        guard let windows = windowsRef as? [AXUIElement] else {
            logger.error("❌ AccessibilityManager: Could not cast windowsRef to [AXUIElement] for app: \(application.localizedName ?? "Unknown")")
            return []
        }

        logger.debug("✅ Got \(windows.count) windows for app: \(application.localizedName ?? "Unknown")")

        var titles: [String] = []
        for window in windows {
            var titleRef: AnyObject?
            let titleResult = AXUIElementCopyAttributeValue(window, kAXTitleAttribute as CFString, &titleRef)

            if titleResult == .success,
               let title = titleRef as? String {
                titles.append(title)
                logger.debug("📄 Window title: \(title)")
            }
        }

        return titles
    }

    func testAccessibilityForApp(_ application: NSRunningApplication) -> Bool {
        let appElement = AXUIElementCreateApplication(application.processIdentifier)
        var windowsRef: AnyObject?
        let result = AXUIElementCopyAttributeValue(appElement, kAXWindowsAttribute as CFString, &windowsRef)

        return result == .success
    }

    func getFallbackWindowFrame(for application: NSRunningApplication) -> NSRect? {
        guard let windowList = CGWindowListCreateDescriptionFromArray(nil) else {
            return nil
        }

        let windows = windowList as NSArray as? [NSDictionary] ?? []
        let appPID = application.processIdentifier

        for window in windows where window["ownerPID"] as? pid_t == appPID {
            guard let boundsDict = window["bounds"] as? [String: NSNumber],
                  let layer = window["layer"] as? Int,
                  layer == 0 else { continue }

            let x = boundsDict["X"]?.doubleValue ?? 0
            let y = boundsDict["Y"]?.doubleValue ?? 0
            let width = boundsDict["Width"]?.doubleValue ?? 0
            let height = boundsDict["Height"]?.doubleValue ?? 0
            return NSRect(x: x, y: y, width: width, height: height)
        }

        return nil
    }

    private func browserURLScript(for application: NSRunningApplication) -> String? {
        guard let bundleID = application.bundleIdentifier?.lowercased() else {
            return nil
        }

        if bundleID.contains("safari") {
            return """
            tell application id "\(bundleID)"
                if (count of windows) is 0 then return ""
                return URL of current tab of front window
            end tell
            """
        }

        if bundleID.contains("chrome") ||
            bundleID.contains("brave") ||
            bundleID.contains("edge") {
            return """
            tell application id "\(bundleID)"
                if (count of windows) is 0 then return ""
                return URL of active tab of front window
            end tell
            """
        }

        return nil
    }
}