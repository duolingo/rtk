#!/usr/bin/env bash
set -euo pipefail

# Soft caps to prevent further growth of known hotspots.
# Tight enough to force extraction/refactor on growth spikes.

# Use parallel arrays for bash 3.2 compatibility (no associative arrays)
FILES=("src/main.rs" "src/hooks/init.rs" "src/discover/registry.rs" "src/cmds/git/git.rs" "src/cmds/cloud/aws_cmd.rs")
CAPES=("2950" "4050" "3600" "2900" "2850")

fail=0
for i in $(seq 0 $((${#FILES[@]} - 1))); do
  file="${FILES[$i]}"
  limit="${CAPES[$i]}"
  [ -f "$file" ] || continue
  lines=$(wc -l < "$file" | tr -d ' ')
  if [ "$lines" -gt "$limit" ]; then
    echo "FAIL [$file] line count $lines exceeds cap $limit"
    fail=1
  fi
done

if [ "$fail" -ne 0 ]; then
  echo "architecture-size-guard: FAILED"
  exit 1
fi

echo "architecture-size-guard: OK"
