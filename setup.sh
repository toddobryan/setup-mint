#!/usr/bin/env bash
#
# New-machine setup, generated from toddobryan@Linux Mint 22.2 (Zara / Ubuntu noble base)
# Run on a fresh Linux Mint 22.x install. Idempotent: safe to re-run.
#
# Usage:
#   ./setup.sh              # run everything
#   ./setup.sh apt cargo    # run only the named sections
#
# Sections: repos apt toolchains cargo npm dotfiles
#
set -uo pipefail
HERE="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
log()  { printf '\033[1;34m==>\033[0m %s\n' "$*"; }
warn() { printf '\033[1;33m[!]\033[0m %s\n' "$*"; }

# --------------------------------------------------------------------------
section_repos() {
  log "Adding custom apt repositories / keyrings"
  sudo install -d /etc/apt/keyrings

  # OBS Studio PPA
  if [ ! -f /etc/apt/sources.list.d/obsproject.list ]; then
    sudo add-apt-repository -y ppa:obsproject/obs-studio
  fi

  # Claude Desktop
  if [ ! -f /usr/share/keyrings/claude-desktop-archive-keyring.asc ]; then
    curl -fsSL https://downloads.claude.ai/claude-desktop/apt/keyring.asc \
      | sudo tee /usr/share/keyrings/claude-desktop-archive-keyring.asc >/dev/null
    echo "deb [arch=amd64,arm64 signed-by=/usr/share/keyrings/claude-desktop-archive-keyring.asc] https://downloads.claude.ai/claude-desktop/apt/stable stable main" \
      | sudo tee /etc/apt/sources.list.d/claude-desktop.list >/dev/null
  fi

  # TeamViewer
  if [ ! -f /usr/share/keyrings/teamviewer-keyring.gpg ]; then
    curl -fsSL https://linux.teamviewer.com/pubkey/currentkey.asc \
      | sudo gpg --dearmor -o /usr/share/keyrings/teamviewer-keyring.gpg
    echo "deb [signed-by=/usr/share/keyrings/teamviewer-keyring.gpg] https://linux.teamviewer.com/deb stable main" \
      | sudo tee /etc/apt/sources.list.d/teamviewer.list >/dev/null
  fi

  # GitHub CLI (gh) — you have it installed; ensure its repo exists
  if [ ! -f /etc/apt/sources.list.d/github-cli.list ]; then
    curl -fsSL https://cli.github.com/packages/githubcli-archive-keyring.gpg \
      | sudo dd of=/usr/share/keyrings/githubcli-archive-keyring.gpg
    echo "deb [arch=$(dpkg --print-architecture) signed-by=/usr/share/keyrings/githubcli-archive-keyring.gpg] https://cli.github.com/packages stable main" \
      | sudo tee /etc/apt/sources.list.d/github-cli.list >/dev/null
  fi

  sudo apt-get update
}

# --------------------------------------------------------------------------
section_apt() {
  log "Installing apt packages ($(wc -l < "$HERE/apt-packages.txt") from manifest)"
  # shellcheck disable=SC2046
  sudo apt-get install -y $(grep -vE '^\s*#|^\s*$' "$HERE/apt-packages.txt" | tr '\n' ' ')
}

# --------------------------------------------------------------------------
section_toolchains() {
  # --- rustup / Rust (you had 1.96.0) ---
  if ! command -v rustup >/dev/null 2>&1; then
    log "Installing rustup"
    curl --proto '=https' --tlsv1.2 -sSf https://sh.rustup.rs | sh -s -- -y
    # shellcheck disable=SC1090
    . "$HOME/.cargo/env"
  fi

  # --- nvm + Node (you had v22.21.0) ---
  if [ ! -d "${NVM_DIR:-$HOME/.nvm}" ] && [ ! -d /opt/nvm ]; then
    log "Installing nvm + Node 22"
    curl -o- https://raw.githubusercontent.com/nvm-sh/nvm/v0.40.1/install.sh | bash
    export NVM_DIR="$HOME/.nvm"
    # shellcheck disable=SC1091
    . "$NVM_DIR/nvm.sh"
    nvm install 22
  fi

  # --- pyenv + Python versions ---
  if ! command -v pyenv >/dev/null 2>&1 && [ ! -d "$HOME/.pyenv" ]; then
    log "Installing pyenv"
    curl -fsSL https://pyenv.run | bash
    export PYENV_ROOT="$HOME/.pyenv"; export PATH="$PYENV_ROOT/bin:$PATH"
    eval "$(pyenv init -)"
  fi
  if command -v pyenv >/dev/null 2>&1; then
    while read -r v; do
      [ -z "$v" ] && continue
      pyenv versions --bare | grep -qx "$v" || { log "pyenv install $v"; pyenv install -s "$v"; }
    done < "$HERE/pyenv-versions.txt"
    pyenv global "$(head -1 "$HERE/pyenv-versions.txt")"
  fi

  # --- ghcup / Haskell (you had GHC 9.6.7) ---
  if ! command -v ghcup >/dev/null 2>&1 && [ ! -d "$HOME/.ghcup" ]; then
    log "Installing ghcup (Haskell) — non-interactive"
    export BOOTSTRAP_HASKELL_NONINTERACTIVE=1
    curl --proto '=https' --tlsv1.2 -sSf https://get-ghcup.haskell.org | sh
  fi

  warn ".NET SDK, Flutter/Dart, Android SDK, and Java beyond openjdk-17 are large and"
  warn "version-sensitive. See README 'Manual toolchains' rather than scripting blindly."
}

# --------------------------------------------------------------------------
section_cargo() {
  command -v cargo >/dev/null 2>&1 || { warn "cargo not found; run toolchains first"; return; }
  log "Installing cargo tools"
  # cargo-binstall first (fast prebuilt binaries), then use it for the rest
  cargo install cargo-binstall 2>/dev/null || true
  while read -r tool; do
    [ -z "$tool" ] && continue
    cargo install --list | grep -q "^$tool " && continue
    log "cargo tool: $tool"
    cargo binstall -y "$tool" 2>/dev/null || cargo install "$tool"
  done < "$HERE/cargo-tools.txt"
}

# --------------------------------------------------------------------------
section_npm() {
  command -v npm >/dev/null 2>&1 || { warn "npm not found; run toolchains first"; return; }
  log "Installing global npm packages"
  while read -r pkg; do
    [ -z "$pkg" ] && continue
    npm install -g "$pkg"
  done < "$HERE/npm-global.txt"
}

# --------------------------------------------------------------------------
section_dotfiles() {
  log "Installing dotfiles (backing up any existing ones to *.bak)"
  for f in "$HERE"/dotfiles/.*; do
    base="$(basename "$f")"
    case "$base" in .|..) continue;; esac
    [ -f "$f" ] || continue
    [ -e "$HOME/$base" ] && cp -a "$HOME/$base" "$HOME/$base.bak.$(date +%s)"
    cp -a "$f" "$HOME/$base"
    log "installed ~/$base"
  done
  warn "Review ~/.bashrc / ~/.profile: they may reference paths (pyenv, nvm, cargo,"
  warn "ghcup) that only exist after the toolchains section has run."
}

# --------------------------------------------------------------------------
section_vscode() {
  command -v code >/dev/null 2>&1 || { warn "'code' not on PATH; install VS Code first (apt/repo)"; return; }
  [ -f "$HERE/vscode-extensions.txt" ] || { warn "no vscode-extensions.txt"; return; }
  log "Installing VS Code extensions ($(wc -l < "$HERE/vscode-extensions.txt"))"
  local installed; installed="$(code --list-extensions 2>/dev/null)"
  while read -r ext; do
    [ -z "$ext" ] && continue
    grep -qix "$ext" <<<"$installed" && continue
    code --install-extension "$ext" --force
  done < "$HERE/vscode-extensions.txt"
  warn "VS Code settings/keybindings sync is not included — sign in to Settings Sync,"
  warn "or copy ~/.config/Code/User/{settings,keybindings}.json from the old machine."
}

# --------------------------------------------------------------------------
section_desktop() {
  log "Restoring desktop settings (dconf + XFCE/xfconf)"
  warn "This overwrites current desktop config. Backups are written first."
  if command -v dconf >/dev/null 2>&1 && [ -f "$HERE/desktop/dconf.ini" ]; then
    dconf dump / > "$HOME/dconf-backup-$(date +%s).ini" 2>/dev/null
    dconf load / < "$HERE/desktop/dconf.ini"
    log "dconf restored"
  fi
  if [ -f "$HERE/desktop/xfconf.txt" ]; then
    warn "XFCE (xfconf.txt) is a human-readable dump, not auto-loadable. Apply key"
    warn "settings by hand, or copy ~/.config/xfce4/ from the old machine while logged out of XFCE."
  fi
}

# --------------------------------------------------------------------------
main() {
  local sections=("$@")
  [ ${#sections[@]} -eq 0 ] && sections=(repos apt toolchains cargo npm dotfiles vscode)
  for s in "${sections[@]}"; do
    "section_$s" || warn "section '$s' reported errors (continuing)"
  done
  log "Done. See README.md for the manual steps a script cannot do."
}
main "$@"
