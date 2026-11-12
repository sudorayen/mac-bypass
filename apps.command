#!/bin/bash
# nuke-managed-prefs.command
# deletes the managed preference plists, then locks the dir with schg

set -euo pipefail

MANAGED="/Library/Managed Preferences"
USER_DIR="$MANAGED/$USER"

FILES=(
  "$MANAGED/com.apple.appstore.plist"
  "$MANAGED/com.apple.applicationaccess.plist"
  "$MANAGED/com.apple.applicationaccess.new.plist"
  "$MANAGED/.GlobalPreferences.plist"
  "$USER_DIR/com.apple.appstore.plist"
  "$USER_DIR/com.apple.applicationaccess.plist"
  "$USER_DIR/com.apple.applicationaccess.new.plist"
  "$USER_DIR/complete.plist"
)

sudo -v   # prompt once, cache creds

for f in "${FILES[@]}"; do
  if [ -e "$f" ]; then
    sudo rm -f "$f" && echo "removed: $f"
  else
    echo "absent:  $f"
  fi
done

# lock the whole managed preferences dir
sudo chflags schg "$MANAGED"
echo "locked: $MANAGED (schg)"

# to undo later:
# sudo chflags noschg "$MANAGED"
