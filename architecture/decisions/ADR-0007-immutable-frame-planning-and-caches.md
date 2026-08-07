# ADR-0007: Render from immutable frame captures through specialized planners and bounded caches

- Status: accepted
- Date: 2026-06-10
- Implementation state: implemented
- Source designs:
  - `docs/history/designs/2026-05-19-frame-engine-internal-split.md`
  - `docs/history/designs/2026-05-29-p9-frame-rendering-and-caches.md`
  - `docs/history/designs/2026-06-01-p9-frame-rendering-findings-closure.md`
  - `docs/history/designs/2026-06-10-overlay-frame-capture.md`
  - `docs/history/research/2026-05-17-frame-meta-revision-split.md`
- Current owners:
  - `docs/architecture/01_runtime_ownership.md`
  - `docs/contracts/frame_rendering.md`
  - `docs/contracts/cache_policy.md`
- Supersedes: none
- Superseded by: none
- Retirement design: none
- Retired on: none

## Context

Rendering needs committed rows, selection and preview facts, camera and viewport
inputs, resource binding, background policy, and several cache lifecycles. A
monolithic renderer would combine capture, admission, planning, decoration,
assets, and painting. Splitting those concerns into public services would expose
frame-private implementation and still leave ownership of orchestration unclear.

Painters cannot safely read live runtime state because inputs could change
during paint. Ordinary committed records also have different invalidation from
selection decoration, move supplements, static background, and overlay preview.
Using one cache identity for all of them would either retain transient state or
invalidate ordinary work unnecessarily. The original overlay capture reused a
main-scene-style snapshot even though overlay previews need a much smaller fact
set.

## Decision

Keep one private frame-engine facade as the internal orchestration entry point.
It delegates capture, spatial admission, ordinary planning, selected-move
supplement planning, selection decoration, background planning, asset binding,
and overlay planning to specialized frame-private collaborators.

Capture reads each required owner once and produces immutable painter inputs.
Painters consume only completed main or overlay outputs; they do not read live
runtime, resolver, selection, store, or public document projection state.

Ordinary committed planning and its bounded caches exclude selection membership
and preview deltas. Selection decoration, selected-move supplements, static
background, and overlay previews remain separate derived stages with their own
owned keys and lifecycles. Cache admission and publication are all-or-nothing
for the output being built.

Main capture retains the committed-scene facts required by ordinary planning.
Overlay capture is intentionally compact and contains only the immutable
viewport, camera, preview, and style facts required by overlay planning. It does
not take a full main-scene snapshot merely for an overlay-only update.

## Rationale

A private facade keeps sequencing explicit without turning each collaborator
into a public subsystem. Immutable capture closes the temporal boundary before
painting and makes frame output deterministic for a given captured input.

Separating ordinary, decoration, supplement, background, and overlay stages
matches their distinct invalidation domains. Bounded owner-specific caches can
reuse durable work without storing transient interaction state or becoming a
second scene source of truth.

## Consequences

- Frame collaborators remain internal and can evolve behind the facade.
- Painters are simple consumers of immutable outputs and cannot resolve missing
  facts during paint.
- Selection, preview, camera, background, style, and resource changes invalidate
  only the stages whose current owners declare those dependencies.
- Ordinary planning must use spatially admitted committed rows rather than a
  global scene sort or public document materialization.
- Main and overlay capture are deliberately asymmetric; consumers cannot assume
  one snapshot shape serves both.

## Current owners and enforcement

`docs/architecture/01_runtime_ownership.md` owns frame placement and the boundary
between runtime facts, frame construction, and surface painting.
`docs/contracts/frame_rendering.md` owns capture, planning, immutable output, and
painter behavior. `docs/contracts/cache_policy.md` owns current cache keys,
capacity, eviction, and probes.

The current routes are `lib/src/frame/frame_engine.dart`,
`lib/src/frame/frame_capture_service.dart`, the frame-private planners under
`lib/src/frame/`, and the output consumers
`lib/src/surface/main_painter.dart` and
`lib/src/surface/overlay_painter.dart`. Registered proofs enforce bounded cache
behavior, transient-state exclusion, compact overlay capture, and no live
painter reads without copying their mutable inventory here.

## Source evidence

The 2026-05-19 design selected the private facade and collaborator split. The
2026-05-29 P9 design selected immutable frame output and separated bounded cache
stages; the 2026-06-01 findings design refined admission and failure containment.
The 2026-06-10 design selected compact overlay capture while retaining the same
facade and painter boundary. The frame-meta research supplies historical context
only; later revision-domain evolution remains owned by current documents.

Commit `8c23d955` on 2026-06-10 recorded the execution Change Contract for the
last retained refinement. Commits `8354f3e7` and `ad2d6202` implemented compact
capture and migrated its consumers, and `3c86f24c` recorded completion that day.
Earlier frame implementation commits remain evidence for the retained facade and
planner architecture. Together with the current owners, these commits establish
the header date and implemented state.
