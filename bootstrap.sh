#!/usr/bin/env bash
# Takes a fresh Mac from nothing to a built nix-darwin config.
# Run this once. After it finishes, use ./rebuild.sh for every later change.
set -euo pipefail

DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd -P)"

# ── Platform detection: drives steps 2, 4, 5 below ─────────────────────────
PLATFORM="$(uname -s)"
case "$PLATFORM" in
  Darwin) PLATFORM_LABEL="macOS" ;;
  Linux)  PLATFORM_LABEL="Linux (Ubuntu/Debian assumed)" ;;
  *) echo "Unsupported platform: $PLATFORM"; exit 1 ;;
esac

# ── Guard: fail early if placeholder values haven't been replaced ─────────
if grep -q '"yourname"' "$DIR/flake.nix" 2>/dev/null; then
  echo "ERROR: flake.nix still contains placeholder user = \"yourname\"."
  echo "       Set user = \"$(whoami)\" (and homeDir if your home folder differs) before continuing."
  exit 1
fi

echo "==> Step 1: Determinate Nix"
if command -v nix >/dev/null 2>&1; then
  echo "    nix already installed, skipping"
else
  curl --proto '=https' --tlsv1.2 -sSf -L https://install.determinate.systems/nix \
    | sh -s -- install --no-confirm
  set +u
  # shellcheck disable=SC1091
  . /nix/var/nix/profiles/default/etc/profile.d/nix-daemon.sh
  set -u
fi

echo "==> Step 2: ${PLATFORM_LABEL} system packages + package manager"
case "$PLATFORM" in
  Darwin)
    if command -v brew >/dev/null 2>&1; then
      echo "    brew already installed, skipping"
    else
      /bin/bash -c "$(curl -fsSL https://raw.githubusercontent.com/Homebrew/install/HEAD/install.sh)"
    fi
    ;;
  Linux)
    # apt packages: basics for the bootstrap itself, plus fonts that GUI apps
    # expect system-wide, plus docker from Ubuntu's repo. apt-get (not apt) for
    # stable scripting output. sudo apt-get update first so the install doesn't
    # hit a stale cache.
    sudo apt-get update
    sudo apt-get install -y \
      git build-essential ca-certificates curl wget xz-utils unzip zip \
      fonts-noto-color-emoji fonts-noto-cjk fonts-hack-ttf fonts-jetbrains-mono \
      iproute2 dnsutils docker.io docker-compose-v2
    # docker group membership so `docker` works without sudo. The new group
    # only takes effect on next login, or `newgrp docker` in the current shell.
    if ! groups "$(whoami)" | grep -q "\bdocker\b"; then
      sudo usermod -aG docker "$(whoami)"
      echo "    Added $(whoami) to the docker group. Log out and back in (or run 'newgrp docker') before using docker without sudo."
    fi
    ;;
esac

echo "==> Step 3: symlink this repo to ~/.dotfiles"
ln -sfn "$DIR" ~/.dotfiles

echo "==> Step 4: personalize the configured username"
REAL_USER="$(whoami)"
FLAKE_USER="$(sed -nE 's/^[[:space:]]*user = "([^"]+)";.*/\1/p' "$DIR/flake.nix" | head -n1)"
if [ -z "$FLAKE_USER" ]; then
  echo "    Could not find the single \"user = \" line in flake.nix."
  echo "    Edit flake.nix yourself before continuing."
  exit 1
elif [ "$FLAKE_USER" != "$REAL_USER" ]; then
  echo "    flake.nix is configured for user \"$FLAKE_USER\", but you are \"$REAL_USER\"."
  echo "    NOTE: On this machine the account name (\"$REAL_USER\") differs from"
  echo "    the home folder name. Check flake.nix - it has separate 'user' and"
  echo "    'homeDir' variables. If 'user' should be \"$REAL_USER\", answer y."
  read -r -p "    Rewrite flake.nix's \"user = \" line to \"$REAL_USER\"? [y/N] " REPLY
  if [ "$REPLY" = "y" ] || [ "$REPLY" = "Y" ]; then
    sed -i '' -E "s/^([[:space:]]*user = \")[^\"]+(\";.*)/\1${REAL_USER}\2/" "$DIR/flake.nix"
    echo "    Updated. Review the change with: git diff flake.nix"
  else
    echo "    Kept as \"$FLAKE_USER\". Make sure this matches your actual macOS account name."
    echo "    Run: whoami   to confirm your account name."
  fi
else
  echo "    flake.nix already matches \"$REAL_USER\", nothing to do."
fi

# Linux only: rewrite homeDirLinux in flake.nix to match actual $HOME
# (typically /home/<user>). Step 5 below uses this for
# `home-manager switch --flake $DIR#${REAL_USER}`. Mac keeps homeDir only.
if [ "$PLATFORM" = Linux ]; then
  REAL_HOME="$HOME"
  CURRENT_LINUX_HOME="$(sed -nE 's/^[[:space:]]*homeDirLinux = "([^"]+)";.*/\1/p' "$DIR/flake.nix" | head -n1)"
  if [ -z "$CURRENT_LINUX_HOME" ]; then
    echo "    Could not find the single \"homeDirLinux = \" line in flake.nix."
    echo "    Edit flake.nix yourself before continuing."
    exit 1
  elif [ "$CURRENT_LINUX_HOME" != "$REAL_HOME" ]; then
    echo "    flake.nix homeDirLinux is \"$CURRENT_LINUX_HOME\", but \$HOME is \"$REAL_HOME\"."
    read -r -p "    Rewrite flake.nix's \"homeDirLinux = \" line to \"$REAL_HOME\"? [y/N] " REPLY
    if [ "$REPLY" = "y" ] || [ "$REPLY" = "Y" ]; then
      sed -i '' -E "s/^([[:space:]]*homeDirLinux = \")[^\"]+(\";.*)/\1${REAL_HOME}\2/" "$DIR/flake.nix"
      echo "    Updated. Review with: git diff flake.nix"
    else
      echo "    Kept as \"$CURRENT_LINUX_HOME\". Make sure this matches the actual Linux home directory."
    fi
  else
    echo "    flake.nix homeDirLinux already matches \"$REAL_HOME\", nothing to do."
  fi
fi

case "$PLATFORM" in
  Darwin)
    echo "==> Step 5: first darwin-rebuild switch (pinned to nix-darwin-26.05)"

    # Third-party taps carrying casks (e.g. augani/dory) need an explicit
    # `brew trust` before Homebrew will load them - otherwise `brew bundle`
    # (run by nix-homebrew during activation) fails with "Refusing to load
    # cask ... from untrusted tap". Trust is idempotent and persists in
    # trust.json, so re-running this is a no-op once trusted. Mirrors the
    # trust_taps() step in rebuild.sh.
    brew trust --taps augani/dory >/dev/null 2>&1 || true

    # Tap-trust warnings ("Cannot check whether X is outdated because its tap
    # is not trusted") are suppressed at the source via HOMEBREW_NO_AUTO_UPDATE
    # in configuration.nix environment.sessionVariables. Disabling `brew update`
    # during brew bundle eliminates both the auto-update hint and the tap-trust
    # warnings. Note: `brew trust --formula` does NOT actually mark the tap as
    # trusted - the trust flag is tap-level and only set by brew for official
    # taps or via attestations. If a future rebuild needs to re-enable update
    # checks for these taps, use HOMEBREW_AUTO_UPDATE_SECS or HOMEBREW_NO_ENV_HINTS.
    # `nix run github:nix-darwin/...` re-resolves the branch ref via GitHub's
    # API. As root (sudo) that call is unauthenticated and hits the 60/hr rate
    # limit ("HTTP error 403"). Three defenses, in order:
    #   1. If darwin-rebuild is already on the system (prior switch), use it
    #      directly - zero network, zero store lookups. This is the common
    #      re-bootstrap case.
    #   2. Otherwise, run the pinned darwin-rebuild from the committed
    #      flake.lock by building the flake's `darwin-rebuild` package - no
    #      GitHub API ref resolution.
    #   3. Last resort (stale/missing lock): feed gh's token through
    #      NIX_CONFIG so nix's github.com fetches authenticate even for the
    #      root subprocess (same pattern rebuild.sh uses for `nix flake
    #      update`).
    NIX_BIN="$(command -v nix)"
    if [ -x /run/current-system/sw/bin/darwin-rebuild ]; then
      sudo /run/current-system/sw/bin/darwin-rebuild switch --flake "$DIR#mac"
    elif [ -f "$DIR/flake.lock" ] && grep -q '"nix-darwin"' "$DIR/flake.lock"; then
      sudo "$NIX_BIN" build "$DIR#darwinConfigurations.mac.system"
      sudo ./result/sw/bin/darwin-rebuild switch --flake "$DIR#mac"
      sudo rm -f ./result
    else
      GH_TOKEN_VAL="$(gh auth token 2>/dev/null || true)"
      if [ -n "$GH_TOKEN_VAL" ]; then
        sudo env "NIX_CONFIG=access-tokens = github.com ${GH_TOKEN_VAL}" \
          "$NIX_BIN" run github:nix-darwin/nix-darwin/nix-darwin-26.05#darwin-rebuild -- \
          switch --flake "$DIR#mac"
      else
        sudo "$NIX_BIN" run github:nix-darwin/nix-darwin/nix-darwin-26.05#darwin-rebuild -- \
          switch --flake "$DIR#mac"
      fi
    fi
    ;;
  Linux)
    echo "==> Step 5: first home-manager switch (standalone, no nix-darwin on Linux)"

    # No nix-darwin equivalent on non-NixOS distros. Activate home-manager
    # directly via the homeConfigurations."${user}" output from flake.nix.
    # homeDirLinux (set just above) tells home.nix where the user's $HOME is
    # (/home/<user> on Ubuntu/Debian). Same home.nix works for both platforms;
    # isLinux = true makes it drop /opt/homebrew/bin from sessionPath and add
    # ~/.nix-profile/bin instead.
    nix run home-manager -- switch --flake "$DIR#${REAL_USER}"
    ;;
esac

echo "==> Step 6: nvm + Node.js LTS"
export NVM_DIR="$HOME/.nvm"
if [ -d "$NVM_DIR" ]; then
  echo "    nvm already installed, skipping"
else
  PROFILE=/dev/null bash -c \
    'curl -o- https://raw.githubusercontent.com/nvm-sh/nvm/v0.40.3/install.sh | bash'
  set +u
  # shellcheck disable=SC1091
  [ -s "$NVM_DIR/nvm.sh" ] && . "$NVM_DIR/nvm.sh"
  set -u
  nvm install --lts
  echo "    Node.js $(node --version) installed via nvm"
fi

# Always ensure the LTS is installed and active. `nvm use --lts` would
# maintain $NVM_DIR/current, but it REFUSES to run when ~/.npmrc sets a
# global `prefix` (this machine's intentional setup: prefix=~/.local for
# npm globals). So instead of relying on nvm use, create the `current`
# symlink directly - home.nix/configuration.nix put ~/.nvm/current/bin on
# PATH, and this keeps that path valid across LTS upgrades.
set +u
# shellcheck disable=SC1091
[ -s "$NVM_DIR/nvm.sh" ] && . "$NVM_DIR/nvm.sh"
set -u
nvm install --lts 2>/dev/null || nvm install --lts
# `nvm version lts` may return "N/A" when ~/.npmrc has a global prefix;
# fall back to the most recently installed version dir in that case.
LTS_VERSION="$(nvm version lts 2>/dev/null || true)"
if [ -z "$LTS_VERSION" ] || [ "$LTS_VERSION" = "N/A" ]; then
  LTS_VERSION="$(ls -1 "$NVM_DIR/versions/node" | sort -V | tail -1)"
fi
rm -f "$NVM_DIR/current"
ln -sfn "$NVM_DIR/versions/node/$LTS_VERSION" "$NVM_DIR/current"
echo "    ~/.nvm/current -> $LTS_VERSION"

# `node` and friends must resolve even outside an interactive nvm shell
# (MCP servers, cron, rebuild.sh). Keep a stable symlink in ~/.local/bin.
mkdir -p "$HOME/.local/bin"
ln -sfn "$NVM_DIR/current/bin/node" "$HOME/.local/bin/node"
echo "    Node.js $(node --version) installed via nvm (current -> $HOME/.nvm/current)"

echo "==> Step 7: ~/.local/bin — no-mistakes and treehouse"
mkdir -p "$HOME/.local/bin"

# no-mistakes: AI-gated PR quality pipeline
if [ -x "$HOME/.local/bin/no-mistakes" ]; then
  echo "    no-mistakes already installed, skipping"
else
  echo "    installing no-mistakes..."
  NM_TMP="$(mktemp -d)"
  NM_VERSION="$(curl -fsSL https://api.github.com/repos/kunchenguid/no-mistakes/releases/latest | grep '"tag_name"' | sed -E 's/.*"v([^"]+)".*/\1/')"
  curl -fsSL "https://github.com/kunchenguid/no-mistakes/releases/download/v${NM_VERSION}/no-mistakes-v${NM_VERSION}-darwin-arm64.tar.gz" \
    -o "$NM_TMP/nm.tar.gz"
  tar -xzf "$NM_TMP/nm.tar.gz" -C "$NM_TMP/"
  cp "$NM_TMP/no-mistakes" "$HOME/.local/bin/no-mistakes"
  chmod +x "$HOME/.local/bin/no-mistakes"
  rm -rf "$NM_TMP"
  echo "    no-mistakes $("$HOME/.local/bin/no-mistakes" --version 2>&1 | head -1) installed"
fi

# treehouse: reusable git worktree pool for parallel agents
if [ -x "$HOME/.local/bin/treehouse" ]; then
  echo "    treehouse already installed, skipping"
else
  echo "    installing treehouse..."
  TH_TMP="$(mktemp -d)"
  TH_VERSION="$(curl -fsSL https://api.github.com/repos/kunchenguid/treehouse/releases/latest | grep '"tag_name"' | sed -E 's/.*"v([^"]+)".*/\1/')"
  curl -fsSL "https://github.com/kunchenguid/treehouse/releases/download/v${TH_VERSION}/treehouse-v${TH_VERSION}-darwin-arm64.tar.gz" \
    -o "$TH_TMP/th.tar.gz"
  tar -xzf "$TH_TMP/th.tar.gz" -C "$TH_TMP/"
  cp "$TH_TMP/treehouse" "$HOME/.local/bin/treehouse"
  chmod +x "$HOME/.local/bin/treehouse"
  rm -rf "$TH_TMP"
  echo "    treehouse $("$HOME/.local/bin/treehouse" --version 2>&1) installed"
fi

echo "==> Step 7.5: herdr plugin â herdr-file-viewer (smarzban/herdr-file-viewer)"
# Git-aware, read-only file viewer that lives in a herdr pane: tree on the
# left, diffs / rendered markdown / syntax-highlighted code on the right.
# Installed via herdr's plugin manager, which clones the repo and fetches
# the prebuilt aarch64-apple-darwin binary (or falls back to cargo build).
# Keybindings (prefix+shift+f for split, prefix+shift+t for own tab) live in
# ~/.dotfiles/home/.config/herdr/config.toml (symlinked by home.nix).
# Plugin runtime state and cache (plugins.json, plugins/github/) are
# gitignored in this repo so we don't commit herdr's internal registry.
if herdr plugin list 2>/dev/null | grep -q "herdr-file-viewer"; then
  echo "    herdr-file-viewer already installed, skipping"
else
  echo "    installing herdr-file-viewer..."
  herdr plugin install smarzban/herdr-file-viewer --yes
  echo "    herdr-file-viewer installed"
fi

echo "==> Step 8: agent CLI tools (npm globals)"
set +u
[ -s "$NVM_DIR/nvm.sh" ] && . "$NVM_DIR/nvm.sh"
set -u
# Standard npm-global agent CLIs. Loop keeps the install list declarative:
# add a new AXI by appending its package name here (and to the same list in
# home.nix's updateAgentCliTools + scripts/update-tools.sh).
for pkg in \
  gh-axi \
  gnhf \
  lavish-axi \
  tasks-axi \
  chrome-devtools-axi \
  sqlite-axi \
  gws-axi \
  gitsheets-axi \
  pg-axi \
  cyber-mux \
  graft \
; do
  if command -v "$pkg" >/dev/null 2>&1; then
    echo "    $pkg already installed, skipping"
  else
    npm install -g "$pkg"
  fi
done

# docker-axi / kubernetes-axi: not yet published to npm - install straight from
# GitHub so the `bin` entries land in npm's global prefix like the others.
for pkg in docker-axi kubernetes-axi; do
  if command -v "$pkg" >/dev/null 2>&1; then
    echo "    $pkg already installed, skipping"
  else
    npm install -g "thatdudealso/$pkg"
  fi
done

echo "==> Step 9: agent session hooks (gh-axi GitHub context, lavish-axi HTML artifact review)"
gh-axi setup hooks 2>/dev/null || true
# Lavish Editor - HTML artifact review. Hooks feed ambient context (open
# sessions, playbooks) into Claude Code, Codex, OpenCode, Copilot CLI sessions.
# The plugin registers the installed package with VS Code, Cursor, Copilot CLI.
lavish-axi setup hooks 2>/dev/null || true
lavish-axi setup plugin 2>/dev/null || true

echo "==> Step 10: firstmate (multi-agent crew orchestrator)"
FIRSTMATE_DIR="$HOME/git/personal/firstmate"
if [ -d "$FIRSTMATE_DIR" ]; then
  echo "    firstmate already cloned, pulling latest..."
  git -C "$FIRSTMATE_DIR" pull --ff-only 2>/dev/null || echo "    (could not pull, continuing)"
else
  mkdir -p "$HOME/git/personal"
  git clone https://github.com/kunchenguid/firstmate "$FIRSTMATE_DIR"
  echo "    firstmate cloned to $FIRSTMATE_DIR"
fi

echo "==> Step 11: npm agent tools (ponytail, command-code, gh-axi hooks for ponytail, mattpocock skills)"
if command -v ponytail >/dev/null 2>&1 || npm list -g "@dietrichgebert/ponytail" >/dev/null 2>&1; then
  echo "    ponytail already installed, skipping"
else
  npm install -g @dietrichgebert/ponytail
fi

# Command Code (https://commandcode.ai/) - taste-learning coding agent
# Pinned to @latest so bootstrap installs the newest release. To upgrade an
# existing install later, run: npm i -g command-code@latest
if command -v command-code >/dev/null 2>&1; then
  echo "    command-code already installed, skipping (run \`npm i -g command-code@latest\` to upgrade)"
else
  npm install -g command-code@latest
  echo "    command-code $(command-code --version 2>&1 | head -1) installed"
fi

# OpenCode 2 (https://opencode.ai/v2/docs) - the only OpenCode we run.
# Installed from the `next` npm tag as `opencode2`. npm prefix is ~/.local,
# so the binary lands in ~/.local/bin/opencode2 (on PATH via sessionPath).
# Shell alias: oc2. Config is symlinked from home/.config/opencode/ via home.nix.
if command -v opencode2 >/dev/null 2>&1; then
  echo "    opencode2 already installed: $(opencode2 --version 2>&1 | head -1)"
else
  npm install -g @opencode-ai/cli@next
  echo "    opencode2 installed: $(opencode2 --version 2>&1 | head -1)"
fi

# Cursor CLI (https://cursor.com/docs/cli/overview) - install via official
# installer. Prefer the unambiguous binary name `cursor-agent` (also installs
# `agent`, which collides with Grok's `~/.local/bin/agent` symlink). MCP config
# lives in home/.cursor/mcp.json (symlinked by home.nix). After install, enable
# servers with: cursor-agent mcp enable <name>
if [ -x "$HOME/.local/bin/cursor-agent" ]; then
  echo "    cursor CLI already installed: $("$HOME/.local/bin/cursor-agent" --version 2>&1 | head -1)"
else
  # Preserve Grok's agent symlink if present; Cursor install may overwrite
  # ~/.local/bin/agent with its own binary.
  GROK_AGENT_TARGET=""
  if [ -L "$HOME/.local/bin/agent" ] && readlink "$HOME/.local/bin/agent" | grep -q '\.grok/'; then
    GROK_AGENT_TARGET="$(readlink "$HOME/.local/bin/agent")"
  fi
  curl https://cursor.com/install -fsS | bash
  if [ -n "$GROK_AGENT_TARGET" ]; then
    ln -sfn "$GROK_AGENT_TARGET" "$HOME/.local/bin/agent"
    echo "    restored Grok agent symlink at ~/.local/bin/agent"
  fi
  echo "    cursor CLI installed: $("$HOME/.local/bin/cursor-agent" --version 2>&1 | head -1)"
fi
# Short command name that works without zsh aliases (shell alias `ca` still set in home.nix)
if [ -x "$HOME/.local/bin/cursor-agent" ]; then
  ln -sfn "$HOME/.local/bin/cursor-agent" "$HOME/.local/bin/ca"
  echo "    cursor-agent shim: $HOME/.local/bin/ca -> cursor-agent"
fi

# Pi coding agent (https://pi.dev/) - npm global package. Uses ~/.pi/agent for
# settings, AGENTS.md, skills, sessions. AGENTS.md + settings.json are
# symlinked from home/.pi/agent/ via home.nix.
if command -v pi >/dev/null 2>&1; then
  echo "    pi already installed, skipping (run \`npm i -g --ignore-scripts @earendil-works/pi-coding-agent@latest\` to upgrade)"
else
  npm install -g --ignore-scripts @earendil-works/pi-coding-agent
  echo "    pi $(pi --version 2>&1 | head -1) installed"
fi

# Grok Build / xAI CLI (https://x.ai/cli) - official installer. Binary lands at
# ~/.local/bin/grok (and also as `agent` under ~/.grok/bin). Prefer `grok` /
# shell alias `gx` so it stays distinct from other tools named agent.
# Config + AGENTS.md are symlinked from home/.grok/ via home.nix.
if command -v grok >/dev/null 2>&1; then
  echo "    grok (xAI CLI) already installed: $(grok --version 2>&1 | head -1)"
else
  curl -fsSL https://x.ai/cli/install.sh | bash
  echo "    grok installed: $(grok --version 2>&1 | head -1)"
fi
# Short command name that works without zsh aliases (shell alias `gx` still set in home.nix)
if [ -x "$HOME/.local/bin/grok" ]; then
  ln -sfn "$HOME/.local/bin/grok" "$HOME/.local/bin/gx"
  echo "    grok shim: $HOME/.local/bin/gx -> grok"
elif [ -x "$HOME/.grok/bin/grok" ]; then
  ln -sfn "$HOME/.grok/bin/grok" "$HOME/.local/bin/grok"
  ln -sfn "$HOME/.local/bin/grok" "$HOME/.local/bin/gx"
  echo "    grok shim: $HOME/.local/bin/gx -> grok"
fi

echo "==> Step 12: headroom (token compression layer - 20-95% fewer tokens)"
if "$HOME/.local/bin/headroom" --version >/dev/null 2>&1; then
  echo "    headroom already installed, skipping"
else
  # Install via pip3 and symlink the binary
  pip3 install "headroom-ai" 2>/dev/null || pip install "headroom-ai" 2>/dev/null
  HEADROOM_BIN="$(pip3 show headroom-ai 2>/dev/null | grep Location | awk '{print $2}')/../../../bin/headroom"
  if [ -f "$HEADROOM_BIN" ]; then
    ln -sf "$HEADROOM_BIN" "$HOME/.local/bin/headroom"
    echo "    headroom $("$HOME/.local/bin/headroom" --version 2>/dev/null | head -1) installed"
  else
    echo "    headroom install: pip3 may need to be run manually if this fails"
  fi
fi

# headroom's MCP server needs the MCP SDK; install alongside headroom
if python3 -c "import mcp" 2>/dev/null; then
  echo "    mcp Python SDK already installed, skipping"
else
  pip3 install mcp 2>&1 | tail -1
fi

echo "==> Step 13: global agent skill packs (Agent Skills standard)"
# Install into ~/.agents/skills and register for every host that supports global
# skills (Claude, Codex, Cursor, OpenCode, Gemini, Copilot, Cline, ...).
# Eve/PromptScript do not support global install and are expected to fail.
# Upgrade later:
#   npx skills update -g
#   npx skills add <owner/repo> -g --all
install_skill_pack() {
  local repo="$1"
  local marker_skill="$2"   # one skill name that proves the pack is present
  if [ -d "$HOME/.agents/skills/$marker_skill" ]; then
    echo "    $repo already present (found $marker_skill), skipping install"
  else
    echo "    installing $repo ..."
    npx --yes skills add "$repo" -g --all 2>&1 | tail -15
  fi
}
install_skill_pack "mattpocock/skills" "grill-me"
install_skill_pack "addyosmani/agent-skills" "using-agent-skills"
install_skill_pack "kishoreHQ/last30days-skill" "last30days"
install_skill_pack "blader/humanizer" "humanizer"
install_skill_pack "elayadesign/ai-design-skills" "landing-page-design"
install_skill_pack "tonbistudio/buzz-skills" "buzz-media-attachments"
install_skill_pack "emilkowalski/skills" "emil-design-eng"
install_skill_pack "nextlevelbuilder/ui-ux-pro-max-skill" "ui-ux-pro-max"
install_skill_pack "vercel-labs/skills" "find-skills"
# Lavish Editor (lavish-axi) - HTML artifact review. Only the public `lavish`
# skill; the repo's internal `lavish-design` brand skill stays hidden.
if [ -d "$HOME/.agents/skills/lavish" ]; then
  echo "    kunchenguid/lavish-axi already present (found lavish), skipping install"
else
  echo "    installing kunchenguid/lavish-axi (lavish skill) ..."
  npx --yes skills add "kunchenguid/lavish-axi" -g --skill lavish 2>&1 | tail -15
fi

# AXI ecosystem skills - each AXI repo ships an installable Agent Skill that
# teaches agents the CLI surface. Installed globally like the packs above.
#   chrome-devtools-axi  - browser automation (skill: chrome-devtools-axi)
#   sqlite-axi           - SQLite inspection (skill: sqlite-axi)
#   tasks-axi            - backlog management (skill: tasks-axi)
#   specops              - spec-driven development (whole repo is the skill)
#   gitsheets            - git-as-spreadsheet (skill: gitsheets)
# Note: gws-axi ships the same specops skill (not a gws-axi one) and cyber-mux
# only ships an internal dev skill (mux-gap-scan), so neither is installed here.
install_axi_skill() {
  local repo="$1" marker_skill="$2" skill_name="$3"
  if [ -d "$HOME/.agents/skills/$marker_skill" ]; then
    echo "    $repo already present (found $marker_skill), skipping install"
  else
    echo "    installing $repo ($skill_name skill) ..."
    npx --yes skills add "$repo" -g --skill "$skill_name" 2>&1 | tail -15
  fi
}
install_axi_skill "kunchenguid/chrome-devtools-axi" "chrome-devtools-axi" "chrome-devtools-axi"
install_axi_skill "SSBrouhard/sqlite-axi" "sqlite-axi" "sqlite-axi"
install_axi_skill "kunchenguid/tasks-axi" "tasks-axi" "tasks-axi"
install_axi_skill "JarvusInnovations/specops" "specops" "specops"
install_axi_skill "JarvusInnovations/gitsheets" "gitsheets" "gitsheets"

echo "==> Step 14: sync upstream skill repos + wire canonical skills to every agent"
# scripts/sync-skills.sh clones the upstream skill repos (mattpocock/skills,
# davidondrej/skills, obra/superpowers, anthropics/skills, garrytan/gstack,
# ui-ux-pro-max, addyosmani/agent-skills, ai-agents-skills, ai-toolkit,
# shadcn/improve, terraform-skill) into ~/.agents/skills, then wires every
# agent's skill dir to it (Claude/Codex/Cursor/Grok/Pi/OpenCode/CommandCode/
# Gemini/Copilot/Kiro/Windsurf/AdaL/Hermes). Idempotent - safe to re-run.
bash "$DIR/scripts/sync-skills.sh"

# Grok native plugin for last30days (marketplace source in home/.grok/config.toml)
if command -v grok >/dev/null 2>&1; then
  if grok plugin list 2>/dev/null | grep -qi last30days; then
    echo "    grok plugin last30days already installed"
  else
    grok plugin marketplace add kishoreHQ/last30days-skill 2>/dev/null || true
    grok plugin install last30days --trust 2>&1 | tail -5 || \
      grok plugin install kishoreHQ/last30days-skill --trust 2>&1 | tail -5 || true
  fi
fi

echo "==> Step 15: code-review-graph (PR-level structural review, https://github.com/tirth8205/code-review-graph)"
# Installed via 'uv tool install' (modern pipx equivalent). uv is already on PATH
# via ~/.local/bin (installed by step 12 headroom). The binary symlinks to
# ~/.local/bin/code-review-graph (on PATH via home.nix sessionPath).
# To upgrade later: uv tool upgrade code-review-graph
UV_BIN="$(command -v uv || echo "$HOME/.local/bin/uv")"
if "$HOME/.local/bin/code-review-graph" --version >/dev/null 2>&1; then
  echo "    code-review-graph already installed, skipping (run \`uv tool upgrade code-review-graph\` to upgrade)"
else
  "$UV_BIN" tool install code-review-graph
  echo "    code-review-graph $("$HOME/.local/bin/code-review-graph" --version 2>&1 | head -1) installed"
  # Optional: auto-configure all detected agent platforms (OpenCode, Claude Code, Copilot CLI, etc.)
  # Skipped by default so dotfiles stay declarative. Run manually after bootstrap:
  #   code-review-graph install
fi

echo ""
echo "==> Done. Open a new terminal, then run: rebuild"
echo ""
echo "    Core agent tools:"
echo "      no-mistakes       $("$HOME/.local/bin/no-mistakes" --version 2>&1 | head -1)"
echo "      treehouse         $("$HOME/.local/bin/treehouse" --version 2>&1)"
echo "      gh-axi            $(gh-axi --version 2>/dev/null)"
echo "      gnhf              $(gnhf --version 2>/dev/null)"
echo "      lavish-axi        $(lavish-axi --version 2>/dev/null)"
echo "      chrome-devtools-axi $(chrome-devtools-axi --version 2>/dev/null)"
echo "      sqlite-axi        $(sqlite-axi --version 2>/dev/null)"
echo "      gws-axi           $(gws-axi --version 2>/dev/null)"
echo "      gitsheets-axi     $(gitsheets-axi --version 2>/dev/null)"
echo "      pg-axi            $(pg-axi --version 2>/dev/null)"
echo "      cyber-mux         $(cyber-mux --version 2>/dev/null)"
echo "      docker-axi        $(docker-axi --version 2>/dev/null)"
echo "      kubernetes-axi    $(kubernetes-axi --version 2>/dev/null)"
echo "      graft             $(graft --version 2>/dev/null)"
echo "      headroom          $("$HOME/.local/bin/headroom" --version 2>/dev/null | head -1)"
echo "      code-review-graph $("$HOME/.local/bin/code-review-graph" --version 2>&1 | head -1)"
echo "      cursor-agent      $("$HOME/.local/bin/cursor-agent" --version 2>&1 | head -1)"
echo "      pi                $(pi --version 2>&1 | head -1)"
echo "      grok              $(grok --version 2>&1 | head -1)"
echo "      opencode2         $(opencode2 --version 2>&1 | head -1)"
echo "      firstmate         $FIRSTMATE_DIR"
echo ""
echo "    MCP servers (available in all agents):"
echo "      codegraph         - code intelligence"
echo "      headroom          - token compression"
echo "      code-review-graph - PR structural review"
echo "      claude-mem        - cross-session memory"
echo ""
echo "    Skills ($(ls "$HOME/.agents/skills/" 2>/dev/null | wc -l | tr -d ' ') in ~/.agents/skills, mirrored to Claude/Codex/Cursor/Grok/Pi/OpenCode/CommandCode/Gemini/Copilot):"
echo "      mattpocock/skills (~41), addyosmani/agent-skills (~24), last30days, lavish, chrome-devtools-axi, sqlite-axi, tasks-axi, specops, gitsheets, + other packs"
