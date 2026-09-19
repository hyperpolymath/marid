<!--
SPDX-License-Identifier: CC-BY-SA-4.0
Copyright (c) 2026 Jonathan D.A. Jewell <j.d.a.jewell@open.ac.uk>
-->

# Third-party notices

This file records third-party material carried in this repository, per the
licensing commitments in `PROJECT_BRIEF.md` §1 (third-party material retains
its required licenses and notices).

## License texts

- `LICENSES/MPL-2.0.txt` — Mozilla Public License 2.0 (code, configuration,
  scripts).
- `LICENSES/CC-BY-SA-4.0.txt` — Creative Commons Attribution-ShareAlike 4.0
  (documentation prose and original documentation artwork).

Per-file `SPDX-License-Identifier` headers are authoritative. `REUSE.toml`
states the repository's license mapping.

## Vendored third-party material

None as of 2026-09-18. This repository currently contains only original
scaffolding minted from `hyperpolymath/rsr-template-repo` (MPL-2.0 /
CC-BY-SA-4.0, same rightsholder) plus the original Marid brief and skeleton.

When Gate 0–2 work vendors or pins third-party material (schemas, IDL files,
generated code, fixtures, artwork, documentation excerpts), each item must be
listed here with its source, version, license, and required notices, and the
corresponding entries must be added to `REUSE.toml`.

## Dependencies (not vendored)

Runtime and development dependencies are declared per package
(`packages/*/Project.toml`, `web/*/package.json`, once created at Gate 2)
and are not copied into this repository. Their licenses are reviewed at
Gate 0 (see `docs/audits/licensing.adoc`) and re-checked at Gate 5.

## HTTP/JSON vertical slice (2026-09-19)

- HTTP.jl: MIT; maintained HTTP/1.1 listener and client, not an HTTP/2 claim.
- JSON3.jl: MIT; JSON wire serialization/parsing (no Julia eval/deserialization).
- Exact resolved versions and transitive dependencies are recorded in
  `examples/http_json/Manifest.toml` and the Codec/Transport manifests. Upstream
  packages retain their license files in package distributions; no third-party
  source was copied into Marid.
