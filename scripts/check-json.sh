#!/usr/bin/env bash
# check-json.sh - validate all JSON and JSONC config files under home/.
# JSONC comments are stripped with a string-aware parser (a naive // regex
# would break on URLs like https://).

set -u
REPO_ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
FAIL=0

strip_jsonc() {
  python3 - "$1" <<'PY'
import json, sys
s = open(sys.argv[1]).read()
out, i, in_str = [], 0, False
while i < len(s):
    c = s[i]
    if in_str:
        out.append(c)
        if c == "\\":
            out.append(s[i+1]); i += 2; continue
        if c == '"':
            in_str = False
    else:
        if c == '"':
            in_str = True; out.append(c)
        elif c == "/" and i + 1 < len(s) and s[i+1] == "/":
            while i < len(s) and s[i] != "\n":
                i += 1
            continue
        else:
            out.append(c)
    i += 1
json.loads("".join(out))
PY
}

while IFS= read -r f; do
  case "$f" in
    *.jsonc)
      if ! strip_jsonc "$f" 2>/dev/null; then
        echo "INVALID JSONC: $f" >&2
        FAIL=1
      fi
      ;;
    *)
      if ! jq empty "$f" 2>/dev/null; then
        echo "INVALID JSON: $f" >&2
        FAIL=1
      fi
      ;;
  esac
done < <(find "$REPO_ROOT/home" -type f \( -name '*.json' -o -name '*.jsonc' \))

if [ "$FAIL" -ne 0 ]; then
  exit 1
fi
echo "OK: all JSON/JSONC files parse"
