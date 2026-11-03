#!/usr/bin/env bash
set -euo pipefail

# 1. Install Homebrew if it's not already there
if ! command -v brew &>/dev/null; then
  /bin/bash -c "$(curl -fsSL https://raw.githubusercontent.com/Homebrew/install/HEAD/install.sh)"
fi

# 2. Put brew on PATH for this session (Apple Silicon path)
eval "$(/opt/homebrew/bin/brew shellenv)"

# 3. Install everything in the Brewfile (run from the same folder)
brew bundle --file="$(dirname "$0")/Brewfile"

echo "✅ Done. Apps installed. Now do the manual per-user steps."