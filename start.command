#!/bin/bash

# MindGate Launcher Script
# This script builds and runs MindGate

cd "$(dirname "$0")"

echo "🚀 Building MindGate..."
swift build

if [ $? -eq 0 ]; then
    echo "✅ Build successful!"
    echo "🧠 Starting MindGate..."
    swift run
else
    echo "❌ Build failed. Please check the errors above."
    read -p "Press any key to exit..."
fi
