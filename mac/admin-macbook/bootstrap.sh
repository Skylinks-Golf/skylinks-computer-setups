#!/usr/bin/env bash
#
# Skylinks Admin MacBook Bootstrap
#
# Downloads setup.sh + Brewfile and hands off to setup.sh. This exists so the
# Flipper payload is a single typed line instead of a timing-sensitive sequence.
#
# Run it with:
#   bash -c "$(curl -fsSL <raw-url-to-this-file>)"
#
# Note the $(...) form rather than a pipe: it keeps stdin attached to the
# terminal so setup.sh can prompt for the admin password.
#
# Override the ref for branch testing:
#   SKYLINKS_SETUP_REF=feature/skylinks-admin-macbook-setup bash -c "$(curl ...)"

set -euo pipefail

# Ref the setup files are fetched from. Point this at an immutable release tag
# (e.g. mac-setup-v1) before rolling this out to machines, and update the
# Flipper payload URL to the same tag in the same commit.
SKYLINKS_SETUP_REF="${SKYLINKS_SETUP_REF:-master}"

REPO_RAW="https://raw.githubusercontent.com/Skylinks-Golf/skylinks-computer-setups"
BASE_URL="$REPO_RAW/$SKYLINKS_SETUP_REF/mac/admin-macbook"
SETUP_DIR="$HOME/Skylinks-Setup"

echo "Skylinks MacBook bootstrap"
echo "Source ref: $SKYLINKS_SETUP_REF"
echo

mkdir -p "$SETUP_DIR"
cd "$SETUP_DIR"

echo "Downloading setup files..."
curl -fsSL --max-time 60 -o "$SETUP_DIR/setup.sh"  "$BASE_URL/setup.sh"
curl -fsSL --max-time 60 -o "$SETUP_DIR/Brewfile" "$BASE_URL/Brewfile"
chmod +x "$SETUP_DIR/setup.sh"

echo "Downloaded:"
ls -la "$SETUP_DIR/setup.sh" "$SETUP_DIR/Brewfile"
echo

echo "Starting setup..."
echo
exec "$SETUP_DIR/setup.sh"
