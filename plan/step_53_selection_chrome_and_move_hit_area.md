# Change Contract

## Goal

Make selection feedback behave like one ordered scene object: multi-select renders one union chrome, single-select remains one object chrome, higher-order content can cover selection chrome, box chrome strokes stay inside box bounds, and selected groups can start move from empty space inside the shared selection box without stealing clicks from higher-order content.

## Source Inputs

- Design: `.design/2026-06-04-selection-chrome-and-move-hit-area.md`
- Research: `.research/2026-06-04-selection-chrome-and-move-hit-area.md`
- Phase: none
- PLAN: `PLAN.md`
- Other: current user requirements on painter-output z-order proof, occlusion-aware group drag, mixed multi-select inside stroke policy, and forbidding `SelectedOrderSnapshot` as the paint-order source.

## Classification

Profile: BEHAVIOR_CHANGE

Obligations: SEAM_MIGRATION

## Decision Trace

| Source decision | Contract location | Execution unit / proof surface |
|---|---|---|
| `D1` Multi-select selection chrome emits one group primitive from union paint bounds; single-select emits one primitive for the selected element. | `Boundaries.Owner`, `Boundaries.In Scope`, Unit 1 | Unit 1 frame planner tests assert primitive count, union bounds, selected-move delta alignment, and preserved single-select behavior. |
| `D2` Selection chrome carries paint order and is painted interleaved with main records, not as a global after-pass. | `Boundaries.Order Constraints`, Unit 2 | Unit 2 painter-output test proves higher-order content actually paints over chrome; primitive token checks alone are insufficient. |
| `D3` Selection decoration key must invalidate when selected chrome order can change. | `Boundaries.Source of Truth`, Unit 1 | Unit 1 key fixture changes selected top order or structural revision while selected ids/bounds are otherwise stable and observes a rebuilt ordered decoration plan. |
| `D4` Inside stroke placement applies to box chrome for multi-select union, single rect, and single image; line/stroke stay bounds/outline or later line-specific decoration. | `Boundaries.In Scope`, Unit 1, Unit 2 | Unit 1 primitive placement metadata tests distinguish box chrome from bounds/outline chrome; Unit 2 painter geometry tests prove box strokes do not protrude outside primitive bounds. |
| `D5` Group-box selected-move admission is computed at `InteractionReadPort` and admitted by `MoveMachine`, not by app/surface code. | `Boundaries.Owner`, `Boundaries.In Scope`, `Boundaries.Dependency/import direction`, Unit 3, Unit 4 | Unit 3 read-port/runtime tests expose immutable exact-hit and group-union facts; Unit 4 move-machine/runtime tests admit selected move from empty group interior. |
| `D6` Ordinary exact hit-test remains intact and topmost hit/order facts are preserved alongside group-union admission. | `Boundaries.Compatibility`, Unit 3, Unit 6 | Unit 3 uses a policy-owned hit result or equivalent geometry seam; Unit 6 keeps point selection and context-action top-hit regressions passing through exact geometry. |
| `D7` Group-box admission respects z-order by rejecting union-only admission when a higher-order content hit is above the top selected order token. | `Boundaries.Order Constraints`, `Temporal Surface Closure`, Unit 3, Unit 4 | Unit 3 computes occlusion-aware selected-move start facts from one pointer-down snapshot; Unit 4 runtime test proves a higher-order overlapping object blocks union-only group drag. |
| `D8` Durable frame, interaction, geometry, and selected-move diagram docs must be updated by the implementation contract. | `Boundaries.Source of Truth`, Unit 5 | Unit 5 updates existing docs/diagrams/registry surfaces and proves docs generation/checks are current. |
| User requirement: do not solve z-order only by adding `paintOrderToken` to the primitive. | Unit 2 `Completion Check` | Painter-output proof must fail if `MainFramePainter` still paints decorations after all records. |
| User requirement: group drag from union bounds must be occlusion-aware, not a bare `union.contains(point)` check. | Unit 3 and Unit 4 `Completion Check` | Occluding-object read-port/runtime tests must reject union-only admission when top content above selected chrome covers the point. |
| User requirement: mixed multi-select uses the group box as box chrome, including selections made only of line/stroke elements. | `Boundaries.Compatibility`, Unit 1, Unit 2 | Unit 1 treats multi-select union as box chrome regardless of selected families; Unit 2 proves inside group-box stroke placement while Unit 4 keeps broad bounds-interior drag limited to multi-select. |
| User requirement: do not use `SelectedOrderSnapshot` as paint order. | `Boundaries.Source of Truth`, Unit 1, Unit 2 | Unit 1/2 derive chrome order from `FrameElementFacts.orderToken` / `RenderElementRecord.orderToken`; tests or structural assertions fail if selected document-order ids become the paint-order source. |
| User requirement: keep the feature fast without hacks. | `Boundaries.Performance Constraints`, Unit 2, Unit 3, Unit 6 | Unit 2 proves bounded painter merge without global scene sort or `saveLayer`; Unit 3 proves bounded spatial/read work without document scan or stored sync state; Unit 6 keeps structural no-overlay/no-live-read/cache non-churn proof. |

## Evidence

- `.design/2026-06-04-selection-chrome-and-move-hit-area.md:13` / disposition: design is `READY_FOR_CONTRACT` -> write a full step contract instead of a blocker.
- `.design/2026-06-04-selection-chrome-and-move-hit-area.md:17` / product outcome: multi-select should render one frame, upper scene objects can cover chrome, and group drag can start from shared selection-box empty space -> contract scope must cover rendering and selected-move admission, not only planner metadata.
- `.design/2026-06-04-selection-chrome-and-move-hit-area.md:19` / boundary: change is internal and selection visuals remain frame-owned while selected-move admission remains interaction-read-boundary-owned -> no public API/schema/application hit-area work is in scope.
- `.design/2026-06-04-selection-chrome-and-move-hit-area.md:25` / classification: selected profile is `BEHAVIOR_CHANGE` with `SEAM_MIGRATION` -> execution units must migrate internal seams and prove user-visible behavior.
- `.design/2026-06-04-selection-chrome-and-move-hit-area.md:116` / selected form: frame owns chrome and interaction owns move-start admission while selected union is derived independently per boundary -> owner split is fixed.
- `.design/2026-06-04-selection-chrome-and-move-hit-area.md:118` / selected form: multi-select primitive uses union paint bounds and maximum selected order token, and painter interleaves chrome by order -> Unit 1 owns primitive metadata and Unit 2 owns painter output.
- `.design/2026-06-04-selection-chrome-and-move-hit-area.md:120` / stroke placement: multi-select union, single image, and single rect use inside box chrome, while line/stroke single-select stay non-inside bounds/outline -> Unit 1 and Unit 2 must encode and paint placement explicitly.
- `.design/2026-06-04-selection-chrome-and-move-hit-area.md:122` / selected-move admission: read adapter returns exact selected movable hit facts plus group-union containment and top-hit/order facts from one immutable pointer-down snapshot -> Unit 3 and Unit 4 must not move hit-area logic to painter/app code.
- `.design/2026-06-04-selection-chrome-and-move-hit-area.md:130` / decision trace D1: one group primitive and single-select primitive behavior are locked -> Unit 1 must prove direct primitive count and bounds.
- `.design/2026-06-04-selection-chrome-and-move-hit-area.md:131` / decision trace D2: ordered chrome must replace global after-pass decoration paint -> Unit 2 must prove actual painter output order.
- `.design/2026-06-04-selection-chrome-and-move-hit-area.md:132` / decision trace D3: decoration key must invalidate on selected chrome order changes -> Unit 1 must cover order/structural invalidation.
- `.design/2026-06-04-selection-chrome-and-move-hit-area.md:133` / decision trace D4: inside placement is limited to box chrome surfaces -> Unit 1 and Unit 2 must preserve line/stroke single-select behavior while treating multi-select group box as box chrome.
- `.design/2026-06-04-selection-chrome-and-move-hit-area.md:134` / decision trace D5: group-box admission belongs to `InteractionReadPort` and `MoveMachine` -> Unit 3 and Unit 4 own selected-move start changes.
- `.design/2026-06-04-selection-chrome-and-move-hit-area.md:135` / decision trace D6: exact hit-test remains intact and topmost hit/order facts are preserved -> Unit 3 and Unit 6 must protect ordinary selection/context hits.
- `.design/2026-06-04-selection-chrome-and-move-hit-area.md:136` / decision trace D7: higher-order content blocks union-only group admission -> Unit 3 and Unit 4 must prove occlusion rejection.
- `.design/2026-06-04-selection-chrome-and-move-hit-area.md:137` / decision trace D8: durable docs and diagrams must change -> Unit 5 owns source-of-truth updates.
- `.design/2026-06-04-selection-chrome-and-move-hit-area.md:143` / outcome-proof: checking selected count or visual smoke alone can pass while two primitives still exist -> Unit 1 uses direct planner fixture assertions.
- `.design/2026-06-04-selection-chrome-and-move-hit-area.md:145` / outcome-proof: checking primitive `orderToken` alone can pass while painter draws decorations last -> Unit 2 requires painter-output occlusion proof.
- `.design/2026-06-04-selection-chrome-and-move-hit-area.md:150` / outcome-proof: pure rectangle containment can steal clicks from upper objects -> Unit 3 and Unit 4 require occluding-object negative proof.
- `.design/2026-06-04-selection-chrome-and-move-hit-area.md:165` / hard gate: successor seams are ordered decoration metadata, ordered painter insertion, richer selected-move facts, and policy-owned top-hit result data -> units must migrate consumers before retiring old behavior.
- `.design/2026-06-04-selection-chrome-and-move-hit-area.md:166` / temporal closure: selected-move admission is one immutable pointer-down decision and pointer move never reruns admission -> Unit 4 must preserve session temporal behavior.
- `.design/2026-06-04-selection-chrome-and-move-hit-area.md:167` / all-or-nothing boundary: no new document mutation boundary is introduced and group admission only creates reversible session state -> Unit 4 completion checks must preserve terminal cleanup/commit semantics.
- `.design/2026-06-04-selection-chrome-and-move-hit-area.md:185` / rejected alternatives: using `SelectedOrderSnapshot` document order as chrome paint order is rejected -> Units 1 and 2 must use captured order tokens instead.
- `.design/2026-06-04-selection-chrome-and-move-hit-area.md:257` / source-of-truth impact: frame rendering docs must describe group primitive, order/placement metadata, structural/order invalidation, and interleaved paint -> Unit 5 docs scope is required.
- `.design/2026-06-04-selection-chrome-and-move-hit-area.md:258` / source-of-truth impact: interaction docs must describe exact hit or occlusion-aware multi-select union admission -> Unit 5 docs scope is required.
- `.design/2026-06-04-selection-chrome-and-move-hit-area.md:259` / source-of-truth impact: geometry docs must change if an id-plus-order hit result seam is added -> Unit 5 must keep geometry docs consistent with the chosen seam.
- `.design/2026-06-04-selection-chrome-and-move-hit-area.md:260` / source-of-truth impact: selected-move sequence diagram must include group union containment and top-hit/order facts -> Unit 5 diagram update is required.
- `.design/2026-06-04-selection-chrome-and-move-hit-area.md:261` / source-of-truth impact: selected-move state diagram must include multi-select union admission and occlusion rejection -> Unit 5 diagram update is required.
- `.research/2026-06-04-selection-chrome-and-move-hit-area.md:13` / current state: selection decoration is a frame-owned separate decoration pass with one primitive per selected element and after-all-records paint -> frame planner and painter are the owning visual causes.
- `.research/2026-06-04-selection-chrome-and-move-hit-area.md:19` / current state: selected-move admission starts only from topmost selected movable geometry, and start facts do not expose union bounds -> read-port and move-machine seams must change.
- `.research/2026-06-04-selection-chrome-and-move-hit-area.md:25` / current state: no existing group chrome, bounding-box drag, or inside-frame contract was found -> durable docs must be updated with the new meaning.
- `lib/src/frame/selection_decoration_planner.dart:69` / primitive shape: current primitive has only bounds, color, stroke width, and halo width -> Unit 1 must add immutable order and placement metadata.
- `lib/src/frame/selection_decoration_planner.dart:113` / primitive planning: current planner yields a primitive for each selected facts row -> Unit 1 must replace per-row multi-select output with one group primitive.
- `lib/src/frame/selection_decoration_planner.dart:139` / key: current key includes selection/bounds/preview/style/DPR but no selected order token -> Unit 1 must add order invalidation through a stable source such as structural revision or selected top order token.
- `lib/src/frame/selection_decoration_planner.dart:155` / bounds source: current decoration bounds come from render paint bounds plus selected-move delta -> Unit 1 must reuse this source for group union instead of inventing a second geometry truth.
- `lib/src/surface/main_painter.dart:25` / record order: painter already iterates main-frame records in paint order -> Unit 2 can insert decoration into this ordered stream.
- `lib/src/surface/main_painter.dart:35` / global after-pass: painter currently draws selection decorations after records -> Unit 2 must retire this behavior and prove it cannot overpaint higher content.
- `lib/src/surface/main_painter.dart:73` / centered draw: selection decoration painting currently draws centered rect strokes from primitive bounds -> Unit 2 must introduce inside-box painting for box chrome.
- `lib/src/contracts/internal/frame_facts_port.dart:29` / handle facts: element handles carry `orderToken` -> geometry/read boundary can expose top-hit order without document-order selection snapshots.
- `lib/src/contracts/internal/frame_facts_port.dart:45` / frame facts: element facts include kind, order token, visibility, selectability, lock, transformability, and geometry facts -> Unit 1 and Unit 3 have the facts needed for group bounds/order and family placement.
- `lib/src/frame/render_element_record.dart:122` / render record: immutable records carry family, order token, paint bounds, and hit bounds -> Unit 1 and Unit 2 can pass painter data without public element reads.
- `docs/contracts/frame_rendering.md:147` / owner table: `SelectionDecorationPlanner` owns selection UI decoration and its key -> Unit 1 owns chrome grouping/key metadata.
- `docs/contracts/frame_rendering.md:213` / cache boundary: ordinary render records must not include selection state and selection UI is a separate decoration pass -> Units 1 and 2 must keep chrome separate from ordinary record cache identity.
- `docs/contracts/frame_rendering.md:279` / selection decoration docs: decoration reads selected ids through captured selection facts and invalidates separately from ordinary plans -> Unit 1 must preserve derived plan ownership.
- `docs/contracts/frame_rendering.md:287` / selected order docs: `selectedOrder` is derived by selection/structural revision and is not selection truth -> Units 1 and 2 must not promote `SelectedOrderSnapshot` to chrome paint-order source.
- `lib/src/frame/frame_engine.dart:97` / frame assembly: main frame already builds captured frame, ordinary plan, selected-move supplement, selection decoration, selected order, and output -> units can migrate seams without changing the public frame facade.
- `lib/src/frame/frame_paint_output.dart:12` / output shape: `MainFramePaintOutput` stores selection decoration separately from records and selected-move supplement -> Unit 2 can keep separation while painting ordered chrome.
- `lib/src/frame/selected_order_cache.dart:26` / selected order snapshot: `SelectedOrderSnapshot` contains ordered selected ids, not order-token paint data -> Units 1 and 2 must not use it as chrome z-order.
- `lib/src/geometry/hit_test_policy.dart:21` / topmost hit: policy sorts candidates by order token and returns topmost exact hit id -> Unit 3 should extend or pair this policy-owned result with order facts instead of duplicating hit logic in runtime.
- `lib/src/geometry/hit_test_policy.dart:63` / exact hit: exact hit delegates by element kind after eligibility and bounds checks -> Unit 3 must keep ordinary exact geometry semantics intact.
- `docs/contracts/geometry.md:82` / point hit: point hit is content-only, reverse paint order, first exact hit wins, and background is not pointer-selectable -> Unit 3 and Unit 6 must preserve topmost exact hit behavior.
- `lib/src/interaction/interaction_read_port.dart:8` / read boundary: interaction read port is the single immutable fact boundary for pointer decisions -> Unit 3 must add group facts here, not in app/surface/painter.
- `lib/src/interaction/interaction_read_port.dart:52` / start facts: current selected-move start facts expose selected ids, movable selected ids, controller epoch, selection revision, hit-selected flag, and query facts -> Unit 3 must add or rename facts to distinguish exact selected geometry hit from group-union admission.
- `lib/src/runtime/runtime_interaction_read_adapter.dart:41` / runtime adapter: selected-move start facts are built from selection, frame, spatial query, and hit-test policy -> Unit 3 is the owner for selected union containment and occlusion facts.
- `lib/src/runtime/runtime_interaction_read_adapter.dart:72` / exact hit flag: `hitSelectedMovable` currently means topmost hit id is movable selected id -> Unit 3 must preserve this exact-hit fact while adding group admission.
- `lib/src/interaction/move_machine.dart:15` / admission: `MoveMachine.start` currently rejects unless exact selected movable hit is true -> Unit 4 must change admission predicate using read-port facts.
- `lib/src/runtime/runtime_interaction_move_read_models.dart:70` / union helper: selected-move commit read models already union moved element bounds -> Unit 3 may reuse or extract this concept at the runtime read boundary to avoid duplicate union semantics.
- `docs/contracts/interaction_engine.md:159` / read contract: selected-related reads are batched by intent through `InteractionReadPort` -> Unit 3 must keep the group hit area in the read snapshot.
- `docs/contracts/interaction_engine.md:172` / fallback behavior: move-mode click within pointer slop is point-selection commit through marquee/select -> Unit 4 and Unit 6 must preserve fallback when selected move is rejected.
- `docs/diagrams/seq_selected_move_preview_commit.mmd:37` / sequence: selected-move start facts currently come from read port -> Unit 5 must update the sequence, not create a new source-of-truth document.
- `docs/diagrams/state_selected_move.mmd:16` / state diagram: current state names selected target admission -> Unit 5 must update admission state semantics.
- `docs/verification/tests.md:1` / generated inventory: tests inventory is generated from docs registry -> Unit 5 must update registry/generated docs when new durable test ids are introduced.
- `test/frame/fixtures/selection_decoration_plan_fixture.dart:72` / current proof: existing fixture asserts one selected rect primitive bounds -> Unit 1 must preserve single-select and add multi-select/order/placement cases.
- `test/surface/fixtures/no_live_runtime_read_in_painters_fixture.dart:50` / current proof: main painter has a paint-order test for records only -> Unit 2 must add decoration-vs-record painter output proof.
- `test/interaction/fixtures/interaction_read_port_fixture.dart:33` / current proof: read-port fixture covers selected-move start facts and `hitSelectedMovable` -> Unit 3 must extend it with group union, top-hit, and occlusion facts.
- `test/interaction/fixtures/move_machine_fixture.dart:30` / current proof: selected move admission starts from selected geometry hit -> Unit 4 must add group-interior start and occlusion rejection paths.
- `test/interaction/fixtures/move_machine_fixture.dart:163` / current proof: terminal behavior covers resolver commit/action paths -> Unit 4 must show group-box admission still uses the same terminal cleanup/commit semantics.

## Boundaries

Owner:

Frame owns selection chrome planning, primitive metadata, decoration key invalidation, and separation from ordinary paint cache. Surface painter owns ordered consumption of immutable frame output and box/outline stroke painting. Geometry owns exact topmost hit policy and any id-plus-order hit result seam. Runtime read adapter owns composing selected ids, movable ids, top-hit/order facts, selected union containment, and occlusion facts into immutable `InteractionReadPort` facts. `MoveMachine` owns selected-move start admission from those facts. Existing docs/contracts/diagrams/verification registry own durable behavior descriptions. `PLAN.md` and this file own planning state only.

In Scope:

Extend `SelectionDecorationPrimitive` / `SelectionDecorationPlan` / `SelectionDecorationKey` so single-select emits one ordered primitive and multi-select emits exactly one ordered union primitive. The multi-select union is always group box chrome, including mixed or only line/stroke selections. Box chrome for multi-select, single rect, and single image uses inside stroke placement; single line and single stroke remain bounds/outline chrome without broad inside-rect drag semantics. Paint selection decoration interleaved with main records by captured order tokens so higher-order content can cover chrome. Extend selected-move start facts and runtime read mapping with exact selected hit, group-union containment, selected top order, and higher-order occluder information from one pointer-down snapshot. Admit selected move when the exact topmost hit is a movable selected id, or when a multi-selected union contains the point and no higher-order exact content hit occludes it. Update docs, diagrams, generated verification inventory, and focused tests for the changed behavior.

Out of Scope:

Do not add public API fields, document schema changes, public selection metadata, application-computed hit areas, `CanvasSurface` overlay hit boxes, resize handles, rotate handles, new context-action behavior, line/stroke-specific handle systems, old scene compatibility, global scene sorting, ordinary paint cache selection state, stored selection-union state, or app/runtime live reads from painters. Do not use `SelectedOrderSnapshot` or document-order selected ids as the chrome paint-order source; it may remain selected-order derived data for its existing purpose, but chrome z-order must use captured `orderToken` facts or immutable render records.

Source of Truth:

The design file is the contract source input and decision handoff. The research file is the current-state evidence source. Durable behavior after implementation belongs in existing owners: `docs/contracts/frame_rendering.md`, `docs/contracts/interaction_engine.md`, `docs/contracts/geometry.md` if a hit-result seam changes, `docs/diagrams/seq_selected_move_preview_commit.mmd`, `docs/diagrams/state_selected_move.mmd`, `docs/_registry/sections.yaml`, generated `docs/verification/tests.md` when new required proof ids or paths are introduced, and `docs/verification/guardrails.md` only if the implementation adds or changes a repository guardrail. Runtime truth remains selected ids from selection facts, order tokens and element bounds from frame/geometry facts, and exact hits from `HitTestPolicy`; group bounds/order are derived per frame or read snapshot and are not new committed state.

Compatibility:

Public API signatures, schemas, document formats, resource/session behavior, ordinary exact hit testing, point selection, context-action targeting, selected-move preview publication, selected-move terminal commit/cleanup semantics, and ordinary paint cache identity must remain compatible. Rejected selected-move group admission must fall through to existing move-mode behavior with no selected-move preview, resolver call, action, or document mutation. Single selected line/stroke bounds interior must not become a selected-move start area unless exact geometry is hit. Multi-select group box chrome uses inside placement as an explicit product rule even when all selected elements are lines or strokes.

Dependency/import direction:

Frame and surface painter code may consume frame-owned plans, immutable render records, render primitive snapshots, and asset bindings. Frame code must not import runtime/store/app surfaces for chrome planning. Surface painters must not receive or live-read runtime, store, resolver, public document projection, or selection owners. Interaction code consumes `InteractionReadPort` immutable facts; runtime read adapter may compose frame facts, selection facts, spatial query, and geometry hit policy. Geometry policy must remain the owner of exact hit semantics. Docs/diagram changes must update existing source-of-truth files instead of adding a new behavior document.

Order Constraints:

Migrate frame data first: add primitive order/placement metadata, group primitive planning, and key invalidation before relying on painter insertion. Then migrate painter output: paint static background, records at or below the chrome order, the ordered decoration primitive, then higher-order records; prove output order directly. Then migrate geometry/read seams: preserve exact topmost hit and expose top-hit order through a policy-owned result or equivalent immutable read fact before changing `MoveMachine`. Then migrate `MoveMachine.start` admission and runtime tests. Finally update docs/diagrams/registry/generated docs and run repository checks. Retire per-selected multi-select chrome, global after-pass selection paint, exact-only group selected-move admission, and any tests that encode those old behaviors only after replacement tests exist.

Performance Constraints:

Painter order insertion must be bounded by the already-built main-frame record stream plus the selection decoration primitive list for the current frame; do not introduce a global scene sort, full document traversal, offscreen `saveLayer`, or ordinary paint cache write to render selection chrome. Selected-union derivation must visit only selected handles/facts in the current frame or interaction read snapshot. Pointer-down occlusion must use the bounded spatial point query and policy-owned exact hit result for the down point; do not scan the whole document for occluders and do not store selection union bounds as committed state, cached app state, or sync glue. Do not add a `CanvasSurface` overlay hit target, background synchronizer, or app-side bridge to keep visual chrome and interaction hit areas consistent. Add a persistent cache only if a focused measurement or failing performance test justifies it, and then document the invariant that invalidates it in the owning source of truth.

Temporal Surface Closure:

The temporal invariant is that selected-move admission is a single immutable pointer-down read decision; pointer move samples never rerun admission or recompute occlusion. Synchronous callback surfaces in the changed admission window are none before selected-move session admission; resolver callbacks remain terminal-only. Guard owner is `InteractionEngine` plus `MoveMachine`; read boundary owner is `InteractionReadPort`. Allowed public observation order is unchanged: rejected start publishes no selected-move preview, calls no resolver, emits no action, and makes no document mutation; admitted start can publish selected-move preview through the existing preview path; zero-delta terminal cleans preview without resolver/action. Occluded group-union admission is rejected with the same no-mutation signal as any other rejected selected-move start.

All-Or-Nothing Failure Boundary:

No new document mutation boundary is introduced. Decoration planning computes derived immutable plan data before publishing the frame output; painter draw has no store mutation and no recoverable document side effect. Selected-move group admission only creates reversible session state until terminal. Fallible geometry/read work, including spatial query, element resolution, union derivation, and occluder classification, must complete before admission. The irreversible document mutation point remains the existing selected-move terminal edit path. Failure projection before admission is rejected start with no preview/resolver/action/document change; failure projection at zero-delta or stale terminal remains cleanup-only through existing terminal semantics.

## Execution Units

### [x] Unit 1: Selection decoration group primitive and order-aware key

Owner:

`lib/src/frame/selection_decoration_planner.dart`, directly necessary frame-private value types/helpers, and frame planner fixtures/tests.

Boundary:

Produce immutable selection chrome primitives from captured frame facts and selection facts. This unit does not paint the primitives, decide selected-move admission, update docs, or change public API.

Change:

Extend selection decoration primitives with captured paint order token, selected count or chrome form, and stroke placement metadata. For zero selection, keep no primitives. For single selection, emit one primitive for the selected element with bounds from the existing render paint bounds source, selected-move preview delta shift, the element order token, and placement based on element family: inside box for rect/image, bounds/outline for line/stroke/text/path unless the implementation has an already-documented existing placement for those families. For multi-select, emit exactly one group-box primitive whose bounds are the union of all selected paint bounds shifted by selected-move preview delta, whose paint order token is the maximum selected element order token, and whose placement is inside box chrome regardless of selected element families. Update the decoration key so selected chrome order changes invalidate the plan through structural revision, selected top order token, or an equally frame-owned order fact. Do not use `SelectedOrderSnapshot` as the source of chrome paint order.

Completion Check:

Frame planner tests under the selection decoration fixture prove direct outcomes: two selected elements produce exactly one primitive whose `boundsWorld` equals the union of selected paint bounds and whose selected-move preview delta shifts that union; a single rect and single image each produce one inside-box primitive using that element's order token; a single line/stroke still produces one non-inside bounds/outline primitive and does not gain box-inside semantics; a multi-select made only of line/stroke elements still produces one inside group-box primitive; changing selected top order or structural revision rebuilds or changes the plan even when selected ids and bounds are otherwise stable; ordinary paint plan/cache keys still do not include selection membership or preview facts. A structural or focused test must fail if chrome paint order is derived from `SelectedOrderSnapshot.orderedSelectedIds` rather than captured order tokens.

Depends On:

None.

### [x] Unit 2: Main painter ordered chrome and inside-box stroke output

Owner:

`lib/src/surface/main_painter.dart`, painter-facing frame output consumption, and surface painter/order fixtures/tests.

Boundary:

Consume immutable frame output and render selection chrome in scene order. This unit does not compute selected union bounds, selected ids, runtime read facts, or gesture admission.

Change:

Replace global after-pass selection decoration painting with ordered insertion into the existing main-record paint stream. Paint each selection decoration primitive after records with order token less than or equal to the primitive paint order and before records with a greater order token, without globally sorting the whole scene or writing ordinary record cache state. Paint box chrome with inside stroke placement so the visible stroke does not protrude outside the primitive bounds; keep non-box/bounds-outline placement for primitive forms that Unit 1 marks that way. Preserve static background first and painter no-live-runtime-read boundaries.

Completion Check:

Painter tests prove actual output, not only primitive metadata: a lower-order selected object or selected group with an overlapping higher-order unselected record renders with the higher-order content visibly covering the selection frame; the test must fail if `MainFramePainter` still draws all selection decorations after all records. A painter geometry test records or inspects drawn stroke rectangles and proves inside-box chrome for single rect/image and multi-select group does not protrude outside primitive bounds, while non-box outline chrome does not incorrectly use inside-box placement. Existing record bottom-to-top and no-live-runtime-read painter tests remain passing, and focused assertions prove ordered decoration insertion is a bounded merge over the existing paint-order stream plus selection primitives, does not introduce a global scene sort, does not call `saveLayer`, and does not write ordinary cache state.

Depends On:

Unit 1.

### [x] Unit 3: Read-port selected move start facts and occlusion-aware group union

Owner:

`lib/src/geometry/hit_test_policy.dart` if an id-plus-order result seam is needed, `lib/src/interaction/interaction_read_port.dart`, `lib/src/runtime/runtime_interaction_read_adapter.dart`, focused runtime read helpers, and read-port/runtime fixtures.

Boundary:

Compute immutable pointer-down facts for selected-move start from selection, frame, spatial query, and geometry policy. This unit does not decide final move-machine admission beyond carrying facts, does not paint chrome, and does not mutate document state.

Change:

Preserve ordinary exact topmost hit behavior while exposing enough immutable facts for selected-move start: exact topmost hit id, exact topmost hit order token when present, whether the exact hit is a movable selected id, selected ids, movable selected ids, selected group union bounds for multi-select, selected top order token, whether the pointer is inside the selected group union, and whether a higher-order exact content hit occludes union-only admission. Use `HitTestPolicy` or a policy-owned hit-result seam for exact hit id/order; do not duplicate exact element-kind hit logic in runtime. Derive selected union from current read-snapshot element bounds using the same geometry policy concept as selected-move commit bounds. Compute occlusion so a bare `union.contains(point)` cannot admit a group drag when the point is over a higher-order exact content hit above the selected top order token.

Completion Check:

Read-port/runtime tests prove immutable selected-move start facts for direct outcomes: exact selected movable hit remains true for a selected geometry hit; separated selected movable elements expose multi-select group union containment for a point between exact shapes; the same point over a higher-order unselected exact content hit reports occlusion and does not mark union-only admission as available; topmost exact hit id/order remains available for ordinary selection/context consumers; selected/movable ids remain immutable and document/action ordered as previously required. Geometry policy tests or read-port tests fail if runtime duplicates element-kind exact-hit switches instead of using the policy-owned seam. A negative test proves a single selected line/stroke bounds miss does not produce group-union admission. A focused bounded-work assertion or fixture proves the read adapter uses the spatial point-query candidates plus selected handles/facts for the current snapshot and does not scan all document elements, store committed group bounds, or introduce app/runtime sync state for occlusion.

Depends On:

Unit 2.

### [x] Unit 4: Move-machine admission and runtime selected-move behavior

Owner:

`lib/src/interaction/move_machine.dart`, interaction/runtime selected-move start integration, and move-machine/runtime fixtures.

Boundary:

Decide selected-move session admission from `SelectedMoveStartFacts` and preserve existing preview/terminal behavior after admission. This unit does not compute raw hit geometry, paint chrome, or change resolver/edit-kernel terminal ownership.

Change:

Update `MoveMachine.start` so non-empty selected ids and movable selected ids admit selected move when either the exact topmost hit is a movable selected id or the read-port facts show multi-select group union containment with no higher-order occluder. Reject empty selection, empty movable set, single-selection bounds-only misses, occluded union-only starts, stale/non-finite admission facts, and any fact combination that does not satisfy the read-port-owned policy. Preserve the existing session capture, selected-move preview, pointer move, terminal commit, resolver cancel/error, zero-delta cleanup, stale selection cleanup, and no-action/no-document-mutation behavior.

Completion Check:

Move-machine and runtime tests prove direct behavior: pointer down inside empty space between two selected movable elements starts a selected-move session and subsequent move publishes the existing `CanvasSelectedMovePreview`; pointer down inside the selected union but over a higher-order unselected exact hit rejects selected-move start and falls through with no selected-move preview, resolver call, action, or document mutation; pointer down inside a single selected line/stroke bounding box but outside exact geometry rejects selected-move start; exact selected movable hit still admits as before. Terminal regression tests run through the new group-box admission path and prove non-zero terminal commit uses existing `SelectedMoveCommitIntent` data, zero delta cleans without resolver/action, resolver cancel/error clean preview through existing paths, and stale selection/controller facts still reject mutation.

Depends On:

Unit 3.

### [x] Unit 5: Durable docs, diagrams, and generated verification inventory

Owner:

`docs/contracts/frame_rendering.md`, `docs/contracts/interaction_engine.md`, `docs/contracts/geometry.md` when the geometry hit-result seam changes, `docs/diagrams/seq_selected_move_preview_commit.mmd`, `docs/diagrams/state_selected_move.mmd`, `docs/_registry/sections.yaml`, generated `docs/verification/tests.md`, and docs tests/checks.

Boundary:

Update existing source-of-truth documentation and generated verification inventory for the new behavior. This unit does not create a new behavior document and does not implement production code.

Change:

Document frame selection decoration as one single/group primitive with order/placement metadata, inside box chrome for multi-select/rect/image, structural/order invalidation, and interleaved main-scene painting while keeping ordinary paint cache free of selection state. Document selected-move start facts as exact selected geometry hit or occlusion-aware multi-select union containment from `InteractionReadPort`, including the immutable pointer-down snapshot and no-mutation rejection signal. Document geometry hit result order exposure only if the implementation adds or changes that seam. Update selected-move sequence and state diagrams to show group union containment, top-hit/order facts, occlusion rejection, and unchanged terminal paths. Update registry/generated verification docs when new test ids or proof paths become durable. Update `docs/verification/guardrails.md` only if Unit 6 adds or changes a repository guardrail; otherwise do not claim a new guardrail.

Completion Check:

Documentation checks prove source-of-truth consistency: `dart run docs/tool/sync_generated_docs.dart --check` and `dart run docs/tool/check_docs.dart` pass after any needed regeneration. A docs diff review can trace every new durable behavior to an existing source-of-truth owner and no new standalone behavior doc is added. Diagram text explicitly names group-union admission, top-hit/order facts, occlusion rejection, and unchanged terminal cleanup/commit paths. Generated `docs/verification/tests.md` is current if `docs/_registry/sections.yaml` changes. `docs/verification/guardrails.md` is updated in the same unit if, and only if, the implementation adds or changes a guardrail in Unit 6.

Depends On:

Units 1, 2, 3, and 4.

### [x] Unit 6: Compatibility proof, metrics, and final repository checks

Owner:

Focused compatibility tests, guardrail/boundary tests if needed, and repository verification commands for changed frame, surface, geometry, interaction, runtime, docs, and test owners.

Boundary:

Prove the migrated seams do not regress adjacent public behavior or repository boundaries. This unit does not introduce new product behavior beyond the selected chrome and selected-move hit-area changes.

Change:

Add or preserve focused compatibility proof for ordinary point selection, marquee fallback, context-action topmost hit behavior, no public API/schema change, painter no-live-runtime-read boundaries, ordinary cache non-churn, and import direction. Update guardrail tests only if focused behavior tests cannot mechanically enforce a stable repository boundary. Run repository-required checks for all touched code, docs, and generated surfaces.

Completion Check:

Focused tests prove ordinary point selection and context-action targeting still use exact topmost geometry instead of selection union containment; move-mode rejected selected-move starts still route to existing fallback behavior; public API/schema snapshots or compile checks show no new public fields or document format changes; painter boundary tests still reject live runtime/store/resolver reads; ordinary paint cache tests still show selection/preview facts are excluded. Structural or focused checks fail if the implementation adds a `CanvasSurface` overlay hit target, app-side selection-union bridge, persisted selection-union cache without documented measured justification, full-document occluder scan, or `SelectedOrderSnapshot` paint-order dependency. Required verification commands for this mixed code/docs step are `dart analyze`, `dcm analyze .`, scoped `dcm calculate-metrics` for changed production/test/tool/docs-generation owners such as `lib/src/frame`, `lib/src/surface`, `lib/src/geometry`, `lib/src/interaction`, `lib/src/runtime`, `test/frame`, `test/surface`, `test/interaction`, and docs tooling if touched, plus the focused Dart/Flutter tests that cover Units 1 through 4 and compatibility tests in this unit. Run `dart run docs/tool/sync_generated_docs.dart --check` and `dart run docs/tool/check_docs.dart` when docs/registry/generated docs changed. Run architecture graph checks only if architecture graph-owned seams, diagrams, generated graph views, or phase closure state are changed.

Depends On:

Units 1, 2, 3, 4, and 5.
