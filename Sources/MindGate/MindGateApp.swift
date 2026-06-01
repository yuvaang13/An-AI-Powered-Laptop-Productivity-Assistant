import SwiftUI
import AppKit

class AppDelegate: NSObject, NSApplicationDelegate {
    var accessibilityManager: AccessibilityManager!
    var windowManager: WindowManager!
    var workspaceMonitor: WorkspaceMonitor!
    var decisionEngine: DecisionEngine!

    func applicationDidFinishLaunching(_ notification: Notification) {
        print("🚀 MindGate: Application launched")

        // Initialize managers
        accessibilityManager = AccessibilityManager()
        decisionEngine = DecisionEngine.shared
        windowManager = WindowManager(decisionEngine: decisionEngine)
        workspaceMonitor = WorkspaceMonitor(
            windowManager: windowManager,
            decisionEngine: decisionEngine
        )

        // Check accessibility permissions
        let hasPermissions = accessibilityManager.hasAccessibilityPermissions()
        print("🔐 Accessibility permissions: \(hasPermissions ? "✅ Granted" : "❌ Denied")")

        // Start monitoring regardless of permissions for testing
        // Browser monitoring requires permissions, but app monitoring works without them
        workspaceMonitor.startMonitoring()

        if !hasPermissions {
            print("⚠️ Browser monitoring may not work without accessibility permissions")
            print("💡 Grant permissions in System Settings > Privacy & Security > Accessibility")
        }
    }

    func applicationShouldTerminateAfterLastWindowClosed(_ sender: NSApplication) -> Bool {
        return false
    }

    private func showAccessibilityPrompt() {
        let alert = NSAlert()
        alert.messageText = "Accessibility Permissions Required"
        alert.informativeText = "MindGate needs accessibility permissions to monitor your active applications and help you stay focused.\n\nPlease grant permissions in System Settings > Privacy & Security > Accessibility."
        alert.alertStyle = .warning
        alert.addButton(withTitle: "Open System Settings")
        alert.addButton(withTitle: "Quit")

        let response = alert.runModal()

        if response == .alertFirstButtonReturn {
            NSWorkspace.shared.open(URL(string: "x-apple.systempreferences:com.apple.preference.security?Privacy_Accessibility")!)
        }

        NSApplication.shared.terminate(nil)
    }
}
