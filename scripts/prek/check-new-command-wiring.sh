#!/usr/bin/env bash
set -euo pipefail

# If a new src/cmds/*_cmd.rs is added, require routing/wiring updates.
# Enforces command architecture coupling:
#   - src/main.rs (CLI wiring)
#   - src/discover/rules.rs (rewrite routing)

status_lines=$(jj status --color never | sed -n 's/^\([AMD]\) \(.*\)$/\1 \2/p')

added_cmds=$(echo "$status_lines" | awk '$1=="A" && $2 ~ /^src\/cmds\/.+_cmd\.rs$/ {print $2}')

if [ -z "$added_cmds" ]; then
  echo "new-command-wiring-guard: OK (no new *_cmd.rs files)"
  exit 0
fi

changed_files=$(echo "$status_lines" | awk '{print $2}')

missing=0
if ! echo "$changed_files" | grep -nE '^src/main\.rs$' >/dev/null; then
  echo "FAIL new command module added, but src/main.rs was not updated"
  missing=1
fi
if ! echo "$changed_files" | grep -nE '^src/discover/rules\.rs$' >/dev/null; then
  echo "FAIL new command module added, but src/discover/rules.rs was not updated"
  missing=1
fi

if [ "$missing" -ne 0 ]; then
  echo "new-command-wiring-guard: FAILED"
  echo "Added command modules:"
  echo "$added_cmds" | sed 's/^/  - /'
  exit 1
fi

echo "new-command-wiring-guard: OK"
