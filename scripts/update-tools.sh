#!/usr/bin/env bash
# update-tools.sh - update every agent tool to its latest version.
#
# Called by:
#   rebuild.sh --upgrade  (step 6/7)
#   bootstrap.sh          (after first install)
#   manually:  ./scripts/update-tools.sh
#
# Covers:
#   GitHub-release binaries : no-mistakes, treehouse
#   git clones              : firstmate
#   pip tools               : headroom (headroom-ai + mcp SDK)
#   uv tools                : code-review-graph
#   npm globals             : gh-axi, gnhf, command-code, lavish-axi,
#                             tasks-axi, ponytail, pi
#   curl installer          : grok
#   herdr plugins           : browser, reviewr, memex, plus, vim-navigation
#
# Each tool is updated only if it's installed; missing tools are skipped
# (bootstrap.sh installs them for the first time). Safe to re-run.

set -uo pipefail

HOME_DIR="${HOME:?}"

update_github_release_binary() {
  local name="$1" repo="$2" bin_path="$3"
  if [ ! -x "$bin_path" ]; then
    echo "    $name not installed - skipping (bootstrap installs it)"
    return 0
  fi
  echo "    checking $name (GitHub release)..."
  local current latest
  current="$("$bin_path" --version 2>&1 | grep -oE '[0-9]+\.[0-9]+\.[0-9]+' | head -1)"
  latest="$(curl -fsSL --max-time 10 "https://api.github.com/repos/${repo}/releases/latest" \
    | grep '"tag_name"' | sed -E 's/.*"v([^"]+)".*/\1/' 2>/dev/null || true)"
  if [ -z "$latest" ]; then
    echo "    WARN: could not fetch latest $name version (network?) - keeping current"
    return 0
  fi
  if [ "$current" = "$latest" ]; then
    echo "    $name already at $latest - skipping"
    return 0
  fi
  echo "    updating $name ($current -> $latest)..."
  local tmp url
  tmp="$(mktemp -d)"
  url="https://github.com/${repo}/releases/download/v${latest}/${name}-v${latest}-darwin-arm64.tar.gz"
  if curl -fsSL --max-time 60 "$url" -o "$tmp/$name.tar.gz" 2>/dev/null; then
    tar -xzf "$tmp/$name.tar.gz" -C "$tmp/" 2>/dev/null
    if [ -f "$tmp/$name" ]; then
      cp "$tmp/$name" "$bin_path"
      chmod +x "$bin_path"
      echo "    $name -> $( "$bin_path" --version 2>&1 | head -1 )"
    else
      echo "    WARN: downloaded archive for $name had unexpected layout - keeping current"
    fi
  else
    echo "    WARN: download failed for $name - keeping current"
  fi
  rm -rf "$tmp"
}

update_firstmate() {
  local dir="$HOME_DIR/git/personal/firstmate"
  if [ ! -d "$dir/.git" ]; then
    echo "    firstmate not cloned - skipping (bootstrap clones it)"
    return 0
  fi
  echo "    updating firstmate (git pull)..."
  git -C "$dir" pull --ff-only 2>/dev/null && echo "    firstmate -> $(git -C "$dir" log --oneline -1 2>/dev/null)" \
    || echo "    WARN: firstmate pull failed (dirty tree?) - keeping current"
}

update_headroom() {
  local bin="$HOME_DIR/.local/bin/headroom"
  if ! "$bin" --version >/dev/null 2>&1; then
    echo "    headroom not installed - skipping (bootstrap installs it)"
    return 0
  fi
  echo "    updating headroom (pip)..."
  pip3 install --upgrade "headroom-ai" 2>/dev/null || pip install --upgrade "headroom-ai" 2>/dev/null \
    || echo "    WARN: headroom pip upgrade failed - keeping current"
  if ! python3 -c "import mcp" 2>/dev/null; then
    pip3 install mcp 2>&1 | tail -1
  fi
  echo "    headroom -> $("$bin" --version 2>/dev/null | head -1)"
}

update_grok() {
  if [ ! -x "$HOME_DIR/.local/bin/grok" ]; then
    echo "    grok not installed - skipping (bootstrap installs it)"
    return 0
  fi
  echo "    updating grok (official installer)..."
  curl -fsSL https://x.ai/cli/install.sh | bash 2>/dev/null \
    || echo "    WARN: grok update failed - keeping current"
  # Grok installer claims ~/.local/bin/agent; Cursor owns that name - repair.
  if [ -x "$HOME_DIR/.local/bin/cursor-agent" ]; then
    ln -sf "$HOME_DIR/.local/bin/cursor-agent" "$HOME_DIR/.local/bin/agent"
  fi
  echo "    grok -> $("$HOME_DIR/.local/bin/grok" --version 2>&1 | head -1)"
}

echo "==> Updating GitHub-release binaries"
update_github_release_binary "no-mistakes" "kunchenguid/no-mistakes" "$HOME_DIR/.local/bin/no-mistakes"
update_github_release_binary "treehouse"   "kunchenguid/treehouse"   "$HOME_DIR/.local/bin/treehouse"
echo ""

echo "==> Updating git-cloned tools"
update_firstmate
echo ""

echo "==> Updating pip tools"
update_headroom
echo ""

echo "==> Updating uv tools"
if command -v uv >/dev/null 2>&1; then
  if command -v code-review-graph >/dev/null 2>&1; then
    uv tool upgrade code-review-graph || echo "    WARN: code-review-graph upgrade failed"
  else
    echo "    code-review-graph not installed - skipping"
  fi
  if command -v skillspector >/dev/null 2>&1; then
    uv tool upgrade skillspector || echo "    WARN: skillspector upgrade failed"
  else
    echo "    skillspector not installed - skipping"
  fi
else
  echo "    uv not on PATH - skipping"
fi
echo ""

echo "==> Updating npm globals"
if command -v npm >/dev/null 2>&1; then
  npm_pkgs=(
    "gh-axi"
    "gnhf"
    "command-code"
    "lavish-axi"
    "tasks-axi"
    "@dietrichgebert/ponytail"
    "@earendil-works/pi-coding-agent"
    "agnix"
    "cc-safety-net"
  )
  to_install=()
  for pkg in "${npm_pkgs[@]}"; do
    if npm list -g --depth=0 "$pkg" >/dev/null 2>&1; then
      installed="$(npm list -g --depth=0 "$pkg" 2>/dev/null | grep "${pkg}@" | sed -E 's/.*@([0-9]+\.[0-9]+\.[0-9]+).*/\1/' | head -1)"
      latest="$(npm view "$pkg" version 2>/dev/null)"
      if [ -n "$installed" ] && [ "$installed" = "$latest" ]; then
        echo "    $pkg already at $latest - skipping"
      else
        echo "    $pkg needs update ($installed -> $latest)"
        to_install+=("${pkg}@latest")
      fi
    else
      echo "    $pkg not installed - skipping (bootstrap installs it)"
    fi
  done
  if [ "${#to_install[@]}" -gt 0 ]; then
    npm install -g "${to_install[@]}"
  else
    echo "    all npm globals up to date"
  fi
else
  echo "    npm not on PATH - skipping npm agent tools"
fi
echo ""

echo "==> Updating grok"
update_grok
echo ""

echo "==> Updating herdr plugins"
if command -v herdr >/dev/null 2>&1; then
  herdr plugin install ogulcancelik/herdr-browser --yes 2>/dev/null || \
    echo "    herdr-browser: install failed (server may need restart)"
  herdr plugin install persiyanov/herdr-reviewr --yes 2>/dev/null || \
    echo "    herdr-reviewr: install failed (server may need restart)"
  herdr plugin install nicosuave/memex --yes 2>/dev/null || \
    echo "    memex: install failed (server may need restart)"
  herdr plugin install cloudmanic/herdr-plus --yes 2>/dev/null || \
    echo "    herdr-plus: install failed (server may need restart)"
  herdr plugin install paulbkim-dev/vim-herdr-navigation --yes 2>/dev/null || \
    echo "    vim-herdr-navigation: install failed (server may need restart)"
else
  echo "    herdr not on PATH - skipping herdr plugins"
fi
echo ""

echo "==> Agent tools up to date."
