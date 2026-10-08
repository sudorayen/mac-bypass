#!/bin/bash
set -euo pipefail

DMG_URL="https://protonvpn.com/download/macos/6.5.1/ProtonVPN_mac_v6.5.1.dmg"

TMP_DMG="/tmp/ProtonVPN.dmg"
MOUNT_POINT="/Volumes/ProtonVPN"
APP_PATH="/Applications/ProtonVPN.app"

cleanup() {
    if mount | grep -q "on $MOUNT_POINT "; then
        hdiutil detach "$MOUNT_POINT" -quiet 2>/dev/null || true
    fi

    rm -f "$TMP_DMG"
}

trap cleanup EXIT

echo "Downloading Proton VPN..."

curl -L \
    --fail \
    --show-error \
    --retry 3 \
    "$DMG_URL" \
    -o "$TMP_DMG"

echo "Download complete."

echo "Checking DMG..."

if ! hdiutil imageinfo "$TMP_DMG" >/dev/null 2>&1; then
    echo "ERROR: Downloaded file is not a valid DMG."
    exit 1
fi

echo "DMG is valid."

# Make sure an old mount isn't in the way.
if mount | grep -q "on $MOUNT_POINT "; then
    hdiutil detach "$MOUNT_POINT" -quiet || true
fi

echo "Mounting Proton VPN..."

hdiutil attach "$TMP_DMG" -nobrowse -quiet

# Find ProtonVPN.app regardless of the exact DMG layout.
APP_IN_DMG=$(
    find "$MOUNT_POINT" \
        -maxdepth 2 \
        -type d \
        -name "ProtonVPN.app" \
        -print \
        -quit
)

if [ -z "${APP_IN_DMG:-}" ]; then
    echo "ERROR: ProtonVPN.app was not found."
    exit 1
fi

echo "Found ProtonVPN.app."

echo "Installing Proton VPN into /Applications..."

if [ -d "$APP_PATH" ]; then
    echo "Removing existing Proton VPN installation..."
    sudo rm -rf "$APP_PATH"
fi

sudo ditto "$APP_IN_DMG" "$APP_PATH"

if [ ! -d "$APP_PATH" ]; then
    echo "ERROR: Installation failed."
    exit 1
fi

echo "Proton VPN installed."

echo "Adding Proton VPN to Dock..."

DOCK_APPS="$(defaults read com.apple.dock persistent-apps 2>/dev/null || true)"

if ! printf '%s' "$DOCK_APPS" | grep -Fq "/Applications/ProtonVPN.app"; then
    defaults write com.apple.dock persistent-apps -array-add \
    '<dict>
        <key>tile-data</key>
        <dict>
            <key>file-data</key>
            <dict>
                <key>_CFURLString</key>
                <string>/Applications/ProtonVPN.app</string>
                <key>_CFURLStringType</key>
                <integer>0</integer>
            </dict>
        </dict>
    </dict>'

    killall Dock 2>/dev/null || true

    echo "Proton VPN added to Dock."
else
    echo "Proton VPN is already in the Dock."
fi

echo ""
echo "========================================"
echo " Proton VPN installed successfully!"
echo "========================================"
echo ""
echo "Application: /Applications/ProtonVPN.app"
echo "Dock: Proton VPN"
echo ""
