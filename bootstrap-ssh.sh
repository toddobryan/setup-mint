#!/usr/bin/env bash
#
# bootstrap-ssh.sh — step 0 on a fresh machine, BEFORE cloning this repo.
#
# Creates a GitHub SSH key, registers it with GitHub, then clones the repo so
# you can run ./setup.sh. Everything else in this repo assumes it has already run.
#
# Get it onto the new machine without cloning (pick one):
#   * copy this one file via USB / scp, or
#   * if the repo is public:
#       curl -fsSL https://raw.githubusercontent.com/toddobryan/setup-mint/main/bootstrap-ssh.sh -o bootstrap-ssh.sh
#
# Then run it as a FILE (not piped) so the passphrase and login prompts work:
#   bash bootstrap-ssh.sh
#
set -euo pipefail

EMAIL="${GIT_EMAIL:-toddobryan@gmail.com}"
KEY="$HOME/.ssh/github_id_ed25519"          # matches your naming convention
REPO_SSH="git@github.com:toddobryan/setup-mint.git"
CLONE_DEST="$HOME/code/bash/setup-mint"
TITLE="${SSH_KEY_TITLE:-$(hostname)-$(date +%Y%m%d)}"

log()  { printf '\033[1;34m==>\033[0m %s\n' "$*"; }
warn() { printf '\033[1;33m[!]\033[0m %s\n' "$*"; }

# 1. Generate the key (skip if it already exists) --------------------------
mkdir -p "$HOME/.ssh" && chmod 700 "$HOME/.ssh"
if [ -f "$KEY" ]; then
  log "Key already exists: $KEY — reusing it."
else
  log "Generating a new ed25519 key at $KEY"
  warn "You'll be prompted for a passphrase. Setting one is recommended;"
  warn "press Enter twice for none if you prefer."
  ssh-keygen -t ed25519 -C "$EMAIL" -f "$KEY"   # interactive passphrase prompt
fi

# 2. ~/.ssh/config so git uses this key for github.com ---------------------
CONFIG="$HOME/.ssh/config"
touch "$CONFIG" && chmod 600 "$CONFIG"
if ! grep -qE '^\s*Host\s+github\.com\s*$' "$CONFIG"; then
  log "Adding a github.com block to $CONFIG"
  cat >> "$CONFIG" <<EOF

Host github.com
    HostName github.com
    User git
    IdentityFile $KEY
    IdentitiesOnly yes
EOF
fi

# 3. Load it into the agent for this session -------------------------------
eval "$(ssh-agent -s)" >/dev/null
ssh-add "$KEY" 2>/dev/null || warn "ssh-add didn't load the key (agent may already have it)."

# 4. Register the public key with GitHub -----------------------------------
if command -v gh >/dev/null 2>&1; then
  log "gh CLI found — using it to register the key."
  gh auth status >/dev/null 2>&1 || gh auth login   # browser/device flow, no SSH needed
  if gh ssh-key add "$KEY.pub" --title "$TITLE" --type authentication; then
    log "Public key uploaded to GitHub as '$TITLE'."
  else
    warn "gh ssh-key add failed (key may already be registered). Continuing."
  fi
else
  warn "gh not installed. Add the key by hand:"
  echo
  echo "  1. Copy the public key below."
  echo "  2. Open https://github.com/settings/ssh/new"
  echo "  3. Paste it, give it a title, and save."
  echo
  echo "----- public key -----"; cat "$KEY.pub"; echo "----------------------"
  command -v xdg-open >/dev/null 2>&1 && xdg-open "https://github.com/settings/ssh/new" >/dev/null 2>&1 || true
  read -rp "Press Enter once you've added it on GitHub... " _
fi

# 5. Verify the connection -------------------------------------------------
log "Testing SSH to GitHub (a 'successfully authenticated' message is what you want)"
ssh -o StrictHostKeyChecking=accept-new -T git@github.com || true

# 6. Clone the repo --------------------------------------------------------
if [ -d "$CLONE_DEST/.git" ]; then
  log "Repo already at $CLONE_DEST — pulling latest."
  git -C "$CLONE_DEST" pull --ff-only || true
else
  log "Cloning $REPO_SSH -> $CLONE_DEST"
  mkdir -p "$(dirname "$CLONE_DEST")"
  git clone "$REPO_SSH" "$CLONE_DEST"
fi

log "Done. Next:"
echo "    cd $CLONE_DEST && ./setup.sh"
