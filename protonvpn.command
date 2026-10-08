#!/bin/bash
set -euo pipefail

# Proton VPN official macOS DMG
DMG_URL="https://protonvpn.com/download/macos/6.5.1/ProtonVPN_mac_v6.5.1.dmg"

TMP_DIR="$(mktemp -d /tmp/protonvpn.XXXXXX)"
DMG_PATH="$TMP_DIR/ProtonVPN.dmg"
MOUNT_POINT="$TMP_DIR/mount"
APP_PATH="/Applications/ProtonVPN.app"

cleanup() {
    hdiutil detach "$MOUNT_POINT" -quiet 2>/dev/null || true
    rm -rf "$TMP_DIR"
}

trap cleanup EXIT

echo "Downloading Proton VPN..."

curl \
    --fail \
    --location \
    --silent \
    --show-error \
    --retry 3 \
    --connect-timeout 15 \
    "$DMG_URL" \
    -o "$DMG_PATH"

echo "Download complete."

# Verify the DMG
if ! hdiutil imageinfo "$DMG_PATH" >/dev/null 2>&1; then
    echo "ERROR: Downloaded file is not a valid DMG."
    exit 1
fi

mkdir -p "$MOUNT_POINT"

echo "Mounting Proton VPN..."

hdiutil attach \
    "$DMG_PATH" \
    -mountpoint "$MOUNT_POINT" \
    -nobrowse \
    -readonly \
    -quiet

# Find ProtonVPN.app
APP_IN_DMG=$(
    find "$MOUNT_POINT" \
        -maxdepth 3 \
        -type d \
        -name "ProtonVPN.app" \
        -print \
        -quit
)

if [ -z "${APP_IN_DMG:-}" ]; then
    echo "ERROR: ProtonVPN.app was not found in the DMG."
    exit 1
fi

echo "Found ProtonVPN.app."

# Install
echo "Installing Proton VPN into /Applications..."

if [ -d "$APP_PATH" ]; then
    echo "Removing existing Proton VPN..."
    sudo rm -rf "$APP_PATH"
fi

sudo ditto "$APP_IN_DMG" "$APP_PATH"

if [ ! -d "$APP_PATH" ]; then
    echo "ERROR: Installation failed."
    exit 1
fi

echo "Installation complete."

# Add to Dock
echo "Adding Proton VPN to the Dock..."

DOCK_APPS="$(defaults read com.apple.dock persistent-apps 2>/dev/null || true)"

if ! printf '%s' "$DOCK_APPS" | grep -Fq "/Applications/ProtonVPN.app"; then
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

    echo "Added Proton VPN to the Dock."
else
    echo "Proton VPN is already in the Dock."
fi

killall Dock 2>/dev/null || true

echo
echo "======================================"
echo " Proton VPN installed successfully!"
echo "======================================"
echo
echo "Location: /Applications/ProtonVPN.app"
echo "Dock:     Proton VPN added"
