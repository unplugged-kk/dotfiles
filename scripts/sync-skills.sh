#!/usr/bin/env bash
# sync-skills.sh - keep every agent's skill folder in sync with the canonical
# ~/.agents/skills/ directory, and pull in the upstream skill repos.
#
# Canonical layout (see ~/.agents/skills/distribute-skill-to-all-agents/SKILL.md):
#   ~/.agents/skills/           canonical authoring location
#   ~/.claude/skills            -> ~/.agents/skills   (symlink)
#   ~/.pi/agent/skills          -> ~/.agents/skills   (symlink)
#   ~/.hermes/skills/           independent copy (rsync)
#   ~/.config/opencode/skills/  per-skill symlinks (has its own skills too)
#   ~/.cursor/skills-cursor/    per-skill symlinks (has bundled skills too)
#   ~/.copilot/skills/          per-skill symlinks
#   ~/.commandcode/skills/      per-skill symlinks
#
# Upstream skill repos are shallow-cloned into ~/.agents/skill-repos/ and their
# skills (any dir containing SKILL.md) synced into ~/.agents/skills/.
#
# Collision policy: if two sources provide the same skill name, the existing
# canonical copy wins; then mattpocock/skills; then davidondrej/skills.
# Exception: skills listed in OWNER_REPOS below are "owned" by their upstream
# repo and are ALWAYS refreshed from it on every sync, so updates propagate
# (e.g. shadcn/improve -> "improve", antonbabenko/terraform-skill).
#
# Usage:
#   sync-skills.sh          - update repos + sync all agents (idempotent)
#   sync-skills.sh --repos  - only update the upstream repos
#   sync-skills.sh --local  - only sync ~/.agents/skills -> agents
#
# Run from bootstrap.sh (first machine) and rebuild.sh --upgrade (updates).

set -euo pipefail

HOME_DIR="${HOME:?}"
AGENTS_SKILLS="$HOME_DIR/.agents/skills"
REPO_CACHE="$HOME_DIR/.agents/skill-repos"
CLAUDE_SKILLS="$HOME_DIR/.claude/skills"
PI_SKILLS="$HOME_DIR/.pi/agent/skills"
HERMES_SKILLS="$HOME_DIR/.hermes/skills"
OPENCODE_SKILLS="$HOME_DIR/.config/opencode/skills"
CURSOR_SKILLS="$HOME_DIR/.cursor/skills-cursor"
COPILOT_SKILLS="$HOME_DIR/.copilot/skills"
COMMANDCODE_SKILLS="$HOME_DIR/.commandcode/skills"

MODE="${1:-all}"

# ── 1. Update upstream repos ───────────────────────────────────────────────
update_repo() {
  local name="$1" url="$2"
  local dir="$REPO_CACHE/$name"
  if [ -d "$dir/.git" ]; then
    git -C "$dir" fetch --depth 1 origin >/dev/null 2>&1 || true
    git -C "$dir" reset --hard origin/main >/dev/null 2>&1 || true
    echo "    updated $name"
  else
    mkdir -p "$REPO_CACHE"
    git clone --depth 1 "$url" "$dir" >/dev/null 2>&1 || echo "    WARN: could not clone $name (network?)"
    [ -d "$dir/.git" ] && echo "    cloned $name"
  fi
}

sync_repos() {
  echo "==> Updating upstream skill repos"
  update_repo "mattpocock"  "https://github.com/mattpocock/skills.git"
  update_repo "davidondrej" "https://github.com/davidondrej/skills.git"
  # shadcn/improve is a single-skill repo: the repo IS the source of truth for
  # the "improve" skill, so it refreshes the canonical copy (see OWNER_REPOS).
  update_repo "shadcn-improve" "https://github.com/shadcn/improve.git"
  # antonbabenko/terraform-skill - authoritative Terraform/OpenTofu best-practices
  # skill (owner skill; refreshes the "terraform-skill" canonical copy).
  update_repo "terraform-skill" "https://github.com/antonbabenko/terraform-skill.git"
}

# Repos that are the authoritative (owner) source for one specific skill.
# For these, the canonical copy is refreshed from the repo on every sync so
# upstream updates propagate. Format: "repo:skill-name".
OWNER_REPOS=(
  "shadcn-improve:improve"
  "davidondrej:distribute-skill-to-all-agents"
  "terraform-skill:terraform-skill"
)

# ── 1b. Sync command-code's bundled skills ────────────────────────────────
# command-code ships skills in the npm package (agent-browser, design).
# They live at <npm-root>/command-code/skills/<name>/SKILL.md. Copy them into
# the canonical folder so ALL agents get them, not just command-code.
# They refresh whenever command-code updates (they're owned by the package).
CC_BUNDLED_SKILLS=""
for candidate in \
  "/opt/homebrew/lib/node_modules/command-code/skills" \
  "$HOME_DIR/.nvm/versions/node/"*/lib/node_modules/command-code/skills
do
  if [ -d "$candidate" ]; then
    CC_BUNDLED_SKILLS="$candidate"
    break
  fi
done

install_cc_bundled_skills() {
  [ -n "$CC_BUNDLED_SKILLS" ] || return 0
  echo "==> Syncing command-code bundled skills (from $CC_BUNDLED_SKILLS)"
  while IFS= read -r skill_md; do
    local skill_dir name dest
    skill_dir="$(dirname "$skill_md")"
    name="$(basename "$skill_dir")"
    dest="$AGENTS_SKILLS/$name"
    mkdir -p "$AGENTS_SKILLS"
    rm -rf "$dest"
    cp -R "$skill_dir" "$dest"
    echo "    synced command-code skill: $name"
  done < <(find "$CC_BUNDLED_SKILLS" -name SKILL.md -type f 2>/dev/null)
}

# ── 2. Sync repo skills into ~/.agents/skills ─────────────────────────────
# Priority: existing canonical > mattpocock > davidondrej, EXCEPT for skills
# owned by OWNER_REPOS, which always refresh from their repo.
install_repo_skills() {
  local repo="$1" prefix="$2"
  [ -d "$REPO_CACHE/$repo" ] || return 0
  # Skill = any dir containing SKILL.md. davidondrej nests under skills/<cat>/<name>.
  while IFS= read -r skill_md; do
    local skill_dir name dest owner_entry owned_by_repo
    skill_dir="$(dirname "$skill_md")"
    name="$(basename "$skill_dir")"
    dest="$AGENTS_SKILLS/$name"
    # Is this repo the owner of this skill? If so, always refresh.
    owned_by_repo=0
    for owner_entry in "${OWNER_REPOS[@]}"; do
      if [ "${owner_entry%%:*}" = "$repo" ] && [ "${owner_entry##*:}" = "$name" ]; then
        owned_by_repo=1
        break
      fi
    done
    if [ -d "$dest" ] && [ "$owned_by_repo" -ne 1 ]; then
      # Already present from a higher-priority source; skip (do not clobber).
      continue
    fi
    mkdir -p "$AGENTS_SKILLS"
    # Copy so the canonical copy is ours to edit (not tied to the repo cache).
    # For owner skills this replaces the previous canonical copy with the
    # latest upstream (updates propagate).
    rm -rf "$dest"
    cp -R "$skill_dir" "$dest"
    if [ "$owned_by_repo" -eq 1 ]; then
      echo "    refreshed skill: $name (from $prefix, authoritative)"
    else
      echo "    installed skill: $name (from $prefix)"
    fi
  done < <(find "$REPO_CACHE/$repo" -name SKILL.md -type f 2>/dev/null)
}

sync_repo_skills() {
  echo "==> Syncing upstream skills into ~/.agents/skills"
  # mattpocock first (higher priority), then davidondrej (only fills gaps).
  # Owner skills (e.g. improve from shadcn) are refreshed by their owner repo.
  install_repo_skills "mattpocock" "mattpocock/skills"
  install_repo_skills "davidondrej" "davidondrej/skills"
  install_repo_skills "shadcn-improve" "shadcn/improve"
  install_repo_skills "terraform-skill" "antonbabenko/terraform-skill"
  # command-code's bundled skills (agent-browser, design) - always refresh.
  install_cc_bundled_skills
}

# ── 3. Wire canonical skills to every agent ───────────────────────────────
link_agent_dir() {
  local target="$1" link="$2"
  if [ -L "$link" ]; then
    : # already a symlink (correct)
  elif [ -e "$link" ]; then
    # Real dir (e.g. ~/.claude/skills with leftovers). Back it up, then link.
    mv "$link" "${link}.backup-$(date +%Y%m%d%H%M%S)"
    echo "    moved existing $link to backup"
  fi
  mkdir -p "$(dirname "$link")"
  ln -sfn "$target" "$link"
}

wire_agent_links() {
  echo "==> Wiring canonical skills to agents"

  # Claude Code: whole-folder symlink
  link_agent_dir "$AGENTS_SKILLS" "$CLAUDE_SKILLS"
  echo "    ~/.claude/skills -> ~/.agents/skills"

  # Pi: whole-folder symlink (pi reads ~/.pi/agent/skills)
  link_agent_dir "$AGENTS_SKILLS" "$PI_SKILLS"
  echo "    ~/.pi/agent/skills -> ~/.agents/skills"

  # Hermes: independent copy (hermes snapshots at session start)
  mkdir -p "$HERMES_SKILLS"
  rsync -a --delete "$AGENTS_SKILLS/" "$HERMES_SKILLS/"
  echo "    ~/.hermes/skills rsynced"

  # OpenCode + Cursor + Copilot + CommandCode: per-skill symlinks
  # (each dir may hold its own skills too - don't clobber real dirs)
  for dir in "$OPENCODE_SKILLS" "$CURSOR_SKILLS" "$COPILOT_SKILLS" "$COMMANDCODE_SKILLS"; do
    mkdir -p "$dir"
    for skill in "$AGENTS_SKILLS"/*/; do
      [ -d "$skill" ] || continue
      name="$(basename "$skill")"
      link="$dir/$name"
      if [ -e "$link" ] && [ ! -L "$link" ]; then
        continue # real dir owned by the agent - don't clobber
      fi
      ln -sfn "$skill" "$link"
    done
    echo "    $(basename "$dir") wired ($(ls "$dir" | wc -l | tr -d ' ') entries)"
  done
}

# ── main ───────────────────────────────────────────────────────────────────
mkdir -p "$AGENTS_SKILLS"

case "$MODE" in
  --repos) sync_repos ;;
  --local) sync_repo_skills; wire_agent_links ;;
  *)       sync_repos; sync_repo_skills; wire_agent_links ;;
esac

echo "    Done. $(ls "$AGENTS_SKILLS" | wc -l | tr -d ' ') skills in ~/.agents/skills/"
