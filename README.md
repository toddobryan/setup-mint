# New machine setup

Generated from **toddobryan** on Linux Mint 22.2 (Zara). Run on a fresh Mint 22.x box.

## Step 0 — get the repo and run it (right after install)

This repo is **public**, so on a fresh machine you just clone it over HTTPS — no key,
no file transfer. Reachable from Firefox or straight from the terminal:

```bash
sudo apt update && sudo apt install -y git        # Mint XFCE does NOT ship git — this is required
git clone https://github.com/toddobryan/setup-mint.git ~/code/bash/setup-mint
cd ~/code/bash/setup-mint
./setup.sh                 # everything (or: ./setup.sh apt cargo  for just some sections)
```

That's the entire "right after install" flow.

## Optional — set up your GitHub SSH key

`bootstrap-ssh.sh` is **not** needed to get this repo (the HTTPS clone above needs no
auth). Its only job is to create a GitHub SSH key for your own future `git push` work:
it generates `~/.ssh/github_id_ed25519`, registers it with GitHub (via `gh`, or prints
the key for you to paste), and re-points this clone at the SSH remote. Run it whenever:

```bash
bash bootstrap-ssh.sh
```

Default run: `env repos apt toolchains cargo debs manual flutter dotfiles vscode jetbrains`.
The script is idempotent — re-running skips what's already there. Three sections are **not**
in the default set: `npm` (globals you're reconsidering), `desktop` (dconf), and `xfce`
(XFCE prefs — **must be run logged out of XFCE**, see below). Run explicitly, e.g.
`./setup.sh xfce`.

## What it does automatically
- **env** — installs your custom `/etc/profile.d` files (`system/profile.d/`): system-wide
  nvm (`/opt/nvm`), Flutter on PATH, and Android SDK env. Your `~` dotfiles do **not** set
  these, so this section is what actually makes Node/Flutter/Android tools resolve.
- **repos** — adds OBS PPA, Racket PPA, Claude Desktop, GitHub CLI, VS Code, 1Password, and Chrome apt sources
- **apt** — installs the packages you added yourself (`apt-packages.txt`), incl. `code`, `1password`, `google-chrome-stable`
- **toolchains** — rustup, **system-wide nvm at `/opt/nvm`** (group-owned; Node **not** auto-installed — see below), pyenv (+ your Python versions), ghcup/Haskell
- **cargo** — your 12 cargo tools (`cargo-tools.txt`), via `cargo-binstall` where possible
- **npm** (not in default run) — global npm packages (`npm-global.txt`); parked while you decide which globals you want
- **debs** — apps from downloaded `.deb`s (no repo): **Discord, Zoom, Surrealist** (latest from each vendor)
- **manual** — **uv/uvx** and **SurrealDB (`surreal`)** to `/usr/local/bin`, plus **dvorak** built from source (`github.com/tbocek/dvorak`; `make install` also sets up its udev rule + systemd unit)
- **flutter** — clones Flutter stable to `/opt/flutter` (kept as your Dart toolchain), user-owned so `flutter upgrade` needs no sudo
- **dotfiles** — `.bashrc .zshrc .profile .gitconfig .gtkrc-2.0`, backing up existing ones
- **vscode** — installs your 91 VS Code extensions (`vscode-extensions.txt`)
- **jetbrains** — installs JetBrains Toolbox to `/opt` (manual tarball, not apt), chowned to
  your user so it can self-update without sudo. The IDEs themselves need a JetBrains
  account login, so `jetbrains-apps.txt` is a checklist you install from Toolbox by hand.
- **desktop** (opt-in) — restores dconf (GTK/Cinnamon app settings)
- **xfce** (opt-in) — restores your XFCE prefs from `desktop/xfce4/` (panels, keyboard
  shortcuts incl. Dvorak, window manager, terminal). **Must be run logged out of XFCE**
  (from a TTY: log out → `Ctrl+Alt+F2` → log in → `./setup.sh xfce` → back with `Ctrl+Alt+F1`)
  or `xfconfd` overwrites it on logout. The section refuses to run if it detects a live XFCE
  session. Monitor layout is excluded (hardware-specific — set it by hand).

Deliberately **excluded**: `claude-desktop-unofficial` (redundant with the official
`claude-desktop` from the repo). Orphaned config from tried-and-dropped apps (Vivaldi,
Edge Dev, Chrome Beta/Unstable, Chromium, Evolution) was never installed here at all.

## Do these by hand — a script shouldn't

**Secrets / credentials** — copy these directly from the old machine over a trusted
channel (USB, `rsync`/`scp` on your LAN). Never regenerate them from a script and
never commit them anywhere:
- `~/.ssh/` — SSH keys and config (`chmod 600` the private keys after copying)
- `~/.gnupg/` — GPG keys
- `~/.claude.json`, `~/.codex`, `~/.config/gh` — API tokens / CLI auth
- `~/.m2/settings.xml`, `~/.cargo/credentials`, `~/.npmrc` — registry tokens if present

Example transfer from the old machine:
```bash
rsync -aP ~/.ssh ~/.gnupg toddobryan@NEW_HOST:~/
```

**Account logins (GUI apps)** — installed by the script, but you sign in yourself:
Claude Desktop, Zoom, Discord, VS Code (Settings Sync), Chrome, browsers/Thunderbird.

**Android SDK** (`/opt/Android/Sdk`) — the `android-sdk.sh` env is restored by the **env**
section, but the SDK itself is large and best populated via Android Studio's SDK manager
(Android Studio installs through JetBrains Toolbox), or `sdkmanager` from cmdline-tools.
Flutter needs it for Android builds — run `flutter doctor --android-licenses` after.

**Brother printer** (`MFC9970CDW`) — hardware-specific drivers (`brscan4`, `mfc9970cdw*`,
`printer-driver-brlaser`). Only needed if the same printer is attached. Install via Brother's
`linux-brprinter-installer` from support.brother.com, which prompts for the model.

**Node via nvm** — `/opt/nvm` is installed group-owned (`nvm` group), and you're
deliberately not in that group, so installing a Node version is an explicit sudo action:
```bash
sudo -E env NVM_DIR=/opt/nvm bash -c '. /opt/nvm/nvm.sh && nvm install 22'
```
Then decide on globals and run `./setup.sh npm` if you still want `npm-global.txt`.

**Other toolchains** — installed manually so you control versions:
- **.NET SDK** — `~/.dotnet` exists; install via Microsoft's feed or `dotnet-install.sh`
- **Java** — `openjdk-17-jdk` comes via apt; add other JDKs if you need them

## Verify after running
```bash
# open a NEW shell first so /etc/profile.d changes are loaded
rustc --version && node --version && ghc --version && pyenv versions
uv --version && surreal version && flutter --version
gh auth status        # will prompt you to log in
```
