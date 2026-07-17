#!/usr/bin/env bash
set -euo pipefail
DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd -P)"
ln -sfn "$DIR" ~/.dotfiles

# ── Platform detection: drives which activate/build/pkg-upgrade command runs ──
PLATFORM="$(uname -s)"
REAL_USER="$(whoami)"
case "$PLATFORM" in
  Darwin)
    # macOS: full nix-darwin + home-manager + nix-homebrew bundle
    activate()      { sudo /run/current-system/sw/bin/darwin-rebuild switch --flake "$DIR#mac"; }
    activate_dry()  { sudo /run/current-system/sw/bin/darwin-rebuild build  --flake "$DIR#mac" || true; }
    pkg_upgrade()   { brew upgrade --greedy || true; }
    ;;
  Linux)
    # Linux: standalone home-manager, no nix-darwin equivalent (would need NixOS).
    # homeConfigurations."${user}" in flake.nix (set by bootstrap.sh) holds the
    # /home/<user> homeDir for this logged-in account. Same home.nix on both.
    activate()      { home-manager switch --flake "$DIR#${REAL_USER}"; }
    activate_dry()  { home-manager build  --flake "$DIR#${REAL_USER}" || true; }
    pkg_upgrade()   { sudo apt-get update && sudo apt-get upgrade -y || true; }
    ;;
  *)
    echo "Unsupported platform: $PLATFORM" >&2
    exit 1
    ;;
esac

usage() {
  cat <<EOF
Usage: ./rebuild.sh [--upgrade | --dry-run]

Default: rebuild the system with the current flake.lock (fast, no upgrades).

--upgrade, -u
  Full upgrade pass - only packages whose versions changed get rebuilt.
    1. nix flake update         - refresh flake.lock to latest inputs
                                   (nixpkgs / nix-darwin / home-manager)
    2. darwin-rebuild build     - build only what changed (no activation)
    3. darwin-rebuild switch    - activate the new generation
    4. brew upgrade             - bump brew packages that have newer versions
    5. nix profile upgrade '.*'  - bump user-profile packages (none currently)

  Each step is skipped automatically if there's nothing to do.

--dry-run
  Show what --upgrade WOULD change, then exit. Touches flake.lock in memory
  only (restores it before exiting).

--help, -h
  Show this help.

Examples:
  ./rebuild.sh                  # fast: apply current dotfiles, no upgrades
  ./rebuild.sh --upgrade        # bump everything to latest, then activate
  ./rebuild.sh --dry-run        # preview upgrade plan without changes
EOF
}

UPGRADE=false
DRY_RUN=false
for arg in "$@"; do
  case "$arg" in
    --upgrade|-u) UPGRADE=true ;;
    --dry-run)    UPGRADE=true; DRY_RUN=true ;;
    --help|-h)    usage; exit 0 ;;
    *) echo "Unknown arg: $arg"; usage; exit 1 ;;
  esac
done

if [ "$UPGRADE" = false ]; then
  activate
fi

# ── Upgrade flow ────────────────────────────────────────────────────────────
LOCK="$DIR/flake.lock"
LOCK_BAK="$(mktemp -t flake.lock.XXXXXX)"
cp "$LOCK" "$LOCK_BAK"
trap 'cp "$LOCK_BAK" "$LOCK"; rm -f "$LOCK_BAK"' EXIT

cd "$DIR"

echo "==> 1/5: nix flake update (refresh lockfile to latest inputs)"
# Use gh's auth token so we don't hit GitHub's unauthenticated 60-req/hour
# rate limit. Token is read at call time (not stored) and exported only for
# this nix subprocess - it never lands in flake.lock, nix.conf, or git history.
if command -v gh >/dev/null 2>&1 && gh auth status >/dev/null 2>&1; then
  GH_TOKEN_VAL="$(gh auth token 2>/dev/null)"
  if [ -n "$GH_TOKEN_VAL" ]; then
    # Nix looks for github.com in NIX_CONFIG (key=value lines, newline-separated)
    NIX_CONFIG="access-tokens = github.com ${GH_TOKEN_VAL}" nix flake update
  else
    nix flake update
  fi
else
  nix flake update
fi
echo ""

echo "==> 2/5: lockfile diff (what changed)"
if diff -u "$LOCK_BAK" "$LOCK" >/dev/null 2>&1; then
  echo "    (no lockfile changes - nothing new upstream)"
else
  diff -u "$LOCK_BAK" "$LOCK" || true
fi
echo ""

if [ "$DRY_RUN" = true ]; then
  echo "==> 3/5: DRY-RUN - showing build plan, NOT activating"
  activate_dry
  echo ""
  echo "==> 4/5: DRY-RUN - skipping brew upgrade"
  echo "==> 5/5: DRY-RUN - skipping nix profile upgrade"
  echo ""
  echo "DRY-RUN complete. Lockfile restored. Re-run without --dry-run to apply."
  exit 0
fi

echo "==> 3/5: $( [[ "$PLATFORM" = Linux ]] && echo home-manager || echo darwin-rebuild ) switch (apply upgraded system)"
activate
echo ""

echo "==> 4/5: $( [[ "$PLATFORM" = Linux ]] && echo 'apt upgrade' || echo 'brew upgrade' ) (latest system packages)"
pkg_upgrade
echo ""

echo "==> 5/5: nix profile upgrade (user-profile packages)"
# Currently empty (everything is declarative via configuration.nix / home.nix),
# but kept for future when ad-hoc packages get installed via `nix profile install`.
nix profile upgrade '.*' 2>/dev/null || echo "    (no user-profile packages to upgrade)"
echo ""

rm -f "$LOCK_BAK"
trap - EXIT

echo "==> Done. New system generation active."
echo "    Compare generations:  darwin-rebuild --list-generations"
echo "    Roll back if needed:  darwin-rebuild --rollback"
