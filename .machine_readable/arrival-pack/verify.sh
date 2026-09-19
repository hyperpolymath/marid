#!/usr/bin/env bash
# SPDX-License-Identifier: MPL-2.0
# Copyright (c) 2026 Jonathan D.A. Jewell (hyperpolymath) <j.d.a.jewell@open.ac.uk>
#
# verify.sh — verification for the CLAUDE.md arrival pack.
set -euo pipefail

ROOT="$(git rev-parse --show-toplevel)"
TARGET="$ROOT/CLAUDE.md"

[ -f "$TARGET" ] || { echo "DRIFT: CLAUDE.md missing"; exit 1; }

echo "OK: CLAUDE.md arrival pack is present."
