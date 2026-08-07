# ADR-0006: Keep geometry committed and spatial acceleration derived and reliability-typed

- Status: accepted
- Date: 2026-05-29
- Implementation state: implemented
- Source designs:
  - `docs/history/designs/2026-05-29-p8-geometry-spatial.md`
  - `docs/history/research/2026-05-18-non-invertible-transform-fallback.md`
- Current owners:
  - `docs/contracts/geometry.md`
  - `docs/contracts/spatial_kernel.md`
  - `docs/contracts/validation_limits.md`
- Supersedes: none
- Superseded by: none
- Retirement design: none
- Retired on: none

## Context

Frame, selection, context, and eraser workflows need bounded candidate lookup,
but the committed store already owns element identity, order, geometry inputs,
and revisions. Putting spatial indexes in the store would make an acceleration
policy part of document truth. Allowing geometry to read concrete store tables
would invert the owner boundary, while creating a second committed-facts port
would duplicate the existing immutable row projection.

Candidate lookup also has reliability states that are not equivalent to a
successful empty result. A stale generation, invalid index, or exhausted budget
must not be interpreted as “nothing was hit.” Historical evidence additionally
recorded conflicting descriptions of non-invertible transform fallback. The
current architecture resolves that issue at transform/geometry admission rather
than treating it as permission for an untyped spatial success.

## Decision

Committed element and geometry inputs remain store-owned truth. Geometry owns
exact bounds, eligibility, and family-specific hit policy. A spatial kernel owns
only derived, rebuildable acceleration structures and reads immutable committed
facts through the established internal facts boundary.

Accepted touched effects update only affected spatial membership when the
change can be applied incrementally. Replacement or changes that invalidate the
index use a reset or rebuild path rather than cloning the full index for every
ordinary edit. A failed derived update does not rewrite or roll back committed
document truth; it leaves spatial state invalid or rebuild-needed until a safe
query/rebuild route handles it.

Spatial queries return typed reliability outcomes. Candidate success, stale or
invalid state, and budget exhaustion remain distinguishable, and consumers may
not convert a non-candidate outcome into a successful empty candidate set.
Invalid-index fallback is bounded and separate from geometry admission for
non-finite or non-invertible transforms.

## Rationale

Derived indexing makes the accelerator disposable and reconstructible while
preserving one committed source of truth. Reusing the immutable committed-facts
boundary avoids a parallel row model and keeps geometry independent of concrete
store implementation.

Typed outcomes force frame and interaction consumers to preserve uncertainty.
That prevents unreliable queries from becoming destructive empty-hit,
empty-selection, or partial-eraser decisions.

## Consequences

- Spatial indexes may be discarded and rebuilt without changing the document.
- Ordinary touched edits update bounded membership rather than cloning or
  sorting the full scene.
- Consumers must handle reliability outcomes explicitly before exact geometry
  work or mutation admission.
- A post-acceptance spatial failure is contained as derived-state invalidity;
  committed state remains accepted.
- Geometry and spatial owners provide primitives only; frame and interaction
  retain ownership of their user workflows and terminal decisions.

## Current owners and enforcement

`docs/contracts/geometry.md` owns exact geometry, eligibility, and corrupted-row
behavior. `docs/contracts/spatial_kernel.md` owns derived index lifecycle,
touched updates, fallback, and typed query outcomes.
`docs/contracts/validation_limits.md` owns transform admission limits.

The current code routes through `lib/src/geometry/geometry_policy.dart`,
`lib/src/geometry/hit_test_policy.dart`, and
`lib/src/geometry/spatial_kernel.dart`. Their current registered proof surfaces
cover touched updates, rebuild/invalid state, stale generations, bounded query
failure, and exact geometry without making this ADR a copy of those ledgers.

## Source evidence

The 2026-05-29 design selected a derived spatial kernel under geometry, the
existing immutable committed-facts boundary, touched delivery, and typed
reliability results after rejecting direct store reads, store-owned spatial
truth, and a parallel facts port. The 2026-05-18 research is historical evidence
of the earlier transform-fallback conflict, not current behavior.

Commit `471b4c08` on 2026-05-29 recorded the execution Change Contract for the
P8 decision. Commits `d5825625`, `bfb3e388`, `82945bfb`, and `01464863`
implemented geometry policy, index structures, kernel lifecycle, and runtime
delivery; `7212afeb` closed the corresponding verification documentation that
day. Those commits and the current owners establish the header date and
implemented state.
