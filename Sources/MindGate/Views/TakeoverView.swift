import SwiftUI

struct TakeoverView: View {
    let configuration: Configuration
    weak var windowManager: WindowManager?
    let decisionEngine: DecisionEngine

    var body: some View {
        VStack(spacing: 24) {
            VStack(spacing: 8) {
                Text("Time to Refocus")
                    .font(.system(size: 28, weight: .bold, design: .rounded))
                    .foregroundColor(Color(hex: configuration.theme.colors.primary))
                
                Text("Your work is waiting for you.")
                    .font(.system(size: 16, weight: .medium, design: .rounded))
                    .foregroundColor(Color(hex: configuration.theme.colors.textSecondary))
            }

            VStack(alignment: .leading, spacing: 12) {
                Text("Productive Suggestions:")
                    .font(.system(size: 14, weight: .semibold, design: .rounded))
                    .foregroundColor(Color(hex: configuration.theme.colors.primary).opacity(0.8))
                
                ScrollView {
                    VStack(alignment: .leading, spacing: 10) {
                        ForEach(configuration.settings.productiveTasks, id: \.self) { task in
                            HStack(alignment: .top, spacing: 8) {
                                Image(systemName: "circle.fill")
                                    .font(.system(size: 6))
                                    .padding(.top, 6)
                                Text(task)
                                    .font(.system(size: 14, weight: .regular, design: .rounded))
                            }
                            .foregroundColor(Color(hex: configuration.theme.colors.text))
                        }
                    }
                    .padding()
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .background(
                        RoundedRectangle(cornerRadius: 12)
                            .fill(Color(hex: configuration.theme.colors.surface).opacity(0.3))
                    )
                }
                .frame(maxHeight: 180)
            }

            VStack(spacing: 12) {
                HStack(spacing: 12) {
                    Button(action: openNewBrowserTab) {
                        Label("New Tab", systemImage: "safari.fill")
                            .frame(maxWidth: .infinity)
                    }
                    .buttonStyle(MinimalActionButtonStyle(configuration: configuration))

                    Button(action: openProductiveApp) {
                        Label("Open App", systemImage: "app.fill")
                            .frame(maxWidth: .infinity)
                    }
                    .buttonStyle(MinimalActionButtonStyle(configuration: configuration))
                }

                Button(action: {
                    windowManager?.hideOrb()
                }) {
                    Text("Dismiss & Return to Work")
                        .font(.system(size: 14, weight: .semibold, design: .rounded))
                        .frame(maxWidth: .infinity)
                }
                .buttonStyle(MinimalActionButtonStyle(configuration: configuration))
            }
        }
        .padding(24)
        .background(
            RoundedRectangle(cornerRadius: 24)
                .fill(Color(hex: configuration.theme.colors.background).opacity(0.95))
                .shadow(color: Color.black.opacity(0.3), radius: 20)
        )
    }

    private func openNewBrowserTab() {
        if let url = URL(string: "https://www.google.com") {
            NSWorkspace.shared.open(url)
            windowManager?.hideOrb()
        }
    }

    private func openProductiveApp() {
        if let appName = configuration.settings.productiveApps.randomElement() {
            NSWorkspace.shared.launchApplication(appName)
            windowManager?.hideOrb()
        }
    }
}
