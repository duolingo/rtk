#!/usr/bin/env bash
set -euo pipefail

# Soft caps to prevent further growth of known hotspots.
# Tight enough to force extraction/refactor on growth spikes.

declare -A CAP
CAP["src/main.rs"]=2400
CAP["src/hooks/init.rs"]=3120
CAP["src/discover/registry.rs"]=2430
CAP["src/cmds/git/git.rs"]=2440
CAP["src/cmds/cloud/aws_cmd.rs"]=2780

fail=0
for file in "${!CAP[@]}"; do
  [ -f "$file" ] || continue
  lines=$(wc -l < "$file" | tr -d ' ')
  limit=${CAP[$file]}
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
