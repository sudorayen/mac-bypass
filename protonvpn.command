#!/bin/bash
set -euo pipefail

APP_NAME="ProtonVPN"
APP_PATH="/Applications/ProtonVPN.app"

TMP_DIR="$(mktemp -d /tmp/protonvpn.XXXXXX)"
DMG_PATH="$TMP_DIR/ProtonVPN.dmg"
MOUNT_POINT="$TMP_DIR/mount"

# Proton's official macOS download page.
DOWNLOAD_URL="https://protonvpn.com/download/macos"

cleanup() {
    if mount | grep -q "on $MOUNT_POINT "; then
        hdiutil detach "$MOUNT_POINT" -quiet 2>/dev/null || true
    fi

    rm -rf "$TMP_DIR"
}

trap cleanup EXIT

echo "Downloading the latest Proton VPN for macOS..."

mkdir -p "$MOUNT_POINT"

# Follow Proton's redirects.
curl \
    --fail \
    --location \
    --silent \
    --show-error \
    --retry 3 \
    --connect-timeout 15 \
    --output "$DMG_PATH" \
    "$DOWNLOAD_URL"

echo "Download complete."

# Make sure the result is actually a DMG.
if ! hdiutil imageinfo "$DMG_PATH" >/dev/null 2>&1; then
    echo "ERROR: Proton did not return a valid DMG."
    exit 1
fi

echo "Mounting Proton VPN..."

hdiutil attach \
    "$DMG_PATH" \
    -mountpoint "$MOUNT_POINT" \
    -nobrowse \
    -readonly \
    -quiet

# Locate ProtonVPN.app.
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

# Verify Apple's code signature before installing.
echo "Verifying Proton VPN..."

if ! codesign --verify --deep --strict "$APP_IN_DMG" >/dev/null 2>&1; then
    echo "ERROR: Proton VPN failed code-signature verification."
    exit 1
fi

echo "Signature verified."

# Install into Applications.
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

echo "Installed successfully."

# ------------------------------------------------------------
# Dock
# ------------------------------------------------------------

echo "Adding Proton VPN to the Dock..."

# Only add it if it isn't already there.
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
echo " Proton VPN installation complete!"
echo "======================================"
echo
echo "Installed: $APP_PATH"
echo "Dock:      Added"
