#!/usr/bin/env bash
set -euo pipefail

# check-call-home.sh — block project-owned outbound network / telemetry paths.
#
# RTK is allowed to proxy a network-capable command only when the user asked for
# that command (for example: `rtk curl https://...`). RTK itself must not carry a
# network stack, embed an endpoint, or have CI/hooks exfiltrate project data.
# This scans the full tree and does not depend on git staging, so it works with jj.

fail=0

section() {
  printf '\n== %s ==\n' "$1"
}

mark_fail() {
  fail=1
  printf 'FAIL: %s\n' "$1"
}

print_matches() {
  local matches="$1"
  if [ -n "$matches" ]; then
    printf '%s\n' "$matches" | sed 's/^/  /'
  fi
}

join_by_pipe() {
  local first=1
  for item in "$@"; do
    if [ "$first" -eq 1 ]; then
      printf '%s' "$item"
      first=0
    else
      printf '|%s' "$item"
    fi
  done
}

# Crates that bring an outbound network stack or common HTTP/DNS/TLS clients.
# If RTK ever needs one, that should be a deliberate architecture decision with
# an explicit policy update, not an incidental dependency addition.
BLOCKED_NETWORK_CRATES=(
  reqwest ureq hyper hyper-util h2 h3 tokio async-std smol surf isahc attohttpc minreq ehttp
  curl curl-sys socket2 mio quinn quinn-proto quinn-udp
  trust-dns-resolver trust-dns-client trust-dns-proto hickory-resolver hickory-client hickory-proto
  native-tls rustls rustls-native-certs rustls-pki-types rustls-webpki webpki-roots
  openssl openssl-sys boring boring-sys schannel security-framework
  tungstenite tokio-tungstenite async-tungstenite websocket
  tonic grpcio axum warp actix-web rocket lettre
  paho-mqtt rumqttc lapin nats redis
  postgres tokio-postgres mysql mysql_async mongodb sqlx
  ssh2 thrussh aws-config aws-credential-types aws-smithy-client
)
BLOCKED_CRATES_ALT="$(join_by_pipe "${BLOCKED_NETWORK_CRATES[@]}")"
# Prefix families are matched separately so new AWS SDK service crates cannot
# slide in by picking a not-yet-enumerated package name.
BLOCKED_CRATES_NAME_RE="(${BLOCKED_CRATES_ALT}|aws-sdk-[[:alnum:]_-]+)"
BLOCKED_CRATES_RE="^${BLOCKED_CRATES_NAME_RE}$"

section "Cargo dependency graph has no network stack"

if [ -f Cargo.lock ]; then
  lock_matches=$(awk -F '"' '/^name = "/ { print FILENAME ":" FNR ":" $2 }' Cargo.lock \
    | awk -F ':' -v re="$BLOCKED_CRATES_RE" '$3 ~ re { print }' || true)
  if [ -n "$lock_matches" ]; then
    mark_fail "network-capable crate present in Cargo.lock"
    print_matches "$lock_matches"
  else
    echo "OK Cargo.lock contains no blocked network crates"
  fi
else
  mark_fail "Cargo.lock is missing; cannot verify dependency graph"
fi

if [ -f Cargo.toml ]; then
  toml_direct=$(grep -nE "^[[:space:]]*${BLOCKED_CRATES_NAME_RE}([[:space:]]*=|[[:space:]]*\\{)" Cargo.toml || true)
  toml_alias=$(grep -nE "package[[:space:]]*=[[:space:]]*\"${BLOCKED_CRATES_NAME_RE}\"" Cargo.toml || true)
  toml_matches=$(printf '%s\n%s\n' "$toml_direct" "$toml_alias" | sed '/^$/d')
  if [ -n "$toml_matches" ]; then
    mark_fail "network-capable crate declared in Cargo.toml"
    print_matches "$toml_matches"
  else
    echo "OK Cargo.toml declares no blocked network crates"
  fi
fi

section "Rust/build code has no direct outbound network APIs"

rust_files=()
if [ -d src ]; then
  while IFS= read -r -d '' file; do
    rust_files+=("$file")
  done < <(find src -type f -name '*.rs' -print0)
fi
[ -f build.rs ] && rust_files+=("build.rs")

if [ "${#rust_files[@]}" -gt 0 ]; then
  # This is intentionally broad. False positives should be resolved by design:
  # keep RTK without in-process networking rather than adding allowlisted calls.
  rust_network_re='(std::net|core::net|TcpStream|TcpListener|UdpSocket|ToSocketAddrs|lookup_host|socket2|mio::net|tokio::net|async_std::net|smol::net|reqwest|ureq|hyper::|isahc|surf::|awc::|attohttpc|minreq|curl::|redis::|postgres::|mysql::|mongodb::|sqlx::|libc::(socket|connect|sendto|recvfrom|getaddrinfo))'
  rust_matches=$(grep -nE "$rust_network_re" "${rust_files[@]}" 2>/dev/null || true)
  if [ -n "$rust_matches" ]; then
    mark_fail "direct network API/client usage detected"
    print_matches "$rust_matches"
  else
    echo "OK no direct network APIs in Rust/build code"
  fi

  # Process-assisted egress is only acceptable in the dedicated user-requested
  # curl/wget proxy modules. Everywhere else it is a call-home footgun.
  egress_cmd_re='(Command::new|resolved_command)\("(curl|wget|nc|netcat|ncat|socat|ssh|scp|sftp)"\)'
  egress_matches=$(grep -nE "$egress_cmd_re" "${rust_files[@]}" 2>/dev/null \
    | grep -Ev '^(src/cmds/cloud/curl_cmd\.rs|src/cmds/cloud/wget_cmd\.rs):' || true)
  if [ -n "$egress_matches" ]; then
    mark_fail "network helper process spawned outside a dedicated user proxy"
    print_matches "$egress_matches"
  else
    echo "OK no hidden network helper process usage"
  fi

  hardcoded_egress_re='\.(arg|args)\([^\n]*(https?://|api\.)'
  hardcoded_egress=$(grep -nE "$hardcoded_egress_re" "${rust_files[@]}" 2>/dev/null || true)
  if [ -n "$hardcoded_egress" ]; then
    mark_fail "hard-coded endpoint passed to a child process"
    print_matches "$hardcoded_egress"
  else
    echo "OK no hard-coded endpoint child-process args"
  fi
else
  echo "OK no Rust files found"
fi

section "No telemetry/call-home module names"

name_matches=$(find src build.rs \
  \( -iname '*telemetry*' -o -iname '*call*home*' -o -iname '*phone*home*' -o -iname '*analytics*upload*' \) \
  -print 2>/dev/null || true)
if [ -n "$name_matches" ]; then
  mark_fail "telemetry/call-home-looking source path detected"
  print_matches "$name_matches"
else
  echo "OK no telemetry/call-home source paths"
fi

symbol_matches=""
if [ "${#rust_files[@]}" -gt 0 ]; then
  symbol_matches=$(grep -nE '(TELEMETRY_URL|RTK_TELEMETRY|CALL_HOME|PHONE_HOME|ANALYTICS_ENDPOINT|ANALYTICS_UPLOAD)' "${rust_files[@]}" 2>/dev/null || true)
fi
if [ -n "$symbol_matches" ]; then
  mark_fail "telemetry/call-home-looking symbol detected"
  print_matches "$symbol_matches"
else
  echo "OK no telemetry/call-home symbols"
fi

section "Agent hooks do not perform their own network egress"

hook_files=()
for dir in hooks .github/hooks openclaw; do
  if [ -d "$dir" ]; then
    while IFS= read -r -d '' file; do
      hook_files+=("$file")
    done < <(find "$dir" -type f \
      \( -name '*.sh' -o -name '*.ts' -o -name '*.js' -o -name '*.json' \) \
      ! -name 'test-*' -print0)
  fi
done

if [ "${#hook_files[@]}" -gt 0 ]; then
  hook_egress_re='(^|[[:space:]])(curl|wget|nc|netcat|ncat|socat|ssh|scp|sftp)([[:space:]]|$)|fetch\(|XMLHttpRequest|https\.request|http\.request|node-fetch|axios|WebSocket'
  hook_matches=$(grep -nE "$hook_egress_re" "${hook_files[@]}" 2>/dev/null || true)
  if [ -n "$hook_matches" ]; then
    mark_fail "agent hook network egress detected"
    print_matches "$hook_matches"
  else
    echo "OK hooks have no network egress primitives"
  fi
else
  echo "OK no hook files found"
fi

section "Pre-commit helper scripts do not perform network egress"

prek_files=()
if [ -d scripts/prek ]; then
  while IFS= read -r -d '' file; do
    prek_files+=("$file")
  done < <(find scripts/prek -type f ! -name 'check-call-home.sh' -print0)
fi

if [ "${#prek_files[@]}" -gt 0 ]; then
  prek_egress_re='(^|[[:space:]])(curl|wget|nc|netcat|ncat|socat|ssh|scp|sftp)([[:space:]]|$)|https?://|api\.(anthropic|openai|mistral|groq)\.com|ANTHROPIC_API_KEY|OPENAI_API_KEY|GOOGLE_API_KEY|MISTRAL_API_KEY|GROQ_API_KEY|OPENROUTER_API_KEY'
  prek_matches=$(grep -nE "$prek_egress_re" "${prek_files[@]}" 2>/dev/null || true)
  if [ -n "$prek_matches" ]; then
    mark_fail "pre-commit helper network egress detected"
    print_matches "$prek_matches"
  else
    echo "OK pre-commit helper scripts have no network egress primitives"
  fi
else
  echo "OK no pre-commit helper scripts found"
fi

section "GitHub workflow shell does not call external endpoints"

workflow_files=()
if [ -d .github/workflows ]; then
  while IFS= read -r -d '' file; do
    workflow_files+=("$file")
  done < <(find .github/workflows -type f \( -name '*.yml' -o -name '*.yaml' \) -print0)
fi

if [ "${#workflow_files[@]}" -gt 0 ]; then
  workflow_egress_re='(^|[[:space:]])(curl|wget|nc|netcat|ncat|socat|ssh|scp|sftp)([[:space:]]|$)|api\.(anthropic|openai|mistral|groq)\.com|generativelanguage\.googleapis\.com|openrouter\.ai|ANTHROPIC_API_KEY|OPENAI_API_KEY|GOOGLE_API_KEY|MISTRAL_API_KEY|GROQ_API_KEY|OPENROUTER_API_KEY'
  workflow_matches=$(grep -nE "$workflow_egress_re" "${workflow_files[@]}" 2>/dev/null || true)
  workflow_url_matches=$(grep -nE 'https?://' "${workflow_files[@]}" 2>/dev/null \
    | grep -Ev 'https://github(\\\\)?\.com' || true)
  workflow_matches=$(printf '%s\n%s\n' "$workflow_matches" "$workflow_url_matches" | sed '/^$/d')
  if [ -n "$workflow_matches" ]; then
    mark_fail "workflow-owned network/API egress detected"
    print_matches "$workflow_matches"
  else
    echo "OK workflows have no shell-level external egress"
  fi
else
  echo "OK no workflow files found"
fi

if [ "$fail" -ne 0 ]; then
  cat <<'EOF'

check-call-home: FAILED

RTK must not phone home. To fix this, remove the project-owned egress path.
Allowed: proxying a user-requested network command (for example `rtk curl URL`).
Forbidden: in-process network clients, telemetry endpoints, CI/API exfiltration,
or hidden curl/wget/nc/ssh-style helper calls.
EOF
  exit 1
fi

printf '\ncheck-call-home: OK — no project-owned call-home paths detected\n'
