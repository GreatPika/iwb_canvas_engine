# ADR-0001: Adopt a single maintained package with an acyclic contracts-led runtime

- Status: accepted
- Date: 2026-06-08
- Implementation state: implemented
- Source designs:
  - `docs/history/designs/2026-05-27-acyclic-runtime-public-api-architecture.md`
  - `docs/history/designs/2026-06-03-legacy-example-full-parity-port.md`
  - `docs/history/designs/2026-06-08-legacy-phase-cleanup.md`
- Current owners:
  - `docs/architecture/00_architecture_overview.md`
  - `docs/architecture/02_package_boundaries.md`
  - `docs/contracts/public_api_v1.md`
- Supersedes: none
- Superseded by: none
- Retirement design: none
- Retired on: none

## Context

The rebuilt engine needed public value types and cross-owner seams that could be
used by runtime, store, edit, codec, diagnostics, resources, frame, and later
interaction code. Keeping those declarations in the public facade made internal
owners point upward into API implementation and then back through runtime
composition. That shape created dependency cycles and made future owners depend
on facade placement rather than on stable contracts.

The repository also contained legacy, donor, phase, compatibility, and example
surfaces from the rebuild. Deleting them before transferring retained behavior
would lose architectural knowledge; keeping them after transfer would leave a
second apparent package, runtime, or roadmap.

Considered alternatives moved the public runtime class into the runtime owner,
introduced adapter copies of public values, or tolerated cycles through
exceptions. Those forms either blurred facade and implementation ownership,
created duplicate type truth, or preserved the dependency defect.

## Decision

Maintain one package root, one public package barrel, and one composed runtime
root. Dependency-neutral public DTO, value, error, policy, and port declarations
live in a dependency-low public contracts layer. Public implementation entry
points such as `CanvasRuntime` remain API-owned. `CanvasSurface` and
`CanvasTextEditingOverlay` are narrow surface-owned public widget exceptions
re-exported through API. Non-public ports, facts, effects, and result seams used
across internal owners live in a dependency-low internal contracts layer.

The API layer re-exports public contracts and owns explicitly named public
implementation entry points that adapt to implementation seams. Runtime and
ordinary implementation owners consume contracts rather than the API facade.
Surface-owned public widget adapters may reference `CanvasRuntime` in public
constructor signatures under the documented narrow exception without becoming
the runtime owner. The runtime root composes implementation owners but must not
turn that composition edge into an implementation-to-API back edge.

Application adapters and examples remain external public consumers. Legacy,
donor, phase, compatibility, and fallback-runtime surfaces are removed only
after retained behavior and constraints have a current owner. No removed
surface remains as a second shipped runtime or current source of truth.

## Rationale

A lower contract layer resolves the shared-type ownership problem rather than
masking individual cycles. It preserves the supported public facade while
letting implementation dependencies form a directed graph. Separating public
and internal contracts also prevents an internal seam from becoming public
merely because several owners need it.

Replacement before deletion protects durable knowledge during migration, while
the final single-package form removes permanent synchronization pressure and
ambiguity about which runtime or documentation lineage is current.

## Consequences

- API facades may adapt into implementation, but runtime and ordinary
  implementation owners share types through contract owners rather than
  importing facades.
- Surface-owned public widget adapters may use the documented `CanvasRuntime`
  signature exception without owning runtime state or internals.
- Cross-owner seams must remain narrow enough that contracts do not become a
  second implementation layer.
- Public-consumer examples and compile proofs cannot rely on package internals.
- Adding an owner or dependency requires preserving the directed ownership
  graph; cycle exceptions are not a migration substitute.
- Historical rebuild and legacy artifacts remain evidence only after their
  retained facts move to current owners.

## Current owners and enforcement

`docs/architecture/00_architecture_overview.md` owns the maintained-package,
single-runtime scope. `docs/architecture/02_package_boundaries.md` owns current
placement and dependency direction. `docs/contracts/public_api_v1.md` owns the
public behavior exposed through the package facade.

Their registered guardrails, architecture graph obligations, public-barrel
proof, external-consumer compile proof, and single-runtime-root proof enforce
the current form. Those owners and proof inventories may evolve without being
copied into this ADR.

## Source evidence

The 2026-05-27 design selected a contracts layer below the public facade after
rejecting runtime-owned public declarations, duplicated adapter types, and cycle
exceptions. The 2026-06-03 example design selected the package as an
external-public-only consumption boundary. The 2026-06-08 cleanup design
selected the replacement-before-deletion rule and final no-phase,
single-maintained-package form. Commit `3016a9b4` on 2026-06-08 recorded the
execution Change Contract adopting D1-D11. Later implementation on 2026-06-08
and 2026-06-09, together with the current owners, corroborates the implemented
state.
