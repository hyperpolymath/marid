<!--
SPDX-License-Identifier: CC-BY-SA-4.0
Copyright (c) 2026 Jonathan D.A. Jewell <j.d.a.jewell@open.ac.uk>
-->

# AGENTS.md — Marid repository instructions

Read PROJECT_BRIEF.md before making architectural changes.

Implement only the currently approved task or gate.
Do not silently expand scope or weaken acceptance criteria.

Prefer maintained dependencies over new protocol/runtime implementations.
Record architectural choices in docs/adr/.
Record evidence and version-specific findings in docs/audits/.

Do not introduce circular package dependencies.
Keep integrations optional and independently usable.

Preserve required third-party notices.
Do not publish, register packages, deploy services, or use paid services
without approval.

Report what was implemented, what was actually tested, what was not tested,
and what remains blocked. Never equate mocks or skipped tests with
interoperability.

## Repository-specific notes (Marid on the RSR estate)

These notes adapt the brief's file layout to estate compliance rules. They
do not change the brief's requirements.

- The brief is canonical at `PROJECT_BRIEF.md` (repository root). Do not
  edit its requirements without owner approval.
- Estate rule: general documentation under `docs/` is AsciiDoc (`.adoc`),
  never Markdown. The brief's `docs/*.md` names therefore map as follows:
  - `docs/architecture.md` → `docs/marid-architecture.adoc`
  - `docs/compatibility.md` → `docs/marid-compatibility.adoc`
  - `docs/roadmap.md` → `docs/marid-roadmap.adoc`
  - `docs/audits/*.md` → `docs/audits/*.adoc`
  - `docs/adr/*` → `docs/adr/*.adoc` (project ADRs; the RSR template's own
    decisions remain in `docs/decisions/`)
- Root shape is enforced by `.machine_readable/root-allow.txt` (CI fails
  on drift). New root entries must be added there with a justifying comment.
- `docs/architecture/REPOSITORY-MAP.adoc` is generated. After adding,
  moving, or deleting files, run `just repo-map` before committing; CI
  fails if the map is stale.
- `CLAUDE.md` is generated from the `.a2ml` sources (`just claude-md`).
  Do not hand-edit it; edit the `.a2ml` sources and regenerate.
- Julia packages live in `packages/` with one `Project.toml` each (from
  Gate 2). There is intentionally no `Project.toml` at the repository root.
- The `src/interface/` Idris2/Zig seam is retained RSR spine, required by
  `just validate`. It is not Marid application code.
- Gate kickoff prompts (Gate 0 assignment, bounded-task prompt, worker
  division) live in `docs/agent-launch.adoc`.
