#!/usr/bin/env bash
# sync-skills.sh - keep every agent's skill folder in sync with the canonical
# ~/.agents/skills/ directory, and pull in the upstream skill repos.
#
# Canonical layout (see ~/.agents/skills/distribute-skill-to-all-agents/SKILL.md):
#   ~/.agents/skills/           canonical authoring location
#   ~/.claude/skills            -> ~/.agents/skills   (symlink)
#   ~/.pi/agent/skills          -> ~/.agents/skills   (symlink)
#   ~/.hermes/skills/           independent copy (rsync; hermes snapshots)
#   ~/.codex/skills             per-skill symlinks
#   ~/.cursor/skills            per-skill symlinks (Cursor Code / IDE skills)
#   ~/.cursor/skills-cursor/    per-skill symlinks (Cursor CLI bundled dir)
#   ~/.grok/skills              per-skill symlinks
#   ~/.gemini/skills            per-skill symlinks
#   ~/.config/opencode/skills       per-skill symlinks (opencode2)
#   ~/.copilot/skills/          per-skill symlinks
#   ~/.commandcode/skills/      per-skill symlinks
#   ~/.kiro/skills              per-skill symlinks
#   ~/.windsurf/skills          per-skill symlinks
#   ~/.adal/skills              per-skill symlinks
#
# Upstream skill repos are shallow-cloned into ~/.agents/skill-repos/ and their
# skills (any dir containing SKILL.md) synced into ~/.agents/skills/.
#
# Collision policy: if two sources provide the same skill name, the existing
# canonical copy wins; then the first repo to install it keeps it. Repos install
# in the order listed in SYNC_REPOS. Skills listed in OWNER_REPOS are "owned" by
# their upstream repo and are ALWAYS refreshed from it on every sync, so updates
# propagate (e.g. shadcn/improve -> "improve", antonbabenko/terraform-skill).
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
OPENCODE_CONFIG_SKILLS="$HOME_DIR/.config/opencode/skills"
CURSOR_SKILLS="$HOME_DIR/.cursor/skills"
CURSOR_SKILLS_CURSOR="$HOME_DIR/.cursor/skills-cursor"
COPILOT_SKILLS="$HOME_DIR/.copilot/skills"
COMMANDCODE_SKILLS="$HOME_DIR/.commandcode/skills"
CODEX_SKILLS="$HOME_DIR/.codex/skills"
GROK_SKILLS="$HOME_DIR/.grok/skills"
GEMINI_SKILLS="$HOME_DIR/.gemini/skills"
KIRO_SKILLS="$HOME_DIR/.kiro/skills"
WINDSURF_SKILLS="$HOME_DIR/.windsurf/skills"
ADAL_SKILLS="$HOME_DIR/.adal/skills"

MODE="${1:-all}"

# name|git-url|display (clone dir name is the "name" - keep it stable so OWNER_REPOS
# and the per-repo exclude rules below can reference it).
SYNC_REPOS=(
  "mattpocock|https://github.com/mattpocock/skills.git|mattpocock/skills"
  "davidondrej|https://github.com/davidondrej/skills.git|davidondrej/skills"
  "superpowers|https://github.com/obra/superpowers.git|obra/superpowers"
  "anthropics|https://github.com/anthropics/skills.git|anthropics/skills"
  "gstack|https://github.com/garrytan/gstack.git|garrytan/gstack"
  "uiux-pro-max|https://github.com/nextlevelbuilder/ui-ux-pro-max-skill.git|nextlevelbuilder/ui-ux-pro-max-skill"
  "addyosmani|https://github.com/addyosmani/agent-skills.git|addyosmani/agent-skills"
  "ai-agents-skills|https://github.com/hoodini/ai-agents-skills.git|hoodini/ai-agents-skills"
  "ai-toolkit|https://github.com/c0x12c/ai-toolkit.git|c0x12c/ai-toolkit"
  "shadcn-improve|https://github.com/shadcn/improve.git|shadcn/improve"
  "terraform-skill|https://github.com/antonbabenko/terraform-skill.git|antonbabenko/terraform-skill"
)

# Repos that are the authoritative (owner) source for one specific skill.
# For these, the canonical copy is refreshed from the repo on every sync so
# upstream updates propagate. Format: "repo:skill-name".
OWNER_REPOS=(
  "shadcn-improve:improve"
  "davidondrej:distribute-skill-to-all-agents"
  "terraform-skill:terraform-skill"
)

# ── 1. Update upstream repos ───────────────────────────────────────────────
update_repo() {
  local name="$1" url="$2"
  local dir="$REPO_CACHE/$name"
  if [ -d "$dir/.git" ]; then
    # Auto-set the default branch so `master`-only repos reset correctly.
    git -C "$dir" remote set-head origin --auto >/dev/null 2>&1 || true
    git -C "$dir" fetch --depth 1 origin >/dev/null 2>&1 || true
    local head="origin/$(git -C "$dir" symbolic-ref --short refs/remotes/origin/HEAD 2>/dev/null | sed 's|origin/||')"
    head="${head:-origin/main}"
    git -C "$dir" reset --hard "$head" >/dev/null 2>&1 || \
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
  local name url display
  for entry in "${SYNC_REPOS[@]}"; do
    name="${entry%%|*}"; rest="${entry#*|}"
    url="${rest%%|*}";           display="${rest#*|}"
    update_repo "$name" "$url" || true
  done
}

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
# Skip paths a repo carries that aren't consumer skills (templates, test
# fixtures, internal sub-projects, duplicate copies of the same skills).
# rel is the SKILL.md path relative to the repo root (e.g. "skills/x/SKILL.md").
skill_path_skipped() {
  local repo="$1" rel="$2"
  case "$repo:$rel" in
    anthropics:template/*)   return 0 ;;
    # gstack ships a router SKILL.md at the repo root; installing it drags the
    # entire repo tree (test fixtures, openclaw, bundler locks) into the hub.
    gstack:SKILL.md)         return 0 ;;
    gstack:openclaw/*)       return 0 ;;
    gstack:test/*)           return 0 ;;
    ai-agents-skills:templates/*) return 0 ;;
    ai-toolkit:.codex/*)     return 0 ;;   # toolkit/skills is the full set
    uiux-pro-max:cli/*)      return 0 ;;   # .claude/skills is the consumer set
  esac
  return 1
}

install_repo_skills() {
  local repo="$1" prefix="$2"
  [ -d "$REPO_CACHE/$repo" ] || return 0
  # Skill = any dir containing SKILL.md. MattPocock nests under skills/<cat>/<name>,
  # DavidOndrej under skills/<cat>/<name>, deep repos under .claude/skills etc.
  while IFS= read -r skill_md; do
    local skill_dir name dest owner_entry owned_by_repo rel
    rel="${skill_md#$REPO_CACHE/$repo/}"
    skill_path_skipped "$repo" "$rel" && continue
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

# ── 2b. Sync this dotfiles repo's own skills (skill-orchestrator) ─────────
# ~/.dotfiles/skills/* are authored here; the canonical hub should always carry
# the latest version, so every agent sees them.
install_dotfiles_skills() {
  local dot_skills="$HOME_DIR/.dotfiles/skills"
  [ -d "$dot_skills" ] || return 0
  echo "==> Syncing repo-local skills (from $dot_skills)"
  mkdir -p "$AGENTS_SKILLS"
  while IFS= read -r skill_md; do
    local skill_dir name dest
    skill_dir="$(dirname "$skill_md")"
    name="$(basename "$skill_dir")"
    dest="$AGENTS_SKILLS/$name"
    rm -rf "$dest"
    cp -R "$skill_dir" "$dest"
    echo "    synced repo-local skill: $name"
  done < <(find "$dot_skills" -name SKILL.md -type f 2>/dev/null)
}

sync_repo_skills() {
  echo "==> Syncing upstream skills into ~/.agents/skills"
  local name rest display
  for entry in "${SYNC_REPOS[@]}"; do
    name="${entry%%|*}"; rest="${entry#*|}"
    display="${rest#*|}"
    install_repo_skills "$name" "$display"
  done
  # command-code's bundled skills (agent-browser, design) - always refresh.
  install_cc_bundled_skills
  # There is no modern standardized entry for VoltAgent/awesome-agent-skills:
  # it is a curated *index* of 1497+ skills from other repos (0 SKILL.md files),
  # not an installable pack. It is referenced as a discovery catalog from the
  # README and skill-orchestrator instead of being installed here.
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

  # Agents that scan a single skills folder: whole-folder symlink.
  link_agent_dir "$AGENTS_SKILLS" "$CLAUDE_SKILLS"
  echo "    ~/.claude/skills -> ~/.agents/skills"
  link_agent_dir "$AGENTS_SKILLS" "$PI_SKILLS"
  echo "    ~/.pi/agent/skills -> ~/.agents/skills"

  # Hermes: independent copy (hermes snapshots at session start).
  mkdir -p "$HERMES_SKILLS"
  rsync -a --delete "$AGENTS_SKILLS/" "$HERMES_SKILLS/"
  echo "    ~/.hermes/skills rsynced"

  # Everything else: per-skill symlinks so each dir may keep its own skills too.
  local dir
  for dir in "$CODEX_SKILLS" "$CURSOR_SKILLS" "$CURSOR_SKILLS_CURSOR" \
             "$GROK_SKILLS" "$GEMINI_SKILLS" \
             "$OPENCODE_CONFIG_SKILLS" "$COPILOT_SKILLS" \
             "$COMMANDCODE_SKILLS" "$KIRO_SKILLS" "$WINDSURF_SKILLS" \
             "$ADAL_SKILLS"; do
    mkdir -p "$dir"
    # Drop stale symlinks whose target vanished from the hub (e.g. skill renamed
    # or intentionally removed upstream) so every agent dir reflects the hub.
    for existing in "$dir"/*; do
      [ -L "$existing" ] || continue
      [ -e "$existing" ] || rm -f "$existing"
    done
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
  --local) sync_repo_skills; install_dotfiles_skills; wire_agent_links ;;
  *)       sync_repos; sync_repo_skills; install_dotfiles_skills; wire_agent_links ;;
esac

echo "    Done. $(ls "$AGENTS_SKILLS" | wc -l | tr -d ' ') skills in ~/.agents/skills/"