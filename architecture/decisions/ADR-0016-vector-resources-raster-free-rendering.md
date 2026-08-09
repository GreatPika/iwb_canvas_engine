# ADR-0016: Keep vector resources application-prepared and raster-free

- Status: accepted
- Date: 2026-08-09
- Implementation state: implemented
- Source designs:
  - `docs/planning/designs/2026-08-08-vector-element-resource.md`
  - `docs/planning/plans/2026-08-09-vector-element-resource.md`
  - `docs/history/research/2026-08-07-full-svg-node-resource-surface.md`
- Current owners:
  - `docs/contracts/public_api_v1.md`
  - `docs/contracts/schema_v1.md`
  - `docs/contracts/resources.md`
  - `docs/contracts/cache_policy.md`
  - `docs/contracts/frame_rendering.md`
  - `docs/contracts/interaction_engine.md`
  - `docs/architecture/architecture_graph.yaml`
  - `docs/verification/tests.md`
- Supersedes: none
- Superseded by: none
- Retirement design: none
- Retired on: none

## Context

The package needed a serializable vector document resource without turning the
engine into an asset loader, an asynchronous frame resolver, or a second
application asset owner. The resulting value must remain drawable at any target
size, while document geometry and interaction remain independent from an
asset's intrinsic extent.

The decision also had to preserve the established owner model: schema and
committed-document facts are distinct from prepared rendering assets, resource
sessions borrow rather than own application assets, and diagrams, registries,
generated views, and tests have separate roles.

## Decision

Admit one typed vector descriptor and one vector document element through the
existing Schema v1 and committed-document owners. Resource-reference admission
distinguishes an absent resource from an existing descriptor of the wrong kind
at the existing boundary; it does not create per-family error vocabularies or a
second codec route.

Applications prepare supported raster-free vector input before attaching it to
the synchronous resolver boundary. Preparation copies the supplied byte view
and captures the invocation context before asynchronous upstream work. After
the selected preparation Future settles, it retains neither that snapshot nor
the supplied `BuildContext`; selected-Future failures have one bounded public
projection rather than an upstream error contract. The upstream dependency,
native Picture, and liveness observation remain private. Global Picture hooks
are supported only as non-interfering observation; embedded-raster input is
unsupported, so this decision adds no dependency fork, global error
interception, or duplicate input recognizer.

`CanvasPreparedVector` is application-owned. It keeps default identity equality
through disposal; changing it to value equality is a future public API
decision. Application code owns freshness, publication aliases, release, and
disposal, while the engine uses synchronous internal borrows and never disposes
application assets or exposes its cache identities. Target and aggregate
release remove matching engine borrows before a fallible notification boundary;
later notification failure remains contained after accepted publication. The
application releases every alias of the same wrapper before disposal.

Frame output binds admitted prepared values immutably and paints their Picture
directly at the element's target bounds. The public element kind is the sole
semantic interaction discriminator, and sealed frame rows are the sole
frame-payload discriminator. This keeps vector geometry, selection, and
context behavior within their existing owners without parallel family mirrors.
Group opacity is record-explicit: zero or full opacity creates no layer, while
partial opacity creates one target-bounded layer for that record.

## Rationale

Separating preparation from synchronous resolution keeps IO and upstream work
outside frame execution and makes application ownership explicit. Keeping the
upstream representation private avoids freezing third-party types or mutable
liveness as public compatibility surface.

Typed descriptor and element admission extends the existing document model
without serializing vector payload bytes. Direct Picture rendering preserves
resolution independence while the established frame, geometry, and interaction
owners continue to decide target bounds, chrome, and user-visible behavior.

## Consequences

- Applications supply and retire prepared vectors; engine resource and frame
  owners only retain and release their borrows.
- Schema v1 remains the only document wire route, with vector support alongside
  the existing resource and element families.
- Frame resolution remains synchronous and does not perform asset loading or
  introduce pending render state.
- A later change to supported input, prepared-value equality, public native
  access, or asset ownership requires a new public or architecture decision.

## Current owners and enforcement

`docs/contracts/public_api_v1.md` owns the public preparation and document
compatibility contract. Schema, resource, cache, frame, geometry, and
interaction owners record their respective current behavior; none is replaced
by this ADR. `docs/architecture/architecture_graph.yaml` owns graph-checkable
architecture relationships, and the registries own their structured
relationships and generated projections.

`docs/verification/tests.md` and `docs/verification/guardrails.md` own the
verification inventory and executable boundary policy. Their owner-focused
proofs, the documentation checks, and the architecture-graph checks provide
evidence for this decision without becoming semantic authorities.

## Source evidence

The 2026-08-08 design selected typed vector document admission, private
raster-free preparation, application-owned prepared values, borrowed
resolution, direct Picture rendering, and retirement of duplicate family
mirrors. The accepted 2026-08-09 Change Contract decomposed those choices into
owner-level implementation units and required current-owner closure before this
ADR and lifecycle integration.

The historical vector-surface research supplied upstream behavior evidence only.
Current implementation, contracts, registries, graph, and verification owners
establish the implemented state; the historical artifacts remain rationale and
evidence rather than present behavior authorities.
