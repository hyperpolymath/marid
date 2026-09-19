<!--
SPDX-License-Identifier: CC-BY-SA-4.0
Copyright (c) 2026 Jonathan D.A. Jewell <j.d.a.jewell@open.ac.uk>

Provenance: transcribed 2026-09-18 from the owner's program brief ("Marid
project brief" through "9. Execution plan"). This file is the canonical
product/engineering contract for the Marid program. Do not edit its
requirements without owner approval; record estate-specific file mappings
(docs .md -> .adoc, RSR root shape) in AGENTS.md instead.
-->

# Marid project brief

## 1. Product definition

Marid.jl is a Julia-first framework for web applications, APIs, and reactive scientific dashboards, with interoperable protocols and frontend independence.

### Design commitments

- Application logic and original backend integrations are written in Julia.
- React, Vue, and other frontend frameworks are supported through standard APIs—not a proprietary rendering requirement.
- Protocol adapters remain independently usable.
- Transport, serialization, application services, and persistence are separate concerns.
- Distributed routing is an optional control-plane feature, not part of every request's execution.
- ArangoDB is the initial external database target. We are not building a database engine.
- Native protocol interoperability matters more than merely having packages with the right names.

### Licensing

- Original source, tests, examples, browser code, and authored tooling: MPL-2.0.
- Documentation prose and original documentation artwork: CC-BY-SA-4.0.
- Third-party material retains its required licenses and notices.
- Explicit policies cover documentation snippets, docstrings, IDL files, generated code, and generator templates.
- Use the standard license texts, not a modified "MPL variant."

Names, package registry availability, and relevant trademarks must be checked before public release.

## 2. Launch deliverables

There are five integration packages plus the Marid core. We should not pretend the core disappears from the workload.

| Package | Initial supported scope | Evidence required before calling it ready |
|---|---|---|
| MaridArango.jl | Native Julia HTTP client; documents, edges, bound AQL queries, cursors, revision-aware updates, transaction operations | Tests against an actual supported ArangoDB release; cursor cleanup, conflicts, failures, and retry behavior tested |
| MaridGRPC.jl | Native-protocol unary calls and server streaming; metadata, deadlines, cancellation, status/trailers | An independent standard gRPC client successfully exercises these features |
| MaridGraphQL.jl | Queries and mutations; schema validation, variables, resolver context, partial errors, batching hooks, resource limits | Standard GraphQL clients work; authorization, malformed queries, limits, and partial failures are tested |
| MaridCapnProto.jl | Cap'n Proto message encoding/decoding and schema-toolchain integration | Bidirectional interoperability with an independent implementation |
| MaridBebop.jl | Explicitly pinned Bebop v3 schema/compiler/runtime integration | Bidirectional interoperability with an independent implementation |
| Marid.jl | Local routing, middleware, lifecycle, application context, contract bindings, HTTP/JSON, live-update integration | Reference application uses the integrations without duplicating business logic |

### Important scope boundaries

For the initial release:

- Cap'n Proto message support is not native Cap'n Proto RPC support.
- gRPC support must identify exactly which streaming modes work.
- GraphQL subscriptions require a separately identified transport implementation.
- A Bebop or Cap'n Proto message sent over WebSocket must not be advertised as some other standard RPC protocol.
- A thin Julia wrapper around an audited external runtime is different from an entirely Julia implementation. Document that distinction.
- If adequate Julia tooling does not exist, the agent must report that before silently turning an adapter task into a runtime/compiler project.

## 3. Repository and dependency structure

Start with one monorepo. The packages can still be independently versioned and registered.

```text
marid/
├── PROJECT_BRIEF.md
├── AGENTS.md
├── LICENSES/
├── REUSE.toml
├── THIRD_PARTY_NOTICES.md
├── docs/
│   ├── architecture.md
│   ├── compatibility.md
│   ├── roadmap.md
│   ├── audits/
│   └── adr/
├── packages/
│   ├── Marid/
│   ├── MaridArango/
│   ├── MaridGRPC/
│   ├── MaridGraphQL/
│   ├── MaridCapnProto/
│   └── MaridBebop/
├── web/
│   ├── client/
│   ├── react/
│   ├── vue/
│   └── elements/
├── contracts/
├── fixtures/
├── examples/
│   └── relationship_explorer/
├── test/
│   └── interop/
└── scripts/
```

### Dependency rules

- Marid must not unconditionally load every adapter.
- Adapter packages must work without a running Marid application.
- Adapters must not depend on one another.
- Marid-specific bindings should use optional integration modules or Julia package extensions where appropriate.
- Shared application-context definitions belong in the small core; standalone clients need not depend on them.
- Do not create a dozen utility packages before their interfaces have proved useful.

The architecture is:

```text
React / Vue / other frontends / RPC clients
                     │
          Protocol-specific interfaces
                     │
             Application services
     identity / policy / execution context
                     │
          Persistence and computation
                     │
                 ArangoDB
```

Cap'n Proto and Bebop provide message/schema capabilities where explicitly supported. They are not universal replacements for each protocol's native contract.

## 4. Establish these contracts before extensive implementation

These are the decisions that become expensive to retrofit.

| Contract | Required design |
|---|---|
| Execution context | Verified principal, tenant scope, deadline, cancellation, trace/request IDs |
| Application services | Ordinary Julia interfaces, not functions that require HTTP request objects |
| Authorization | Enforcement at service/resolver boundaries, not solely HTTP middleware |
| Streaming | Bounded buffering, slow-consumer behavior, cancellation, disconnect cleanup, ownership |
| Errors | Stable domain errors with protocol-specific mappings |
| Resource budgets | Message sizes, nesting, query cost, concurrency, execution duration |
| Lifecycle | Explicit application instances, startup, readiness, draining, shutdown |
| Contract evolution | Stable identifiers, native schemas, compatibility rules, pinned generators |
| Data ownership | Clear ownership/lifetime rules for borrowed buffers and decoded values |
| Retries | Explicit retryability and idempotency policy; no "exactly once" claims |
| Observability | Structured logs, operation-level metrics, trace propagation; no mandatory external telemetry |
| Persistence | Explicit transaction and cursor ownership, optimistic concurrency, pagination |

Additional requirements:

- No arbitrary Julia evaluation from network messages.
- No Julia object deserialization from untrusted clients as a shortcut for a wire protocol.
- Cancellation must not be represented as "the caller stopped waiting" while expensive work continues unnoticed.
- No global singleton holding user-specific authentication or tenant state.
- No automatic retries of writes unless their safety is established.

### Preserve native schemas

Use:

- OpenAPI/JSON Schema for appropriate HTTP APIs.
- GraphQL SDL for GraphQL.
- `.proto` for gRPC.
- `.capnp` for Cap'n Proto.
- `.bop` for Bebop.

Marid may maintain a contract registry containing identifiers, versions, fingerprints, and implementation bindings. It should not invent a replacement universal IDL.

Document translations for large integers, timestamps, binary data, null versus omitted values, and default values. Julia, JavaScript, GraphQL, and binary schemas do not have identical type semantics.

## 5. Browser compatibility

### Required foundation

- HTTP/JSON with OpenAPI 3.1 where applicable.
- GraphQL through its native interface.
- SSE for server-to-browser updates.
- A documented WebSocket application protocol where bidirectional communication is needed.
- Consistent HTTP errors using Problem Details where appropriate.
- Same-origin deployment as the simple default.
- Explicit cross-origin authentication and credential policies.

### Browser packages

| Package | Purpose |
|---|---|
| `@marid/client` | Framework-independent client, cancellation, errors, live subscriptions, reconnect/resynchronization |
| `@marid/react` | Thin React integration and lifecycle cleanup |
| `@marid/vue` | Thin Vue integration and lifecycle cleanup |
| `@marid/elements` | Small portable Web Components demonstrator; not a new comprehensive widget library |

The TypeScript client should expose familiar interfaces:

- Promises.
- AbortSignal.
- Async iterables where useful.
- Snapshot/subscription interfaces for reactive state.

Existing GraphQL and generated API clients should also work directly. Do not force every client through a universal Marid SDK.

### Compatibility requirements

- No window or document access merely from importing the SDK.
- Request-scoped credentials and caches for SSR use.
- Unmounting a component cleans up subscriptions.
- Reconnection detects missed updates and resynchronizes.
- Older browser bundles can remain compatible during rolling server deployments.
- SSR-safe SDK support does not mean Julia implements Next.js or Nuxt rendering.

For reusable controls, use Custom Elements, properties, DOM events, and explicit styling hooks. Provide framework wrappers only where they improve ergonomics.

Browser-facing gRPC requires a separately selected gRPC-Web, Connect, or gateway approach. Native gRPC support alone is insufficient.

## 6. Routing, reactive state, and persistence boundaries

### Routing

Start with:

- Declarative route specifications.
- Validation.
- Versioned, immutable local snapshots.
- Local activation of complete revisions.
- A route-store interface with a local implementation.

Later, Raft may distribute authoritative configuration.

Raft must not be used to replicate handler functions, ordinary requests, or live connections. Nodes must advertise which handlers and contract versions they actually have installed.

### Reactive state

Initially:

- Each session has one owning worker.
- Session state is isolated.
- Reconnection and worker failure have documented behavior.
- Durable state is stored separately.

CRDT support is a later, data-type-specific capability—not a promise that arbitrary Julia objects can be safely replicated.

### ArangoDB

Expose document, edge, and graph capabilities directly. Do not force them through a relational ORM abstraction.

The browser talks to application services, not directly to an unrestricted database endpoint.

Audit the exact ArangoDB release, edition, and deployment terms. Its internal Agency is not Marid's general-purpose consensus backend.

### Reserve interfaces, defer larger implementations

Establish extension boundaries for:

- Tables.jl and Arrow IPC.
- Identity-provider integration.
- Domain-event publication.
- Durable outbox implementations.
- Conditional writes and pagination.
- Background workers.
- Distributed route stores.

Do not include a new database, ORM, identity provider, Raft implementation, Arrow Flight service, or visual builder in the initial workload.

## 7. One reference application must exercise everything

Build a small relationship explorer backed by ArangoDB.

It should support:

- Creating and retrieving entities.
- Connecting entities with edges.
- Exploring a bounded neighborhood.
- Running a small Julia analysis with progress updates.

Expose the same application services through:

- HTTP/JSON.
- GraphQL.
- gRPC.

Provide Cap'n Proto and Bebop import/export fixtures or endpoints with explicitly documented semantics.

Build three frontends against those services:

- Plain JavaScript.
- React.
- Vue.

Include one small shared Web Component, such as a progress indicator.

This application is the integration test—not a separate implementation of business logic for each protocol.

## 8. Definition of done

A package is ready only when it has:

- A documented public API.
- A supported-version and feature matrix.
- Unit tests.
- Real interoperability or database integration tests.
- Failure-path and resource-cleanup tests.
- A runnable example.
- Licensing and third-party notices.
- Reproducible installation and test instructions.
- CI for the declared Julia versions and platforms.
- An explicit list of unsupported features.

Mocks are useful for unit tests. They do not prove gRPC interoperability or ArangoDB compatibility.

Also measure:

- Julia cold startup and first useful response.
- Warm latency and allocations.
- Memory behavior under repeated connect/disconnect.
- Cancellation and shutdown behavior.

Never report skipped or unexecuted tests as passing.

## 9. Execution plan

### Gate 0 — Feasibility and licensing audit

Before production implementation:

- Inspect existing Julia packages and relevant native runtimes.
- Check maintenance, supported features, exact versions, licenses, and generated-code terms.
- Audit HTTP/2 and gRPC feasibility specifically.
- Audit Cap'n Proto and Bebop compiler/runtime feasibility.
- Audit GraphQL execution support—not just schema parsing.
- Select an ArangoDB version for testing.
- Check proposed package names.

Produce an evidence-backed matrix:

| Integration | Existing implementation | Missing capabilities | License | Recommendation | Blocker |
|---|---|---|---|---|---|

Recommendations must distinguish:

- Reuse a Julia implementation.
- Build a Julia adapter over an audited external runtime.
- Contribute missing functionality upstream.
- Build new implementation work.
- Reduce or change scope.
- Stop for approval if a new runtime, substantial code generator, or non-Julia bridge is required.

### Gate 1 — Interoperability spikes

Prove the highest-risk assumptions using disposable, minimal examples:

- Standard client → proposed gRPC server.
- Independent Cap'n Proto implementation ↔ Julia.
- Independent Bebop implementation ↔ Julia.
- Standard GraphQL client → proposed executor.
- Julia client → actual ArangoDB instance.

Do not freeze the shared API until these results are understood.

### Gate 2 — Foundation

Create:

- Package skeletons and independent environments.
- License mapping.
- CI and test tooling.
- Shared context and lifecycle contracts.
- Architectural decision records.
- Browser-event contract.

Scaffolding alone does not constitute protocol support.

### Gate 3 — Independent packages

Implement the five packages against their acceptance criteria.

Parallel work is appropriate once the shared contracts and runtime choices have been approved.

### Gate 4 — Assembly and browser integrations

Implement:

- Thin Marid bindings.
- The framework-independent client.
- React/Vue wrappers.
- The reference application.
- Real-browser and cross-protocol tests.

### Gate 5 — Release review

Review:

- Support matrix.
- Security and failure behavior.
- Licensing.
- Documentation.
- Reproducibility.
- Package registration and release order.

Public registration, publishing, deployment, and use of paid services require explicit approval.
