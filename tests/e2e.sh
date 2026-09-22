#!/usr/bin/env bash
# SPDX-License-Identifier: MPL-2.0
# Copyright (c) 2026 Jonathan D.A. Jewell (hyperpolymath) <j.d.a.jewell@open.ac.uk>
#
# RSR Standard E2E Test Template
#
# End-to-end tests validate the full pipeline: build → run → verify output.
# Customise this file for your project. Delete the examples that don't apply.
#
# Usage:
#   bash tests/e2e.sh
#   just e2e
#
# Merge requirements (STANDING): All 6 test categories must pass before merge:
#   P2P, E2E (this file), aspect, execution, lifecycle, benchmarks

set -euo pipefail

PASS=0
FAIL=0
SKIP=0

# ─── Colour helpers ──────────────────────────────────────────────────
green() { printf '\033[32m%s\033[0m\n' "$*"; }
red()   { printf '\033[31m%s\033[0m\n' "$*"; }
yellow(){ printf '\033[33m%s\033[0m\n' "$*"; }

echo "═══════════════════════════════════════════════════════════════"
echo "  MARID — End-to-End Tests"
echo "═══════════════════════════════════════════════════════════════"
echo ""

# ═══════════════════════════════════════════════════════════════════════
# Template instantiation
# ═══════════════════════════════════════════════════════════════════════
# This is the harness CI runs (.github/workflows/e2e.yml calls tests/e2e.sh),
# so the instantiation test has to be called from here to run at all. Until
# now its only caller was benches/template_bench.sh, which discards the exit
# code with `|| true` because a benchmark wants a duration, not a verdict —
# so the test could fail on every run and nothing said so.
INSTANTIATION_TEST="$(dirname "$0")/e2e/template_instantiation_test.sh"
if [ -f "$INSTANTIATION_TEST" ]; then
    echo ""
    echo "── Template instantiation ─────────────────────────────────────"
    if bash "$INSTANTIATION_TEST" "$(dirname "$0")/.."; then
        green "PASS: template instantiation"
        PASS=$((PASS + 1))
    else
        red "FAIL: template instantiation"
        FAIL=$((FAIL + 1))
    fi
else
    yellow "SKIP: template instantiation (test not found)"
    SKIP=$((SKIP + 1))
fi

# ═══════════════════════════════════════════════════════════════════════
# Summary
# ═══════════════════════════════════════════════════════════════════════
echo ""
echo "═══════════════════════════════════════════════════════════════"
printf "  Results: "
green "PASS=$PASS" | tr -d '\n'
echo -n "  "
if [ "$FAIL" -gt 0 ]; then red "FAIL=$FAIL" | tr -d '\n'; else echo -n "FAIL=0"; fi
echo -n "  "
if [ "$SKIP" -gt 0 ]; then yellow "SKIP=$SKIP"; else echo "SKIP=0"; fi
echo "═══════════════════════════════════════════════════════════════"

exit "$FAIL"
