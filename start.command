#!/bin/bash

# MindGate Launcher Script
# This script builds and runs MindGate

cd "$(dirname "$0")"

echo "🚀 Building MindGate..."
swift build

if [ $? -eq 0 ]; then
    echo "✅ Build successful!"
    echo "🧠 Starting MindGate..."
    echo "Press Ctrl+C to stop"
    echo "----------------------------------------"
    swift run
    echo "----------------------------------------"
    echo "MindGate stopped"
else
    echo "❌ Build failed. Please check the errors above."
fi

read -p "Press any key to exit..."
