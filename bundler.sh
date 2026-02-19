#!/bin/bash
set -e

APP_NAME="sshhh"
BUILD_DIR=".build/release"
APP_BUNDLE="$APP_NAME.app"
CONTENTS_DIR="$APP_BUNDLE/Contents"
MACOS_DIR="$CONTENTS_DIR/MacOS"
RESOURCES_DIR="$CONTENTS_DIR/Resources"

echo "🚀 Building $APP_NAME for release..."
swift build -c release --arch arm64

echo "📦 Creating App Bundle structure..."
rm -rf "$APP_BUNDLE"
mkdir -p "$MACOS_DIR"
mkdir -p "$RESOURCES_DIR"

# Copy binary
cp "$BUILD_DIR/$APP_NAME" "$MACOS_DIR/"

# Create Info.plist setup
cat > "$CONTENTS_DIR/Info.plist" <<EOF
<?xml version="1.0" encoding="UTF-8"?>
<!DOCTYPE plist PUBLIC "-//Apple//DTD PLIST 1.0//EN" "http://www.apple.com/DTDs/PropertyList-1.0.dtd">
<plist version="1.0">
<dict>
    <key>CFBundleExecutable</key>
    <string>$APP_NAME</string>
    <key>CFBundleIdentifier</key>
    <string>com.sshhh.app</string>
    <key>CFBundleName</key>
    <string>$APP_NAME</string>
    <key>CFBundleIconFile</key>
    <string>AppIcon</string>
    <key>CFBundleShortVersionString</key>
    <string>1.0</string>
    <key>CFBundleVersion</key>
    <string>1</string>
    <key>LSUIElement</key>
    <true/> <!-- Run as agent (menubar app) -->
    <key>NSMicrophoneUsageDescription</key>
    <string>sshhh needs microphone access to record your speech for transcription.</string>
    <key>NSHighResolutionCapable</key>
    <true/>
</dict>
</plist>
EOF

# Copy Icon
if [ -f "sshhh.icns" ]; then
    echo "🎨 Copying AppIcon..."
    cp "sshhh.icns" "$RESOURCES_DIR/AppIcon.icns"
fi

if [ -f "SpeakingIcon.png" ]; then
    echo "🗣️ Copying SpeakingIcon..."
    cp "SpeakingIcon.png" "$RESOURCES_DIR/"
fi

echo "📝 Signing app (ad-hoc)..."
codesign --force --deep --sign - "$APP_BUNDLE"

echo "✅ $APP_NAME.app created successfully!"

# Create DMG
echo "💿 Creating DMG..."
DMG_NAME="$APP_NAME.dmg"
CANVAS_DIR="dmg_canvas"

rm -rf "$CANVAS_DIR" "$DMG_NAME"
mkdir -p "$CANVAS_DIR"

# Copy App to DMG canvas
cp -R "$APP_BUNDLE" "$CANVAS_DIR/"

# Create Applications shortcut
ln -s /Applications "$CANVAS_DIR/Applications"

# Set DMG Icon
if [ -f "sshhh.icns" ]; then
    echo "🎨 Applying icon to DMG volume..."
    cp "sshhh.icns" "$CANVAS_DIR/.VolumeIcon.icns"
    # Set the custom icon flag on the folder
    SetFile -a C "$CANVAS_DIR"
fi

# Create DMG
hdiutil create -volname "$APP_NAME Installer" -srcfolder "$CANVAS_DIR" -ov -format UDZO "$DMG_NAME"

# Set DMG file icon (modern way)
if [ -f "sshhh.icns" ]; then
    echo "🎨 Setting DMG file icon..."
    swift -e 'import AppKit; NSWorkspace.shared.setIcon(NSImage(contentsOfFile: "sshhh.icns"), forFile: "'$DMG_NAME'", options: [])'
fi

# Cleanup
rm -rf "$CANVAS_DIR"

echo "✅ $DMG_NAME created successfully!"
echo "📍 Location: $(pwd)/$DMG_NAME"
