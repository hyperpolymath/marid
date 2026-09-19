#!/usr/bin/env bash
# SPDX-License-Identifier: MPL-2.0
# One-shot integration test. Requires bootstrapped Julia example and gateway Mix deps.
set -euo pipefail
root=$(cd "$(dirname "$0")/../.." && pwd)
gateway=$(cd "${1:?Usage: run_http_gateway.sh /path/to/patched/gateway}" && pwd)
work=${EVIDENCE_DIR:-$(mktemp -d)}
mkdir -p "$work"
work=$(cd "$work" && pwd)
backend_pid= gateway_pid=
cleanup() {
  code=$?
  trap - EXIT
  for pid in "$backend_pid" "$gateway_pid"; do
    if [[ -n "$pid" ]]; then kill "$pid" 2>/dev/null || true; wait "$pid" 2>/dev/null || true; fi
  done
  if [[ "$code" != 0 ]]; then
    cat "$work"/http-backend.log "$work"/http-gateway.log 2>/dev/null || true
  fi
  echo "HTTP/gateway evidence: $work (exit $code)"
  exit "$code"
}
trap cleanup EXIT
trap 'exit 130' INT
trap 'exit 143' TERM
cd "$root"
export ELIXIR_ERL_OPTIONS=${ELIXIR_ERL_OPTIONS:-+fnu}
export MARID_GATEWAY_URL=http://127.0.0.1:18088
scripts/marid generate capability-spec examples/http_json/service.jl --deny-by-default > "$work/policy.yaml"
MARID_HOST=127.0.0.1 MARID_PORT=18080 julia --startup-file=no --project=examples/http_json examples/http_json/server.jl > "$work/http-backend.log" 2>&1 &
backend_pid=$!
(cd "$gateway" && exec env MIX_ENV=test POLICY_PATH="$work/policy.yaml" BACKEND_URL=http://127.0.0.1:18080 PORT=18088 VERISIMDB_URL=http://127.0.0.1:1 mix run --no-start "$root/test/interop/gateway_server.exs") > "$work/http-gateway.log" 2>&1 &
gateway_pid=$!
bun test test/interop/http_gateway.test.js
kill "$backend_pid"
wait "$backend_pid" 2>/dev/null || true
backend_pid=
bun test test/interop/gateway_unavailable.test.js
