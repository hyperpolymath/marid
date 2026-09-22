#!/usr/bin/env bash
# SPDX-License-Identifier: MPL-2.0

# Self-test for the workflow-coverage clause in scripts/check-lock-sync.sh.
# Each case uses a private workflow directory so failures identify the clause
# being exercised instead of depending on the repository's current lockfile.

set -euo pipefail

ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/../.." && pwd)"
CHECKER="$ROOT/scripts/check-lock-sync.sh"
FIXTURE="$(mktemp -d)"
WORKFLOWS="$FIXTURE/.github/workflows"
trap 'rm -rf "$FIXTURE"' EXIT

reset_fixture() {
    rm -rf "$WORKFLOWS"
    mkdir -p "$WORKFLOWS"
}

write_workflow() {
    local name="$1"
    cat > "$WORKFLOWS/$name" <<'YAML'
name: Fixture
on: workflow_dispatch
jobs: {}
YAML
}

expect_pass() {
    local label="$1"
    local output
    if ! output=$("$CHECKER" "$WORKFLOWS" 2>&1); then
        printf 'FAIL: %s\n%s\n' "$label" "$output" >&2
        exit 1
    fi
    printf '%s\n' "$output"
}

expect_fail() {
    local label="$1"
    local output_file="$2"
    if "$CHECKER" "$WORKFLOWS" > "$output_file" 2>&1; then
        printf 'FAIL: checker accepted %s\n' "$label" >&2
        exit 1
    fi
}

assert_contains() {
    local file="$1"
    local expected="$2"
    if ! grep -Fq -- "$expected" "$file"; then
        printf 'FAIL: expected output to contain %q\n' "$expected" >&2
        sed -n '1,160p' "$file" >&2
        exit 1
    fi
}

# A zero-uses workflow is covered by an explicit empty-list entry. Cover both
# supported workflow extensions so the path canonicalisation is exercised.
reset_fixture
write_workflow alpha.yml
write_workflow beta.yaml
cat > "$WORKFLOWS/actions.lock" <<'YAML'
version: 'v0.0.2'
workflows:
    '.github/workflows/alpha.yml': []
    '.github/workflows/beta.yaml': []
dependencies:
YAML
pass_output="$FIXTURE/pass.out"
expect_pass "covered .yml and .yaml workflows" > "$pass_output"
assert_contains "$pass_output" "every workflow file has a lockfile key (zero-uses: workflows included)"

# Regression: clauses 1-3 are vacuously satisfied for a workflow with no
# `uses:` lines. Clause 4 must reject it, name its canonical path, and explain
# the empty-list repair without misclassifying it as an unlocked action.
reset_fixture
write_workflow covered.yml
write_workflow unlisted.yml
cat > "$WORKFLOWS/actions.lock" <<'YAML'
version: 'v0.0.2'
workflows:
    '.github/workflows/covered.yml': []
dependencies:
YAML
single_output="$FIXTURE/single.out"
expect_fail "an unlisted zero-uses workflow" "$single_output"
assert_contains "$single_output" "FAIL actions.lock: UNLISTED WORKFLOWS"
assert_contains "$single_output" "1 workflow file(s) have no key in the lockfile"
assert_contains "$single_output" ".github/workflows/unlisted.yml"
assert_contains "$single_output" "'.github/workflows/x.yml': []"
if grep -Fq "unlocked refs" "$single_output"; then
    echo "FAIL: a zero-uses workflow was reported as having unlocked refs" >&2
    exit 1
fi

# Report every missing path, not only the first one, and keep the count exact
# across the two filename extensions accepted by the checker.
write_workflow second-missing.yaml
multiple_output="$FIXTURE/multiple.out"
expect_fail "multiple unlisted workflows" "$multiple_output"
assert_contains "$multiple_output" "2 workflow file(s) have no key in the lockfile"
assert_contains "$multiple_output" ".github/workflows/unlisted.yml"
assert_contains "$multiple_output" ".github/workflows/second-missing.yaml"

# A similarly named lock entry must not cover a workflow with a different
# extension. This guards the exact-path comparison at the lockfile boundary.
reset_fixture
write_workflow same-name.yaml
cat > "$WORKFLOWS/actions.lock" <<'YAML'
version: 'v0.0.2'
workflows:
    '.github/workflows/same-name.yml': []
dependencies:
YAML
extension_output="$FIXTURE/extension.out"
expect_fail "a lock key with the wrong extension" "$extension_output"
assert_contains "$extension_output" ".github/workflows/same-name.yml"
assert_contains "$extension_output" "lockfile entry for a workflow file that does not exist"
assert_contains "$extension_output" ".github/workflows/same-name.yaml"
assert_contains "$extension_output" "1 workflow file(s) have no key in the lockfile"

# A missing key for a workflow that does use an external action must still be
# included in the coverage report in addition to the existing clause-1 error.
reset_fixture
cat > "$WORKFLOWS/action-user.yml" <<'YAML'
name: Action user
on: workflow_dispatch
jobs:
  test:
    runs-on: ubuntu-latest
    steps:
      - uses: actions/checkout@v7.0.1
YAML
cat > "$WORKFLOWS/actions.lock" <<'YAML'
version: 'v0.0.2'
workflows:
dependencies:
YAML
action_output="$FIXTURE/action.out"
expect_fail "an unlisted workflow with an external action" "$action_output"
assert_contains "$action_output" "not onboarded: no lockfile entry for this path"
assert_contains "$action_output" "unlocked refs: actions/checkout@v7.0.1"
assert_contains "$action_output" "FAIL actions.lock: UNLISTED WORKFLOWS"
assert_contains "$action_output" ".github/workflows/action-user.yml"

# Keep the two repository-level configuration fixes covered as regressions:
# the gate itself has an explicit empty-list lock entry and can be dispatched
# manually after a startup failure prevents GitHub's normal rerun operation.
assert_contains "$ROOT/.github/workflows/actions.lock" "'.github/workflows/lock-sync-gate.yml': []"
if ! "$CHECKER" "$ROOT/.github/workflows"; then
    echo "FAIL: repository workflows are not accepted by check-lock-sync" >&2
    exit 1
fi
if ! grep -Fqx "  workflow_dispatch:" "$ROOT/.github/workflows/lock-sync-gate.yml"; then
    echo "FAIL: lock-sync-gate.yml has no workflow_dispatch trigger" >&2
    exit 1
fi

echo "PASS: workflow coverage and lock-sync gate regressions are covered"
