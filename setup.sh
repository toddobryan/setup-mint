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

  # VS Code (official Microsoft repo). The .deb normally adds this itself, but we
  # set it up first so `code` can be installed straight from the apt manifest.
  if [ ! -f /etc/apt/sources.list.d/vscode.sources ]; then
    curl -fsSL https://packages.microsoft.com/keys/microsoft.asc \
      | sudo gpg --dearmor -o /usr/share/keyrings/microsoft.gpg
    sudo tee /etc/apt/sources.list.d/vscode.sources >/dev/null <<'EOF'
Types: deb
URIs: https://packages.microsoft.com/repos/code
Suites: stable
Components: main
Architectures: amd64
Signed-By: /usr/share/keyrings/microsoft.gpg
EOF
  fi

  # 1Password (official repo). The .deb normally adds this itself.
  if [ ! -f /etc/apt/sources.list.d/1password.sources ]; then
    curl -fsSL https://downloads.1password.com/linux/keys/1password.asc \
      | sudo gpg --dearmor -o /usr/share/keyrings/1password-archive-keyring.gpg
    sudo tee /etc/apt/sources.list.d/1password.sources >/dev/null <<'EOF'
Types: deb
URIs: https://downloads.1password.com/linux/debian/amd64
Suites: stable
Components: main
Architectures: amd64
Signed-By: /usr/share/keyrings/1password-archive-keyring.gpg
EOF
  fi

  # Google Chrome (official repo). The .deb normally adds this itself.
  if [ ! -f /etc/apt/sources.list.d/google-chrome.sources ]; then
    curl -fsSL https://dl.google.com/linux/linux_signing_key.pub \
      | sudo gpg --dearmor -o /usr/share/keyrings/google-chrome.gpg
    sudo tee /etc/apt/sources.list.d/google-chrome.sources >/dev/null <<'EOF'
X-Repolib-Name: Google Chrome
Types: deb
URIs: https://dl.google.com/linux/chrome-stable/deb/
Suites: stable
Components: main
Architectures: amd64
Signed-By: /usr/share/keyrings/google-chrome.gpg
EOF
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

  # --- nvm (system-wide, multi-user) ---
  # nvm lives at /opt/nvm owned by an `nvm` group (see system/profile.d/nvm.sh).
  # You're intentionally NOT in that group, so installing Node versions is a
  # deliberate sudo action — this mirrors how you'd run a shared lab machine.
  # Node is NOT installed here on purpose (you're reconsidering globals).
  if [ ! -d /opt/nvm ]; then
    log "Installing system-wide nvm at /opt/nvm (group-owned by 'nvm')"
    sudo groupadd -f nvm
    sudo git clone https://github.com/nvm-sh/nvm.git /opt/nvm
    sudo git -C /opt/nvm checkout "$(sudo git -C /opt/nvm describe --tags --abbrev=0)"
    sudo chown -R root:nvm /opt/nvm
    sudo find /opt/nvm -type d -exec chmod 2775 {} +   # setgid: new files stay group nvm
    sudo find /opt/nvm -type f -exec chmod g+w {} +
    warn "To add Node later (needs sudo — you're not in the nvm group):"
    warn "  sudo -E env NVM_DIR=/opt/nvm bash -c '. /opt/nvm/nvm.sh && nvm install 22'"
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
section_env() {
  # Custom system-wide shell env that lives in /etc/profile.d (NOT your ~ dotfiles):
  # nvm (/opt/nvm), flutter (/opt/flutter/bin), android sdk (/opt/Android/Sdk).
  log "Installing custom /etc/profile.d files"
  for f in "$HERE"/system/profile.d/*.sh; do
    [ -f "$f" ] || continue
    sudo install -m 0644 "$f" "/etc/profile.d/$(basename "$f")"
    log "installed /etc/profile.d/$(basename "$f")"
  done
}

# --------------------------------------------------------------------------
section_debs() {
  # Apps installed from a downloaded .deb (no apt repo). URLs are vendor "latest".
  log "Installing downloaded .deb apps (discord, zoom, surrealist)"
  local tmp; tmp="$(mktemp -d)"; trap 'rm -rf "$tmp"' RETURN

  _install_deb() { # name  url
    dpkg -l "$1" 2>/dev/null | grep -q '^ii' && { log "$1 already installed"; return; }
    log "downloading $1"
    if curl -fL "$2" -o "$tmp/$1.deb"; then
      sudo apt-get install -y "$tmp/$1.deb"
    else
      warn "couldn't download $1 from $2 — install it by hand."
    fi
  }

  _install_deb discord "https://discord.com/api/download?platform=linux&format=deb"
  _install_deb zoom    "https://zoom.us/client/latest/zoom_amd64.deb"

  # Surrealist ships .deb assets on GitHub releases; resolve the latest amd64 one.
  if ! dpkg -l surrealist 2>/dev/null | grep -q '^ii'; then
    local surl
    surl="$(curl -fsSL https://api.github.com/repos/surrealdb/surrealist/releases/latest \
            | grep -oE 'https://[^"]+(amd64|x86_64|linux)[^"]+\.deb' | head -1)"
    [ -n "$surl" ] && _install_deb surrealist "$surl" \
      || warn "couldn't find a Surrealist .deb asset — grab it from https://surrealdb.com/surrealist"
  fi
}

# --------------------------------------------------------------------------
section_manual() {
  # uv/uvx (Astral) — you keep these in /usr/local/bin (system-wide).
  if ! command -v uv >/dev/null 2>&1; then
    log "Installing uv + uvx to /usr/local/bin"
    curl -LsSf https://astral.sh/uv/install.sh | sudo env UV_INSTALL_DIR=/usr/local/bin sh
  fi

  # SurrealDB server (`surreal`) — official installer drops it in /usr/local/bin.
  if ! command -v surreal >/dev/null 2>&1; then
    log "Installing SurrealDB (surreal)"
    curl -sSf https://install.surrealdb.com | sudo sh
  fi

  # dvorak — built from source (github.com/tbocek/dvorak). `make install` also
  # installs the udev rule + systemd unit, so the remapper works for all users.
  if ! command -v dvorak >/dev/null 2>&1; then
    log "Building dvorak from source"
    local dv="$HOME/code/c-c++/dvorak"
    [ -d "$dv/.git" ] || git clone https://github.com/tbocek/dvorak.git "$dv"
    ( cd "$dv" && make && sudo make install )
  fi
}

# --------------------------------------------------------------------------
section_flutter() {
  # You keep Flutter as the easiest way to maintain a working Dart toolchain.
  # profile.d/flutter.sh (installed by section_env) puts /opt/flutter/bin on PATH.
  if [ -d /opt/flutter ]; then
    log "Flutter already present at /opt/flutter"
  else
    log "Cloning Flutter (stable) to /opt/flutter"
    sudo git clone --depth 1 -b stable https://github.com/flutter/flutter.git /opt/flutter
    sudo chown -R "$(id -un):$(id -gn)" /opt/flutter   # user-owned so `flutter upgrade` needs no sudo
  fi
  export PATH="/opt/flutter/bin:$PATH"
  flutter --version 2>/dev/null || warn "Open a new shell (for PATH) then run: flutter doctor"
}

# --------------------------------------------------------------------------
section_jetbrains() {
  # JetBrains Toolbox is a manual tarball install to /opt (NOT apt/PPA). It then
  # manages the individual IDEs, which require a JetBrains account login to install.
  if ls -d /opt/jetbrains-toolbox-* >/dev/null 2>&1; then
    log "JetBrains Toolbox already installed in /opt."
  else
    log "Installing JetBrains Toolbox (latest) to /opt"
    local tmp; tmp="$(mktemp -d)"
    # Stable redirect to the newest Linux tarball — avoids pinning a stale version.
    if curl -fsSL "https://data.services.jetbrains.com/products/download?platform=linux&code=TBA" -o "$tmp/toolbox.tar.gz"; then
      sudo tar -xzf "$tmp/toolbox.tar.gz" -C /opt
      # /opt is root-owned so extraction needs sudo, but Toolbox self-updates in
      # place — hand the app dir to your user so updates don't require sudo.
      sudo chown -R "$(id -un):$(id -gn)" /opt/jetbrains-toolbox-*
      local bin; bin="$(find /opt/jetbrains-toolbox-* -maxdepth 2 -name jetbrains-toolbox -type f 2>/dev/null | head -1)"
      if [ -n "$bin" ] && [ -n "${DISPLAY:-}" ]; then
        log "Launching Toolbox once so it registers its menu entry + autostart."
        "$bin" >/dev/null 2>&1 &
      else
        warn "Toolbox extracted to /opt. Launch it once manually to finish setup:"
        warn "  $bin"
      fi
    else
      warn "Couldn't download Toolbox. Install it by hand from https://www.jetbrains.com/toolbox-app/"
    fi
    rm -rf "$tmp"
  fi
  warn "Sign in to JetBrains Toolbox, then (re)install the IDEs you had:"
  grep -vE '^\s*#|^\s*$' "$HERE/jetbrains-apps.txt" | sed 's/^/      - /'
}

# --------------------------------------------------------------------------
main() {
  local sections=("$@")
  [ ${#sections[@]} -eq 0 ] && sections=(env repos apt toolchains cargo debs manual flutter dotfiles vscode jetbrains)
  for s in "${sections[@]}"; do
    "section_$s" || warn "section '$s' reported errors (continuing)"
  done
  log "Done. See README.md for the manual steps a script cannot do."
}
main "$@"
