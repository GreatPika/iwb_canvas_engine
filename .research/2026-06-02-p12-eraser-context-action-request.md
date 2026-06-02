---
date: 2026-06-02
researcher: Codex
commit: efabccff
branch: new-architecture
research_question: "What in the current repository already defines behavior, constraints, and integration points for P12 eraser and context-action request?"
---

# Research: P12 Eraser And Context-Action Request

## Summary

P12 is already defined as the phase that adds eraser preview/commit and
context-action double-tap request routing. The phase request states that P12
builds the eraser state machine, `CanvasEraserPreview`, exact-hit integration,
terminal deletion through `EditKernel`, no-partial behavior on exact-budget
overflow, context-action request emission, `CanvasInteractionRequestId`,
guarded `commitTextEdit`, terminal cleanup, and stale terminal rejection
(`docs/implementation/p12_eraser_and_text_request.md:5`,
`docs/implementation/p12_eraser_and_text_request.md:11`,
`docs/implementation/p12_eraser_and_text_request.md:17`,
`docs/implementation/p12_eraser_and_text_request.md:20`,
`docs/implementation/p12_eraser_and_text_request.md:23`,
`docs/implementation/p12_eraser_and_text_request.md:26`).

The current codebase already contains the public API shapes, geometry eraser
primitives, spatial eraser candidate query, edit-kernel deletion and rollback
paths, overlay preview rendering for eraser previews, pointer cleanup
coordination, stale terminal cleanup infrastructure, and public smoke coverage
for today's placeholder context/text behavior. The production runtime does not
currently implement the P12 request producer or text edit acceptance path:
`handleDoubleTap` throws `UnsupportedError`, `commitTextEdit` validates input
and returns `false`, and no production `InteractionRequestRegistry` was found
(`lib/src/runtime/runtime_root.dart:841`, `lib/src/runtime/runtime_root.dart:845`,
`lib/src/runtime/runtime_root.dart:649`, `lib/src/runtime/runtime_root.dart:657`).

P12 crosses documented boundaries between geometry, spatial queries, preview
state, pointer interaction, edit commits, event dispatch, public streams, and
application-owned UI. The contracts keep these boundaries separate:
InteractionEngine reads committed facts through narrow read ports and commits
only through `EditKernel` (`docs/contracts/interaction_engine.md:144`,
`docs/contracts/interaction_engine.md:151`), geometry owns eraser hit policy and
budget inputs (`docs/contracts/geometry.md:157`,
`docs/contracts/geometry.md:167`), and public API owns the request/event/text
command surface (`docs/contracts/public_api_v1.md:381`,
`docs/contracts/public_api_v1.md:1475`).

## Detailed Findings

### 1. P12 Phase Inputs And Documentation Map

- **Location**: `docs/implementation/p12_eraser_and_text_request.md:1`.
- **Description**: The P12 request is titled "P12 eraser and context-action
  request" and sets the implementation purpose as eraser preview/commit with
  exact-check budgets plus context-action double-tap request routing
  (`docs/implementation/p12_eraser_and_text_request.md:5`,
  `docs/implementation/p12_eraser_and_text_request.md:6`,
  `docs/implementation/p12_eraser_and_text_request.md:7`).
- **Scope facts**: The build scope explicitly names the eraser state machine,
  `CanvasEraserPreview`, exact-hit integration, terminal commit through
  `EditKernel`, no partial erase when exact checks exceed budget, direct and
  pointer-sample double-tap routing, target read models, request ids, guarded
  text edit commits, terminal cleanup, and stale terminal rejection
  (`docs/implementation/p12_eraser_and_text_request.md:11`,
  `docs/implementation/p12_eraser_and_text_request.md:14`,
  `docs/implementation/p12_eraser_and_text_request.md:15`,
  `docs/implementation/p12_eraser_and_text_request.md:16`,
  `docs/implementation/p12_eraser_and_text_request.md:18`,
  `docs/implementation/p12_eraser_and_text_request.md:20`,
  `docs/implementation/p12_eraser_and_text_request.md:21`,
  `docs/implementation/p12_eraser_and_text_request.md:23`,
  `docs/implementation/p12_eraser_and_text_request.md:24`,
  `docs/implementation/p12_eraser_and_text_request.md:26`).
- **Dependencies**: P12 states dependencies on P5 deletion commits/rollback, P8
  geometry and spatial exact hit primitives, P9 overlay preview capture, P10
  pointer session/move safety, and P11 draw-mode preview infrastructure
  (`docs/implementation/p12_eraser_and_text_request.md:37`,
  `docs/implementation/p12_eraser_and_text_request.md:39`,
  `docs/implementation/p12_eraser_and_text_request.md:40`,
  `docs/implementation/p12_eraser_and_text_request.md:41`,
  `docs/implementation/p12_eraser_and_text_request.md:42`,
  `docs/implementation/p12_eraser_and_text_request.md:43`).
- **Read-first contract inputs**: P12 names public API v1, interaction engine,
  geometry policy, and tests as the required read-first sections
  (`docs/implementation/p12_eraser_and_text_request.md:45`,
  `docs/implementation/p12_eraser_and_text_request.md:47`,
  `docs/implementation/p12_eraser_and_text_request.md:48`,
  `docs/implementation/p12_eraser_and_text_request.md:49`,
  `docs/implementation/p12_eraser_and_text_request.md:50`).
- **Contracts satisfied by P12**: The P12 file states that the phase satisfies
  eraser policy, exact-check budgets, and no-partial-commit behavior from
  geometry policy; eraser and context-action interaction behavior from the
  interaction engine; public `CanvasEraserPreview`, context-action request
  event, guarded text edit commit, editText action payload API, and erase action
  payload API from public API v1; and operation matrix rows for eraser preview,
  eraser commit, and context request behavior
  (`docs/implementation/p12_eraser_and_text_request.md:85`,
  `docs/implementation/p12_eraser_and_text_request.md:87`,
  `docs/implementation/p12_eraser_and_text_request.md:88`,
  `docs/implementation/p12_eraser_and_text_request.md:89`,
  `docs/implementation/p12_eraser_and_text_request.md:90`,
  `docs/implementation/p12_eraser_and_text_request.md:91`,
  `docs/implementation/p12_eraser_and_text_request.md:92`,
  `docs/implementation/p12_eraser_and_text_request.md:93`,
  `docs/implementation/p12_eraser_and_text_request.md:94`,
  `docs/implementation/p12_eraser_and_text_request.md:95`).
- **P12 exit-gate load cleanup fact**: The P12 exit gate states that stale
  terminal samples do not commit and that `loadDocument` prepared cleanup before
  install clears eraser/context gesture state on success while failure preserves
  it where required (`docs/implementation/p12_eraser_and_text_request.md:153`,
  `docs/implementation/p12_eraser_and_text_request.md:154`,
  `docs/implementation/p12_eraser_and_text_request.md:155`,
  `docs/implementation/p12_eraser_and_text_request.md:156`).
- **P12 risks and trade-offs**: The P12 file identifies eraser deletion as the
  interaction path most likely to partially mutate state, and states that
  budget-exceeded terminal behavior must be cleanup/no-op and never partial
  commit. It also states that context menus and text editing UI remain
  application-owned and the engine only emits the request
  (`docs/implementation/p12_eraser_and_text_request.md:158`,
  `docs/implementation/p12_eraser_and_text_request.md:160`,
  `docs/implementation/p12_eraser_and_text_request.md:161`,
  `docs/implementation/p12_eraser_and_text_request.md:162`,
  `docs/implementation/p12_eraser_and_text_request.md:163`).
- **P12 phase placement**: The P12 file says eraser and context-action request
  both need geometry, spatial, frame preview, pointer session, event dispatch,
  and edit safety, and that they belong after move and draw tools when shared
  interaction machinery is already proven
  (`docs/implementation/p12_eraser_and_text_request.md:165`,
  `docs/implementation/p12_eraser_and_text_request.md:167`,
  `docs/implementation/p12_eraser_and_text_request.md:168`,
  `docs/implementation/p12_eraser_and_text_request.md:169`).
- **Documentation entry point**: `docs/README.md` routes implementation phases
  through `docs/indexes/by_phase.md`, verification through
  `docs/verification/`, subsystem contracts through `docs/indexes/by_subsystem.md`,
  diagrams through `docs/diagrams/catalog.md`, and Change Contracts through
  `PLAN.md` plus `plan/` (`docs/README.md:7`, `docs/README.md:10`,
  `docs/README.md:11`, `docs/README.md:12`, `docs/README.md:16`,
  `docs/README.md:19`).
- **Active plan**: `PLAN.md` states that it is the active roadmap/source of truth
  for current work and that completed steps remain historical references
  (`PLAN.md:5`, `PLAN.md:15`). The step list read in `PLAN.md:21` through
  `PLAN.md:70` ends with completed Step 48 P11 draw tools and contains no P12
  plan step.
- **Phase index**: The generated phase index maps P12 to public API, edit
  kernel, load document, operation matrix, interaction engine, geometry policy,
  spatial kernel, and tests sections (`docs/indexes/by_phase.md:107`,
  `docs/indexes/by_phase.md:109`, `docs/indexes/by_phase.md:110`,
  `docs/indexes/by_phase.md:111`, `docs/indexes/by_phase.md:112`,
  `docs/indexes/by_phase.md:113`, `docs/indexes/by_phase.md:114`,
  `docs/indexes/by_phase.md:115`, `docs/indexes/by_phase.md:116`).

### 2. Eraser Behavior Already Defined

- **Location**: `docs/diagrams/state_eraser.mmd:16`.
- **Description**: The eraser state diagram defines admission as requiring an
  active token, session id, controller epoch, draw mode, eraser tool, finite
  point, and finite thickness (`docs/diagrams/state_eraser.mmd:16`,
  `docs/diagrams/state_eraser.mmd:18`,
  `docs/diagrams/state_eraser.mmd:19`).
- **Preview state machine facts**: Eraser down publishes the first
  `CanvasEraserPreview`, move updates query spatial candidates and exact eraser
  checks, preview budget overflow produces corridor-only preview without
  tentative ids, and preview candidate refresh is read-only
  (`docs/diagrams/seq_eraser_commit.mmd:27`,
  `docs/diagrams/seq_eraser_commit.mmd:33`,
  `docs/diagrams/seq_eraser_commit.mmd:48`,
  `docs/diagrams/seq_eraser_commit.mmd:50`,
  `docs/diagrams/seq_eraser_commit.mmd:51`,
  `docs/diagrams/state_eraser.mmd:47`,
  `docs/diagrams/state_eraser.mmd:49`,
  `docs/diagrams/state_eraser.mmd:55`).
- **Corridor and thickness**: Public API v1 defines eraser as a draw tool,
  includes `eraserThickness` in `CanvasDrawStyle`, and defines
  `CanvasEraserPreview` with unmodifiable corridor and thickness
  (`docs/contracts/public_api_v1.md:1568`,
  `docs/contracts/public_api_v1.md:1663`,
  `docs/contracts/public_api_v1.md:2066`,
  `docs/contracts/public_api_v1.md:2070`,
  `docs/contracts/public_api_v1.md:2072`,
  `docs/contracts/public_api_v1.md:2073`).
- **Preview revision effects**: The interaction contract states that preview
  changes publish sealed variants and increment preview revision while public
  preview payloads exclude selected ids, pointer tokens, active pointer ids, and
  session ids (`docs/contracts/interaction_engine.md:153`,
  `docs/contracts/interaction_engine.md:257`). `InteractionEngine.replacePreview`
  increments `_previewRevision` only when the preview state actually changes
  (`lib/src/interaction/interaction_engine.dart:103`,
  `lib/src/interaction/interaction_engine.dart:110`).
- **Cleanup-only paths**: P12 states eraser cleanup-only paths clear preview and
  session through the existing cleanup seam and do not emit erase action or
  document state (`docs/implementation/p12_eraser_and_text_request.md:31`,
  `docs/implementation/p12_eraser_and_text_request.md:32`). The eraser state
  diagram includes cancel, mode/load/interactive/dispose, stale/invalid, empty
  ids, budget overflow, and edit-failure as cleanup-only paths
  (`docs/diagrams/state_eraser.mmd:112`,
  `docs/diagrams/state_eraser.mmd:114`,
  `docs/diagrams/state_eraser.mmd:116`,
  `docs/diagrams/state_eraser.mmd:119`,
  `docs/diagrams/state_eraser.mmd:120`).
- **Exact-hit budgets and no partial erase**: The geometry contract defines
  preview candidate/exact budgets as 512/4096 per sample and terminal
  candidate/exact budgets as 4096/32768 per gesture. Preview budget overflow
  produces corridor-only preview; terminal budget overflow produces cleanup/no-op
  with no partial erase and no document, selection, spatial, projection, main
  repaint, or action effect (`docs/contracts/geometry.md:167`,
  `docs/contracts/geometry.md:170`,
  `docs/contracts/geometry.md:171`,
  `docs/contracts/geometry.md:172`,
  `docs/contracts/geometry.md:173`,
  `docs/contracts/geometry.md:174`,
  `docs/contracts/geometry.md:175`). The exact-budget sequence diagram separates
  preview spatial, preview exact, terminal spatial, terminal exact, empty exact
  ids, and non-empty exact ids (`docs/diagrams/seq_eraser_exact_budget.mmd:33`,
  `docs/diagrams/seq_eraser_exact_budget.mmd:43`,
  `docs/diagrams/seq_eraser_exact_budget.mmd:66`,
  `docs/diagrams/seq_eraser_exact_budget.mmd:79`,
  `docs/diagrams/seq_eraser_exact_budget.mmd:89`,
  `docs/diagrams/seq_eraser_exact_budget.mmd:92`,
  `docs/diagrams/seq_eraser_exact_budget.mmd:101`).
- **Deletion commit location**: Runtime command deletion currently uses
  `EditKernel.prepareInteractionCommit`, calls `edit.removeElement`, augments the
  commit plan with delete/remove action intents, and delivers the result
  (`lib/src/runtime/runtime_root.dart:570`,
  `lib/src/runtime/runtime_root.dart:593`,
  `lib/src/runtime/runtime_root.dart:606`).
- **Rollback and edit installation**: `EditKernel.prepareInteractionCommit` opens
  a synchronous edit session, compiles a plan, installs only when the plan has
  changes, and returns no publish result for no-op plans
  (`lib/src/edit/edit_kernel.dart:82`, `lib/src/edit/edit_kernel.dart:123`).
  `CommitApplier.apply` installs document changes before applying selection
  effects and returning action intents (`lib/src/edit/commit_applier.dart:25`,
  `lib/src/edit/commit_applier.dart:55`).
- **Geometry hit testing and spatial candidates**: `HitTestPolicy.exactEraserHit`
  dispatches by element family after eraser eligibility checks
  (`lib/src/geometry/hit_test_policy.dart:79`,
  `lib/src/geometry/hit_test_policy.dart:94`). `SpatialKernel.queryEraser`
  delegates eraser candidate lookup to the paint index
  (`lib/src/geometry/spatial_kernel.dart:139`,
  `lib/src/geometry/spatial_kernel.dart:145`).
- **Preview capture**: `FrameCaptureService.captureOverlayFrame` routes every
  preview except none and selected-move into overlay preview
  (`lib/src/frame/frame_capture_service.dart:28`,
  `lib/src/frame/frame_capture_service.dart:49`). `OverlayPreviewPlanner` maps
  `CanvasEraserPreview` to `EraserOverlayPrimitive`
  (`lib/src/frame/overlay_preview_planner.dart:78`,
  `lib/src/frame/overlay_preview_planner.dart:138`).

### 3. P12 Donor Inputs

- **Location**: `docs/implementation/p12_eraser_and_text_request.md:52`.
- **Description**: The P12 phase file has an explicit `Required donors` section.
  It names `foundation_pointer_input_contract`,
  `foundation_action_event_immutability`, `geometry_interactive_geometry`,
  `geometry_eraser_exact_hit`, `interaction_pointer_session`,
  `interaction_pointer_normalizer`, `interaction_event_dispatcher`,
  `interaction_double_tap_router`, `interaction_gesture_runtime`,
  `interaction_draw_coordinator`, and `interaction_mutation_boundary` as
  required donor inputs (`docs/implementation/p12_eraser_and_text_request.md:52`,
  `docs/implementation/p12_eraser_and_text_request.md:54`,
  `docs/implementation/p12_eraser_and_text_request.md:55`,
  `docs/implementation/p12_eraser_and_text_request.md:56`,
  `docs/implementation/p12_eraser_and_text_request.md:57`,
  `docs/implementation/p12_eraser_and_text_request.md:58`,
  `docs/implementation/p12_eraser_and_text_request.md:59`,
  `docs/implementation/p12_eraser_and_text_request.md:60`,
  `docs/implementation/p12_eraser_and_text_request.md:61`,
  `docs/implementation/p12_eraser_and_text_request.md:62`,
  `docs/implementation/p12_eraser_and_text_request.md:63`,
  `docs/implementation/p12_eraser_and_text_request.md:64`).
- **P12 donor decisions and owners**: P12 marks pointer input and interactive
  geometry donors as `copy/adapt`, action events, eraser exact hit,
  pointer session, event dispatch, double-tap router, gesture runtime, and
  mutation boundary donors as `adapt`, and draw coordinator as `adapt/rewrite`.
  The named target owners are Canvas pointer API and InteractionEngine,
  CanvasActionEvent/context-action request events, draw and eraser geometry
  helpers, eraser exact-hit engine, InteractionEngine pointer session, pointer
  sample normalizer, interaction event dispatch, context-action double-tap
  router, InteractionEngine dispatch order and cleanup, draw/line/eraser
  machines, and the interaction-owned mutation bridge into `EditKernel`
  (`docs/implementation/p12_eraser_and_text_request.md:54`,
  `docs/implementation/p12_eraser_and_text_request.md:64`).
- **Forbidden donor structure in P12**: The phase file forbids donor structure
  from `avoid_scene_controller_facades`, `avoid_interactive_runtime_whole`,
  `avoid_scene_builder_public_architecture`, `avoid_scene_codec_whole`, and
  `avoid_scene_store_controller_whole`
  (`docs/implementation/p12_eraser_and_text_request.md:66`,
  `docs/implementation/p12_eraser_and_text_request.md:68`,
  `docs/implementation/p12_eraser_and_text_request.md:69`,
  `docs/implementation/p12_eraser_and_text_request.md:70`,
  `docs/implementation/p12_eraser_and_text_request.md:71`,
  `docs/implementation/p12_eraser_and_text_request.md:72`).
- **Donor reuse boundary**: The donor inventory defines the current engine as a
  functional oracle and implementation donor, not a legacy dependency. Donor
  use means copying or adapting proven algorithms, contracts, tests, and
  guardrails into the root package shape, without importing the legacy runtime
  or preserving legacy public API (`docs/donors/00_reuse_rules.md:13`,
  `docs/donors/00_reuse_rules.md:14`,
  `docs/donors/00_reuse_rules.md:15`,
  `docs/donors/00_reuse_rules.md:16`). Reuse rules distinguish `copy`,
  `copy/adapt`, `adapt`, `adapt/rewrite`, and `rewrite-reference`
  (`docs/donors/00_reuse_rules.md:24`, `docs/donors/00_reuse_rules.md:30`,
  `docs/donors/00_reuse_rules.md:32`), and reused donors require ported or
  equivalent tests before an implementation slice closes
  (`docs/donors/00_reuse_rules.md:34`,
  `docs/donors/00_reuse_rules.md:35`).
- **P12 phase-bound donor list**: The generated donor-to-phase index maps
  `foundation_pointer_input_contract` to P2/P10/P11/P12 and owner
  Canvas pointer API and InteractionEngine (`docs/indexes/donor_to_phase.md:96`,
  `docs/indexes/donor_to_phase.md:99`,
  `docs/indexes/donor_to_phase.md:100`), maps
  `foundation_action_event_immutability` to P2/P10/P11/P12 and owner
  CanvasActionEvent plus context-action request events
  (`docs/indexes/donor_to_phase.md:102`,
  `docs/indexes/donor_to_phase.md:105`,
  `docs/indexes/donor_to_phase.md:106`), maps
  `geometry_interactive_geometry` to P8/P10/P11/P12 and draw/eraser geometry
  helpers (`docs/indexes/donor_to_phase.md:126`,
  `docs/indexes/donor_to_phase.md:129`,
  `docs/indexes/donor_to_phase.md:130`), and maps
  `geometry_eraser_exact_hit` to P8/P12 and the eraser exact-hit engine
  (`docs/indexes/donor_to_phase.md:132`,
  `docs/indexes/donor_to_phase.md:135`,
  `docs/indexes/donor_to_phase.md:136`).
- **Pointer and event donors**: The donor registry entry
  `foundation_pointer_input_contract` uses legacy pointer input contract files
  for pointer phases, policy validation, and device kind handling, blocks P12,
  and relates to public API and interaction engine sections
  (`docs/_registry/donors.yaml:332`, `docs/_registry/donors.yaml:345`,
  `docs/_registry/donors.yaml:351`,
  `docs/_registry/donors.yaml:355`,
  `docs/_registry/donors.yaml:356`,
  `docs/_registry/donors.yaml:357`,
  `docs/_registry/donors.yaml:358`). The
  `foundation_action_event_immutability` donor uses `lib/src/core/action_events.dart`
  for immutable events, timestamp normalization, and context-action request
  evidence, blocks P12, and requires typed action payload tests
  (`docs/_registry/donors.yaml:361`,
  `docs/_registry/donors.yaml:363`,
  `docs/_registry/donors.yaml:370`,
  `docs/_registry/donors.yaml:372`,
  `docs/_registry/donors.yaml:376`,
  `docs/_registry/donors.yaml:381`).
- **Geometry and eraser donors**: The donor registry maps
  `geometry_interactive_geometry` to `lib/src/interactive/internal/interactive_geometry.dart`
  for segment batching, segment bounds, and rect-distance prefiltering; it blocks
  P12 and requires eraser guardrail tests
  (`docs/_registry/donors.yaml:450`,
  `docs/_registry/donors.yaml:452`,
  `docs/_registry/donors.yaml:459`,
  `docs/_registry/donors.yaml:461`,
  `docs/_registry/donors.yaml:466`,
  `docs/_registry/donors.yaml:471`). It maps
  `geometry_eraser_exact_hit` to the legacy interactive eraser exact-hit files
  for projected eraser-to-local algorithms, singular transform fallback, and
  batched exact checks; it blocks P12 and excludes legacy snapshots, delete
  eligibility shell, and debug counters as structure
  (`docs/_registry/donors.yaml:477`,
  `docs/_registry/donors.yaml:479`,
  `docs/_registry/donors.yaml:480`,
  `docs/_registry/donors.yaml:485`,
  `docs/_registry/donors.yaml:487`,
  `docs/_registry/donors.yaml:489`,
  `docs/_registry/donors.yaml:495`).
- **Donor guide for eraser**: `docs/donors/02_geometry_hit_test_eraser.md`
  states geometry, hit-test, and eraser donors are ported as algorithms over new
  shape structs, not as legacy `SceneNode` or `NodeSnapshot` APIs
  (`docs/donors/02_geometry_hit_test_eraser.md:8`,
  `docs/donors/02_geometry_hit_test_eraser.md:10`,
  `docs/donors/02_geometry_hit_test_eraser.md:11`). Its eraser rows preserve
  segment batching, range bounds, rect-distance prefiltering, projected
  eraser-to-local algorithms, singular transform fallback, and batched exact
  line/stroke checks while marking legacy sampling, snapshots, delete
  eligibility, and debug counters as risks
  (`docs/donors/02_geometry_hit_test_eraser.md:18`,
  `docs/donors/02_geometry_hit_test_eraser.md:19`).
- **Interaction donors**: The donor-to-phase index maps
  `interaction_pointer_session`, `interaction_pointer_normalizer`,
  `interaction_event_dispatcher`, `interaction_double_tap_router`,
  `interaction_gesture_runtime`, `interaction_draw_coordinator`, and
  `interaction_mutation_boundary` to P12-relevant owners
  (`docs/indexes/donor_to_phase.md:312`,
  `docs/indexes/donor_to_phase.md:321`,
  `docs/indexes/donor_to_phase.md:327`,
  `docs/indexes/donor_to_phase.md:330`,
  `docs/indexes/donor_to_phase.md:333`,
  `docs/indexes/donor_to_phase.md:336`,
  `docs/indexes/donor_to_phase.md:339`,
  `docs/indexes/donor_to_phase.md:348`,
  `docs/indexes/donor_to_phase.md:351`,
  `docs/indexes/donor_to_phase.md:354`,
  `docs/indexes/donor_to_phase.md:357`,
  `docs/indexes/donor_to_phase.md:358`).
- **Double-tap and lifecycle donor entries**: The registry entry
  `interaction_double_tap_router` targets P12, owns context-action double-tap
  routing, and depends on the new context-action target hit policy
  (`docs/_registry/donors.yaml:1171`,
  `docs/_registry/donors.yaml:1176`,
  `docs/_registry/donors.yaml:1177`,
  `docs/_registry/donors.yaml:1179`,
  `docs/_registry/donors.yaml:1188`). `interaction_draw_coordinator` targets
  P11/P12, owns draw/line/eraser machines, preserves stroke, line, eraser
  lifecycle, pending line state, and exception-safe terminal cleanup, and keeps
  eraser internals blocked until the new geometry/spatial model exists
  (`docs/_registry/donors.yaml:1236`,
  `docs/_registry/donors.yaml:1244`,
  `docs/_registry/donors.yaml:1245`,
  `docs/_registry/donors.yaml:1246`,
  `docs/_registry/donors.yaml:1248`,
  `docs/_registry/donors.yaml:1250`). `interaction_mutation_boundary` targets
  P5/P10/P11/P12 and owns the interaction bridge into `EditKernel`
  (`docs/_registry/donors.yaml:1262`,
  `docs/_registry/donors.yaml:1267`,
  `docs/_registry/donors.yaml:1270`,
  `docs/_registry/donors.yaml:1271`,
  `docs/_registry/donors.yaml:1273`).
- **Interaction donor guide**:
  `docs/donors/06_interaction_edit_event_staged_load.md` identifies
  `interactive_double_tap_router.dart` as preserving context-action double-tap
  routing with dependency on the new context target hit policy and read model
  (`docs/donors/06_interaction_edit_event_staged_load.md:19`). The same guide
  identifies `interactive_draw_coordinator.dart`, draw engines, terminal router,
  and action emitter as preserving stroke/line/eraser lifecycle, pending line
  state, and exception-safe terminal cleanup, with eraser internals dependent on
  the new geometry/spatial model (`docs/donors/06_interaction_edit_event_staged_load.md:22`).

### 4. Cleanup And Terminal Safety

- **Location**: `lib/src/interaction/pointer_tool_cleanup_coordinator.dart:70`.
- **Description**: `PointerToolCleanupCoordinator.cleanup` accepts a
  `PointerCleanupRequest` and returns `PointerCleanupOutcome`, including preview
  cleanup, repaint target, active session/token disposition, pending line and
  pending context tap disposition, load/dispose flags, and
  `actionEmissionAllowed: false`
  (`lib/src/interaction/pointer_tool_cleanup_coordinator.dart:70`,
  `lib/src/interaction/pointer_tool_cleanup_coordinator.dart:93`,
  `lib/src/interaction/pointer_tool_cleanup_coordinator.dart:98`,
  `lib/src/interaction/pointer_tool_cleanup_coordinator.dart:117`).
- **Coordinator ownership**: The interaction contract states that cleanup-capable
  tool machines return typed cleanup requests to `InteractionEngine`, and
  `InteractionEngine` is the only caller of `PointerToolCleanupCoordinator`
  (`docs/contracts/interaction_engine.md:141`,
  `docs/contracts/interaction_engine.md:142`,
  `docs/contracts/interaction_engine.md:143`). Production `InteractionEngine`
  calls the coordinator in `cleanupPointerTool` and applies the outcome by
  clearing preview, pending line, and active session as instructed
  (`lib/src/interaction/interaction_engine.dart:136`,
  `lib/src/interaction/interaction_engine.dart:850`,
  `lib/src/interaction/interaction_engine.dart:854`,
  `lib/src/interaction/interaction_engine.dart:858`).
- **Pending context cleanup representation**: The cleanup coordinator has
  `PointerPendingContextTapDisposition`, and the request/outcome can carry
  pending context tap cleanup state
  (`lib/src/interaction/pointer_tool_cleanup_coordinator.dart:35`,
  `lib/src/interaction/pointer_tool_cleanup_coordinator.dart:78`,
  `lib/src/interaction/pointer_tool_cleanup_coordinator.dart:111`). No production
  pending context tap state machine was found in `lib/src/interaction` or
  `lib/src/runtime`; only these cleanup request/outcome flags were found.
- **Terminal cleanup routes**: Terminal pointer samples enter `_handleTerminal`;
  invalid terminal decisions are produced by
  `PointerSampleNormalizer.invalidTerminalCleanupDecision` before active terminal
  dispatch (`lib/src/interaction/interaction_engine.dart:525`,
  `lib/src/interaction/interaction_engine.dart:530`,
  `lib/src/interaction/interaction_engine.dart:531`).
- **Stale terminal rejection**: Stale controller epoch terminal samples cause a
  cleanup-only decision that clears the active session
  (`lib/src/interaction/pointer_sample_normalizer.dart:79`,
  `lib/src/interaction/pointer_sample_normalizer.dart:80`,
  `lib/src/interaction/pointer_sample_normalizer.dart:82`;
  `lib/src/interaction/interaction_engine.dart:691`,
  `lib/src/interaction/interaction_engine.dart:696`). Stale pointer terminal
  samples do not generally clean active sessions in the normalizer, but line
  sessions have a special stale-pointer cleanup path
  (`lib/src/interaction/pointer_sample_normalizer.dart:73`,
  `lib/src/interaction/pointer_sample_normalizer.dart:76`,
  `lib/src/interaction/interaction_engine.dart:708`,
  `lib/src/interaction/interaction_engine.dart:715`).
- **Cleanup/no-op separation**: The interaction contract states that no-op
  cleanup does not emit actions, publish context requests, mutate document or
  selection, update spatial/projection/resource state, or schedule repaint unless
  preview cleanup requires it (`docs/contracts/interaction_engine.md:156`,
  `docs/contracts/interaction_engine.md:227`,
  `docs/contracts/interaction_engine.md:232`). The P12 request applies the same
  no-effect rule to context tap cleanup
  (`docs/implementation/p12_eraser_and_text_request.md:33`,
  `docs/implementation/p12_eraser_and_text_request.md:35`).
- **Load cleanup**: Runtime load prepares interaction cleanup before load install
  (`lib/src/runtime/runtime_root.dart:1001`,
  `lib/src/runtime/runtime_root.dart:1016`). Operation matrix notes that a failed
  load preserves current gesture/preview/selection/spatial/projection/actions,
  while successful load consumes prepared cleanup without post-install
  interaction calls (`docs/contracts/operation_matrix.md:309`,
  `docs/contracts/operation_matrix.md:315`).
- **Guardrails**: Guardrails document and tooling register interaction cleanup
  coordinator dependency bans, stale terminal commit checks, and pointer cleanup
  coordinator ownership (`docs/verification/guardrails.md:214`,
  `docs/verification/guardrails.md:216`,
  `docs/verification/guardrails.md:217`;
  `tool/guardrails/src/core_boundary_checks.dart:56`,
  `tool/guardrails/src/core_boundary_checks.dart:96`).

### 5. Context-Action Request Routing

- **Location**: `docs/contracts/interaction_engine.md:264`.
- **Description**: The interaction contract documents P10 compatibility and P12
  double-tap behavior. Before P12, `handleDoubleTap` is unsupported and has no
  effects; P12 double-tap emits exactly one context-action request for an
  accepted target and has no document, selection, preview, repaint, spatial,
  projection, resource, or action effect
  (`docs/contracts/interaction_engine.md:264`,
  `docs/contracts/interaction_engine.md:273`,
  `docs/contracts/interaction_engine.md:274`,
  `docs/contracts/interaction_engine.md:275`,
  `docs/contracts/interaction_engine.md:276`,
  `docs/contracts/interaction_engine.md:277`).
- **Direct entry point**: Public `CanvasToolPort` declares
  `handleDoubleTap({required Offset position, int? timestampMs})`, and
  `_RuntimeToolPort` forwards it to `RuntimeRoot.handleDoubleTap`
  (`lib/src/contracts/public/canvas_tools.dart:110`,
  `lib/src/contracts/public/canvas_tools.dart:122`,
  `lib/src/runtime/runtime_root.dart:1695`,
  `lib/src/runtime/runtime_root.dart:1697`).
- **Current runtime behavior**: `RuntimeRoot.handleDoubleTap` is currently a
  `Never` method that throws `UnsupportedError('P12 context action double tap is not implemented.')`
  (`lib/src/runtime/runtime_root.dart:841`,
  `lib/src/runtime/runtime_root.dart:843`,
  `lib/src/runtime/runtime_root.dart:845`).
- **Pointer-sample recognition**: `InteractionEngine.handlePointerSample`
  currently routes by pointer lifecycle phases down/move/up/cancel and no
  implemented double-tap recognizer was found in that method
  (`lib/src/interaction/interaction_engine.dart:213`,
  `lib/src/interaction/interaction_engine.dart:223`,
  `lib/src/interaction/interaction_engine.dart:226`). Public pointer policy
  already exposes `doubleTapSlop` and `doubleTapMaxDelayMs`
  (`lib/src/contracts/public/canvas_pointer.dart:15`,
  `lib/src/contracts/public/canvas_pointer.dart:16`,
  `lib/src/contracts/public/canvas_pointer.dart:61`).
- **Direct double-tap flow**: The context-action sequence diagram defines direct
  `handleDoubleTap`, non-finite rejection before target resolution/request
  emission, timestamp resolution, pending tap cleanup, target resolution, request
  id issuance, and content/empty request emission
  (`docs/diagrams/seq_context_action_request.mmd:23`,
  `docs/diagrams/seq_context_action_request.mmd:25`,
  `docs/diagrams/seq_context_action_request.mmd:27`,
  `docs/diagrams/seq_context_action_request.mmd:28`,
  `docs/diagrams/seq_context_action_request.mmd:31`,
  `docs/diagrams/seq_context_action_request.mmd:32`,
  `docs/diagrams/seq_context_action_request.mmd:35`,
  `docs/diagrams/seq_context_action_request.mmd:44`,
  `docs/diagrams/seq_context_action_request.mmd:46`,
  `docs/diagrams/seq_context_action_request.mmd:51`,
  `docs/diagrams/seq_context_action_request.mmd:53`).
- **Pointer tap history and revalidation**: The pending context-action state
  diagram says direct double tap does not require pending first-tap history,
  clears stale pending history before target resolution, first-tap pending state
  is input history only, and second-tap recognition revalidates target class,
  current document, and current epoch
  (`docs/diagrams/state_pending_context_action_request.mmd:17`,
  `docs/diagrams/state_pending_context_action_request.mmd:19`,
  `docs/diagrams/state_pending_context_action_request.mmd:20`,
  `docs/diagrams/state_pending_context_action_request.mmd:21`,
  `docs/diagrams/state_pending_context_action_request.mmd:22`,
  `docs/diagrams/state_pending_context_action_request.mmd:38`,
  `docs/diagrams/state_pending_context_action_request.mmd:40`,
  `docs/diagrams/state_pending_context_action_request.mmd:88`,
  `docs/diagrams/state_pending_context_action_request.mmd:90`,
  `docs/diagrams/state_pending_context_action_request.mmd:91`,
  `docs/diagrams/state_pending_context_action_request.mmd:92`).
- **Target classes**: Geometry contract separates context-action target
  eligibility from selection hit eligibility; visible non-selectable content can
  produce context targets, and background-only coverage resolves to empty canvas
  (`docs/contracts/geometry.md:61`, `docs/contracts/geometry.md:64`,
  `docs/contracts/geometry.md:67`, `docs/contracts/geometry.md:74`,
  `docs/contracts/geometry.md:75`, `docs/contracts/geometry.md:76`,
  `docs/contracts/geometry.md:77`, `docs/contracts/geometry.md:78`).
- **Read models**: The interaction contract lists required context-action hit
  facts including bounds, generation, element revision, family, controller epoch,
  visibility, and top-hit facts, without exposing concrete store or selection
  mutation (`docs/contracts/interaction_engine.md:159`,
  `docs/contracts/interaction_engine.md:170`). Current `InteractionReadPort`
  defines selected move and marquee read models but no context-action read model
  methods were found (`lib/src/interaction/interaction_read_port.dart:7`,
  `lib/src/interaction/interaction_read_port.dart:21`,
  `lib/src/interaction/interaction_read_port.dart:46`,
  `lib/src/interaction/interaction_read_port.dart:59`,
  `lib/src/interaction/interaction_read_port.dart:106`).
- **Event dispatch**: Runtime pointer handling dispatches interaction commit
  intents for selected move, marquee, stroke, and line, then publishes state for
  non-ignored admissions (`lib/src/runtime/runtime_root.dart:796`,
  `lib/src/runtime/runtime_root.dart:806`,
  `lib/src/runtime/runtime_root.dart:815`,
  `lib/src/runtime/runtime_root.dart:821`,
  `lib/src/runtime/runtime_root.dart:830`,
  `lib/src/runtime/runtime_root.dart:836`). No production method was found that
  adds a `CanvasContextActionRequested` event to `_contextActionRequests`.
- **Application-owned UI**: Public API v1 describes context-action requests as
  application-facing requests; the engine generates ids and applications pass ids
  back to guarded command seams (`docs/contracts/public_api_v1.md:317`,
  `docs/contracts/public_api_v1.md:318`,
  `docs/contracts/public_api_v1.md:319`). The context-action state diagram marks
  issued requests as live for application-owned UI
  (`docs/diagrams/state_pending_context_action_request.mmd:143`,
  `docs/diagrams/state_pending_context_action_request.mmd:145`).

### 6. Request Ids And Guarded Text Edit Commits

- **Location**: `lib/src/contracts/public/canvas_ids.dart:107`.
- **Description**: `CanvasInteractionRequestId` is a public final class whose
  constructor validates through `validateCanvasIdValue` with path
  `interactionRequest.id` and max length `canvasMaxInteractionRequestIdLength`
  (`lib/src/contracts/public/canvas_ids.dart:107`,
  `lib/src/contracts/public/canvas_ids.dart:108`,
  `lib/src/contracts/public/canvas_ids.dart:111`,
  `lib/src/contracts/public/canvas_ids.dart:113`,
  `lib/src/contracts/public/canvas_ids.dart:114`). Equality compares the
  `value` field (`lib/src/contracts/public/canvas_ids.dart:119`,
  `lib/src/contracts/public/canvas_ids.dart:124`).
- **Registry contract**: Public API v1 states there is no public
  `CanvasRuntime.generateInteractionRequestId()`; the engine generates ids for
  emitted interaction requests and applications pass ids back to guarded command
  seams (`docs/contracts/public_api_v1.md:286`,
  `docs/contracts/public_api_v1.md:317`,
  `docs/contracts/public_api_v1.md:318`,
  `docs/contracts/public_api_v1.md:319`). Architecture documentation names an
  `InteractionRequestRegistry` as the interaction-owned registry for issued
  guard facts and describes stored request id, target kind, epoch, retired
  state, and content-target element facts (`docs/architecture/01_runtime_ownership.md:174`,
  `docs/architecture/01_runtime_ownership.md:203`).
- **Current registry absence**: A production `InteractionRequestRegistry`
  implementation was not found in inspected `lib`, `test`, `docs/architecture`,
  `docs/contracts`, `docs/diagrams`, and `tool` searches. Current runtime holds
  only the broadcast context-action stream controller
  (`lib/src/runtime/runtime_root.dart:152`,
  `lib/src/runtime/runtime_root.dart:208`,
  `lib/src/runtime/runtime_root.dart:215`).
- **Current text command**: `CanvasCommandPort` declares
  `commitTextEdit(CanvasInteractionRequestId requestId, String newText, {int? timestampMs})`
  (`lib/src/contracts/public/canvas_runtime.dart:183`,
  `lib/src/contracts/public/canvas_runtime.dart:186`,
  `lib/src/contracts/public/canvas_runtime.dart:187`,
  `lib/src/contracts/public/canvas_runtime.dart:188`). The runtime command port
  forwards to `RuntimeRoot.commitTextEdit`
  (`lib/src/runtime/runtime_root.dart:1701`,
  `lib/src/runtime/runtime_root.dart:1712`,
  `lib/src/runtime/runtime_root.dart:1717`).
- **Current implementation**: `RuntimeRoot.commitTextEdit` ensures mutations are
  allowed, validates command input, and currently returns `false`
  (`lib/src/runtime/runtime_root.dart:649`,
  `lib/src/runtime/runtime_root.dart:654`,
  `lib/src/runtime/runtime_root.dart:655`,
  `lib/src/runtime/runtime_root.dart:657`). Validation rejects negative
  timestamps, reconstructs the request id, and builds a
  `CanvasTextElementUpdate` probe for `newText`
  (`lib/src/runtime/runtime_root.dart:1380`,
  `lib/src/runtime/runtime_root.dart:1385`,
  `lib/src/runtime/runtime_root.dart:1388`,
  `lib/src/runtime/runtime_root.dart:1392`).
- **Contracted stale and wrong-target cases**: Public API v1 states P10 has no
  request registry, so all request ids are unknown and `commitTextEdit` returns
  false without side effects; P12 rejection cases include unknown, retired,
  empty-canvas, wrong family, missing target, generation mismatch, and element
  revision mismatch, with `documentRevision` not treated as a stale guard by
  itself (`docs/contracts/public_api_v1.md:2356`,
  `docs/contracts/public_api_v1.md:2357`,
  `docs/contracts/public_api_v1.md:1474`,
  `docs/contracts/public_api_v1.md:1522`).
- **No-op and changed text semantics**: Operation matrix defines
  `commitTextEdit` stale rejection, no-op accepted, and changed accepted rows:
  stale rejection touches only retired request state when the id is known and
  rejected; no-op accepted retires request state; changed accepted updates text
  through `EditKernel`, advances document revision, conditionally updates bounds
  and spatial state, evicts projection, repaints main, and emits `editText`
  (`docs/contracts/operation_matrix.md:93`,
  `docs/contracts/operation_matrix.md:94`,
  `docs/contracts/operation_matrix.md:95`).
- **Payload**: `CanvasTextEditActionPayload` carries the originating
  `requestId`, previous text length, and next text length
  (`lib/src/contracts/public/canvas_actions.dart:158`,
  `lib/src/contracts/public/canvas_actions.dart:161`,
  `lib/src/contracts/public/canvas_actions.dart:166`,
  `lib/src/contracts/public/canvas_actions.dart:167`,
  `lib/src/contracts/public/canvas_actions.dart:168`).
- **Existing stale edit handle guard**: `EditSession` closes edit handles and
  throws `StateError('CanvasEdit handle is stale.')` when a stale handle is used
  (`lib/src/edit/edit_session.dart:31`, `lib/src/edit/edit_session.dart:131`,
  `lib/src/edit/edit_session.dart:133`).

### 7. Public API And Event Surface

- **Location**: `lib/iwb_canvas_engine.dart:1`.
- **Description**: The public package barrel exports action, preview, runtime,
  tool, element, and id API files (`lib/iwb_canvas_engine.dart:1`,
  `lib/iwb_canvas_engine.dart:5`, `lib/iwb_canvas_engine.dart:10`,
  `lib/iwb_canvas_engine.dart:13`, `lib/iwb_canvas_engine.dart:15`,
  `lib/iwb_canvas_engine.dart:17`). These API files re-export the corresponding
  contract files (`lib/src/api/canvas_actions.dart:1`,
  `lib/src/api/canvas_preview.dart:1`,
  `lib/src/api/canvas_tools.dart:1`,
  `lib/src/api/canvas_runtime.dart:1`,
  `lib/src/api/canvas_ids.dart:1`).
- **Runtime public surface**: `CanvasRuntime` exposes `preview`, `actions`, and
  `contextActionRequests`, along with command and tool ports
  (`lib/src/api/canvas_runtime.dart:37`,
  `lib/src/api/canvas_runtime.dart:45`,
  `lib/src/api/canvas_runtime.dart:46`,
  `lib/src/api/canvas_runtime.dart:47`,
  `lib/src/api/canvas_runtime.dart:49`).
- **Machine-readable public registry**: The public API registry already lists
  `CanvasCommandPort`, `CanvasInteractionRequestId`, `CanvasEraserPreview`,
  `CanvasEraseActionPayload`, `CanvasTextEditActionPayload`,
  `CanvasContextActionRequested`, and context-action target types
  (`docs/_registry/public_api_v1.yaml:39`,
  `docs/_registry/public_api_v1.yaml:51`,
  `docs/_registry/public_api_v1.yaml:72`,
  `docs/_registry/public_api_v1.yaml:84`,
  `docs/_registry/public_api_v1.yaml:85`,
  `docs/_registry/public_api_v1.yaml:86`,
  `docs/_registry/public_api_v1.yaml:88`,
  `docs/_registry/public_api_v1.yaml:89`,
  `docs/_registry/public_api_v1.yaml:90`).
- **Context request event**: `CanvasContextActionRequested` carries request id,
  trigger, target, controller/document revisions, timestamp, and view/world
  positions (`lib/src/contracts/public/canvas_actions.dart:174`,
  `lib/src/contracts/public/canvas_actions.dart:177`,
  `lib/src/contracts/public/canvas_actions.dart:187`,
  `lib/src/contracts/public/canvas_actions.dart:188`,
  `lib/src/contracts/public/canvas_actions.dart:189`,
  `lib/src/contracts/public/canvas_actions.dart:190`,
  `lib/src/contracts/public/canvas_actions.dart:194`).
- **Context targets**: Public action types include content-element and
  empty-canvas context request targets
  (`lib/src/contracts/public/canvas_actions.dart:174`,
  `lib/src/contracts/public/canvas_actions.dart:218`).
- **Action payloads**: `CanvasActionType` already includes `erase` and
  `editText` (`lib/src/contracts/public/canvas_actions.dart:11`,
  `lib/src/contracts/public/canvas_actions.dart:21`,
  `lib/src/contracts/public/canvas_actions.dart:22`).
  `CanvasEraseActionPayload` carries eraser thickness, erased element ids, and
  corridor point count (`lib/src/contracts/public/canvas_actions.dart:144`,
  `lib/src/contracts/public/canvas_actions.dart:147`,
  `lib/src/contracts/public/canvas_actions.dart:150`,
  `lib/src/contracts/public/canvas_actions.dart:152`,
  `lib/src/contracts/public/canvas_actions.dart:155`).
- **Current action finalizer surface**: Internal `CommitActionIntentKind` does
  not include erase or editText; it ends at drawLine
  (`lib/src/contracts/internal/commit_action_intent.dart:9`,
  `lib/src/contracts/internal/commit_action_intent.dart:18`). Current
  `RuntimeActionFinalizer` maps existing intents to move, select, transform,
  delete, clear, pencil, marker, and line actions
  (`lib/src/runtime/runtime_action_finalizer.dart:44`,
  `lib/src/runtime/runtime_action_finalizer.dart:57`,
  `lib/src/runtime/runtime_action_finalizer.dart:113`,
  `lib/src/runtime/runtime_action_finalizer.dart:135`).
- **Smoke test contract**: The public incremental smoke test imports the package
  public barrel as an external consumer (`test/smoke/public_incremental_smoke_test.dart:18`,
  `test/smoke/public_incremental_smoke_test.dart:24`). It verifies that
  `contextActionRequests` is broadcast
  (`test/smoke/public_incremental_smoke_test.dart:553`,
  `test/smoke/public_incremental_smoke_test.dart:554`), direct double tap throws
  unsupported today (`test/smoke/public_incremental_smoke_test.dart:568`,
  `test/smoke/public_incremental_smoke_test.dart:571`), unknown
  `commitTextEdit` returns false
  (`test/smoke/public_incremental_smoke_test.dart:647`,
  `test/smoke/public_incremental_smoke_test.dart:652`,
  `test/smoke/public_incremental_smoke_test.dart:657`), and delete command action
  behavior still works after the failed text edit call
  (`test/smoke/public_incremental_smoke_test.dart:660`,
  `test/smoke/public_incremental_smoke_test.dart:663`).
- **Smoke expansion policy**: The tests contract defines the smoke test as a
  shared Flutter consumer harness and package-boundary proof that stays coarse
  while focused tests own detailed diagnostics
  (`docs/verification/tests.md:568`, `docs/verification/tests.md:589`,
  `docs/verification/tests.md:590`, `docs/verification/tests.md:591`). It must
  expand only by appending the next real public user step after the public API
  exposes one (`docs/verification/tests.md:592`,
  `docs/verification/tests.md:593`). The original smoke-step contract records
  the same append-only rule for future public steps
  (`plan/step_28_public_incremental_smoke_test.md:88`,
  `plan/step_28_public_incremental_smoke_test.md:92`). P11's completed step
  contract cites that smoke policy and uses it to require draw behavior to be
  appended through the root-barrel public consumer path
  (`plan/step_48_p11_draw_tools.md:110`,
  `plan/step_48_p11_draw_tools.md:111`,
  `plan/step_48_p11_draw_tools.md:112`).
- **Typed public compile tests**: Typed action payload tests construct erase,
  text edit, and context request payloads (`test/api/typed_action_payloads_test.dart:72`,
  `test/api/typed_action_payloads_test.dart:77`,
  `test/api/typed_action_payloads_test.dart:134`,
  `test/api/typed_action_payloads_test.dart:155`). Public API contract tests
  construct eraser preview and context request shapes
  (`test/api_contract/public_api_v1_compiles_as_written_test.dart:369`,
  `test/api_contract/public_api_v1_compiles_as_written_test.dart:440`,
  `test/api_contract/public_api_v1_compiles_as_written_test.dart:490`,
  `test/api_contract/public_api_v1_compiles_as_written_test.dart:535`).

### 8. Geometry, Spatial, And Preview Integration

- **Location**: `lib/src/geometry/geometry_policy.dart:17`.
- **Description**: Geometry policy defines eraser preview and terminal budget
  constants, including candidate and exact-check limits
  (`lib/src/geometry/geometry_policy.dart:17`,
  `lib/src/geometry/geometry_policy.dart:20`).
- **Corridor helper**: `GeometryPolicy.corridorEnvelope` filters finite corridor
  points, inflates the envelope by thickness/2 plus hit padding and hit slop,
  and exposes exact radius as thickness/2
  (`lib/src/geometry/geometry_policy.dart:75`,
  `lib/src/geometry/geometry_policy.dart:97`). Budget helpers produce preview
  budget inputs per sample and terminal fixed budget inputs
  (`lib/src/geometry/geometry_policy.dart:100`,
  `lib/src/geometry/geometry_policy.dart:112`).
- **Exact checks**: `HitTestPolicy.exactEraserHit` rejects ineligible facts and
  dispatches exact-hit testing by element family
  (`lib/src/geometry/hit_test_policy.dart:79`,
  `lib/src/geometry/hit_test_policy.dart:94`). Eraser eligibility requires
  non-empty corridor, non-zero envelope, visible/deletable non-background facts,
  finite and invertible transforms where required, and overlap with the corridor
  envelope (`lib/src/geometry/hit_test_policy.dart:125`,
  `lib/src/geometry/hit_test_policy.dart:144`).
- **Spatial queries**: `SpatialKernel.queryEraser` queries the paint index,
  whereas hit and marquee paths query hit indexes
  (`lib/src/geometry/spatial_kernel.dart:115`,
  `lib/src/geometry/spatial_kernel.dart:145`). `SpatialQueryResult` represents
  candidate results, budget exceeded, invalid index, and stale candidate
  outcomes (`lib/src/geometry/spatial_query_result.dart:1`,
  `lib/src/geometry/spatial_query_result.dart:46`).
- **Public preview state**: Public preview state includes
  `CanvasPreviewKind.eraser`, `CanvasPreviewState.eraser`, and
  `CanvasEraserPreview` with immutable corridor/thickness
  (`lib/src/contracts/public/canvas_preview.dart:4`,
  `lib/src/contracts/public/canvas_preview.dart:47`,
  `lib/src/contracts/public/canvas_preview.dart:50`,
  `lib/src/contracts/public/canvas_preview.dart:163`,
  `lib/src/contracts/public/canvas_preview.dart:174`).
- **Preview-to-frame boundary**: Captured frames carry preview state and preview
  revision (`lib/src/frame/captured_frame.dart:10`,
  `lib/src/frame/captured_frame.dart:64`). Overlay frame capture admits eraser
  previews (`lib/src/frame/frame_capture_service.dart:28`,
  `lib/src/frame/frame_capture_service.dart:49`), and overlay painting renders
  eraser corridors with round caps and thickness
  (`lib/src/frame/overlay_frame_painter.dart:31`,
  `lib/src/frame/overlay_frame_painter.dart:43`,
  `lib/src/frame/overlay_frame_painter.dart:92`,
  `lib/src/frame/overlay_frame_painter.dart:100`).
- **Preview-only vs committed state**: Interaction preview replacement updates
  preview state/revision only when preview changes
  (`lib/src/interaction/interaction_engine.dart:103`,
  `lib/src/interaction/interaction_engine.dart:110`). Edit commits install
  document changes through the edit kernel and commit applier, not through
  preview state (`lib/src/edit/edit_kernel.dart:82`,
  `lib/src/edit/edit_kernel.dart:123`,
  `lib/src/edit/commit_applier.dart:25`,
  `lib/src/edit/commit_applier.dart:55`).

### 9. Test Surface And Guardrails

- **Location**: `docs/implementation/p12_eraser_and_text_request.md:97`.
- **Description**: P12 names required tests and guardrails for geometry budget
  no-partial behavior, typed action payloads, public preview sealed union,
  commands emitting user actions, preview public state, interaction state
  machines, context-action requests, guarded text edits, cleanup coordinator,
  concrete store import bans, stale terminal commit bans, cleanup coordinator
  ownership, and load interruption behavior
  (`docs/implementation/p12_eraser_and_text_request.md:97`,
  `docs/implementation/p12_eraser_and_text_request.md:99`,
  `docs/implementation/p12_eraser_and_text_request.md:100`,
  `docs/implementation/p12_eraser_and_text_request.md:101`,
  `docs/implementation/p12_eraser_and_text_request.md:102`,
  `docs/implementation/p12_eraser_and_text_request.md:103`,
  `docs/implementation/p12_eraser_and_text_request.md:104`,
  `docs/implementation/p12_eraser_and_text_request.md:105`,
  `docs/implementation/p12_eraser_and_text_request.md:106`,
  `docs/implementation/p12_eraser_and_text_request.md:108`,
  `docs/implementation/p12_eraser_and_text_request.md:116`).
- **Existing P12-named or adjacent tests**: Present files include
  `test/api/typed_action_payloads_test.dart`,
  `test/api_contract/preview_state_sealed_union_test.dart`,
  `test/interaction/commands_emit_user_actions_test.dart`,
  `test/interaction/preview_public_state_test.dart`,
  `test/interaction/pointer_tool_cleanup_coordinator_test.dart`, and
  `test/smoke/public_incremental_smoke_test.dart`. Direct file checks found no
  `test/geometry/eraser_exact_budget_no_partial_commit_test.dart`,
  no `test/interaction/state_machines_test.dart`,
  no `test/interaction/context_action_request_test.dart`, and no
  `test/interaction/text_edit_stale_commit_guard_test.dart`.
- **Tests contract facts**: The tests contract includes
  `test.geometry.eraser_exact_budget_inputs`,
  `test.interaction.context_action_request`,
  `test.interaction.text_edit_stale_commit_guard`,
  `test.interaction.preview_public_state`, and
  `test.interaction.pointer_tool_cleanup_coordinator` in required-test lists
  (`docs/verification/tests.md:151`, `docs/verification/tests.md:179`,
  `docs/verification/tests.md:204`, `docs/verification/tests.md:209`,
  `docs/verification/tests.md:210`). It lists paths including
  `test/geometry/eraser_exact_budget_inputs_test.dart`,
  `test/interaction/preview_public_state_test.dart`,
  `test/interaction/pointer_tool_cleanup_coordinator_test.dart`,
  `test/interaction/text_edit_stale_commit_guard_test.dart`, and
  `test/guardrails/geometry_eraser_exact_budget_inputs_guardrail_test.dart`
  (`docs/verification/tests.md:332`, `docs/verification/tests.md:359`,
  `docs/verification/tests.md:364`, `docs/verification/tests.md:365`,
  `docs/verification/tests.md:372`).
- **Machine-readable test registry**: The section registry already names
  `test.api.typed_action_payloads`,
  `test.interaction.context_action_request`, and
  `test.interaction.text_edit_stale_commit_guard` under registered test lists
  (`docs/_registry/sections.yaml:157`,
  `docs/_registry/sections.yaml:159`,
  `docs/_registry/sections.yaml:160`,
  `docs/_registry/sections.yaml:589`,
  `docs/_registry/sections.yaml:590`,
  `docs/_registry/sections.yaml:591`).
- **Public incremental smoke responsibility**: The tests contract says
  `test/smoke/public_incremental_smoke_test.dart` proves an external Flutter
  consumer can import only the root public barrel, use the shared Flutter
  consumer harness, and exercise public decode/runtime/selection/resource/edit/
  load paths (`docs/verification/tests.md:568`,
  `docs/verification/tests.md:569`, `docs/verification/tests.md:572`,
  `docs/verification/tests.md:589`). The same entry records appended P8, P9,
  interaction, and P11 public compatibility coverage
  (`docs/verification/tests.md:573`, `docs/verification/tests.md:577`,
  `docs/verification/tests.md:581`, `docs/verification/tests.md:585`) and the
  append-only expansion rule for the next real public user step
  (`docs/verification/tests.md:592`, `docs/verification/tests.md:593`).
- **P8 budget coverage boundary**: The tests contract states that
  `test/geometry/eraser_exact_budget_inputs_test.dart` proves eraser corridor,
  exact-hit input limits, and preview/terminal candidate and exact-check budget
  input shapes, while leaving terminal cleanup/no-op commit behavior to P12
  (`docs/verification/tests.md:608`, `docs/verification/tests.md:609`,
  `docs/verification/tests.md:610`, `docs/verification/tests.md:611`).
- **Preview public state coverage**: Tests contract states that
  `test/interaction/preview_public_state_test.dart` proves preview-only pointer
  changes publish preview revision without changing document, selection,
  resourceVisual, interaction, or viewCamera revisions and without emitting
  action events (`docs/verification/tests.md:758`,
  `docs/verification/tests.md:759`,
  `docs/verification/tests.md:760`,
  `docs/verification/tests.md:761`).
- **Cleanup coverage**: Tests contract states that
  `test/interaction/pointer_tool_cleanup_coordinator_test.dart` proves pending
  context tap cleanup emits no context request, stale terminal cleanup creates no
  commit intent, and cleanup emits no user action
  (`docs/verification/tests.md:785`, `docs/verification/tests.md:786`,
  `docs/verification/tests.md:791`, `docs/verification/tests.md:792`,
  `docs/verification/tests.md:793`).
- **Guardrails**: Guardrails inventory defines
  `api.preview_state_sealed_union_publicly_readable`,
  `events.commands_emit_user_actions`, load interruption guardrails,
  `interaction.no_concrete_store_imports`,
  `interaction.no_stale_terminal_commit`,
  `interaction.pointer_cleanup_coordinator_only`,
  `interaction.text_edit_stale_commit_guard`, and
  `geometry.eraser_exact_budget_no_partial`
  (`docs/verification/guardrails.md:176`,
  `docs/verification/guardrails.md:202`,
  `docs/verification/guardrails.md:205`,
  `docs/verification/guardrails.md:206`,
  `docs/verification/guardrails.md:210`,
  `docs/verification/guardrails.md:216`,
  `docs/verification/guardrails.md:217`,
  `docs/verification/guardrails.md:218`,
  `docs/verification/guardrails.md:220`).
- **Guardrail tooling**: Core boundary checks restrict direct
  `PointerToolCleanupCoordinator` calls and imports to allowed owners
  (`tool/guardrails/src/core_boundary_checks.dart:56`,
  `tool/guardrails/src/core_boundary_checks.dart:96`,
  `tool/guardrails/src/core_boundary_checks.dart:894`,
  `tool/guardrails/src/core_boundary_checks.dart:897`). Interaction guardrail
  checks include import boundaries, concrete store import bans, selection/command
  fact restrictions, and cleanup dependency bans
  (`tool/guardrails/src/interaction_guardrail_checks.dart:11`,
  `tool/guardrails/src/interaction_guardrail_checks.dart:24`,
  `tool/guardrails/src/interaction_guardrail_checks.dart:26`,
  `tool/guardrails/src/interaction_guardrail_checks.dart:60`,
  `tool/guardrails/src/interaction_guardrail_checks.dart:63`,
  `tool/guardrails/src/interaction_guardrail_checks.dart:105`,
  `tool/guardrails/src/interaction_guardrail_checks.dart:107`,
  `tool/guardrails/src/interaction_guardrail_checks.dart:142`).

### 10. Integration Map For Future Design

- **Interaction owner**: `InteractionEngine` currently owns pointer sample
  routing, preview replacement, cleanup requests, stale terminal cleanup, and
  dispatch of interaction commit intents
  (`lib/src/interaction/interaction_engine.dart:213`,
  `lib/src/interaction/interaction_engine.dart:525`,
  `lib/src/interaction/interaction_engine.dart:850`,
  `lib/src/interaction/interaction_engine.dart:858`). The contract states it is
  the only caller of the cleanup coordinator and commits only through
  `EditKernel` (`docs/contracts/interaction_engine.md:143`,
  `docs/contracts/interaction_engine.md:151`).
- **Geometry owner**: Geometry policy and hit-test policy own eraser corridor
  envelopes, exact hit checks, eligibility, and exact budget input primitives
  (`lib/src/geometry/geometry_policy.dart:75`,
  `lib/src/geometry/geometry_policy.dart:112`,
  `lib/src/geometry/hit_test_policy.dart:79`,
  `lib/src/geometry/hit_test_policy.dart:144`).
- **Spatial owner**: `SpatialKernel.queryEraser` owns eraser candidate lookup
  through the paint index (`lib/src/geometry/spatial_kernel.dart:139`,
  `lib/src/geometry/spatial_kernel.dart:145`). Spatial query result types expose
  candidate, budget-exceeded, invalid-index, and stale-candidate outcomes
  (`lib/src/geometry/spatial_query_result.dart:1`,
  `lib/src/geometry/spatial_query_result.dart:46`).
- **Preview/frame owner**: Public preview state carries eraser preview data,
  interaction preview state owns preview revision changes, and frame overlay
  planning/paining renders eraser previews
  (`lib/src/contracts/public/canvas_preview.dart:163`,
  `lib/src/interaction/interaction_engine.dart:103`,
  `lib/src/frame/overlay_preview_planner.dart:78`,
  `lib/src/frame/overlay_frame_painter.dart:92`).
- **Edit owner**: `EditKernel.prepareInteractionCommit` and `CommitApplier` own
  atomic document install and rollback boundaries for interaction commits
  (`lib/src/edit/edit_kernel.dart:82`, `lib/src/edit/edit_kernel.dart:123`,
  `lib/src/edit/commit_applier.dart:25`,
  `lib/src/edit/commit_applier.dart:55`).
- **Runtime/event owner**: `RuntimeRoot` currently exposes context action streams,
  forwards public tool/command calls, dispatches pointer commit intents, publishes
  runtime state, and emits actions after state publication
  (`lib/src/runtime/runtime_root.dart:152`,
  `lib/src/runtime/runtime_root.dart:796`,
  `lib/src/runtime/runtime_root.dart:1042`,
  `lib/src/runtime/runtime_root.dart:1051`,
  `lib/src/runtime/runtime_root.dart:1695`,
  `lib/src/runtime/runtime_root.dart:1701`).
- **Public API owner**: Public contracts and API files define the stable external
  shapes for eraser preview, context requests, interaction request ids,
  `commitTextEdit`, erase actions, and editText actions
  (`docs/contracts/public_api_v1.md:381`,
  `docs/contracts/public_api_v1.md:1475`,
  `docs/contracts/public_api_v1.md:2066`,
  `docs/contracts/public_api_v1.md:2219`,
  `docs/contracts/public_api_v1.md:2252`;
  `lib/src/contracts/public/canvas_actions.dart:144`,
  `lib/src/contracts/public/canvas_actions.dart:158`,
  `lib/src/contracts/public/canvas_actions.dart:174`).
- **Host-owned UI boundary**: Context-action requests are emitted to the public
  `contextActionRequests` stream, and the request id returns through guarded
  command seams rather than through engine-owned menus/editors
  (`docs/contracts/public_api_v1.md:317`,
  `docs/contracts/public_api_v1.md:319`,
  `docs/contracts/public_api_v1.md:381`,
  `docs/diagrams/state_pending_context_action_request.mmd:143`,
  `docs/diagrams/state_pending_context_action_request.mmd:145`).
- **Current data flow near eraser commit**: Diagrammed P12 flow is pointer sample
  to interaction token/session gate, preview update and overlay repaint during
  preview, spatial candidate query and exact eraser checks, terminal budget gate,
  `EditKernel` deletion commit for non-empty exact ids, atomic install, spatial
  and projection effects, action after install, then cleanup
  (`docs/diagrams/dfd_pointer_preview_commit.mmd:24`,
  `docs/diagrams/dfd_pointer_preview_commit.mmd:28`,
  `docs/diagrams/dfd_pointer_preview_commit.mmd:40`,
  `docs/diagrams/dfd_pointer_preview_commit.mmd:112`,
  `docs/diagrams/dfd_pointer_preview_commit.mmd:114`,
  `docs/diagrams/seq_eraser_commit.mmd:132`,
  `docs/diagrams/seq_eraser_commit.mmd:168`,
  `docs/diagrams/seq_eraser_commit.mmd:179`,
  `docs/diagrams/seq_eraser_commit.mmd:180`).
- **Current data flow near context request emission**: Diagrammed P12 flow is
  direct or pointer-recognized double tap, finite input/timestamp validation,
  pending tap cleanup through the coordinator, target resolution against current
  facts, request id issuance, registry guard-fact storage, and
  `CanvasContextActionRequested` emission
  (`docs/diagrams/seq_context_action_request.mmd:23`,
  `docs/diagrams/seq_context_action_request.mmd:31`,
  `docs/diagrams/seq_context_action_request.mmd:44`,
  `docs/diagrams/seq_context_action_request.mmd:51`,
  `docs/diagrams/seq_context_action_request.mmd:53`,
  `docs/contracts/operation_matrix.md:123`,
  `docs/contracts/operation_matrix.md:132`).
- **Boundaries explicitly separated by current sources**: Geometry hit policy is
  separate from interaction routing (`docs/contracts/geometry.md:157`,
  `docs/contracts/interaction_engine.md:159`); cleanup/no-op is separate from
  document mutation and action/request emission
  (`docs/contracts/interaction_engine.md:156`,
  `docs/contracts/interaction_engine.md:232`); preview-only state is separate
  from committed document state (`docs/contracts/operation_matrix.md:90`,
  `docs/contracts/operation_matrix.md:91`); host UI is separate from emitted
  request and guarded command surfaces (`docs/contracts/public_api_v1.md:317`,
  `docs/contracts/public_api_v1.md:319`).

## Code References

- `docs/implementation/p12_eraser_and_text_request.md:5` - P12 purpose begins
  with eraser preview/commit and context-action request routing.
- `docs/implementation/p12_eraser_and_text_request.md:97` - P12 named tests and
  guardrails begin.
- `docs/contracts/public_api_v1.md:381` - public runtime context-action request
  stream.
- `docs/contracts/public_api_v1.md:1475` - public `commitTextEdit` command
  contract.
- `docs/contracts/public_api_v1.md:2066` - public eraser preview declaration.
- `docs/contracts/interaction_engine.md:141` - cleanup-capable machines return
  typed cleanup requests to `InteractionEngine`.
- `docs/contracts/interaction_engine.md:273` - P12 double-tap request delivery
  starts.
- `docs/contracts/geometry.md:157` - eraser corridor policy starts.
- `docs/contracts/geometry.md:167` - eraser exact-check budgets start.
- `docs/contracts/operation_matrix.md:90` - eraser preview matrix row.
- `docs/contracts/operation_matrix.md:91` - eraser commit matrix row.
- `docs/contracts/operation_matrix.md:92` - context-action double-tap request
  matrix row.
- `docs/contracts/operation_matrix.md:93` - stale `commitTextEdit` matrix row.
- `docs/contracts/operation_matrix.md:94` - no-op `commitTextEdit` matrix row.
- `docs/contracts/operation_matrix.md:95` - changed `commitTextEdit` matrix row.
- `docs/donors/00_reuse_rules.md:13` - donor inventory reuse boundary.
- `docs/_registry/donors.yaml:477` - eraser exact-hit donor registry entry.
- `docs/_registry/donors.yaml:1171` - context-action double-tap router donor
  registry entry.
- `docs/indexes/donor_to_phase.md:132` - P12 eraser exact-hit donor phase map.
- `docs/indexes/donor_to_phase.md:330` - P12 double-tap router donor phase map.
- `docs/verification/tests.md:568` - public incremental smoke responsibility
  entry.
- `docs/verification/tests.md:592` - append-only public user-step expansion
  rule for the smoke test.
- `lib/src/geometry/geometry_policy.dart:75` - eraser corridor envelope helper.
- `lib/src/geometry/hit_test_policy.dart:79` - exact eraser hit entry point.
- `lib/src/geometry/spatial_kernel.dart:139` - eraser spatial query entry point.
- `lib/src/interaction/pointer_tool_cleanup_coordinator.dart:70` - cleanup
  request object.
- `lib/src/interaction/interaction_engine.dart:525` - terminal pointer routing.
- `lib/src/runtime/runtime_root.dart:841` - current direct double-tap placeholder.
- `lib/src/runtime/runtime_root.dart:649` - current `commitTextEdit`
  implementation.
- `lib/src/contracts/public/canvas_actions.dart:144` - erase action payload.
- `lib/src/contracts/public/canvas_actions.dart:158` - text edit action payload.
- `lib/src/contracts/public/canvas_actions.dart:174` - context-action request
  event.
- `test/smoke/public_incremental_smoke_test.dart:553` - public smoke broadcast
  stream check.
- `test/smoke/public_incremental_smoke_test.dart:647` - public smoke unknown
  `commitTextEdit` check.

## Search Coverage

- **Inspected directly**: `docs/implementation/p12_eraser_and_text_request.md`,
  `PLAN.md`, `docs/README.md`, `docs/contracts/public_api_v1.md`,
  `docs/contracts/interaction_engine.md`, `docs/contracts/geometry.md`,
  `docs/contracts/operation_matrix.md`, `docs/verification/tests.md`,
  `docs/verification/guardrails.md`, `docs/indexes/by_phase.md`,
  `docs/indexes/by_guardrail.md`, `docs/indexes/donor_to_phase.md`,
  `docs/diagrams/catalog.md`, `docs/_registry/public_api_v1.yaml`,
  `docs/_registry/sections.yaml`, `docs/_registry/donors.yaml`,
  `docs/donors/00_reuse_rules.md`,
  `docs/donors/02_geometry_hit_test_eraser.md`,
  `docs/donors/06_interaction_edit_event_staged_load.md`,
  `docs/diagrams/dfd_pointer_preview_commit.mmd`,
  `docs/diagrams/dfd_public_edit.mmd`,
  `docs/diagrams/seq_eraser_commit.mmd`,
  `docs/diagrams/seq_eraser_exact_budget.mmd`,
  `docs/diagrams/seq_context_action_request.mmd`,
  `docs/diagrams/state_eraser.mmd`,
  `docs/diagrams/state_pending_context_action_request.mmd`,
  `docs/diagrams/state_pointer_session.mmd`,
  `plan/step_28_public_incremental_smoke_test.md`,
  `plan/step_48_p11_draw_tools.md`,
  `test/smoke/public_incremental_smoke_test.dart`.
- **Inspected production code**: `lib/iwb_canvas_engine.dart`,
  `lib/src/api/canvas_runtime.dart`, `lib/src/api/canvas_actions.dart`,
  `lib/src/api/canvas_preview.dart`, `lib/src/api/canvas_tools.dart`,
  `lib/src/api/canvas_ids.dart`, `lib/src/contracts/public/canvas_actions.dart`,
  `lib/src/contracts/public/canvas_preview.dart`,
  `lib/src/contracts/public/canvas_runtime.dart`,
  `lib/src/contracts/public/canvas_tools.dart`,
  `lib/src/contracts/public/canvas_ids.dart`,
  `lib/src/contracts/internal/commit_action_intent.dart`,
  `lib/src/geometry/geometry_policy.dart`,
  `lib/src/geometry/hit_test_policy.dart`,
  `lib/src/geometry/spatial_kernel.dart`,
  `lib/src/geometry/spatial_query_result.dart`,
  `lib/src/edit/edit_kernel.dart`, `lib/src/edit/draft_document.dart`,
  `lib/src/edit/commit_applier.dart`, `lib/src/edit/edit_session.dart`,
  `lib/src/frame/captured_frame.dart`,
  `lib/src/frame/frame_capture_service.dart`,
  `lib/src/frame/overlay_preview_planner.dart`,
  `lib/src/frame/overlay_frame_painter.dart`,
  `lib/src/interaction/interaction_engine.dart`,
  `lib/src/interaction/pointer_tool_cleanup_coordinator.dart`,
  `lib/src/interaction/pointer_sample_normalizer.dart`,
  `lib/src/interaction/pointer_session.dart`,
  `lib/src/interaction/interaction_read_port.dart`,
  `lib/src/interaction/draw_stroke_machine.dart`,
  `lib/src/runtime/runtime_root.dart`,
  `lib/src/runtime/runtime_action_finalizer.dart`,
  `lib/src/runtime/runtime_interaction_read_adapter.dart`,
  `lib/src/runtime/runtime_interaction_move_read_models.dart`.
- **Inspected tests and guardrails**:
  `test/api/typed_action_payloads_test.dart`,
  `test/api/fixtures/tool_port_settings_fixture.dart`,
  `test/api/fixtures/command_port_actions_fixture.dart`,
  `test/api_contract/preview_state_sealed_union_test.dart`,
  `test/api_contract/public_api_v1_compiles_as_written_test.dart`,
  `test/api_contract/public_exports_complete_test.dart`,
  `test/api_contract/id_validation_no_extension_type_escape_test.dart`,
  `test/geometry/eraser_exact_budget_inputs_test.dart`,
  `test/geometry/fixtures/eraser_exact_budget_inputs_fixture.dart`,
  `test/frame/fixtures/main_overlay_capture_fixture.dart`,
  `test/frame/fixtures/overlay_preview_admission_fixture.dart`,
  `test/frame/fixtures/frame_drawable_overlay_policy_fixture.dart`,
  `test/interaction/pointer_tool_cleanup_coordinator_test.dart`,
  `test/interaction/pointer_session_test.dart`,
  `test/interaction/pointer_sample_normalizer_test.dart`,
  `test/interaction/preview_public_state_test.dart`,
  `test/interaction/commands_emit_user_actions_test.dart`,
  `tool/guardrails/src/guardrail_registry.dart`,
  `tool/guardrails/src/guardrail_executor.dart`,
  `tool/guardrails/src/core_boundary_checks.dart`,
  `tool/guardrails/src/interaction_guardrail_checks.dart`,
  `tool/guardrails/src/public_api_checks.dart`,
  `tool/guardrails/src/public_api_registry.dart`,
  `test/guardrails/interaction_guardrail_enforcement_test.dart`,
  `test/guardrails/blocking_suite_test.dart`.
- **Searched symbols and patterns**: `P12`, `eraser`, `erase`, `exact`,
  `budget`, `queryEraser`, `exactEraserHit`, `CanvasEraserPreview`,
  `CanvasEraseActionPayload`, `handleDoubleTap`, `doubleTap`,
  `contextActionRequests`, `CanvasContextActionRequested`,
  `CanvasInteractionRequestId`, `InteractionRequestRegistry`,
  `commitTextEdit`, `CanvasTextEditActionPayload`, `text_edit_stale_commit_guard`,
  `pendingContextTap`, `PendingContextTap`, `PointerToolCleanupCoordinator`,
  `no_stale_terminal_commit`, `no_concrete_store_imports`, `donor`,
  `geometry_eraser_exact_hit`, `interaction_double_tap_router`,
  `interaction_draw_coordinator`.
- **Not found**: no production `InteractionRequestRegistry`; no production
  context-action request emission path; no production pending context tap state
  machine/history beyond cleanup request/outcome flags; no eraser-specific
  interaction machine class; no eraser pointer session kind; no context-action
  read-port methods; no `erase` or `editText` internal commit action intent;
  no physical `test/geometry/eraser_exact_budget_no_partial_commit_test.dart`;
  no physical `test/interaction/state_machines_test.dart`; no physical
  `test/interaction/context_action_request_test.dart`; no physical
  `test/interaction/text_edit_stale_commit_guard_test.dart`.
- **Not inspected**: No dependency package internals were inspected because the
  research question concerns repository-local P12 contracts, production owners,
  tests, diagrams, and guardrails.

## Observed Architecture Facts

- **Normative docs route**: `docs/README.md` identifies contracts,
  verification, diagrams, implementation notes, and generated indexes as the
  documentation navigation surface (`docs/README.md:21`,
  `docs/README.md:24`, `docs/README.md:25`,
  `docs/README.md:27`, `docs/README.md:28`).
- **Interaction boundary**: InteractionEngine owns pointer cleanup application
  and terminal routing while committed facts are read through read ports and
  document commits go through `EditKernel` (`docs/contracts/interaction_engine.md:144`,
  `docs/contracts/interaction_engine.md:151`,
  `lib/src/interaction/interaction_engine.dart:525`,
  `lib/src/interaction/interaction_engine.dart:850`).
- **Cleanup boundary**: The cleanup coordinator is a policy component that
  returns cleanup outcomes; it does not own edit, action, request, document, or
  public state emission (`lib/src/interaction/pointer_tool_cleanup_coordinator.dart:70`,
  `lib/src/interaction/pointer_tool_cleanup_coordinator.dart:117`,
  `docs/contracts/interaction_engine.md:227`,
  `docs/contracts/interaction_engine.md:232`).
- **Geometry/spatial boundary**: Geometry owns eraser corridor/exact-hit/budget
  facts; spatial owns candidate lookup and budget-exceeded results
  (`docs/contracts/geometry.md:157`,
  `docs/contracts/geometry.md:175`,
  `lib/src/geometry/spatial_kernel.dart:139`,
  `lib/src/geometry/spatial_query_result.dart:1`).
- **Preview boundary**: Eraser preview is public sealed preview state and overlay
  frame state, separate from committed document mutations
  (`docs/contracts/interaction_engine.md:244`,
  `docs/contracts/interaction_engine.md:257`,
  `lib/src/frame/frame_capture_service.dart:28`,
  `lib/src/frame/overlay_preview_planner.dart:78`).
- **Public request boundary**: Context-action requests are public events with
  engine-generated request ids, and text changes from those requests return
  through `commitTextEdit` (`docs/contracts/public_api_v1.md:317`,
  `docs/contracts/public_api_v1.md:319`,
  `docs/contracts/public_api_v1.md:381`,
  `docs/contracts/public_api_v1.md:1475`).
- **Current compatibility state**: Current public behavior preserves placeholder
  P10 semantics for direct double tap and text edit command: unsupported direct
  double tap and unknown request ids returning false without downstream delete
  action regression (`lib/src/runtime/runtime_root.dart:841`,
  `lib/src/runtime/runtime_root.dart:845`,
  `lib/src/runtime/runtime_root.dart:649`,
  `lib/src/runtime/runtime_root.dart:657`,
  `test/smoke/public_incremental_smoke_test.dart:568`,
  `test/smoke/public_incremental_smoke_test.dart:657`,
  `test/smoke/public_incremental_smoke_test.dart:660`).

## Open Questions

- No production `InteractionRequestRegistry` implementation was found, while
  public API and architecture documents describe request id generation and guard
  fact storage (`docs/contracts/public_api_v1.md:317`,
  `docs/contracts/public_api_v1.md:319`,
  `docs/architecture/01_runtime_ownership.md:174`,
  `docs/architecture/01_runtime_ownership.md:203`).
- No production context-action target read model methods were found in
  `InteractionReadPort`, while the interaction contract lists required target
  facts for context-action routing (`docs/contracts/interaction_engine.md:159`,
  `docs/contracts/interaction_engine.md:170`,
  `lib/src/interaction/interaction_read_port.dart:7`,
  `lib/src/interaction/interaction_read_port.dart:106`).
- No eraser-specific interaction machine or eraser pointer session kind was
  found, while P12 and the eraser state diagram define eraser admission,
  preview, terminal budget, commit, and cleanup states
  (`docs/implementation/p12_eraser_and_text_request.md:11`,
  `docs/diagrams/state_eraser.mmd:16`,
  `lib/src/interaction/pointer_session.dart:8`,
  `lib/src/interaction/pointer_session.dart:14`).
- No production context-action request emission path was found, while public API
  and operation matrix define `contextActionRequests` delivery
  (`docs/contracts/public_api_v1.md:381`,
  `docs/contracts/operation_matrix.md:92`,
  `lib/src/runtime/runtime_root.dart:152`,
  `lib/src/runtime/runtime_root.dart:215`).
- No internal `erase` or `editText` commit action intent was found, while public
  action types and payloads define both public events
  (`lib/src/contracts/public/canvas_actions.dart:21`,
  `lib/src/contracts/public/canvas_actions.dart:22`,
  `lib/src/contracts/internal/commit_action_intent.dart:9`,
  `lib/src/contracts/internal/commit_action_intent.dart:18`).
- The P12-named no-partial eraser commit test, context-action request test,
  state-machine test, and text-edit stale-commit guard test were not present as
  physical test files, while P12 and the tests contract name them
  (`docs/implementation/p12_eraser_and_text_request.md:99`,
  `docs/implementation/p12_eraser_and_text_request.md:104`,
  `docs/implementation/p12_eraser_and_text_request.md:105`,
  `docs/implementation/p12_eraser_and_text_request.md:106`,
  `docs/verification/tests.md:365`).
