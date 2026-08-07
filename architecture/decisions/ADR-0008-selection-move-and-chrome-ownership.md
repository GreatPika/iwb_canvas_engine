# ADR-0008: Separate selection truth, move sessions, and frame-owned selection chrome

- Status: accepted
- Date: 2026-06-04
- Implementation state: implemented
- Source designs:
  - `docs/history/designs/2026-06-01-p10-selection-and-move.md`
  - `docs/history/designs/2026-06-04-selection-chrome-and-move-hit-area.md`
- Current owners:
  - `docs/architecture/03_data_model.md`
  - `docs/contracts/interaction_engine.md`
  - `docs/contracts/frame_rendering.md`
- Supersedes: none
- Superseded by: none
- Retirement design: none
- Retired on: none

## Context

Selection affects runtime observation, gesture admission, move preview, terminal
document edits, and visual chrome, but none of those concerns should become a
second committed document owner. Keeping interaction state in the runtime root
or mutating store/selection owners directly from tools would blur transaction
and cleanup boundaries.

Multi-selection also creates pressure to store a group bounding box or let a
surface overlay own both visuals and hit admission. That would duplicate facts
derived from selected ids and current geometry. Exact-hit-only admission would
also prevent dragging from empty space inside a selected group.

## Decision

The selection kernel owns selected ids, selection normalization, and selection
revision as runtime state. Interaction owns selection and selected-move pointer
sessions, admission, preview, cleanup, and terminal mutation intent. Accepted
document movement still commits through the edit boundary.

Frame owns selection decoration. Multi-selection derives one union primitive;
single selection derives one element primitive. Exact chrome placement and paint
order follow the current frame contract and are outside this ADR's retained
scope. Selected-move preview and chrome suppression remain frame/interaction
facts rather than committed selection geometry.

Group-area move admission is derived at the immutable interaction-read boundary
from current selected ids, bounds, order, and hit reliability. It supplements
rather than replaces ordinary exact hit testing and must respect current
occlusion and reliability policy. No group-bounds value becomes committed,
public, or independently cached truth.

## Rationale

The split assigns each kind of truth to the owner that already controls its
lifecycle: selection membership to selection, gesture state to interaction,
document mutation to edit, and visual decoration to frame. Deriving union bounds
at read/capture time prevents synchronization glue when elements, selection, or
order changes.

Unified chrome and bounded group-area admission give group selection a coherent
visual and interaction model without weakening exact geometry or creating a
surface-owned hit policy.

## Consequences

- Selection changes do not rewrite committed document state.
- Move preview is provisional; only an admitted terminal routes an edit.
- Frame cache identity for ordinary committed records remains independent of
  selection membership and chrome.
- Group-area admission must reject stale, unreliable, or occluded starts rather
  than treating them as empty successful hits.
- Selection chrome is derived from current immutable facts and cannot be used as
  a stored interaction source of truth.

## Current owners and enforcement

`docs/architecture/03_data_model.md` owns selection separation from committed
document state. `docs/contracts/interaction_engine.md` owns read admission,
pointer sessions, preview, cleanup, and selected-move commit routing.
`docs/contracts/frame_rendering.md` owns selection decoration and its current
placement and paint order.

The current routes are `lib/src/selection/selection_kernel.dart`, selected-move
handling under `lib/src/interaction/`, and
`lib/src/frame/selection_decoration_planner.dart`. Current registered proofs
cover selection/cache independence, group admission, terminal cleanup, current
chrome placement, and selected-move output without making this ADR their proof
inventory.

## Source evidence

The 2026-06-01 P10 design selected the selection/interaction/edit ownership
spine and rejected runtime-local sessions and direct mutation ports. The
2026-06-04 design selected union chrome, scene-order placement, and derived
group-area move admission while retaining the P10 ownership split. The current
frame owner instead places selection decoration topmost, so the historical
scene-order placement was not retained and is excluded from this ADR. Union
chrome, derived group admission, and the owner split remain retained.

Commit `5bcfad93` on 2026-06-04 recorded the execution Change Contract for the
later refinement. Commits `ee82199b`, `1f992c06`, `f6f27780`, and `3f3173f5`
implemented the historical chrome refinement and group move admission, and
`1cc6e367` recorded completion that day. Those commits, the earlier P10
implementation lineage, and the current owners establish the header date and
implemented state for the retained ownership, union, and admission decisions.
