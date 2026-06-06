# MindGate - AI-Powered Laptop Productivity Assistant

A futuristic, on-device AI productivity assistant that helps you stay focused by intelligently managing access to distracting applications and websites. Now available cross-platform for macOS and Windows.

## Features

- **AI Orb Interface**: A futuristic, breathing AI orb with flowing line animations that appears when you visit distracting content
- **Liquid Glass Transparency**: Frosted glass effect with CSS backdrop-filter
- **UI Alive Visual Dynamics**: Hover-triggered glow intensification, breathing animations (0.8-1.2 scale), micro-interactions
- **Local AI Evaluation**: Uses Ollama with gemma3:1b running locally to evaluate your access requests
- **Smart Access Control**: AI decides whether to grant access (with time limits) or block the distraction
- **Seamless Integration**: Runs as a background agent without a Dock/taskbar icon
- **Browser Monitoring**: Tracks Safari, Chrome, Firefox, Brave, and Edge for distracting keywords
- **App Monitoring**: Detects when you switch to distracting applications
- **Typing Effect**: Character-by-character reveal for AI responses

## System Requirements

- macOS 10.15 (Catalina) or later
- Windows 10 or later
- Ollama running locally (http://localhost:11434)
- Accessibility permissions (granted on first launch)

## Installation

### Electron (Cross-Platform)

1. Clone this repository:
```bash
git clone https://github.com/yuvaang13/MindGate-An-AI-Powered-Laptop-Productivity-Assistant.git
cd MindGate-An-AI-Powered-Laptop-Productivity-Assistant/mindgate-electron
```

2. Install Ollama if you haven't already:
```bash
# Visit https://ollama.ai to download and install Ollama
# Then pull a model:
ollama pull gemma3:1b
```

3. Install dependencies:
```bash
npm install
```

4. Run in development:
```bash
npm run dev
```

5. Build for production:
```bash
npm run dist
```

## Usage

1. Launch MindGate - it runs in the background
2. When you navigate to a distracting app or website, the AI Orb appears
3. Click the Orb to expand the chat interface
4. Type your justification for needing access
5. The AI evaluates your request:
   - **Approved**: Choose a duration (5/10/15 minutes) and continue
   - **Denied**: The app/website is hidden and you're returned to work

## Architecture

- **WindowManager**: Manages Orb and Overlay BrowserWindows
- **WorkspaceMonitor**: Tracks active application changes
- **SystemMonitor**: Platform-specific window detection (macOS/Windows/Linux)
- **OllamaService**: Handles local AI API communication
- **DecisionEngine**: Processes AI responses and manages access control
- **ConfigurationService**: Persists settings to JSON

## Privacy

- All AI processing happens locally on your machine
- No data is sent to external servers
- Ollama runs entirely on-device

## License

MIT License - feel free to use and modify for your needs.

## Contributing

Contributions are welcome! Please feel free to submit a Pull Request.
