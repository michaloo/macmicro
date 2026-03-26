#!/bin/bash
set -euo pipefail

# Build MacMicro and package it as a macOS .app bundle

SCRIPT_DIR="$(cd "$(dirname "$0")" && pwd)"
PROJECT_DIR="$(dirname "$SCRIPT_DIR")"
BUILD_DIR="$PROJECT_DIR/.build/debug"
APP_DIR="$PROJECT_DIR/build/MacMicro.app"

echo "Building MacMicro..."
cd "$PROJECT_DIR"
swift build

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

# Copy macmicro plugin
mkdir -p "$APP_DIR/Contents/Resources/plugin/macmicro"
cp "$PROJECT_DIR/plugin/macmicro/macmicro.lua" "$APP_DIR/Contents/Resources/plugin/macmicro/"
cp "$PROJECT_DIR/plugin/macmicro/repo.json" "$APP_DIR/Contents/Resources/plugin/macmicro/"

echo "App bundle created at: $APP_DIR"
echo ""
echo "To run:  open $APP_DIR"
echo "To install:  cp -r $APP_DIR /Applications/"
