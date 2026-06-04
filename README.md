# MindGate - AI-Powered Laptop Productivity Assistant

A futuristic, on-device AI productivity assistant for macOS that helps you stay focused by intelligently managing access to distracting applications and websites.

## Features

- **AI Orb Interface**: A futuristic, breathing AI orb with flowing line animations that appears when you visit distracting content
- **Liquid Glass Transparency**: Frosted glass effect using NSVisualEffectView with dynamic blur and adaptive tinting
- **UI Alive Visual Dynamics**: Hover-triggered glow intensification, breathing animations (0.8-1.2 scale), micro-interactions
- **Local AI Evaluation**: Uses Ollama with gemma3:1b running locally to evaluate your access requests
- **Smart Access Control**: AI decides whether to grant access (with time limits) or block the distraction
- **Seamless Integration**: Runs as a background agent without a Dock icon
- **Browser Monitoring**: Tracks Safari, Chrome, Firefox, Brave, and Edge for distracting keywords
- **App Monitoring**: Detects when you switch to distracting applications via Accessibility API
- **Typing Effect**: Character-by-character reveal for AI responses

## Enhancement Roadmap

### Phase 1: Liquid Glass Transparency (macOS)
- Enhanced frosted glass effect with NSVisualEffectView and Gaussian blur
- Configurable transparency levels (90-95%) for different UI layers
- Subtle shadow layers and adaptive color tinting

### Phase 2: UI Alive - Visual Dynamics (macOS)
- Enhanced orb breathing animation with hover state intensification
- Dynamic glow effect that responds to mouse hover
- Ripple effects and scale transitions on button clicks
- Character-by-character typing animation for AI responses

### Phase 3-4: Electron Migration (Cross-Platform)
- React/Framer Motion UI components in `mindgate-electron/`
- Cross-platform window management for Windows/Linux support
- Platform-specific system monitoring modules

## System Requirements

- macOS 14.0 or later
- Swift 5.9 or later
- Ollama running locally (http://localhost:11434)
- Accessibility permissions (granted on first launch)

## Installation

### Using Swift Package Manager (No Xcode Required)

1. Clone this repository:
```bash
git clone https://github.com/yuvaang13/MindGate-An-AI-Powered-Laptop-Productivity-Assistant.git
cd MindGate-An-AI-Powered-Laptop-Productivity-Assistant
```

2. Install Ollama if you haven't already:
```bash
# Visit https://ollama.ai to download and install Ollama
# Then pull a model:
ollama pull gemma3:1b
```

3. Build the project:
```bash
swift build
```

4. Run the application:
```bash
swift run
```

5. Grant Accessibility permissions when prompted:
   - Go to System Settings > Privacy & Security > Accessibility
   - Add MindGate and enable it

### Using Xcode (Optional)

If you prefer to use Xcode:

```bash
# Open the package in Xcode
swift package edit
# Or double-click Package.swift to open in Xcode
```

## Usage

1. Launch MindGate - it runs in the background (no Dock icon)
2. When you navigate to a distracting app or website, the AI Orb appears
3. Click the Orb to expand the chat interface
4. Type your justification for needing access
5. The AI evaluates your request:
   - **Approved**: Choose a duration (5/10/15 minutes) and continue
   - **Denied**: The app/website is hidden and you're returned to work

## Configuration

Edit the `Sources/MindGate/Configuration.swift` file to customize:
- Distracting applications list
- Restricted website keywords
- Ollama model selection
- Access duration options

## Architecture

- **WindowManager**: Manages Orb and Overlay NSPanel windows
- **WorkspaceMonitor**: Tracks active application changes via NSWorkspace
- **AccessibilityMonitor**: Scrapes browser titles using AXUIElement
- **OllamaService**: Handles local AI API communication
- **DecisionEngine**: Processes AI responses and manages access control

## Privacy

- All AI processing happens locally on your machine
- No data is sent to external servers
- Ollama runs entirely on-device

## License

MIT License - feel free to use and modify for your needs

## Contributing

Contributions are welcome! Please feel free to submit a Pull Request.
