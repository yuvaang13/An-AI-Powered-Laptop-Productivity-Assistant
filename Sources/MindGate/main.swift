import SwiftUI
import AppKit
import Foundation

// Main entry point for Swift Package
let app = NSApplication.shared
let delegate = AppDelegate()
app.delegate = delegate

// Handle SIGINT (Ctrl+C) for clean termination
signal(SIGINT) { _ in
    NSApplication.shared.terminate(nil)
}

app.run()
