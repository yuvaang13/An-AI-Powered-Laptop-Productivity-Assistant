import SwiftUI

struct SettingsView: View {
    @EnvironmentObject var configurationManager: ConfigurationManager
    @State private var newDistractingApp: String = ""
    @State private var newRestrictedKeyword: String = ""
    @State private var newMonitoredBrowser: String = ""
    @State private var newProductiveTask: String = ""
    @State private var newProductiveApp: String = ""
    @State private var ollamaURL: String = ""
    @State private var ollamaModel: String = ""
    @State private var justificationCountdownDuration: Int = 15

    var body: some View {
        TabView {
            // MARK: - Monitoring Tab
            Form {
                Section(header: Text("Distracting Applications")) {
                    List {
                        ForEach(configurationManager.configuration.settings.distractingApps, id: \.self) { app in
                            Text(app)
                        }
                        .onDelete(perform: removeDistractingApp)
                    }
                    .frame(height: 150)
                    HStack {
                        TextField("Add new app", text: $newDistractingApp)
                        Button("Add") { addDistractingApp() }
                            .disabled(newDistractingApp.isEmpty)
                    }
                }

                Section(header: Text("Restricted Website Keywords")) {
                    List {
                        ForEach(configurationManager.configuration.settings.restrictedKeywords, id: \.self) { keyword in
                            Text(keyword)
                        }
                        .onDelete(perform: removeRestrictedKeyword)
                    }
                    .frame(height: 150)
                    HStack {
                        TextField("Add new keyword", text: $newRestrictedKeyword)
                        Button("Add") { addRestrictedKeyword() }
                            .disabled(newRestrictedKeyword.isEmpty)
                    }
                }

                Section(header: Text("Monitored Browsers")) {
                    List {
                        ForEach(configurationManager.configuration.settings.monitoredBrowsers, id: \.self) { browser in
                            Text(browser)
                        }
                        .onDelete(perform: removeMonitoredBrowser)
                    }
                    .frame(height: 100)
                    HStack {
                        TextField("Add new browser", text: $newMonitoredBrowser)
                        Button("Add") { addMonitoredBrowser() }
                            .disabled(newMonitoredBrowser.isEmpty)
                    }
                }
            }
            .tabItem { Label("Monitoring", systemImage: "eye") }
            .padding()

            // MARK: - Productivity Tab
            Form {
                Section(header: Text("Productive Tasks")) {
                    List {
                        ForEach(configurationManager.configuration.settings.productiveTasks, id: \.self) { task in
                            Text(task)
                        }
                        .onDelete(perform: removeProductiveTask)
                    }
                    .frame(height: 150)
                    HStack {
                        TextField("Add new task", text: $newProductiveTask)
                        Button("Add") { addProductiveTask() }
                            .disabled(newProductiveTask.isEmpty)
                    }
                }

                Section(header: Text("Productive Apps")) {
                    List {
                        ForEach(configurationManager.configuration.settings.productiveApps, id: \.self) { app in
                            Text(app)
                        }
                        .onDelete(perform: removeProductiveApp)
                    }
                    .frame(height: 150)
                    HStack {
                        TextField("Add new app", text: $newProductiveApp)
                        Button("Add") { addProductiveApp() }
                            .disabled(newProductiveApp.isEmpty)
                    }
                }
            }
            .tabItem { Label("Productivity", systemImage: "checkmark.circle") }
            .padding()

            // MARK: - AI & Advanced Tab
            Form {
                Section(header: Text("Ollama Configuration")) {
                    TextField("Ollama URL", text: $ollamaURL)
                    TextField("Ollama Model", text: $ollamaModel)
                }

                Section(header: Text("Behavior Settings")) {
                    Stepper("Justification Countdown: \(justificationCountdownDuration)s", value: $justificationCountdownDuration, in: 5...60)
                }
                
                Spacer()
                
                Button(action: saveAll) {
                    Text("Save Configuration")
                        .frame(maxWidth: .infinity)
                        .padding(.vertical, 8)
                }
                .buttonStyle(.borderedProminent)
                .padding(.top)
            }
            .tabItem { Label("AI & Advanced", systemImage: "cpu") }
            .padding()
        }
        .frame(width: 600, height: 700)
        .onAppear {
            loadCurrentSettings()
        }
    }

    private func loadCurrentSettings() {
        ollamaURL = configurationManager.configuration.settings.ollamaURL
        ollamaModel = configurationManager.configuration.settings.ollamaModel
        justificationCountdownDuration = configurationManager.configuration.settings.justificationCountdownDuration
    }

    private func saveAll() {
        configurationManager.configuration.settings.ollamaURL = ollamaURL
        configurationManager.configuration.settings.ollamaModel = ollamaModel
        configurationManager.configuration.settings.justificationCountdownDuration = justificationCountdownDuration
        configurationManager.save()
    }

    // MARK: - Helper Methods
    private func addDistractingApp() {
        let trimmed = newDistractingApp.trimmingCharacters(in: .whitespacesAndNewlines)
        if !trimmed.isEmpty && !configurationManager.configuration.settings.distractingApps.contains(trimmed) {
            configurationManager.configuration.settings.distractingApps.append(trimmed)
            newDistractingApp = ""
        }
    }

    private func removeDistractingApp(at offsets: IndexSet) {
        configurationManager.configuration.settings.distractingApps.remove(atOffsets: offsets)
    }

    private func addRestrictedKeyword() {
        let trimmed = newRestrictedKeyword.trimmingCharacters(in: .whitespacesAndNewlines)
        if !trimmed.isEmpty && !configurationManager.configuration.settings.restrictedKeywords.contains(trimmed) {
            configurationManager.configuration.settings.restrictedKeywords.append(trimmed)
            newRestrictedKeyword = ""
        }
    }

    private func removeRestrictedKeyword(at offsets: IndexSet) {
        configurationManager.configuration.settings.restrictedKeywords.remove(atOffsets: offsets)
    }

    private func addMonitoredBrowser() {
        let trimmed = newMonitoredBrowser.trimmingCharacters(in: .whitespacesAndNewlines)
        if !trimmed.isEmpty && !configurationManager.configuration.settings.monitoredBrowsers.contains(trimmed) {
            configurationManager.configuration.settings.monitoredBrowsers.append(trimmed)
            newMonitoredBrowser = ""
        }
    }

    private func removeMonitoredBrowser(at offsets: IndexSet) {
        configurationManager.configuration.settings.monitoredBrowsers.remove(atOffsets: offsets)
    }

    private func addProductiveTask() {
        let trimmed = newProductiveTask.trimmingCharacters(in: .whitespacesAndNewlines)
        if !trimmed.isEmpty && !configurationManager.configuration.settings.productiveTasks.contains(trimmed) {
            configurationManager.configuration.settings.productiveTasks.append(trimmed)
            newProductiveTask = ""
        }
    }

    private func removeProductiveTask(at offsets: IndexSet) {
        configurationManager.configuration.settings.productiveTasks.remove(atOffsets: offsets)
    }

    private func addProductiveApp() {
        let trimmed = newProductiveApp.trimmingCharacters(in: .whitespacesAndNewlines)
        if !trimmed.isEmpty && !configurationManager.configuration.settings.productiveApps.contains(trimmed) {
            configurationManager.configuration.settings.productiveApps.append(trimmed)
            newProductiveApp = ""
        }
    }

    private func removeProductiveApp(at offsets: IndexSet) {
        configurationManager.configuration.settings.productiveApps.remove(atOffsets: offsets)
    }
}
