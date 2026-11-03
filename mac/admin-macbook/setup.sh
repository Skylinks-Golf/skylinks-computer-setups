#!/usr/bin/env bash
#
# Skylinks Admin MacBook Setup
#
# Installs the baseline app package for location-level Skylinks admin/manager
# MacBooks. Intended to be run with an operator physically present at the
# machine: it will trigger macOS password and permission prompts.
#
# Safe to re-run. Homebrew skips anything already installed.
#
# Written for macOS's stock bash 3.2 — do not use bash 4+ syntax here.

set -euo pipefail

SETUP_DIR="$HOME/Skylinks-Setup"
BREWFILE="$SETUP_DIR/Brewfile"
LOG="$SETUP_DIR/setup-$(date +%Y%m%d-%H%M%S).log"

mkdir -p "$SETUP_DIR"
cd "$SETUP_DIR"

# Mirror everything to a log so an on-site failure is diagnosable later.
exec > >(tee -a "$LOG") 2>&1

# Tracks non-fatal problems so the run always reaches the manual checklist.
BUNDLE_FAILED=0

echo "======================================"
echo " Skylinks Admin MacBook Setup"
echo "======================================"
echo
echo "Setup directory: $SETUP_DIR"
echo "Log file:        $LOG"
echo

# ---------------------------------------------------------------------------
# Preflight
# ---------------------------------------------------------------------------

if [[ ! -f "$BREWFILE" ]]; then
  echo "ERROR: Brewfile not found at $BREWFILE"
  echo "Make sure the bootstrap downloaded both setup.sh and Brewfile."
  exit 1
fi

echo "Checking network access..."
if ! curl -fsSL --head --max-time 15 https://brew.sh >/dev/null 2>&1; then
  echo "ERROR: Could not reach brew.sh."
  echo "Check the Wi-Fi/internet connection, then re-run:"
  echo "  cd \"$SETUP_DIR\" && ./setup.sh"
  exit 1
fi
echo "Network check passed."
echo

# Ask for the admin password now, at a predictable moment, rather than several
# minutes into the run buried in Homebrew output. Cask installs need it.
echo "This setup needs the Mac admin password to install applications."
echo "Enter it at the prompt below (nothing is stored or transmitted)."
echo
sudo -v

# Keep the sudo timestamp warm for the duration so the prompt does not
# reappear mid-install.
while true; do
  sudo -n true 2>/dev/null || exit
  sleep 60
  kill -0 "$$" 2>/dev/null || exit
done &
SUDO_KEEPALIVE_PID=$!
trap 'kill "$SUDO_KEEPALIVE_PID" 2>/dev/null || true' EXIT

echo
echo "Admin access confirmed."
echo

# ---------------------------------------------------------------------------
# Homebrew
#
# The Homebrew installer takes care of the Xcode Command Line Tools itself,
# so there is deliberately no separate xcode-select step here.
# ---------------------------------------------------------------------------

if ! command -v brew >/dev/null 2>&1; then
  echo "Homebrew not found. Installing Homebrew..."
  echo "This also installs the Xcode Command Line Tools and may take a while."
  echo
  NONINTERACTIVE=1 /bin/bash -c \
    "$(curl -fsSL https://raw.githubusercontent.com/Homebrew/install/HEAD/install.sh)"
else
  echo "Homebrew already installed."
fi

# Load Homebrew into this shell.
if [[ -x /opt/homebrew/bin/brew ]]; then
  BREW_BIN="/opt/homebrew/bin/brew"
elif [[ -x /usr/local/bin/brew ]]; then
  BREW_BIN="/usr/local/bin/brew"
else
  echo "ERROR: Homebrew appears to be installed, but the brew binary was not found."
  echo "Expected /opt/homebrew/bin/brew or /usr/local/bin/brew."
  exit 1
fi
eval "$("$BREW_BIN" shellenv)"

# Persist it for future Terminal sessions. Without this, brew is missing from
# PATH in every new shell on Apple Silicon.
SHELLENV_LINE="eval \"\$($BREW_BIN shellenv)\""
for PROFILE in "$HOME/.zprofile" "$HOME/.bash_profile"; do
  if [[ -f "$PROFILE" ]] || [[ "$PROFILE" == "$HOME/.zprofile" ]]; then
    touch "$PROFILE"
    if ! grep -qF "$BREW_BIN shellenv" "$PROFILE" 2>/dev/null; then
      printf '\n# Homebrew (added by Skylinks setup)\n%s\n' "$SHELLENV_LINE" >> "$PROFILE"
      echo "Added Homebrew to PATH in $PROFILE"
    fi
  fi
done

echo
echo "Homebrew version:"
brew --version
echo

# ---------------------------------------------------------------------------
# Applications
# ---------------------------------------------------------------------------

echo "Installing Skylinks baseline apps from Brewfile..."
echo

# Never let a single failed cask abort the run — the manual checklist printed
# at the end is the most useful part of this script.
if brew bundle --file="$BREWFILE"; then
  echo
  echo "All baseline apps installed."
else
  BUNDLE_FAILED=1
  echo
  echo "WARNING: One or more apps failed to install. Details are in the log:"
  echo "  $LOG"
  echo "Continuing so the manual checklist is still shown."
fi

echo
echo "Opening Google Chrome..."
echo "Chrome will offer to make itself the default browser — accept that prompt."
echo "(macOS no longer allows a script to change the default browser silently.)"

if [[ -d "/Applications/Google Chrome.app" ]]; then
  open -a "Google Chrome" || true
else
  echo "Google Chrome not found in /Applications. Skipping."
fi

# ---------------------------------------------------------------------------
# Security posture report
#
# Read-only. This changes nothing — it reports what a human still needs to fix
# so the security items cannot be silently skipped on the checklist.
# ---------------------------------------------------------------------------

echo
echo "======================================"
echo " Security posture (report only)"
echo "======================================"
echo

FILEVAULT_STATUS="$(fdesetup status 2>/dev/null || echo 'unknown')"
if echo "$FILEVAULT_STATUS" | grep -q "FileVault is On"; then
  echo "[ OK    ] FileVault is on."
else
  echo "[ ACTION] FileVault is NOT on: $FILEVAULT_STATUS"
  echo "          Enable it: System Settings > Privacy & Security > FileVault"
fi

AUTO_CHECK="$(defaults read /Library/Preferences/com.apple.SoftwareUpdate AutomaticCheckEnabled 2>/dev/null || echo 0)"
if [[ "$AUTO_CHECK" == "1" ]]; then
  echo "[ OK    ] Automatic update checks are enabled."
else
  echo "[ ACTION] Automatic update checks are OFF."
  echo "          Enable them: System Settings > General > Software Update > (i)"
fi

SCREEN_LOCK="$(sysadminctl -screenLock status 2>&1 || true)"
if echo "$SCREEN_LOCK" | grep -qi "screenLock is off"; then
  echo "[ ACTION] Password is NOT required after sleep/screensaver."
  echo "          Enable it: System Settings > Lock Screen"
elif echo "$SCREEN_LOCK" | grep -qi "screenLock delay is"; then
  echo "[ OK    ] Password is required after sleep/screensaver."
else
  echo "[ CHECK ] Could not read the screen lock setting. Verify manually:"
  echo "          System Settings > Lock Screen"
fi

echo
echo "Computer name: $(scutil --get ComputerName 2>/dev/null || echo 'unknown')"
echo "          Set a clear name: System Settings > General > About"

# ---------------------------------------------------------------------------
# Manual steps
# ---------------------------------------------------------------------------

echo
echo "======================================"
if [[ "$BUNDLE_FAILED" -eq 1 ]]; then
  echo " Install finished WITH ERRORS"
else
  echo " Install complete"
fi
echo "======================================"
echo
echo "Manual next steps:"
echo
echo "1. Sign into Chrome with the Skylinks Google account."
echo "2. Confirm Chrome is the default browser."
echo "3. Sign into Google Drive."
echo "4. Sign into Notion and select the Skylinks Golf workspace."
echo "5. Sign into Slack."
echo "6. Sign into Claude."
echo "7. Sign into Zoom."
echo
echo "macOS permissions to grant:"
echo "- Zoom: Camera, Microphone, Screen Recording"
echo "- Google Drive: Files & Folders"
echo "- Slack: Notifications"
echo "- Notion: Notifications"
echo "- Chrome: Notifications if needed"
echo
echo "Validation checks:"
echo "- Chrome opens and is signed into the correct Skylinks profile."
echo "- Chrome is set as default browser."
echo "- Google Drive is syncing."
echo "- Notion opens the Skylinks Golf workspace."
echo "- Slack opens the Skylinks workspace."
echo "- Claude launches successfully."
echo "- Zoom launches and has camera/mic/screen permissions."
echo
echo "Resolve anything marked [ ACTION ] in the security section above."
echo
echo "Full checklist: post-install-checklist.md in the repo."
echo "Setup files and logs are saved in: $SETUP_DIR"
echo

if [[ "$BUNDLE_FAILED" -eq 1 ]]; then
  exit 1
fi
