#!/bin/bash
set -euo pipefail

# Proton VPN official macOS download endpoint
DMG_URL="https://protonvpn.com/download/macos"

TMP_DMG="/tmp/ProtonVPN.dmg"
MOUNT_POINT="/tmp/ProtonVPNMount"
APP_PATH="/Applications/ProtonVPN.app"

echo "Downloading Proton VPN from Proton..."

# Clean up previous files
rm -rf "$TMP_DMG" "$MOUNT_POINT"
mkdir -p "$MOUNT_POINT"

# Download the current Proton VPN macOS installer
curl -L --fail --show-error \
    -A "Mozilla/5.0 (Macintosh; Intel Mac OS X)" \
    "$DMG_URL" \
    -o "$TMP_DMG"

# Make sure it is actually a DMG
if ! hdiutil imageinfo "$TMP_DMG" >/dev/null 2>&1; then
    echo "ERROR: Downloaded file is not a valid DMG."
    exit 1
fi

echo "Mounting Proton VPN installer..."

hdiutil attach "$TMP_DMG" \
    -mountpoint "$MOUNT_POINT" \
    -nobrowse \
    -quiet

# Always clean up when the script exits
cleanup() {
    hdiutil detach "$MOUNT_POINT" -quiet 2>/dev/null || true
    rm -rf "$TMP_DMG" "$MOUNT_POINT"
}

trap cleanup EXIT

# Find the application inside the DMG
APP_IN_DMG=$(
    find "$MOUNT_POINT" \
        -maxdepth 3 \
        -name "ProtonVPN.app" \
        -type d \
        -print -quit
)

if [ -z "${APP_IN_DMG:-}" ]; then
    echo "ERROR: ProtonVPN.app was not found in the DMG."
    exit 1
fi

echo "Installing Proton VPN into /Applications..."

# Remove existing Proton VPN installation
if [ -d "$APP_PATH" ]; then
    sudo rm -rf "$APP_PATH"
fi

# Copy Proton VPN to Applications
sudo cp -R "$APP_IN_DMG" "$APP_PATH"

echo "Adding Proton VPN to the Dock..."

# Add Proton VPN to the Dock
defaults write com.apple.dock persistent-apps -array-add \
"<dict>
    <key>tile-data</key>
    <dict>
        <key>file-data</key>
        <dict>
            <key>_CFURLString</key>
            <string>$APP_PATH</string>
            <key>_CFURLStringType</key>
            <integer>0</integer>
        </dict>
    </dict>
</dict>"

# Restart Dock
killall Dock 2>/dev/null || true

echo ""
echo "========================================"
echo " Proton VPN installed successfully!"
echo "========================================"
echo ""
echo "Installed to: $APP_PATH"
echo "Added to Dock."
