# ADR-0011: Keep CanvasSurface a narrow lifecycle adapter with layer-aware repaint routing

- Status: accepted
- Date: 2026-06-13
- Implementation state: implemented
- Source designs:
  - `docs/history/designs/2026-06-03-p13-flutter-surface.md`
  - `docs/history/designs/2026-06-13-layer-aware-surface-repaint-routing.md`
- Current owners:
  - `docs/architecture/01_runtime_ownership.md`
  - `docs/architecture/02_package_boundaries.md`
  - `docs/contracts/frame_rendering.md`
  - `docs/contracts/interaction_engine.md`
- Supersedes: none
- Superseded by: none
- Retirement design: none
- Retired on: none

## Context

The Flutter surface must connect widget lifetime, runtime attachment, pointer
input, frame output, and painting without becoming a second runtime owner. A
surface that reads mutable runtime state directly from painters would blur the
runtime/surface boundary. A single state-driven paint output would also repaint
unrelated content when only transient overlay content changed.

The initial surface design established lifecycle ownership and a narrow runtime
port. The later repaint design refined the output boundary after the single
`CustomPaint` form proved too coarse: runtime already knew whether main content,
overlay content, or both were affected, but that information was not preserved
through the surface adapter.

## Decision

Keep `CanvasSurface` a narrow Flutter lifecycle adapter. Surface owns widget
attachment and detachment, runtime replacement, surface-local resource and
pointer adapters, and disposal of Flutter-side subscriptions and objects. It
depends on a narrow runtime surface port rather than reaching into runtime
internals or taking ownership of document, interaction, or frame semantics.

Runtime selects the repaint target before publishing frame output. Surface
transfers immutable output into a transient surface-local cache with independent
main and overlay channels, then paints those channels through separate layer
branches and repaint boundaries inside one `LayerPaintHost`. A both-layer update
builds both outputs before assigning `mainOutput` and `overlayOutput` through
their separate `ValueNotifier`s in sequence. This prevents an output-builder
failure from publishing only the output built first, but it does not make
notification of the two channels atomic.

Input mapping remains surface-local because it depends on the live Flutter
render object. Painters consume published immutable output and do not read live
runtime state.

## Rationale

Surface is the correct owner for Flutter lifecycle and coordinate conversion,
while runtime remains the owner of semantic invalidation. Preserving the
runtime-selected repaint target avoids reconstructing intent from downstream
state deltas and prevents overlay-only changes from repainting stable main
content.

Separate immutable output channels make repaint behavior explicit and
debuggable. Building both outputs before the sequential assignments prevents a
builder failure from publishing a partially constructed update. Observers are
still notified separately and receive no atomic pair-publication guarantee.

## Consequences

- Surface remains replaceable and does not become a public or semantic runtime
  owner.
- Main and overlay layers can repaint independently while sharing one coherent
  frame capture.
- One paint host keeps the two paint branches, their stacking order, and their
  independent repaint boundaries reviewable together.
- Runtime-to-surface output transfer is transient presentation state, not a
  second document or frame-planning source of truth.
- Widget attachment, runtime swaps, and disposal must close surface-owned
  resources and subscriptions in a predictable order.
- The earlier single state-driven paint host is historical implementation
  context, not part of the retained decision.

## Current owners and enforcement

`docs/architecture/01_runtime_ownership.md` and
`docs/architecture/02_package_boundaries.md` own the runtime/surface allocation
and dependency direction. `docs/contracts/frame_rendering.md` owns immutable
frame output and repaint semantics. `docs/contracts/interaction_engine.md` owns
the input boundary that the surface adapts.

The current routes are the lifecycle adapter in
`lib/src/surface/canvas_surface_widget.dart`, transient output transfer in
`lib/src/surface/surface_frame_output_cache.dart`, and the single paint host with
two branches in `lib/src/surface/layer_paint_host.dart`. Current lifecycle,
output-construction, layer-isolation, and pointer-boundary proofs remain with
those owners.

## Source evidence

The 2026-06-03 surface design selected a package-owned Flutter surface with a
narrow runtime bridge and rejected both API ownership and direct runtime-root
coupling. The 2026-06-13 repaint design retained that lifecycle allocation while
selecting runtime-directed layer targets, a surface-local transient output
cache, and one host with two paint branches instead of `shouldRepaint` inference
or direct painter reads.

Commit `9553cdf7` on 2026-06-13 recorded the execution Change Contract for the
full retained shape. Commits `2acf26d9`, `8a0b20c8`, and `25d120d3` implemented
runtime repaint targets, output transfer, and split layers; `d576881c` aligned
the current documentation. Later hardening, including `5dd5fd10`, preserved the
same decision. This evidence establishes the header date and implemented state.
