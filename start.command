#!/bin/bash
# start.command – Build and launch MindGate (Electron)

set -euo pipefail
IFS=$'\n\t'

log() {
  echo "[$(date '+%Y-%m-%d %H:%M:%S')] $*"
}

PROJECT_ROOT="$(cd "$(dirname "$0")" && pwd)"
ELECTRON_DIR="${PROJECT_ROOT}/mindgate-electron"

if [[ ! -d "$ELECTRON_DIR" ]]; then
  log "❌  Directory not found: $ELECTRON_DIR"
  exit 1
fi

log "🔧  Changing to Electron project directory..."
cd "$ELECTRON_DIR"

log "📦  Installing npm dependencies..."
npm install

log "🏗️  Building the project..."
npm run build

log "🚀  Launching MindGate..."
npx electron .

log "✅  MindGate started successfully."