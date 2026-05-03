# ADR 0001: Target Engine Architecture

- Status: Accepted
- Date: 2026-04-22

## 1. Intent

This ADR defines the accepted target architecture for `iwb_canvas_engine`.

`ARCHITECTURE.md` remains the checked-in architecture contract for the current
repository state. This ADR fixes the accepted top-level target so refactors can
be judged against one durable architectural decision instead of local
bug-fix direction alone.

This ADR is intentionally narrow:

- it defines the accepted target form
- it defines the top-level rules that must stay true
- it does not define detailed file cuts
- it does not define migration order

## 2. Problem Statement

The package already has a strong outer shape:

- one public package entrypoint
- immutable public document boundary
- mutable internal runtime scene
- explicit layer DAG
- transactional write boundary
- frame-authoritative main-scene rendering

The main architectural weakness is inside the runtime center, not at the layer
graph.

Today the runtime center is harder to reason about than it should be because:

- runtime assembly is spread across several peer owners instead of one clear
  composition root
- the view/runtime seam exposes both main-scene frame reads and live overlay
  preview reads through one mixed contract
- some runtime owners coordinate several responsibilities at once, which makes
  bug placement and review more expensive

## 3. Decision

The target architecture keeps the current package boundary and layer DAG, but
simplifies runtime ownership.

The accepted target form is:

1. `SceneController` remains a thin public facade.
2. One internal composition root assembles the store runtime, interaction
   runtime, and the controller-owned `SceneViewRuntime` boundary.
3. The committed store and write kernel remain the only owners of committed
   scene state.
4. The interaction runtime owns ephemeral gesture state, preview state, and
   pointer-session orchestration only.
5. `SceneControllerMutationBoundary` remains the only interaction-owned bridge
   into committed writes.
6. Main-scene rendering and live overlay preview use separate read contracts or
   facets inside one controller-owned render-state family.
7. The view shell consumes the assembled `SceneViewRuntime` boundary and does
   not reconstruct engine ownership locally.

At the top level, the target runtime center is:

- public facade -> composition root
- composition root -> store runtime, interaction runtime, view-runtime boundary
- interaction runtime -> mutation gateway -> store runtime
- view-runtime boundary -> main-scene read and overlay read -> view consumers

## 4. Architectural Rules

The following rules define the target form:

1. One public controller facade must remain the supported public interactive
   owner for package callers.
2. One assembled `SceneViewRuntime` boundary must remain the only view-facing
   bridge into interactive internals.
3. One internal composition root must assemble the interactive engine graph
   without reabsorbing the responsibilities of the owners it wires together.
4. Interaction-owned state must stay ephemeral until it crosses the mutation
   gateway.
5. The mutation gateway must remain the only interaction-owned owner that
   performs committed writes.
6. Main-scene rendering must read from one atomic frame contract only.
7. Overlay rendering must read from a separate live-preview contract only.
8. Scene and overlay reads may stay inside one controller-owned render-state
   family, but one owner must not mix both responsibilities behind one
   ambiguous interface forever.
9. Store-owned committed state must not depend on interaction-owned preview
   state.
10. The view layer must not reconstruct controller/runtime ownership locally.

## 5. Repository Evidence

This decision is grounded in checked-in code and mechanical evidence:

- DCM and direct file inspection keep pointing to the same runtime-center hot
  spots: composition assembly, mixed render seam, interaction runtime, mutation
  gateway, and store/write path owners.
- `SceneViewRuntime` and `SceneViewRenderState` are not exported from
  `lib/iwb_canvas_engine.dart`, so the render-seam split can stay an internal
  refactor instead of a public API break.
- Scene and overlay invalidation are already separated in the checked-in
  runtime path.
- The critical runtime seams are centralized rather than replicated, which
  makes ownership cleanup feasible without a layer redesign.
- Current guardrails and invariants already align with the desired end-state:
  one assembled runtime boundary, one thin facade, and one interaction-owned
  committed-write gateway.

## 6. Non-Goals

This ADR does not propose:

- a new public package entrypoint
- a reducer-first or event-sourcing redesign
- merging `interactive` and `controller` into one layer
- changing the immutable-public / mutable-runtime split
- changing schema/version ownership
- removing the current guardrail and import-boundary enforcement model

## 7. Guardrail Compatibility

This ADR preserves the repository-local constraints that already match the
desired end-state:

- `SceneController` stays a thin facade over assembled runtime owners
- `SceneViewInteractive` stays a thin adapter from `SceneController` into
  `SceneViewRuntime`
- `SceneViewRuntimeHost` stays the active-runtime and pointer-host owner
- `SceneControllerMutationBoundary` stays the only interaction-owned
  committed-write owner
- `SceneViewRenderSurface` stays a read-only view surface over render state

The current single `SceneViewRenderState` contract is allowed only as a
temporary mixed seam inside one controller-owned render-state family. The
target is to preserve that family while splitting its main-scene and overlay
read roles.

## 8. Companion Docs

This ADR is the accepted top-level target only.

Use the companion documents like this:

- `ARCHITECTURE.md` describes the checked-in architecture now.
- `docs/ARCHITECTURE_ATLAS.md` is the working atlas and the
  planning entrypoint for architecture slices.
- `PLAN.md` records execution order; it does not define architecture.

Source-of-truth order:

`ADR 0001 -> docs/ARCHITECTURE_ATLAS.md -> PLAN`

## 9. Alternatives Considered

### Keep the current shape and continue seam-by-seam hardening

Rejected as the target form because it keeps the same ownership ambiguity in
the runtime center.

### Only split files and helpers without changing ownership

Rejected as insufficient because it may improve local readability without
fixing the mixed render seam or creating one obvious composition root.

### Full layer redesign

Rejected for now because current evidence points to runtime-ownership problems,
not a broken package-level layer DAG, and the migration cost would be much
higher.

## 10. Acceptance Signals

The target architecture can be considered reached when all of the following are
true:

- there is one explicit internal composition root
- `SceneController` no longer owns meaningful assembly logic beyond facade
  delegation
- `SceneViewRuntime` remains the only view-facing interactive runtime boundary
- main-scene render reads and overlay preview reads use different contracts or
  facets inside one controller-owned family
- committed writes from interaction paths still pass through one mutation
  gateway
- guardrails and architecture tests prove the ownership model

Until then, `ARCHITECTURE.md` remains the authoritative description of the
checked-in code, while this ADR remains the accepted top-level target.
