#!/bin/bash
set -euo pipefail

DOWNLOAD_PAGE="https://protonvpn.com/download-macos"
TMP_DMG="/tmp/ProtonVPN.dmg"
MOUNT_POINT="/tmp/ProtonVPNMount"
APP_PATH="/Applications/ProtonVPN.app"

echo "Downloading the latest Proton VPN for macOS..."

# Get Proton's official download page and extract the DMG URL.
DMG_URL=$(
    curl -L --fail --silent --show-error "$DOWNLOAD_PAGE" |
    grep -oE 'https?[^"'\'' ]+\.dmg' |
    head -n 1
)

if [ -z "${DMG_URL:-}" ]; then
    echo "ERROR: Could not find the Proton VPN DMG download URL."
    exit 1
fi

echo "Downloading:"
echo "$DMG_URL"

curl -L --fail --show-error "$DMG_URL" -o "$TMP_DMG"

# Make sure the download is actually a DMG.
if ! hdiutil imageinfo "$TMP_DMG" >/dev/null 2>&1; then
    echo "ERROR: Downloaded file is not a valid DMG."
    rm -f "$TMP_DMG"
    exit 1
fi

# Clean up old mount point.
rm -rf "$MOUNT_POINT"
mkdir -p "$MOUNT_POINT"

echo "Mounting Proton VPN..."

hdiutil attach "$TMP_DMG" \
    -mountpoint "$MOUNT_POINT" \
    -nobrowse \
    -quiet

cleanup() {
    hdiutil detach "$MOUNT_POINT" -quiet || true
    rm -rf "$TMP_DMG" "$MOUNT_POINT"
}

trap cleanup EXIT

# Find ProtonVPN.app inside the mounted DMG.
APP_IN_DMG=$(
    find "$MOUNT_POINT" \
        -maxdepth 2 \
        -name "ProtonVPN.app" \
        -type d \
        -print -quit
)

if [ -z "${APP_IN_DMG:-}" ]; then
    echo "ERROR: ProtonVPN.app was not found in the DMG."
    exit 1
fi

echo "Installing Proton VPN into /Applications..."

# Remove an existing installation.
sudo rm -rf "$APP_PATH"

# Copy the new application.
sudo cp -R "$APP_IN_DMG" "$APP_PATH"

# Make sure the application is readable.
sudo chmod -R a+rX "$APP_PATH"

echo "Adding Proton VPN to the Dock..."

# Remove an existing Proton VPN Dock entry, if present.
defaults read com.apple.dock persistent-apps 2>/dev/null |
    grep -q "/Applications/ProtonVPN.app" && \
    defaults delete com.apple.dock persistent-apps 2>/dev/null || true

# Add Proton VPN to the Dock.
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

killall Dock 2>/dev/null || true

echo ""
echo "======================================"
echo " Proton VPN installed successfully!"
echo "======================================"
echo ""
echo "Application: $APP_PATH"
echo "Proton VPN has also been added to the Dock."