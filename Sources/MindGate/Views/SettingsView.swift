import SwiftUI

struct SettingsView: View {
    @EnvironmentObject var configurationManager: ConfigurationManager
    @State private var newDistractingApp: String = ""
    @State private var newRestrictedKeyword: String = ""
    @State private var newMonitoredBrowser: String = ""

    var body: some View {
        Form {
            Section(header: Text("Distracting Applications")) {
                List {
                    ForEach(configurationManager.configuration.settings.distractingApps, id: \.self) {
                        app in
                        Text(app)
                    }
                    .onDelete(perform: removeDistractingApp)
                }
                HStack {
                    TextField("Add new app", text: $newDistractingApp)
                    Button("Add") {
                        addDistractingApp()
                    }
                }
            }

            Section(header: Text("Restricted Website Keywords")) {
                List {
                    ForEach(configurationManager.configuration.settings.restrictedKeywords, id: \.self) {
                        keyword in
                        Text(keyword)
                    }
                    .onDelete(perform: removeRestrictedKeyword)
                }
                HStack {
                    TextField("Add new keyword", text: $newRestrictedKeyword)
                    Button("Add") {
                        addRestrictedKeyword()
                    }
                }
            }

            Section(header: Text("Monitored Browsers")) {
                List {
                    ForEach(configurationManager.configuration.settings.monitoredBrowsers, id: \.self) {
                        browser in
                        Text(browser)
                    }
                    .onDelete(perform: removeMonitoredBrowser)
                }
                HStack {
                    TextField("Add new browser", text: $newMonitoredBrowser)
                    Button("Add") {
                        addMonitoredBrowser()
                    }
                }
            }

            Section(header: Text("Ollama Configuration")) {
                TextField("Ollama URL", text: $configurationManager.configuration.settings.ollamaURL)
                TextField("Ollama Model", text: $configurationManager.configuration.settings.ollamaModel)
            }

            Section(header: Text("Access Duration Options")) {
                // TODO: Implement editing for access durations and labels
                Text("Access Durations (in seconds): \(configurationManager.configuration.settings.accessDurations.map { String(Int($0)) }.joined(separator: ", "))")
                Text("Access Duration Labels: \(configurationManager.configuration.settings.accessDurationLabels.joined(separator: ", "))")
            }

            Section(header: Text("Productive Tasks and Apps")) {
                // TODO: Implement editing for productive tasks and apps
                Text("Productive Tasks: \(configurationManager.configuration.settings.productiveTasks.joined(separator: ", "))")
                Text("Productive Apps: \(configurationManager.configuration.settings.productiveApps.joined(separator: ", "))")
            }

            Button("Save Configuration") {
                configurationManager.save()
            }
        }
        .padding()
        .frame(width: 600, height: 800)
    }

    private func addDistractingApp() {
        if !newDistractingApp.isEmpty && !configurationManager.configuration.settings.distractingApps.contains(newDistractingApp) {
            configurationManager.configuration.settings.distractingApps.append(newDistractingApp)
            newDistractingApp = ""
        }
    }

    private func removeDistractingApp(at offsets: IndexSet) {
        configurationManager.configuration.settings.distractingApps.remove(atOffsets: offsets)
    }

    private func addRestrictedKeyword() {
        if !newRestrictedKeyword.isEmpty && !configurationManager.configuration.settings.restrictedKeywords.contains(newRestrictedKeyword) {
            configurationManager.configuration.settings.restrictedKeywords.append(newRestrictedKeyword)
            newRestrictedKeyword = ""
        }
    }

    private func removeRestrictedKeyword(at offsets: IndexSet) {
        configurationManager.configuration.settings.restrictedKeywords.remove(atOffsets: offsets)
    }

    private func addMonitoredBrowser() {
        if !newMonitoredBrowser.isEmpty && !configurationManager.configuration.settings.monitoredBrowsers.contains(newMonitoredBrowser) {
            configurationManager.configuration.settings.monitoredBrowsers.append(newMonitoredBrowser)
            newMonitoredBrowser = ""
        }
    }

    private func removeMonitoredBrowser(at offsets: IndexSet) {
        configurationManager.configuration.settings.monitoredBrowsers.remove(atOffsets: offsets)
    }
}
