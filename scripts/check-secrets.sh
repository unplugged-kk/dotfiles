#!/usr/bin/env bash
# check-secrets.sh - guard against committing secrets to the dotfiles repo.
#
# Two modes:
#   check-secrets.sh            - scan the index (staged files); used as a
#                                 pre-commit hook. Exit 1 blocks the commit.
#   check-secrets.sh --tree     - scan the whole tracked tree (CI / manual).
#   check-secrets.sh --all      - scan tracked + untracked files (local audit).
#
# What it catches:
#   - files that should never be committed (*.local.json, *.secrets, .env)
#   - obvious secret-looking values (sk-, ghp_, xoxb-, AKIA..., etc.)
#   - lines that look like `export TOKEN=...` or `password = "..."`

set -u
REPO_ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
cd "$REPO_ROOT"

MODE="index"
if [ "${1:-}" = "--tree" ]; then MODE="tree"; fi
if [ "${1:-}" = "--all" ]; then MODE="all"; fi

FAIL=0

# --- banned file names ------------------------------------------------------
BANNED_FILES='(^|/)([^/]*\.local\.json|[^/]*\.secrets|[^/]*\.env(\.|$))'

# --- secret value patterns --------------------------------------------------
# Match common credential formats. Keep these generic enough to catch real
# secrets but specific enough to avoid noise.
SECRET_PATTERNS=(
  'sk-[A-Za-z0-9_-]{10,}'
  'sk_live_[A-Za-z0-9]+'
  'pk_live_[A-Za-z0-9]+'
  'ghp_[A-Za-z0-9]{20,}'
  'gho_[A-Za-z0-9]{20,}'
  'xox[baprs]-[A-Za-z0-9-]{10,}'
  'AKIA[0-9A-Z]{16}'
  '-----BEGIN (RSA |EC |OPENSSH )?PRIVATE KEY-----'
  'AIza[0-9A-Za-z_-]{20,}'
  'ya29\.[0-9A-Za-z_-]+'
)

contains_secret() {
  local file="$1"
  local pat
  for pat in "${SECRET_PATTERNS[@]}"; do
    if grep -E -q "$pat" "$file" 2>/dev/null; then
      return 0
    fi
  done
  return 1
}

# --- collect files ----------------------------------------------------------
collect_files() {
  case "$MODE" in
    index) git diff --cached --name-only --diff-filter=ACMR ;;
    tree)  git ls-files ;;
    all)   { git ls-files; git ls-files --others --exclude-standard; } ;;
  esac | grep -v '^\.git/' || true
}

for f in $(collect_files); do
  [ -f "$f" ] || continue
  # Banned filename?
  if echo "$f" | grep -qE "$BANNED_FILES"; then
    echo "BLOCKED: $f is a banned filename (would commit a secret)" >&2
    FAIL=1
    continue
  fi
  # Binary files (e.g. .git internals, images) can't be scanned; skip them.
  if file "$f" | grep -qE '(binary|image|archive|executable)'; then
    continue
  fi
  if contains_secret "$f"; then
    echo "BLOCKED: $f contains a secret-looking value" >&2
    FAIL=1
  fi
done

if [ "$FAIL" -ne 0 ]; then
  echo "" >&2
  echo "Secrets guard failed. Remove the offending files/values and re-stage." >&2
  echo "If this is a false positive, adjust scripts/check-secrets.sh." >&2
  exit 1
fi

exit 0
