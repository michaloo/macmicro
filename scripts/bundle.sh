#!/bin/bash
set -euo pipefail

# Build MacMicro and package it as a macOS .app bundle

SCRIPT_DIR="$(cd "$(dirname "$0")" && pwd)"
PROJECT_DIR="$(dirname "$SCRIPT_DIR")"
CONFIG="${1:-debug}"
BUILD_DIR="$PROJECT_DIR/.build/$CONFIG"
APP_DIR="$PROJECT_DIR/build/MacMicro.app"

echo "Building MacMicro ($CONFIG)..."
cd "$PROJECT_DIR"
swift build -c "$CONFIG"
swift build -c "$CONFIG" --target macmicro-cli

echo "Creating app bundle..."
rm -rf "$APP_DIR"
mkdir -p "$APP_DIR/Contents/MacOS"
mkdir -p "$APP_DIR/Contents/Resources"

# Copy executable
cp "$BUILD_DIR/MacMicro" "$APP_DIR/Contents/MacOS/MacMicro"

# Copy Info.plist
cp "$PROJECT_DIR/Sources/Resources/Info.plist" "$APP_DIR/Contents/Info.plist"

# Copy app icon
cp "$PROJECT_DIR/assets/MacMicro.icns" "$APP_DIR/Contents/Resources/MacMicro.icns"

# Copy CLI tool
mkdir -p "$APP_DIR/Contents/SharedSupport/bin"
cp "$BUILD_DIR/macmicro-cli" "$APP_DIR/Contents/SharedSupport/bin/macmicro"

# Copy macmicro plugin
mkdir -p "$APP_DIR/Contents/Resources/plugin/macmicro"
cp "$PROJECT_DIR/plugin/macmicro/macmicro.lua" "$APP_DIR/Contents/Resources/plugin/macmicro/"
cp "$PROJECT_DIR/plugin/macmicro/repo.json" "$APP_DIR/Contents/Resources/plugin/macmicro/"

echo "App bundle created at: $APP_DIR"
echo ""
echo "To run:  open $APP_DIR"
echo "To install:  cp -r $APP_DIR /Applications/"
echo "To install CLI:  ln -sf $APP_DIR/Contents/SharedSupport/bin/macmicro /usr/local/bin/macmicro"
