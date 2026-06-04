# MindGate Electron

Cross-platform Electron implementation of MindGate productivity assistant.

## Development

```bash
npm install
npm run dev
```

## Build

```bash
npm run build
npm run dist
```

## Architecture

- **main.ts**: Electron main process entry point
- **preload.ts**: Secure IPC bridge between main and renderer
- **src/App.tsx**: Root React component
- **src/components/**: UI components (Orb, Chat, Overlay, Settings)
- **src/services/**: Business logic (window management, monitoring, AI decision)
- **src/platform/**: Platform-specific implementations (macOS, Windows, Linux)

## Features

- Cross-platform window monitoring
- Liquid glass UI with Framer Motion
- Local AI evaluation via Ollama
- System tray integration
- Persistent configuration