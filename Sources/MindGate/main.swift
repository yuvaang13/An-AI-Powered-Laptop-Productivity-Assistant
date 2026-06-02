import SwiftUI
import AppKit
import Foundation

// Main entry point for Swift Package
let app = NSApplication.shared
let delegate = AppDelegate()
app.delegate = delegate

// Set activation policy to accessory to avoid dock icon
app.setActivationPolicy(.accessory)

// Handle SIGINT (Ctrl+C) for clean termination
signal(SIGINT) { _ in
    NSApplication.shared.terminate(nil)
}

app.run()
