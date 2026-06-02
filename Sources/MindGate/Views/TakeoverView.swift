import SwiftUI

struct TakeoverView: View {
    let configuration: Configuration
    weak var windowManager: WindowManager?
    let decisionEngine: DecisionEngine

    var body: some View {
        VStack(spacing: 20) {
            Text("Time to refocus!")
                .font(.system(size: 24, weight: .bold, design: .rounded))
                .foregroundColor(Color(hex: configuration.theme.colors.primary).opacity(0.95))

            Text("Here are some suggestions to get back on track:")
                .font(.system(size: 14, weight: .medium, design: .rounded))
                .foregroundColor(Color(hex: configuration.theme.colors.primary).opacity(0.68))

            ScrollView {
                VStack(alignment: .leading, spacing: 10) {
                    ForEach(configuration.settings.productiveTasks, id: \.self) {
                        task in
                        Text("• " + task)
                            .font(.system(size: 14, weight: .regular, design: .rounded))
                            .foregroundColor(Color(hex: configuration.theme.colors.text))
                    }
                }
                .padding()
                .background(
                    RoundedRectangle(cornerRadius: 10)
                        .fill(Color(hex: configuration.theme.colors.surface).opacity(0.5))
                )
            }
            .frame(maxHeight: 150)

            HStack {
                Button(action: openNewBrowserTab) {
                    Label("New Tab", systemImage: "safari.fill")
                }
                .buttonStyle(MinimalActionButtonStyle(configuration: configuration))

                Button(action: openProductiveApp) {
                    Label("Open Productive App", systemImage: "app.fill")
                }
                .buttonStyle(MinimalActionButtonStyle(configuration: configuration))
            }

            Button(action: {
                windowManager?.hideOrb()
            }) {
                Text("Dismiss")
                    .font(.system(size: 14, weight: .semibold, design: .rounded))
            }
            .buttonStyle(MinimalActionButtonStyle(configuration: configuration))
        }
        .padding(.horizontal, 20)
        .onAppear {
            // Optionally, you can log that the takeover view was presented
        }
    }

    private func openNewBrowserTab() {
        if let url = URL(string: "https://www.google.com") {
            NSWorkspace.shared.open(url)
            windowManager?.hideOrb()
        }
    }

    private func openProductiveApp() {
        // Randomly pick one productive app to open
        if let appName = configuration.settings.productiveApps.randomElement() {
            if !NSWorkspace.shared.launchApplication(appName) {
                // Fallback if app doesn't launch
                print("Could not launch app: \(appName)")
            }
            windowManager?.hideOrb()
        }
    }
}
