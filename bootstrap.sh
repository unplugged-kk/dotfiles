#!/usr/bin/env bash
# Takes a fresh Mac from nothing to a built nix-darwin config.
# Run this once. After it finishes, use ./rebuild.sh for every later change.
set -euo pipefail

DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd -P)"

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

echo "==> Step 2: Homebrew"
if command -v brew >/dev/null 2>&1; then
  echo "    brew already installed, skipping"
else
  /bin/bash -c "$(curl -fsSL https://raw.githubusercontent.com/Homebrew/install/HEAD/install.sh)"
fi

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

echo "==> Step 5: first darwin-rebuild switch (pinned to nix-darwin-26.05)"

# Tap-trust warnings ("Cannot check whether X is outdated because its tap
# is not trusted") are suppressed at the source via HOMEBREW_NO_AUTO_UPDATE
# in configuration.nix environment.sessionVariables. Disabling `brew update`
# during brew bundle eliminates both the auto-update hint and the tap-trust
# warnings. Note: `brew trust --formula` does NOT actually mark the tap as
# trusted - the trust flag is tap-level and only set by brew for official
# taps or via attestations. If a future rebuild needs to re-enable update
# checks for these taps, use HOMEBREW_AUTO_UPDATE_SECS or HOMEBREW_NO_ENV_HINTS.
NIX_BIN="$(command -v nix)"
sudo "$NIX_BIN" run github:nix-darwin/nix-darwin/nix-darwin-26.05#darwin-rebuild -- \
  switch --flake ~/.dotfiles#mac

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

echo "==> Step 8: gh-axi + gnhf (npm globals)"
set +u
[ -s "$NVM_DIR/nvm.sh" ] && . "$NVM_DIR/nvm.sh"
set -u
if command -v gh-axi >/dev/null 2>&1; then
  echo "    gh-axi already installed, skipping"
else
  npm install -g gh-axi
fi
if command -v gnhf >/dev/null 2>&1; then
  echo "    gnhf already installed, skipping"
else
  npm install -g gnhf
fi

echo "==> Step 9: gh-axi session hooks (feeds GitHub context into every agent session)"
gh-axi setup hooks 2>/dev/null || true

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

# Cursor CLI (https://cursor.com/docs/cli/overview) - install via official
# installer. Binary lands at ~/.local/bin/agent (also aliased as cursor-agent).
# After install, the MCP config in home/.cursor/mcp.json (symlinked by home.nix)
# provides all 5 MCP servers. Run `agent mcp enable <name>` per server.
if [ -x "$HOME/.local/bin/agent" ]; then
  echo "    cursor CLI (agent) already installed at $HOME/.local/bin/agent, skipping"
else
  curl https://cursor.com/install -fsS | bash
  echo "    cursor CLI installed: $("$HOME/.local/bin/agent" --version 2>&1 | head -1)"
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

echo "==> Step 13: agent skills (mattpocock/skills + addyosmani/agent-skills)"
# Clone and install addyosmani/agent-skills into ~/.claude/skills/
ADDY_SKILLS_TMP="$(mktemp -d)"
git clone --depth 1 https://github.com/addyosmani/agent-skills "$ADDY_SKILLS_TMP" 2>/dev/null
if [ -d "$ADDY_SKILLS_TMP/skills" ]; then
  mkdir -p "$HOME/.claude/skills"
  cp -rn "$ADDY_SKILLS_TMP/skills/"* "$HOME/.claude/skills/" 2>/dev/null || true
  echo "    addyosmani/agent-skills installed to ~/.claude/skills/"
fi
rm -rf "$ADDY_SKILLS_TMP"

echo "==> Step 14: wire ~/.agents/skills to ~/.claude/skills (61 cross-agent skills)"
mkdir -p "$HOME/.claude/skills"
for skill_dir in "$HOME/.agents/skills/"*/; do
  skill_name=$(basename "$skill_dir")
  if [ ! -e "$HOME/.claude/skills/$skill_name" ]; then
    ln -sf "$skill_dir" "$HOME/.claude/skills/$skill_name"
  fi
done
echo "    $(ls "$HOME/.claude/skills/" | wc -l | tr -d ' ') skills available in ~/.claude/skills/"

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
echo "      headroom          $("$HOME/.local/bin/headroom" --version 2>/dev/null | head -1)"
echo "      code-review-graph $("$HOME/.local/bin/code-review-graph" --version 2>&1 | head -1)"
echo "      firstmate         $FIRSTMATE_DIR"
echo ""
echo "    MCP servers (available in all agents):"
echo "      codegraph         - code intelligence"
echo "      headroom          - token compression"
echo "      code-review-graph - PR structural review"
echo "      claude-mem        - cross-session memory"
echo "      atlassian         - Jira, Confluence, Bitbucket (OAuth via remote MCP)"
echo ""
echo "    Skills ($(ls "$HOME/.claude/skills/" | wc -l | tr -d ' ') total in ~/.claude/skills/):"
echo "      mattpocock/skills, addyosmani/agent-skills, ~/.agents/skills (61 skills)"
