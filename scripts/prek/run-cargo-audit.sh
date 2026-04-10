#!/usr/bin/env bash
set -euo pipefail

if ! command -v cargo-audit >/dev/null 2>&1; then
  echo "FAIL cargo-audit not installed."
  echo "Install with: cargo install cargo-audit"
  exit 1
fi

cargo audit
