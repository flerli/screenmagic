#!/bin/bash

# Build script for ScreenMagic

set -e

echo "Building ScreenMagic..."

cd "$(dirname "$0")"

# Build with Swift Package Manager
swift build -c release

# Create app bundle structure
APP_NAME="ScreenMagic"
APP_BUNDLE="$APP_NAME.app"
BUILD_DIR=".build/release"
BUNDLE_DIR="build/$APP_BUNDLE"

rm -rf "build"
mkdir -p "$BUNDLE_DIR/Contents/MacOS"
mkdir -p "$BUNDLE_DIR/Contents/Resources"

# Generate app icon
echo "Generating app icon..."
swift Scripts/generate_icon.swift
iconutil -c icns -o "$BUNDLE_DIR/Contents/Resources/AppIcon.icns" build/AppIcon.iconset
rm -rf build/AppIcon.iconset

# Copy executable
cp "$BUILD_DIR/$APP_NAME" "$BUNDLE_DIR/Contents/MacOS/"

# Copy Info.plist
cp "Resources/Info.plist" "$BUNDLE_DIR/Contents/"

# Copy entitlements
cp "Resources/ScreenMagic.entitlements" "$BUNDLE_DIR/Contents/Resources/"

echo "Build complete: build/$APP_BUNDLE"
echo ""
echo "To run the app:"
echo "  open build/ScreenMagic.app"
echo ""
echo "To install to Applications:"
echo "  cp -r build/ScreenMagic.app /Applications/"
