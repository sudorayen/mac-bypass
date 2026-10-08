#!/bin/bash
set -euo pipefail

# ============================================================
# Proton VPN macOS Installer
#
# Downloads the current stable Proton VPN release from
# Proton's official update feed, verifies the application,
# installs it to /Applications, and adds it to the Dock.
# ============================================================

APP_NAME="ProtonVPN"
APP_PATH="/Applications/ProtonVPN.app"

DMG_PATH="/tmp/ProtonVPN.dmg"
MOUNT_POINT="/tmp/ProtonVPNMount"

# Proton's official Sparkle update feed for macOS.
UPDATE_FEED="https://protonvpn.com/download/macos/updates/v5/sparkle.xml"

# Proton VPN's Apple Developer Team ID.
EXPECTED_TEAM_ID="J6S6Q257EK"

# ------------------------------------------------------------
# Cleanup
# ------------------------------------------------------------

cleanup() {
    if mount | grep -q "on $MOUNT_POINT "; then
        hdiutil detach "$MOUNT_POINT" -quiet 2>/dev/null || true
    fi

    rm -rf "$DMG_PATH" "$MOUNT_POINT"
}

trap cleanup EXIT

rm -rf "$DMG_PATH" "$MOUNT_POINT"
mkdir -p "$MOUNT_POINT"

# ------------------------------------------------------------
# Check requirements
# ------------------------------------------------------------

for command in curl hdiutil find ditto codesign defaults; do
    if ! command -v "$command" >/dev/null 2>&1; then
        echo "ERROR: Required command not found: $command"
        exit 1
    fi
done

# ------------------------------------------------------------
# Find latest stable Proton VPN version
# ------------------------------------------------------------

echo "Checking Proton for the latest stable macOS release..."

FEED=$(curl \
    --fail \
    --silent \
    --show-error \
    --location \
    --retry 3 \
    --connect-timeout 10 \
    "$UPDATE_FEED")

if [ -z "$FEED" ]; then
    echo "ERROR: Could not retrieve Proton's update feed."
    exit 1
fi

# Extract the first non-beta DMG URL.
DMG_URL=$(
    printf '%s\n' "$FEED" |
    grep -oE 'https://[^"]+\.dmg' |
    grep -viE 'beta|early.?access' |
    head -n 1 || true
)

if [ -z "${DMG_URL:-}" ]; then
    echo "ERROR: Could not find a stable Proton VPN DMG in the update feed."
    exit 1
fi

echo "Download URL found:"
echo "$DMG_URL"
echo ""

# ------------------------------------------------------------
# Download
# ------------------------------------------------------------

echo "Downloading Proton VPN..."

curl \
    --fail \
    --silent \
    --show-error \
    --location \
    --retry 3 \
    --connect-timeout 15 \
    "$DMG_URL" \
    -o "$DMG_PATH"

if [ ! -s "$DMG_PATH" ]; then
    echo "ERROR: Proton VPN download is empty."
    exit 1
fi

# ------------------------------------------------------------
# Validate DMG
# ------------------------------------------------------------

echo "Validating DMG..."

if ! hdiutil imageinfo "$DMG_PATH" >/dev/null 2>&1; then
    echo "ERROR: Downloaded file is not a valid macOS disk image."
    exit 1
fi

# ------------------------------------------------------------
# Mount DMG
# ------------------------------------------------------------

echo "Mounting Proton VPN installer..."

hdiutil attach \
    "$DMG_PATH" \
    -mountpoint "$MOUNT_POINT" \
    -nobrowse \
    -readonly \
    -quiet

# ------------------------------------------------------------
# Find application
# ------------------------------------------------------------

APP_IN_DMG=$(
    find "$MOUNT_POINT" \
        -maxdepth 3 \
        -type d \
        -name "ProtonVPN.app" \
        -print \
        -quit
)

if [ -z "${APP_IN_DMG:-}" ]; then
    echo "ERROR: ProtonVPN.app was not found in the official DMG."
    exit 1
fi

echo "Found:"
echo "$APP_IN_DMG"
echo ""

# ------------------------------------------------------------
# Verify Apple code signature
# ------------------------------------------------------------

echo "Verifying Proton VPN code signature..."

if ! codesign \
    --verify \
    --deep \
    --strict \
    "$APP_IN_DMG" >/dev/null 2>&1; then

    echo "ERROR: Code-signature verification failed."
    echo "The application will NOT be installed."
    exit 1
fi

TEAM_ID=$(
    codesign -dv --verbose=4 "$APP_IN_DMG" 2>&1 |
    awk -F= '/^TeamIdentifier=/ {print $2; exit}'
)

if [ "$TEAM_ID" != "$EXPECTED_TEAM_ID" ]; then
    echo "ERROR: Unexpected Apple signing team."
    echo "Expected: $EXPECTED_TEAM_ID"
    echo "Found:    ${TEAM_ID:-unknown}"
    echo "The application will NOT be installed."
    exit 1
fi

echo "Code signature verified."
echo "Team ID: $TEAM_ID"
echo ""

# ------------------------------------------------------------
# Install
# ------------------------------------------------------------

echo "Installing Proton VPN to /Applications..."

if [ -d "$APP_PATH" ]; then
    echo "Removing existing Proton VPN installation..."
    sudo rm -rf "$APP_PATH"
fi

sudo ditto "$APP_IN_DMG" "$APP_PATH"

if [ ! -d "$APP_PATH" ]; then
    echo "ERROR: Proton VPN installation failed."
    exit 1
fi

# Verify the installed copy too.
if ! codesign \
    --verify \
    --deep \
    --strict \
    "$APP_PATH" >/dev/null 2>&1; then

    echo "ERROR: Installed application failed code-signature verification."
    sudo rm -rf "$APP_PATH"
    exit 1
fi

echo "Proton VPN installed successfully."
echo ""

# ------------------------------------------------------------
# Add Proton VPN to Dock
# ------------------------------------------------------------

echo "Adding Proton VPN to the Dock..."

# Check whether Proton VPN is already in the Dock.
if ! defaults read com.apple.dock persistent-apps 2>/dev/null |
    grep -Fq "/Applications/ProtonVPN.app"; then

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

    echo "Proton VPN added to Dock."
else
    echo "Proton VPN is already in the Dock."
fi

# Refresh Dock.
killall Dock 2>/dev/null || true

# ------------------------------------------------------------
# Finished
# ------------------------------------------------------------

echo ""
echo "================================================"
echo " Proton VPN installation complete!"
echo "================================================"
echo ""
echo "Installed:"
echo "  $APP_PATH"
echo ""
echo "The application has been added to your Dock."
echo ""
