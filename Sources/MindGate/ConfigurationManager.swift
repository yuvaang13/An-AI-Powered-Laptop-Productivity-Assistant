import Foundation
import OSLog
import Combine

extension Notification.Name {
    static let configurationSaveFailed = Notification.Name("ConfigurationSaveFailed")
    static let ollamaModelMissing = Notification.Name("OllamaModelMissing")
}

struct ValidationIssue {
    let field: String
    let issue: String
    let correctedValue: Any?
}

class ConfigValidator {
    private let logger = Logger(subsystem: "com.mindgate.MindGate", category: "ConfigValidator")

    func validate(_ configuration: inout Configuration) -> [ValidationIssue] {
        var issues: [ValidationIssue] = []

        if configuration.settings.ollamaURL.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty {
            let defaultURL = AppSettings.defaultSettings.ollamaURL
            issues.append(ValidationIssue(
                field: "ollamaURL",
                issue: "URL is empty, using default",
                correctedValue: defaultURL
            ))
            configuration.settings.ollamaURL = defaultURL
        }

        if configuration.settings.ollamaModel.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty {
            let defaultModel = AppSettings.defaultSettings.ollamaModel
            issues.append(ValidationIssue(
                field: "ollamaModel",
                issue: "Model name is empty, using default",
                correctedValue: defaultModel
            ))
            configuration.settings.ollamaModel = defaultModel
        }

        if configuration.settings.ollamaTimeout < 5 || configuration.settings.ollamaTimeout > 60 {
            let clamped = max(5, min(60, configuration.settings.ollamaTimeout))
            issues.append(ValidationIssue(
                field: "ollamaTimeout",
                issue: "Timeout \(configuration.settings.ollamaTimeout) out of range [5, 60], clamped",
                correctedValue: clamped
            ))
            configuration.settings.ollamaTimeout = clamped
        }

        if configuration.settings.justificationCountdownDuration < 5 || configuration.settings.justificationCountdownDuration > 60 {
            let clamped = max(5, min(60, configuration.settings.justificationCountdownDuration))
            issues.append(ValidationIssue(
                field: "justificationCountdownDuration",
                issue: "Countdown \(configuration.settings.justificationCountdownDuration) out of range [5, 60], clamped",
                correctedValue: clamped
            ))
            configuration.settings.justificationCountdownDuration = clamped
        }

        let seenApps = Set(configuration.settings.distractingApps.map { $0.trimmingCharacters(in: .whitespacesAndNewlines).lowercased() })
        var uniqueApps: [String] = []
        for app in configuration.settings.distractingApps {
            let trimmed = app.trimmingCharacters(in: .whitespacesAndNewlines)
            let lower = trimmed.lowercased()
            if !trimmed.isEmpty && seenApps.contains(lower) {
                if !uniqueApps.contains(where: { $0.trimmingCharacters(in: .whitespacesAndNewlines).lowercased() == lower }) {
                    uniqueApps.append(trimmed)
                }
            } else if !trimmed.isEmpty {
                uniqueApps.append(trimmed)
            }
        }
        if uniqueApps.count != configuration.settings.distractingApps.count {
            issues.append(ValidationIssue(
                field: "distractingApps",
                issue: "Removed duplicates and empty entries",
                correctedValue: uniqueApps
            ))
            configuration.settings.distractingApps = uniqueApps
        }

        let seenKeywords = Set(configuration.settings.restrictedKeywords.map { $0.trimmingCharacters(in: .whitespacesAndNewlines).lowercased() })
        var uniqueKeywords: [String] = []
        for keyword in configuration.settings.restrictedKeywords {
            let trimmed = keyword.trimmingCharacters(in: .whitespacesAndNewlines)
            let lower = trimmed.lowercased()
            if !trimmed.isEmpty && seenKeywords.contains(lower) {
                if !uniqueKeywords.contains(where: { $0.trimmingCharacters(in: .whitespacesAndNewlines).lowercased() == lower }) {
                    uniqueKeywords.append(trimmed)
                }
            } else if !trimmed.isEmpty {
                uniqueKeywords.append(trimmed)
            }
        }
        if uniqueKeywords.count != configuration.settings.restrictedKeywords.count {
            issues.append(ValidationIssue(
                field: "restrictedKeywords",
                issue: "Removed duplicates and empty entries",
                correctedValue: uniqueKeywords
            ))
            configuration.settings.restrictedKeywords = uniqueKeywords
        }

        if !issues.isEmpty {
            logger.info("Configuration validation applied corrections: \(issues.map { $0.field }.joined(separator: ", "))")
        }

        return issues
    }
}

class ConfigMigrator {
    private let logger = Logger(subsystem: "com.mindgate.MindGate", category: "ConfigMigrator")
    let currentVersion = 1

    func migrate(_ configuration: Configuration, from: Int, to: Int) -> Configuration {
        var current = configuration
        for version in (from + 1)...to {
            current = applyMigration(current, toVersion: version)
        }
        return current
    }

    func detectVersion(_ configuration: Configuration) -> Int {
        return configuration.configVersion
    }

    private func applyMigration(_ config: Configuration, toVersion: Int) -> Configuration {
        switch toVersion {
        case 1: return migrateToV1(config)
        default: return config
        }
    }

    private func migrateToV1(_ config: Configuration) -> Configuration {
        var updated = config
        updated.configVersion = 1

        if updated.settings.ollamaTimeout == 0 {
            updated.settings.ollamaTimeout = AppSettings.defaultSettings.ollamaTimeout
        }

        logger.info("Migrated configuration to version 1")
        return updated
    }
}

class ConfigurationManager: ObservableObject {
    @Published var configuration: Configuration

    private let fileURL: URL
    private let validator = ConfigValidator()
    private let migrator = ConfigMigrator()
    private let logger = Logger(subsystem: "com.mindgate.MindGate", category: "ConfigurationManager")
    private var saveDebounceTimer: Timer?
    private let saveDebounceInterval: TimeInterval = 0.5

    init() {
        let fileManager = FileManager.default
        guard let applicationSupportURL = fileManager.urls(for: .applicationSupportDirectory, in: .userDomainMask).first else {
            fatalError("Unable to find application support directory.")
        }
        let appDirectoryURL = applicationSupportURL.appendingPathComponent("MindGate")
        self.fileURL = appDirectoryURL.appendingPathComponent("Configuration.json")

        if !fileManager.fileExists(atPath: appDirectoryURL.path) {
            do {
                try fileManager.createDirectory(at: appDirectoryURL, withIntermediateDirectories: true, attributes: nil)
            } catch {
                fatalError("Unable to create application directory: \(error.localizedDescription)")
            }
        }

        self.configuration = ConfigurationManager.loadConfiguration(from: fileURL, migrator: migrator, validator: validator)
    }

    private static func loadConfiguration(from url: URL, migrator: ConfigMigrator, validator: ConfigValidator) -> Configuration {
        let fileManager = FileManager.default
        if fileManager.fileExists(atPath: url.path) {
            do {
                let data = try Data(contentsOf: url)
                let decoder = JSONDecoder()
                var configuration = try decoder.decode(Configuration.self, from: data)

                let loadedVersion = migrator.detectVersion(configuration)
                if loadedVersion < migrator.currentVersion {
                    configuration = migrator.migrate(configuration, from: loadedVersion, to: migrator.currentVersion)
                }

                _ = validator.validate(&configuration)

                return configuration
            } catch {
                print("Error decoding configuration: \(error.localizedDescription)")
                let defaultConfig = Configuration.default
                saveConfiguration(defaultConfig, to: url)
                return defaultConfig
            }
        } else {
            let defaultConfig = Configuration.default
            saveConfiguration(defaultConfig, to: url)
            return defaultConfig
        }
    }

    static func saveConfiguration(_ configuration: Configuration, to url: URL) {
        do {
            let encoder = JSONEncoder()
            encoder.outputFormatting = .prettyPrinted
            let data = try encoder.encode(configuration)
            try data.write(to: url, options: .atomic)
        } catch {
            print("Error saving configuration: \(error.localizedDescription)")
        }
    }

    func save() {
        saveDebounceTimer?.invalidate()
        saveDebounceTimer = Timer.scheduledTimer(withTimeInterval: saveDebounceInterval, repeats: false) { [weak self] _ in
            self?.performSave()
        }
    }

    private func performSave() {
        do {
            let encoder = JSONEncoder()
            encoder.outputFormatting = .prettyPrinted
            let data = try encoder.encode(configuration)
            try data.write(to: fileURL, options: .atomic)
            logger.info("Configuration saved successfully")
        } catch {
            logger.error("Failed to save configuration: \(error.localizedDescription)")
            let userInfo = ["errorDescription": error.localizedDescription]
            NotificationCenter.default.post(name: .configurationSaveFailed, object: nil, userInfo: userInfo)
        }
    }

    func resetToDefaults() {
        configuration = Configuration.default
        save()
        objectWillChange.send()
    }

    func export(to url: URL) throws {
        do {
            let encoder = JSONEncoder()
            encoder.outputFormatting = .prettyPrinted
            let data = try encoder.encode(configuration)
            try data.write(to: url, options: .atomic)
            logger.info("Configuration exported to \(url.path)")
        } catch {
            logger.error("Failed to export configuration: \(error.localizedDescription)")
            throw ConfigurationError.exportFailed(error.localizedDescription)
        }
    }

    func `import`(from url: URL) throws {
        do {
            let data = try Data(contentsOf: url)
            let decoder = JSONDecoder()
            var importedConfig = try decoder.decode(Configuration.self, from: data)

            if importedConfig.settings.ollamaURL.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty {
                importedConfig.settings.ollamaURL = AppSettings.defaultSettings.ollamaURL
            }
            if importedConfig.settings.ollamaModel.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty {
                importedConfig.settings.ollamaModel = AppSettings.defaultSettings.ollamaModel
            }
            if importedConfig.settings.ollamaTimeout < 5 || importedConfig.settings.ollamaTimeout > 60 {
                importedConfig.settings.ollamaTimeout = max(5, min(60, importedConfig.settings.ollamaTimeout))
            }
            if importedConfig.settings.justificationCountdownDuration < 5 || importedConfig.settings.justificationCountdownDuration > 60 {
                importedConfig.settings.justificationCountdownDuration = max(5, min(60, importedConfig.settings.justificationCountdownDuration))
            }

            let loadedVersion = migrator.detectVersion(importedConfig)
            if loadedVersion < migrator.currentVersion {
                importedConfig = migrator.migrate(importedConfig, from: loadedVersion, to: migrator.currentVersion)
            }

            _ = validator.validate(&importedConfig)

            configuration = importedConfig
            save()
            logger.info("Configuration imported successfully")
        } catch let error as DecodingError {
            logger.error("Failed to import configuration - malformed JSON: \(error.localizedDescription)")
            throw ConfigurationError.importFailed("Malformed JSON: \(error.localizedDescription)")
        } catch {
            logger.error("Failed to import configuration: \(error.localizedDescription)")
            throw ConfigurationError.importFailed(error.localizedDescription)
        }
    }
}

enum ConfigurationError: LocalizedError {
    case exportFailed(String)
    case importFailed(String)

    var errorDescription: String? {
        switch self {
        case .exportFailed(let message): return "Export failed: \(message)"
        case .importFailed(let message): return "Import failed: \(message)"
        }
    }
}