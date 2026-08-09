# New machine setup

Generated from **toddobryan** on Linux Mint 22.2 (Zara). Run on a fresh Mint 22.x box.

## Step 0 — SSH key + clone (before anything else)

The repo's remote is SSH, so you need a GitHub key before you can clone it.
`bootstrap-ssh.sh` solves the chicken-and-egg: get *just that one file* onto the
new machine (USB/scp, or `curl` it from raw GitHub if the repo is public), then:

```bash
bash bootstrap-ssh.sh
```

It generates `~/.ssh/github_id_ed25519`, registers it with GitHub (via `gh` if
present, otherwise it prints the key and opens the GitHub page for you to paste),
tests the connection, and clones this repo to `~/code/bash/setup-mint`. Run it as
a file, not piped into bash, so the passphrase and login prompts work.

## Then — the rest

```bash
cd ~/code/bash/setup-mint
./setup.sh                 # everything
./setup.sh apt cargo       # just some sections
```

Default run: `repos apt toolchains cargo npm dotfiles vscode`. The script is
idempotent — re-running skips what's already there. `desktop` is **not** in the
default set (it overwrites your desktop config); run it explicitly when ready:
`./setup.sh desktop`.

## What it does automatically
- **repos** — adds OBS PPA, Claude Desktop, TeamViewer, and GitHub CLI apt sources
- **apt** — installs the 67 packages you added yourself (`apt-packages.txt`)
- **toolchains** — bootstraps rustup, nvm+Node 22, pyenv (+ your Python versions), ghcup/Haskell
- **cargo** — your 12 cargo tools (`cargo-tools.txt`), via `cargo-binstall` where possible
- **npm** — global npm packages (`npm-global.txt`)
- **dotfiles** — `.bashrc .zshrc .profile .gitconfig .gtkrc-2.0`, backing up existing ones
- **vscode** — installs your 91 VS Code extensions (`vscode-extensions.txt`)
- **desktop** (opt-in) — restores dconf; XFCE settings are a reference dump you apply by hand

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
Claude Desktop, TeamViewer, Zoom, VS Code (Settings Sync), browsers/Thunderbird.

**Large / version-pinned toolchains** — installed manually so you control versions:
- **.NET SDK** — `~/.dotnet` exists; install via Microsoft's feed or `dotnet-install.sh`
- **Flutter / Dart** — `~/.flutter`, `~/.pub-cache`; clone the SDK and run `flutter doctor`
- **Android SDK** — `~/.android`; use Android Studio's SDK manager
- **Java** — `openjdk-17-jdk` comes via apt; add other JDKs if you need them

## Verify after running
```bash
rustc --version && node --version && ghc --version && pyenv versions
gh auth status        # will prompt you to log in
```
