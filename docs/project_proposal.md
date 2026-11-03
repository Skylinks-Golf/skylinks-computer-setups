Citadel Build Brief: Skylinks Admin MacBook Setup Script
Goal
Build a boring, stable, repeatable setup workflow for provisioning Skylinks admin/manager MacBooks.
This should live in the existing public repo:
https://github.com/Skylinks-Golf/skylinks-scripts.git
​
Cut a new branch from main, build the setup files there, then submit for review.
Core philosophy
The more boring, the more stable.
Do not turn this into MDM, account provisioning, role-based setup, or a full internal tooling platform.
The v1 scope is:
Flipper Zero BadUSB opens Terminal
→ downloads setup.sh + Brewfile
→ runs setup.sh
→ setup.sh installs baseline apps
→ Ian completes manual sign-ins/checklist
​
That’s it.
Locked decisions
Decision
Final answer
Repo
https://github.com/Skylinks-Golf/skylinks-scripts.git
Repo status
Existing repo, not empty
Branching
Cut new branch from main
Repo visibility
Public
GitHub org path for raw URLs
Skylinks-Golf/skylinks-scripts
GitHub user/org note
skylinks-golf/ian-skylinks
Google Drive
Install by default
Chrome default browser
Yes, attempt to set Chrome as default
Microsoft Office
Excluded
QoL apps
Excluded
Developer tooling
Excluded
Local Skylinks Admin folder structure
Excluded
Bookmarks
Checklist item only
Flipper payload name
skylinks_admin_mac_install.txt
BadUSB style
“Better BadUSB payload with pauses”
Operator model
Ian physically holds and supervises laptop
Proposed repo layout
Inside the existing skylinks-scripts repo, create a focused subdirectory:
macbook-setup/
├── README.md
├── Brewfile
├── setup.sh
├── post-install-checklist.md
└── flipper/
    └── skylinks_admin_mac_install.txt
​
Why a subdirectory? Because the repo already exists and likely contains other scripts. This keeps the MacBook setup package isolated, easy to find, and hard to confuse with unrelated scripts.
Branch
Suggested branch name:
feature/skylinks-admin-macbook-setup
​
Alternative shorter option:
admin-macbook-setup
​
I’d use the first one because it’s self-explanatory.
Raw GitHub URLs
Assuming files land under macbook-setup/ on main, the final raw URLs should be:
https://raw.githubusercontent.com/Skylinks-Golf/skylinks-scripts/main/macbook-setup/setup.sh
https://raw.githubusercontent.com/Skylinks-Golf/skylinks-scripts/main/macbook-setup/Brewfile
​
During branch testing, use:
https://raw.githubusercontent.com/Skylinks-Golf/skylinks-scripts/feature/skylinks-admin-macbook-setup/macbook-setup/setup.sh
https://raw.githubusercontent.com/Skylinks-Golf/skylinks-scripts/feature/skylinks-admin-macbook-setup/macbook-setup/Brewfile
​
Important: the Flipper payload in the branch can initially point to the branch URLs for testing. Before merging or after merge, update it to point to main.
Files to build
1. macbook-setup/Brewfile
# Brewfile — Skylinks Admin MacBook baseline
# Purpose: Standard app package for location-level Skylinks admin/manager MacBooks.
#
# Keep this boring and stable.
# Microsoft Office is intentionally excluded.
# Quality-of-life apps are intentionally excluded.
# Developer tooling is intentionally excluded.

cask_args appdir: "/Applications"

# Core browser / workspace
cask "google-chrome"

# Skylinks core apps
cask "notion"
cask "slack"
cask "zoom"
cask "google-drive"

# AI assistant
cask "claude"

# Optional helper for Mac App Store installs
brew "mas"
​
No Office. No Rectangle. No dev stack. No “maybe later” commented install lines.
2. macbook-setup/setup.sh
#!/usr/bin/env bash
set -euo pipefail

echo "======================================"
echo " Skylinks Admin MacBook Setup"
echo "======================================"
echo

SETUP_DIR="$HOME/Skylinks-Setup"
BREWFILE="$SETUP_DIR/Brewfile"

mkdir -p "$SETUP_DIR"
cd "$SETUP_DIR"

echo "Setup directory: $SETUP_DIR"
echo

# Confirm Brewfile exists
if [[ ! -f "$BREWFILE" ]]; then
  echo "ERROR: Brewfile not found at $BREWFILE"
  echo "Make sure the Flipper/bootstrap downloaded both setup.sh and Brewfile."
  exit 1
fi

# Confirm network access before deeper install steps
echo "Checking network access..."
if ! curl -fsSL --head https://brew.sh >/dev/null 2>&1; then
  echo "ERROR: Could not reach brew.sh."
  echo "Check Wi-Fi/internet connection, then re-run:"
  echo "cd \"$SETUP_DIR\" && ./setup.sh"
  exit 1
fi

echo "Network check passed."
echo

# Install Xcode Command Line Tools if missing
if ! xcode-select -p >/dev/null 2>&1; then
  echo "Xcode Command Line Tools not found."
  echo "macOS will open an installer prompt."
  echo
  echo "Complete the install, then re-run:"
  echo "cd \"$SETUP_DIR\" && ./setup.sh"
  echo
  xcode-select --install || true
  exit 0
fi

echo "Xcode Command Line Tools found."
echo

# Install Homebrew if missing
if ! command -v brew >/dev/null 2>&1; then
  echo "Homebrew not found. Installing Homebrew..."
  echo "You may be prompted for the Mac admin password."
  echo
  /bin/bash -c "$(curl -fsSL https://raw.githubusercontent.com/Homebrew/install/HEAD/install.sh)"
else
  echo "Homebrew already installed."
fi

# Load Homebrew into PATH
if [[ -x /opt/homebrew/bin/brew ]]; then
  eval "$(/opt/homebrew/bin/brew shellenv)"
elif [[ -x /usr/local/bin/brew ]]; then
  eval "$(/usr/local/bin/brew shellenv)"
else
  echo "ERROR: Homebrew appears to be installed, but brew binary was not found."
  echo "Expected /opt/homebrew/bin/brew or /usr/local/bin/brew."
  exit 1
fi

echo
echo "Homebrew version:"
brew --version
echo

echo "Updating Homebrew..."
brew update

echo
echo "Installing Skylinks baseline apps from Brewfile..."
brew bundle --file="$BREWFILE"

echo
echo "Attempting to set Google Chrome as the default browser..."
echo "macOS may ask for confirmation or may ignore this depending on version."

if [[ -d "/Applications/Google Chrome.app" ]]; then
  open -a "Google Chrome" --args --make-default-browser >/dev/null 2>&1 || true
else
  echo "Google Chrome app not found in /Applications. Skipping default browser attempt."
fi

echo
echo "======================================"
echo " Install complete"
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
echo "Setup files are saved in:"
echo "$SETUP_DIR"
echo
​
Note on setting Chrome as default
The script should attempt it, but the Citadel agent should treat this as best effort, not guaranteed. macOS may require user confirmation or block silent default-browser changes depending on version/security state.
That’s fine. The checklist still includes manual confirmation.
3. macbook-setup/flipper/skylinks_admin_mac_install.txt
Use branch URLs while testing.
ID 05AC:024F Apple:Keyboard
DELAY 2500

REM Open Spotlight
GUI SPACE
DELAY 700
STRING Terminal
DELAY 500
ENTER
DELAY 2000

REM Create setup directory
STRING mkdir -p ~/Skylinks-Setup
ENTER
DELAY 300

STRING cd ~/Skylinks-Setup
ENTER
DELAY 300

REM Download setup files
STRING curl -fsSL -o setup.sh "https://raw.githubusercontent.com/Skylinks-Golf/skylinks-scripts/feature/skylinks-admin-macbook-setup/macbook-setup/setup.sh"
ENTER
DELAY 800

STRING curl -fsSL -o Brewfile "https://raw.githubusercontent.com/Skylinks-Golf/skylinks-scripts/feature/skylinks-admin-macbook-setup/macbook-setup/Brewfile"
ENTER
DELAY 800

REM Make installer executable
STRING chmod +x setup.sh
ENTER
DELAY 300

REM Show downloaded files
STRING ls -la
ENTER
DELAY 500

REM Run installer
STRING ./setup.sh
ENTER
​
After merge to main, update those two URL lines to:
STRING curl -fsSL -o setup.sh "https://raw.githubusercontent.com/Skylinks-Golf/skylinks-scripts/main/macbook-setup/setup.sh"
​
STRING curl -fsSL -o Brewfile "https://raw.githubusercontent.com/Skylinks-Golf/skylinks-scripts/main/macbook-setup/Brewfile"
​
4. macbook-setup/post-install-checklist.md
# Skylinks Admin MacBook — Post-Install Checklist

## App sign-ins

- [ ] Chrome signed into Skylinks Google account
- [ ] Google Drive signed in and syncing
- [ ] Notion signed into Skylinks Golf workspace
- [ ] Slack signed into Skylinks workspace
- [ ] Claude signed in
- [ ] Zoom signed in

## macOS permissions

- [ ] Zoom Camera permission granted
- [ ] Zoom Microphone permission granted
- [ ] Zoom Screen Recording permission granted
- [ ] Google Drive Files & Folders permission granted
- [ ] Slack notifications enabled
- [ ] Notion notifications enabled
- [ ] Chrome notifications configured as needed

## Browser setup

- [ ] Chrome set as default browser
- [ ] Skylinks Admin bookmark folder created manually if needed
- [ ] Google Workspace shortcuts added if needed
- [ ] Notion workspace bookmarked if needed
- [ ] Airtable bookmarked if needed
- [ ] Lightspeed bookmarked if needed
- [ ] Slack web fallback bookmarked if needed
- [ ] Zoom web portal bookmarked if needed

## Device settings

- [ ] Computer name set clearly
- [ ] macOS updates checked
- [ ] Automatic updates enabled
- [ ] FileVault enabled or confirmed
- [ ] Password required after sleep/screensaver
- [ ] Local user account confirmed
- [ ] Device added to inventory, if applicable

## Final validation

- [ ] All installed apps launch
- [ ] User can access Google Workspace
- [ ] User can access Notion
- [ ] User can access Slack
- [ ] User can access Google Drive files
- [ ] User can join a Zoom test meeting
​
5. macbook-setup/README.md
# Skylinks Admin MacBook Setup

Boring, stable setup workflow for location-level Skylinks admin/manager MacBooks.

## Philosophy

Simple and solid.

This is not MDM.  
This is not account provisioning.  
This is not a developer laptop bootstrap.  
This is not a company-executive laptop package.

It installs the baseline apps Ian expects on a standard Skylinks admin MacBook.

## What it installs

- Google Chrome
- Notion
- Slack
- Zoom
- Google Drive
- Claude Desktop
- mas CLI helper

## What it intentionally does not install

- Microsoft Office
- Quality-of-life apps
- Developer tools
- GitHub/GCP tooling
- Password managers
- Role-specific software

Microsoft Office is intentionally excluded because Office is only for select company-level staff. Location-based admins and managers do not need it as part of the default setup.

## Setup method

The normal setup path uses a Flipper Zero BadUSB payload:

1. Open Terminal
2. Create `~/Skylinks-Setup`
3. Download `setup.sh`
4. Download `Brewfile`
5. Make `setup.sh` executable
6. Run `setup.sh`

Ian should physically supervise the process.

## Flipper payload

Payload file:

```text
flipper/skylinks_admin_mac_install.txt
​
Manual steps still required
The script does not and should not automate:
macOS admin password prompts
Apple/macOS permission dialogs
App sign-ins
Google Workspace sign-in
Notion workspace selection
Slack workspace sign-in
Zoom camera/mic/screen permissions
Bookmark setup
Re-running setup
The setup is intended to be safe to re-run.
cd ~/Skylinks-Setup
./setup.sh
​
Homebrew will skip apps that are already installed.
Files
Brewfile — baseline app install list
setup.sh — installer script
post-install-checklist.md — human checklist after install
flipper/skylinks_admin_mac_install.txt — BadUSB payload

---

# Citadel agent implementation plan

## Step 1 — Clone and branch

```bash
git clone https://github.com/Skylinks-Golf/skylinks-scripts.git
cd skylinks-scripts
git checkout main
git pull origin main
git checkout -b feature/skylinks-admin-macbook-setup
​
Step 2 — Create files
mkdir -p macbook-setup/flipper
touch macbook-setup/README.md
touch macbook-setup/Brewfile
touch macbook-setup/setup.sh
touch macbook-setup/post-install-checklist.md
touch macbook-setup/flipper/skylinks_admin_mac_install.txt
chmod +x macbook-setup/setup.sh
​
Step 3 — Add content
Use the file contents above.
Step 4 — Validate
bash -n macbook-setup/setup.sh
​
If on a Mac with Homebrew:
brew bundle check --file=macbook-setup/Brewfile
​
Optional dry-ish run:
brew bundle --file=macbook-setup/Brewfile --no-upgrade
​
Step 5 — Commit
git status
git add macbook-setup
git commit -m "Add Skylinks admin MacBook setup workflow"
git push -u origin feature/skylinks-admin-macbook-setup
​
Step 6 — Test branch URLs
Use the Flipper payload as written with branch URLs:
feature/skylinks-admin-macbook-setup
​
Test that:
Terminal opens.
~/Skylinks-Setup is created.
setup.sh downloads.
Brewfile downloads.
setup.sh runs.
Xcode Command Line Tools handling is understandable.
Homebrew install path works.
Apps install.
Chrome default-browser attempt runs without breaking setup.
Final manual checklist prints.
Step 7 — Before merge
Open PR.
Confirm:
No secrets.
No Office.
No QoL apps.
No developer stack.
No folder-structure creation.
BadUSB payload name is exactly:
skylinks_admin_mac_install.txt
​
Step 8 — After merge
Update BadUSB payload URLs from branch to main.
Either:
Do a follow-up commit on main, or
Before merging, change the payload to main once branch testing is done.
Final URLs:
https://raw.githubusercontent.com/Skylinks-Golf/skylinks-scripts/main/macbook-setup/setup.sh
https://raw.githubusercontent.com/Skylinks-Golf/skylinks-scripts/main/macbook-setup/Brewfile
​
Acceptance criteria

New branch cut from main.

Files live under macbook-setup/.

Flipper payload lives at macbook-setup/flipper/skylinks_admin_mac_install.txt.

Payload uses paused multi-line BadUSB flow.

Payload downloads from GitHub raw URLs.

setup.sh installs/checks Homebrew.

setup.sh handles missing Xcode Command Line Tools.

setup.sh runs brew bundle.

Brewfile includes:

Google Chrome

Notion

Slack

Zoom

Google Drive

Claude

mas

Brewfile does not include:

Microsoft Office

QoL apps

developer tooling

Script attempts to set Chrome as default browser.

No Skylinks Admin local folder structure is created.

Bookmark setup remains manual/checklist-only.

No credentials, tokens, passwords, or secrets are included.

Setup can be re-run safely.

README explains what this is and what it intentionally is not.
Final note for the Citadel agent
Do not get clever.
If tempted to add options, prompts, menus, device inventory sync, role detection, browser profile automation, credential setup, or printer configuration, don’t.
Ship the boring version first.