#!/usr/bin/env bash
set -euo pipefail

fail=0

for file in "$@"; do
  [[ "$file" =~ ^src/cmds/.+_cmd\.rs$ ]] || continue
  [ -f "$file" ] || continue

  if ! grep -nE '^[[:space:]]*#\[cfg\(test\)\]' "$file" >/dev/null; then
    echo "FAIL [$file] missing #[cfg(test)] module"
    fail=1
  fi
done

if [ "$fail" -ne 0 ]; then
  echo "cmd-module-has-tests: FAILED"
  exit 1
fi

echo "cmd-module-has-tests: OK"
