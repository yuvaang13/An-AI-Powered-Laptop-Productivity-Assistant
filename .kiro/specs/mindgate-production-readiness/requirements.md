# Requirements Document

## Introduction

MindGate is a macOS productivity assistant that monitors active applications and browser tabs to detect distracting content, then prompts the user to justify access via a local AI evaluation engine (Ollama). The current codebase has core monitoring and decision logic in place but lacks production-grade robustness: connection resilience for Ollama, comprehensive error handling, validated configuration persistence, resource-bounded monitoring, accessible UI controls, and a testing foundation. This document captures all requirements needed to bring MindGate to a production-ready state.

---

## Glossary

- **MindGate**: The macOS SwiftUI productivity assistant application being developed.
- **OllamaService**: The component responsible for communicating with the local Ollama AI server via HTTP.
- **Ollama**: A locally-running AI inference server, expected at `http://localhost:11434` by default.
- **DecisionEngine**: The component that receives user justification text, invokes OllamaService, and returns an approval decision.
- **WorkspaceMonitor**: The component that detects frontmost application switches and triggers distraction prompts.
- **AccessibilityManager**: The component that uses macOS Accessibility APIs and AppleScript to read browser URLs and window titles.
- **ConfigurationManager**: The component that loads, validates, saves, and migrates the persisted `Configuration.json` file.
- **Configuration**: The JSON file containing AppSettings and UITheme, stored in the macOS Application Support directory.
- **BlockedApp**: A user-defined entry in the distracting applications list, matched by application name or bundle ID.
- **BlockedKeyword**: A user-defined entry in the restricted keywords list, matched against browser URLs and window titles.
- **OrbView**: The floating AI orb UI panel that expands into the chat/justification interface.
- **SettingsView**: The settings panel UI accessible from the macOS status bar menu.
- **PermissionFlow**: The first-launch sequence that requests macOS Accessibility and Automation permissions.
- **GracefulDegradation**: Behavior where MindGate continues operating with reduced functionality when Ollama is unavailable.
- **LocalFallback**: The rule-based approval decision used when Ollama is unreachable.
- **ConfigVersion**: An integer field in Configuration that tracks the schema version for migration purposes.

---

## Requirements

### Requirement 1: Ollama Connection Resilience

**User Story:** As a MindGate user, I want the app to handle Ollama connection failures gracefully, so that I am never left with a frozen UI or a silent failure when the AI service is unavailable.

#### Acceptance Criteria

1. THE OllamaService SHALL define an `OllamaError.timeout` error case.
2. IF `generateResponse` does not receive a response within the configured timeout, THEN THE OllamaService SHALL cancel the request and throw `OllamaError.timeout`.
3. THE OllamaService SHALL use a default timeout of 10 seconds for all `generateResponse` requests.
4. THE AppSettings struct SHALL include an `ollamaTimeout: Int` field representing the timeout duration in seconds.
5. WHERE AppSettings contains an `ollamaTimeout` value in the range 1–300 seconds inclusive, THE OllamaService SHALL use that value for the `generateResponse` timeout duration instead of the default.
6. WHEN OllamaService throws any `OllamaError`, THE DecisionEngine SHALL return a `DecisionResult` with `isApproved` set to `false` and a message containing the text "AI service unavailable".
7. WHEN OllamaService throws `OllamaError.connectionFailed` or `OllamaError.timeout`, THE OllamaService SHALL log an error entry containing the elapsed duration in milliseconds from the moment the request was initiated.
8. WHEN `checkConnection()` is called and Ollama responds with HTTP 200, THE OllamaService SHALL return `true` within 5 seconds.
9. IF `checkConnection()` does not receive a response within 5 seconds, THEN THE OllamaService SHALL return `false` without throwing an exception.
10. THE OllamaService SHALL validate that the AI response body contains a `"response"` string field that is non-empty after trimming whitespace before returning the value.
11. IF the AI response body is missing the `"response"` field or the field is empty or contains only whitespace, THEN THE OllamaService SHALL throw `OllamaError.invalidResponseData`.

---

### Requirement 2: Ollama Automatic Model Availability Check

**User Story:** As a MindGate user, I want the app to warn me if the configured AI model is not available on my Ollama installation, so that I can resolve setup issues before they silently affect functionality.

#### Acceptance Criteria

1. WHEN `checkConnection()` returns `true`, THE OllamaService SHALL also call the `/api/tags` endpoint with a timeout of 30 seconds to verify whether the configured model is present in the local model list.
2. THE OllamaService SHALL consider the configured model "not found" IF the `/api/tags` response JSON contains a `"models"` array AND no array element has a `"name"` string field that exactly equals the configured model name (case-sensitive comparison).
3. IF the configured model is not found, THEN THE OllamaService SHALL emit a warning log entry containing the text "Model not available" and identifying the missing model name.
4. IF the configured model is not found, THEN THE OllamaService SHALL post an `OllamaModelMissingNotification` to `NotificationCenter` with the model name in the notification's `userInfo` dictionary under the key `"modelName"`.
5. WHEN `OllamaModelMissingNotification` is received, THE SettingsView SHALL display a warning banner containing the text "Model not available" and identifying the missing model name, and the banner SHALL remain visible until the user saves a valid model name that exists in the local Ollama installation.
6. IF the `/api/tags` request fails with a network error or non-200 HTTP status, THEN THE OllamaService SHALL log a warning entry containing the text "Failed to query available models" and SHALL NOT post `OllamaModelMissingNotification`.

---

### Requirement 3: Configurable Distraction Detection

**User Story:** As a MindGate user, I want to add, remove, and edit the list of blocked applications and browser keywords from the Settings panel, so that I can tailor distraction detection to my personal workflow.

#### Acceptance Criteria

1. THE SettingsView SHALL display the current `distractingApps` list with controls to add a new entry, edit an existing entry, and delete an existing entry, WHERE each entry accepts strings of length 1–255 characters inclusive and editing commits the change when the user presses Return or the text field loses focus.
2. THE SettingsView SHALL display the current `restrictedKeywords` list with controls to add a new entry, edit an existing entry, and delete an existing entry, WHERE each entry accepts strings of length 1–255 characters inclusive and editing commits the change when the user presses Return or the text field loses focus.
3. WHEN the user performs an add, edit, or delete operation on `distractingApps` or `restrictedKeywords`, THE ConfigurationManager SHALL persist the updated configuration to disk within 1 second.
4. WHEN the WorkspaceMonitor evaluates an application after a list change, THE WorkspaceMonitor SHALL use the latest saved `distractingApps` and `restrictedKeywords` values.
5. THE SettingsView SHALL provide a reset-to-defaults action for both lists that immediately replaces both the in-memory `distractingApps` and `restrictedKeywords` with the values from `AppSettings.defaultSettings` and persists the change to disk within 1 second.
6. THE SettingsView SHALL provide an import action that reads a JSON file containing a `distractingApps` array and a `restrictedKeywords` array and merges the entries into the current lists using case-insensitive trimmed comparison to ignore duplicates, and IF the JSON file is malformed or does not contain the expected structure, THEN THE SettingsView SHALL display an error alert and leave the current lists unchanged.
7. THE SettingsView SHALL provide an export action that writes the current `distractingApps` and `restrictedKeywords` arrays to a user-chosen JSON file, and IF the write fails, THEN THE SettingsView SHALL display an error alert.
8. WHEN the user selects a preset from the preset selection control, THE SettingsView SHALL merge the preset's `distractingApps` and `restrictedKeywords` into the current lists using case-insensitive trimmed comparison to ignore duplicates and persist the merged configuration to disk within 1 second.

---

### Requirement 4: Configuration Validation and Migration

**User Story:** As a MindGate user, I want the app to handle corrupt or outdated configuration files gracefully, so that I never lose app functionality due to a malformed settings file.

#### Acceptance Criteria

1. WHEN ConfigurationManager loads `Configuration.json` and `JSONDecoder` throws a decoding error, THE ConfigurationManager SHALL log the error, write the default configuration to disk, and continue startup with default values.
2. WHEN ConfigurationManager loads `Configuration.json` and `ollamaURL` is an empty string, THE ConfigurationManager SHALL replace it with the default URL `http://localhost:11434/api/generate`.
3. WHEN ConfigurationManager loads `Configuration.json` and `ollamaModel` is an empty string, THE ConfigurationManager SHALL replace it with the default model `gemma3:1b`.
4. WHEN ConfigurationManager loads `Configuration.json` and `justificationCountdownDuration` is less than 5 or greater than 60, THE ConfigurationManager SHALL clamp the value to the range [5, 60].
5. WHEN ConfigurationManager completes field sanitization in criteria 2–4, THE ConfigurationManager SHALL write the corrected configuration back to disk within 1 second.
6. THE Configuration struct SHALL include a `configVersion: Int` field with a default value of `1`.
7. WHEN ConfigurationManager loads a `Configuration.json` with a missing `configVersion` field, THE ConfigurationManager SHALL treat the configuration as version `0`.
8. WHEN ConfigurationManager loads a `Configuration.json` with a `configVersion` lower than the current version, THE ConfigurationManager SHALL apply each migration version step in ascending order from the loaded version to the current version, write the migrated configuration to disk with the updated `configVersion`, and return the migrated configuration.
9. THE ConfigurationManager SHALL expose a `resetToDefaults()` method that replaces the `configuration` @Published property with `Configuration.default`, writes the default configuration to disk within 1 second, and triggers a property change notification.

---

### Requirement 5: macOS Permission Request Flow

**User Story:** As a first-time MindGate user, I want the app to guide me through granting required macOS permissions on first launch, so that I understand why the permissions are needed and can grant them without confusion.

#### Acceptance Criteria

1. WHEN MindGate launches and Accessibility permission has never been granted, THE MindGate application SHALL present a modal dialog explaining why Accessibility permission is required before requesting the permission.
2. WHEN the user dismisses the Accessibility permission dialog without granting access, THE MindGate application SHALL continue to run with browser URL tracking disabled and display a status bar tooltip containing the text "browser URL tracking disabled" that remains visible until Accessibility permission is granted.
3. WHEN Accessibility permission is granted after app launch, THE WorkspaceMonitor SHALL detect the change within 30 seconds and resume browser URL tracking without requiring a restart.
4. WHEN MindGate attempts to execute an AppleScript URL query and receives a permission error, THE AccessibilityManager SHALL log the error and return `nil` without crashing.
5. THE MindGate application SHALL verify Accessibility permission status on every launch, log the result, and IF Accessibility permission is still denied THEN display the status bar tooltip without re-presenting the modal dialog.

---

### Requirement 6: Resource-Bounded Monitoring

**User Story:** As a MindGate user, I want the monitoring loop to consume minimal system resources during normal use, so that MindGate does not noticeably degrade my Mac's performance.

#### Acceptance Criteria

1. WHILE neither the frontmost application nor the active browser URL has changed since the last polling cycle, THE WorkspaceMonitor polling loop SHALL execute at an interval of 1000 milliseconds.
2. WHEN a browser content check is triggered, IF no frontmost application change has occurred within 750 milliseconds of the check trigger, THEN THE WorkspaceMonitor SHALL skip the browser content check for that polling cycle.
3. WHILE the distraction prompt window is not currently visible on screen, THE WorkspaceMonitor SHALL not perform AppleScript URL queries.
4. IF a distraction prompt for an application with the same bundle identifier has been shown within the last 20 seconds, THEN THE WorkspaceMonitor SHALL not re-present the prompt.
5. THE OllamaService SHALL use a dedicated `URLSession` instance configured to enforce a maximum of 2 concurrent connections at any time.
6. WHILE MindGate is running and no frontmost app change or user interaction event has occurred for more than 300 seconds, THE WorkspaceMonitor polling interval SHALL remain at 1000 milliseconds and CPU usage averaged over any 30-second window SHALL NOT exceed 5% as measured by Activity Monitor.

---

### Requirement 7: AI Orb UI — Keyboard Accessibility and Interaction

**User Story:** As a MindGate user, I want to interact with the AI orb entirely via keyboard, so that I can respond to distraction prompts without switching to the mouse.

#### Acceptance Criteria

1. WHEN the OrbView expands to show the justification input, THE OrbView SHALL automatically focus the text input field so the user can begin typing immediately.
2. WHEN the justification text field has focus and contains non-empty input and the user presses Command+Return, THE OrbView SHALL submit the justification for AI evaluation.
3. WHEN the OrbView is visible and expanded, THE OrbView SHALL respond to the Escape key by collapsing the orb and hiding the distraction prompt.
4. WHEN the OrbView is collapsed (orb-only state) and the user presses Space or Return while the orb has keyboard focus, THE OrbView SHALL expand to show the justification input.
5. WHEN the OrbView is displaying the AI response message and the user activates the "Copy" button, THE OrbView SHALL copy the response text to the system clipboard and change the button label to "Copied" for 2 seconds before reverting to "Copy".

---

### Requirement 8: AI Response Streaming and Display

**User Story:** As a MindGate user, I want AI responses to appear progressively, so that I receive feedback faster and the interface feels responsive.

#### Acceptance Criteria

1. WHEN OllamaService receives a streaming response chunk, THE OllamaService SHALL append the chunk text to the in-progress response string and notify observers via an `AsyncStream<String>`.
2. WHEN ChatView receives new response tokens via the stream, THE ChatView SHALL append each token to the displayed text such that the updated text becomes visible within 100 milliseconds of token receipt.
3. WHILE streaming is in progress, THE ChatView SHALL display a "Reveal All" button.
4. WHEN the user activates the "Reveal All" button, THE ChatView SHALL cancel the stream and display the full buffered response text within 500 milliseconds.
5. WHEN a streamed response exceeds 500 characters, THE ChatView SHALL truncate the visible display at 500 characters and show a "Show more" expansion control, and WHEN the user taps the "Show more" control, THE ChatView SHALL expand the display to show the full response text.
6. WHEN streaming completes successfully, THE ChatView SHALL hide the streaming indicator and display the final response text in full (subject to the 500-character truncation rule).
7. WHEN streaming begins, THE ChatView SHALL display a streaming indicator within 200 milliseconds of the first token being received.
8. IF the streaming request fails with a network error or OllamaService error, THEN THE ChatView SHALL hide the streaming indicator, cancel the stream, and display an error message containing the text "Failed to receive AI response".

---

### Requirement 9: Settings Panel — Ollama Configuration and Connection Test

**User Story:** As a MindGate user, I want to configure and verify my Ollama connection from within the Settings panel, so that I can diagnose connectivity issues without leaving the app.

#### Acceptance Criteria

1. THE SettingsView SHALL display editable fields for Ollama URL and Ollama model name.
2. THE SettingsView SHALL display an editable numeric field labeled "Request Timeout" for the Ollama request timeout in seconds, accepting integer values in the range [5, 60], and the field SHALL bind to `AppSettings.ollamaTimeout`.
3. THE AppSettings struct SHALL include an `ollamaTimeout: Int` field with a default value of 10.
4. WHEN the user activates the "Test Connection" button in SettingsView, THE SettingsView SHALL display an in-progress indicator, call `OllamaService.checkConnection()`, and within 6 seconds display either a success message containing the text "Connection successful" or a failure message containing the text "Connection failed".
5. WHEN the user saves Ollama configuration changes (URL, model name, or timeout), THE ConfigurationManager SHALL validate that the URL is non-empty and the timeout is in the range [5, 60], persist the changes to disk within 1 second, and THE OllamaService SHALL use the updated values for all subsequent requests.
6. THE SettingsView SHALL display a logging level selector (Debug, Info, Warning, Error) that controls the minimum log level emitted by all MindGate OSLog categories.

---

### Requirement 10: Error Handling and User Feedback

**User Story:** As a MindGate user, I want to see clear, actionable messages when something goes wrong, so that I know what failed and how to fix it.

#### Acceptance Criteria

1. WHEN DecisionEngine returns a `DecisionResult` with `isApproved` set to `false` due to an Ollama error, THE ChatView SHALL display a message containing either the text "AI evaluation denied access" (if the denial was due to the AI model's evaluation) or the text "AI service unavailable" (if the denial was due to a connection or timeout error).
2. WHEN ConfigurationManager fails to save `Configuration.json`, THE ConfigurationManager SHALL log an error entry containing the file path and error description, and shall post a `ConfigurationSaveFailedNotification` to `NotificationCenter` with the error description in the notification's `userInfo` dictionary under the key `"errorDescription"`.
3. WHEN `ConfigurationSaveFailedNotification` is received, THE SettingsView SHALL display a non-blocking alert banner containing the text "Failed to save configuration" and the error description from the notification, with a dismiss button, and the banner SHALL remain visible until the user dismisses it.
4. WHEN AccessibilityManager's AppleScript call fails for a browser URL query, THE AccessibilityManager SHALL log the browser name, error description, and return `nil` rather than propagating the error.
5. WHEN WorkspaceMonitor encounters a Swift Error thrown during the monitoring loop that is not caught by existing error handlers, THE WorkspaceMonitor SHALL log an error entry containing the error description and the text "Monitoring loop error", restart the monitoring loop after a 2-second delay, and increment a retry counter that prevents infinite restart loops (maximum 5 restarts within 60 seconds).

---

### Requirement 11: Configuration Import and Export (Round-Trip)

**User Story:** As a MindGate user, I want to export my configuration to a file and re-import it on another machine, so that I can keep my productivity settings consistent across devices.

#### Acceptance Criteria

1. THE ConfigurationManager SHALL provide an `export(to url: URL) throws` method that encodes the current `Configuration` to a pretty-printed JSON file at the specified URL.
2. THE ConfigurationManager SHALL provide an `import(from url: URL) throws` method that decodes a `Configuration` from a JSON file, validates that `ollamaURL` is non-empty and `justificationCountdownDuration` is in the range [5, 60], applies field corrections if needed, and replaces the in-memory configuration and persists it to the standard configuration file path within 1 second.
3. FOR ALL valid `Configuration` values, encoding and then decoding the value SHALL produce a `Configuration` that is field-by-field value-equal across all fields of `AppSettings` (distractingApps, restrictedKeywords, monitoredBrowsers, ollamaURL, ollamaModel, accessDurations, accessDurationLabels, productiveTasks, productiveApps, justificationCountdownDuration) and `UITheme` (colors, animation, dimensions) (round-trip property).
4. WHEN `import(from:)` receives a JSON file with an unknown field, THE ConfigurationManager SHALL ignore the unknown field and continue loading known fields.
5. WHEN `import(from:)` receives a JSON file with a missing field, THE ConfigurationManager SHALL substitute the default value for that field from `AppSettings.defaultSettings` or `UITheme.defaultTheme`.
6. IF the `export(to:)` method fails to write the file, THEN THE ConfigurationManager SHALL throw an error containing a description of the write failure and SHALL NOT modify the existing file at the target URL if one exists.
7. IF the `import(from:)` method receives a file containing malformed JSON, THEN THE ConfigurationManager SHALL throw a decoding error and SHALL NOT modify the current in-memory configuration.

---

### Requirement 12: Keyword Matching Correctness

**User Story:** As a MindGate developer, I want the keyword matching logic to be well-specified and tested, so that false positives and false negatives in distraction detection are minimized.

#### Acceptance Criteria

1. THE WorkspaceMonitor keyword matching SHALL perform case-insensitive comparison by converting both the keyword and the target text to lowercase before comparison.
2. WHEN a `BlockedKeyword` entry has leading or trailing whitespace, THE WorkspaceMonitor SHALL trim all leading and trailing whitespace characters (U+0020, U+0009, U+000A, U+000D) before comparing against browser URLs and window titles.
3. WHEN a browser URL or window title (after trimming and lowercasing) exactly equals a `BlockedKeyword` (after trimming and lowercasing), THE WorkspaceMonitor SHALL classify the content as restricted.
4. WHEN a browser URL or window title (after lowercasing) contains a `BlockedKeyword` (after trimming and lowercasing) as a substring, THE WorkspaceMonitor SHALL classify the content as restricted.
5. WHEN a browser URL or window title (after lowercasing) does not contain any `BlockedKeyword` (after trimming and lowercasing) as a substring, THE WorkspaceMonitor SHALL NOT classify the content as restricted.
6. FOR ALL non-empty keyword lists and URL strings WHERE at least one keyword contains at least one non-whitespace character, the `matchedRestrictedKeyword(in:)` function SHALL return a non-nil result if and only if there exists at least one keyword K such that K (after trimming whitespace and converting to lowercase) is a substring of the URL (after converting to lowercase).

---

### Requirement 13: Unit and Integration Test Coverage

**User Story:** As a MindGate developer, I want a foundational test suite covering the core decision and configuration logic, so that regressions are caught before release.

#### Acceptance Criteria

1. THE MindGate test target SHALL include unit tests for `OllamaService.generateResponse` that cover: (a) successful response parsing returning the expected string value, (b) HTTP error status codes (at minimum one 4xx code and one 5xx code) throwing the expected error type, (c) malformed JSON response throwing a decoding error, and (d) connection timeout throwing `OllamaError.timeout`.
2. THE MindGate test target SHALL include unit tests for `DecisionEngine.evaluateRequest` that cover: (a) Ollama approval response returning `DecisionResult(isApproved: true, message: ...)`, (b) Ollama denial response returning `DecisionResult(isApproved: false, message: ...)`, and (c) Ollama service error returning `DecisionResult(isApproved: false, message: "AI service unavailable")`.
3. THE MindGate test target SHALL include unit tests for `ConfigurationManager` that cover: (a) loading a valid configuration and verifying field values match the JSON, (b) loading a corrupt configuration and verifying default values are used, (c) field validation and clamping for `ollamaURL` (empty → default), `ollamaModel` (empty → default), and `justificationCountdownDuration` (out of [5, 60] → clamped), and (d) round-trip encode/decode producing a `Configuration` that is field-by-field value-equal across all `AppSettings` and `UITheme` fields.
4. THE MindGate test target SHALL include unit tests for the `WorkspaceMonitor` keyword matching logic that cover: (a) exact match (keyword == URL), (b) substring match (keyword is substring of URL), (c) case-insensitive match (keyword differs only in case), (d) whitespace-trimmed keyword (keyword with leading/trailing whitespace matches trimmed equivalent in URL), and (e) no-match case (keyword not contained in URL).
5. THE MindGate test target SHALL include a property-based test for the `Configuration` round-trip: for any `Configuration` value generated by the test framework, encoding and then decoding SHALL produce a `Configuration` that is field-by-field value-equal across all `AppSettings` (distractingApps, restrictedKeywords, monitoredBrowsers, ollamaURL, ollamaModel, accessDurations, accessDurationLabels, productiveTasks, productiveApps, justificationCountdownDuration) and `UITheme` (colors, animation, dimensions) fields.
6. THE MindGate test target SHALL include a property-based test for keyword matching: for any non-empty keyword list and URL string, the matching result SHALL be equivalent to the boolean predicate: ∃ keyword ∈ keywords such that trim(lowercase(keyword)) is a substring of lowercase(URL).

---

### Requirement 14: Blocked App Matching by Bundle ID

**User Story:** As a MindGate user, I want the blocked apps list to support bundle IDs as well as display names, so that I can precisely target specific apps without risking false matches on similarly-named apps.

#### Acceptance Criteria

1. WHEN a `BlockedApp` entry in `distractingApps` exactly equals (case-insensitive comparison) the `bundleIdentifier` of the frontmost application, THE WorkspaceMonitor SHALL classify the application as distracting.
2. WHEN a `BlockedApp` entry in `distractingApps` matches the `localizedName` of the frontmost application (case-insensitive, substring match with minimum 1 non-whitespace character), THE WorkspaceMonitor SHALL classify the application as distracting.
3. WHEN a frontmost application has a nil `bundleIdentifier` at runtime, THE WorkspaceMonitor SHALL fall back to matching only against the `localizedName` using the logic in criterion 2.
4. WHEN a `BlockedApp` entry in `distractingApps` matches neither the `bundleIdentifier` nor the `localizedName` of the frontmost application, THE WorkspaceMonitor SHALL NOT classify the application as distracting.
5. THE SettingsView SHALL display both the app display name and bundle ID for each entry when the user views the blocked apps list, and IF the bundle ID is not available for a given entry, THEN THE SettingsView SHALL display only the display name.

---

### Requirement 15: Graceful Degradation When Ollama Is Unavailable

**User Story:** As a MindGate user, I want MindGate to remain functional even if Ollama is not running, so that my workflow is not completely blocked by an AI service dependency.

#### Acceptance Criteria

1. WHEN `OllamaService.checkConnection()` returns `false` at app launch, THE MindGate application SHALL display a status bar tooltip containing the text "AI evaluation is unavailable" that does not block user interaction with other UI elements and does not present as a modal dialog.
2. IF Ollama is unavailable (connection check returns `false` or request throws an error), THEN THE DecisionEngine SHALL return `DecisionResult(isApproved: false, message: "AI offline — access denied")` without evaluating the justification text content.
3. WHEN DecisionEngine invokes `OllamaService.generateResponse` on the next `evaluateRequest` call after Ollama was previously unavailable, THE DecisionEngine SHALL re-attempt the connection and resume using OllamaService for evaluation if the request succeeds.
4. WHEN DecisionEngine applies the fallback rule due to Ollama being unavailable, THE DecisionEngine SHALL log a warning entry containing text identifying the fallback as the reason for the denial.
