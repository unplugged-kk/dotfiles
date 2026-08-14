#!/usr/bin/env bash
# profile-zsh.sh - measure zsh startup time and find slow parts.
#
# Usage:
#   profile-zsh.sh          - time a cold interactive zsh startup (10 runs, median)
#   profile-zsh.sh --zprof  - run zsh with zprof to find the slowest contributors
#
# The --zprof mode requires `zmodload zsh/zprof` at the very top of your zshrc,
# which home-manager can inject via programs.zsh.initContent.

set -euo pipefail

if [ "${1:-}" = "--zprof" ]; then
  echo "==> zsh/zprof breakdown (needs 'zmodload zsh/zprof' first in zshrc)"
  zsh -i -c 'zprof | head -40'
  exit 0
fi

echo "==> Timing cold interactive zsh startup (10 runs, median)"
RUNS=10
times=()
for i in $(seq 1 "$RUNS"); do
  # -i interactive, -c runs the command then exits. Time is wall-clock.
  start=$(python3 -c 'import time; print(time.perf_counter())')
  zsh -i -c 'exit' 2>/dev/null
  end=$(python3 -c 'import time; print(time.perf_counter())')
  times+=("$(python3 -c "print('%.3f' % ($end - $start))")")
done

# median
sorted=$(printf '%s\n' "${times[@]}" | sort -n)
count=$(echo "$sorted" | wc -l | tr -d ' ')
mid=$(( (count + 1) / 2 ))
median=$(echo "$sorted" | sed -n "${mid}p")
echo "Median startup: ${median}s"
echo "All runs: ${times[*]}"

echo ""
echo "Note: a healthy zsh with autosuggestions + syntax highlighting + starship"
echo "is usually < 300ms. If you're above ~500ms, run profile-zsh.sh --zprof"
echo "to find the slow contributors, or check for slow PATH lookups / plugins."
