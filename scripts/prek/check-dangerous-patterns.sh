#!/usr/bin/env bash
set -euo pipefail

fail=0

check_added_lines() {
  local file="$1"
  local added
  added=$(jj diff --color never --git -- "$file" | sed -n 's/^+//p' | grep -v '^+++' || true)

  [ -z "$added" ] && return 0

  # Security-sensitive shell spawning patterns.
  if echo "$added" | rg -n 'Command::new\("(sh|bash)"\)' >/dev/null; then
    echo "FAIL [$file] direct shell spawn detected (Command::new(\"sh\"|\"bash\"))."
    fail=1
  fi

  # Panic/debug markers in production code.
  if echo "$added" | rg -n '(^|[^[:alnum:]_])(todo!|unimplemented!|dbg!)\s*\(' >/dev/null; then
    echo "FAIL [$file] todo!/unimplemented!/dbg! added."
    fail=1
  fi

  # Suspicious env mutation patterns.
  if echo "$added" | rg -n '\.env\("(LD_PRELOAD|PATH)"' >/dev/null; then
    echo "FAIL [$file] .env(\"LD_PRELOAD\"|\"PATH\") added."
    fail=1
  fi
}

for f in "$@"; do
  [[ "$f" == *.rs ]] || continue
  [ -f "$f" ] || continue
  check_added_lines "$f"
done

if [ "$fail" -ne 0 ]; then
  echo "dangerous-patterns-in-added-rust-lines: FAILED"
  exit 1
fi

echo "dangerous-patterns-in-added-rust-lines: OK"
