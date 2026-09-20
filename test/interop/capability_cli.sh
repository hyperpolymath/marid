#!/usr/bin/env bash
# SPDX-License-Identifier: MPL-2.0
set -euo pipefail
root="$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")/../.." && pwd)"
work="$(mktemp -d)"
trap 'rm -rf -- "$work"' EXIT
cd "$work"
cli="$root/scripts/marid"
fixture="$root/fixtures/capability/service.jl"
# Dollar signs and spaces are passed as data, not interpolated Julia source.
cp "$fixture" 'service $(not-a-command) "quoted".jl'
"$cli" generate capability-spec 'service $(not-a-command) "quoted".jl' --global-verbs GET > actual.yaml 2> warning.log
cmp actual.yaml "$root/fixtures/capability/policy.yaml"
grep -q 'not a deny-by-default' warning.log
"$cli" generate capability-spec "$fixture" --global-verbs get,GET > again.yaml 2>/dev/null
cmp actual.yaml again.yaml
reject() {
    if "$cli" "$@" > rejected.out 2> rejected.err; then
        echo "Expected CLI failure: $*" >&2; exit 1
    fi
    test ! -s rejected.out
    test -s rejected.err
}
reject generate capability-spec "$fixture"
reject generate capability-spec missing.jl --global-verbs GET
reject generate capability-spec "$fixture" --global-verbs TRACE
reject generate capability-spec "$fixture" --global-verbs GET,
reject generate capability-spec "$fixture" --global-verbs GET extra
printf '42\n' > wrong.jl
reject generate capability-spec wrong.jl --global-verbs GET
# A failed generation must never truncate a live policy: --out writes aside and
# renames only on success, so the file and its contents survive the failure.
printf 'live\n' > expected.yaml
printf 'live\n' > policy-under-test.yaml
reject generate capability-spec wrong.jl --global-verbs GET --out policy-under-test.yaml
cmp policy-under-test.yaml expected.yaml
if ls policy-under-test.yaml.tmp.* >/dev/null 2>&1; then
    echo "--out left a temporary file behind" >&2; exit 1
fi
{ printf 'println("descriptor diagnostic")\n'; cat "$fixture"; } > noisy.jl
"$cli" generate capability-spec noisy.jl --global-verbs GET > noisy.yaml 2> noisy.err
cmp noisy.yaml actual.yaml
grep -q 'descriptor diagnostic' noisy.err
"$cli" generate capability-spec "$fixture" --deny-by-default > strict.yaml 2> strict.err
cmp strict.yaml "$root/fixtures/capability/policy-strict.yaml"
grep -q '#112' strict.err
echo 'Capability CLI checks passed (external cwd, quoting, deterministic YAML, diagnostics, seven rejection cases).'
