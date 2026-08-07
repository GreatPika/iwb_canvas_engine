---
date: 2026-05-28
researcher: Codex
commit: b1a3a369
branch: new-architecture
research_question: "Check whether the architecture review concerns about the editor/canvas graph are supported by the current repository facts, especially around geometry/spatial, interaction preview, runtime/frame flow, and public/internal contract boundaries."
---

# Research: Architecture Review Graph Concerns

## Summary

The reviewed graph concerns about `geometry_spatial_index`, `frame_renderer`,
`interaction_engine`, `draw_tools`, and `eraser_context_request` describe
future architecture graph nodes or edges rather than current selected-phase
graph facts. The generated graph views are selected for P7
(`docs/diagrams/generated/current_phase.mmd:4`), while the graph source marks
P8 through P13 as `status: future` (`docs/architecture/architecture_graph.yaml:48`,
`docs/architecture/architecture_graph.yaml:54`,
`docs/architecture/architecture_graph.yaml:61`,
`docs/architecture/architecture_graph.yaml:67`,
`docs/architecture/architecture_graph.yaml:73`,
`docs/architecture/architecture_graph.yaml:79`).

The current implementation has a public `CanvasRuntime` facade that delegates
implemented behavior to `RuntimeRoot` (`lib/src/api/canvas_runtime.dart:20`,
`lib/src/api/canvas_runtime.dart:26`, `lib/src/api/canvas_runtime.dart:31`).
`RuntimeRoot` currently owns/composes document store, load pipeline, selection,
edit, resources, runtime state publication, and internal frame facts
(`lib/src/runtime/runtime_root.dart:43`, `lib/src/runtime/runtime_root.dart:54`,
`lib/src/runtime/runtime_root.dart:87`, `lib/src/runtime/runtime_root.dart:92`,
`lib/src/runtime/runtime_root.dart:117`, `lib/src/runtime/runtime_root.dart:131`).
The current frame-related production artifact described here is the internal
`FrameFactsPort` contract (`lib/src/contracts/internal/frame_facts_port.dart:144`)
and the runtime implementation of that port
(`lib/src/runtime/runtime_root.dart:151`). The owner DAG reserves future owner
prefixes for frame, interaction, spatial, and tools code
(`tool/guardrails/src/owner_dag_import_checks.dart:299`,
`tool/guardrails/src/owner_dag_import_checks.dart:300`,
`tool/guardrails/src/owner_dag_import_checks.dart:304`,
`tool/guardrails/src/owner_dag_import_checks.dart:305`), matching the graph's
future nodes for those owners (`docs/architecture/architecture_graph.yaml:380`,
`docs/architecture/architecture_graph.yaml:396`,
`docs/architecture/architecture_graph.yaml:412`,
`docs/architecture/architecture_graph.yaml:428`).

The current boundary enforcement allows internal contracts to depend on public
contracts and rejects the reverse direction through the owner DAG. The owner DAG
explicitly allows `contracts/internal -> contracts/public`
(`tool/guardrails/src/owner_dag_import_checks.dart:326`), rejects non-allowed
owner references after target resolution
(`tool/guardrails/src/owner_dag_import_checks.dart:91`,
`tool/guardrails/src/owner_dag_import_checks.dart:118`,
`tool/guardrails/src/owner_dag_import_checks.dart:122`), and lists public and
internal contract owners separately (`tool/guardrails/src/owner_dag_import_checks.dart:275`,
`tool/guardrails/src/owner_dag_import_checks.dart:279`). Public API facades may
export only public contract declarations (`tool/guardrails/src/core_boundary_checks.dart:336`,
`tool/guardrails/src/core_boundary_checks.dart:338`).

Follow-up graph clarification in this changeset renamed the future interaction
owner from `interaction.selection_move` to `interaction.engine`, reversed the
spatial query edge so interaction consumes spatial results, clarified
runtime/frame flow as `FrameFactsPort` provision, and labeled tool preview
flows as preview intents. Those changes align generated graph wording with the
research conclusion below: the concern was a future-graph readability issue, not
a confirmed current P7 implementation problem.

## Detailed Findings

### 1. Graph Phase Status and Reviewed Edges

- **Location**: primary `docs/architecture/architecture_graph.yaml:42`; generated views at `docs/diagrams/generated/current_phase.mmd:4`.
- **Description**: P0-P6 are closed in the graph source
  (`docs/architecture/architecture_graph.yaml:3`,
  `docs/architecture/architecture_graph.yaml:8`,
  `docs/architecture/architecture_graph.yaml:13`,
  `docs/architecture/architecture_graph.yaml:18`,
  `docs/architecture/architecture_graph.yaml:24`,
  `docs/architecture/architecture_graph.yaml:30`,
  `docs/architecture/architecture_graph.yaml:36`). P7 is selected in generated
  views (`docs/diagrams/generated/full_architecture.mmd:4`,
  `docs/diagrams/generated/current_phase.mmd:4`,
  `docs/diagrams/generated/future_target.mmd:4`). P8-P13 are future
  (`docs/architecture/architecture_graph.yaml:48`,
  `docs/architecture/architecture_graph.yaml:54`,
  `docs/architecture/architecture_graph.yaml:61`,
  `docs/architecture/architecture_graph.yaml:67`,
  `docs/architecture/architecture_graph.yaml:73`,
  `docs/architecture/architecture_graph.yaml:79`).
- **Dependencies**: The graph view renderer places nodes and edges into the
  current selected phase when their required phase is before or at the selected
  phase (`tool/architecture_graph/src/graph_views.dart:137`,
  `tool/architecture_graph/src/graph_views.dart:149`,
  `tool/architecture_graph/src/graph_views.dart:150`). Future edges are selected
  separately (`tool/architecture_graph/src/graph_views.dart:157`,
  `tool/architecture_graph/src/graph_views.dart:162`,
  `tool/architecture_graph/src/graph_views.dart:173`).
- **Data flow**: graph source -> graph view renderer -> generated current/future
  Mermaid views (`tool/architecture_graph/generate_views.dart:74`,
  `tool/architecture_graph/generate_views.dart:78`,
  `tool/architecture_graph/generate_views.dart:81`).

The current selected graph includes P7 resource edges such as
`runtime_root --> resource_surface_session`
(`docs/diagrams/generated/current_phase.mmd:31`) and
`runtime_root --> resource_kernel`
(`docs/diagrams/generated/current_phase.mmd:32`). It does not include the P8-P12
reviewed future interaction/frame/tool edges in the current phase view; those
future edges are shown in `future_target.mmd` (`docs/diagrams/generated/future_target.mmd:17`,
`docs/diagrams/generated/future_target.mmd:28`).

The graph source declares `geometry.spatial_index`, `frame.renderer`, and
`interaction.engine` as future nodes
(`docs/architecture/architecture_graph.yaml:380`,
`docs/architecture/architecture_graph.yaml:396`,
`docs/architecture/architecture_graph.yaml:412`). The reviewed
spatial/interaction edge is now a future `interaction.engine ->
geometry.spatial_index` hit-test boundary with evidence text "Interaction hit
testing will consume spatial query results through the spatial query boundary"
(`docs/architecture/architecture_graph.yaml:769`,
`docs/architecture/architecture_graph.yaml:772`,
`docs/architecture/architecture_graph.yaml:773`,
`docs/architecture/architecture_graph.yaml:774`,
`docs/architecture/architecture_graph.yaml:779`). The generated future view
renders that same future edge as "planned queries hits through by P10"
(`docs/diagrams/generated/future_target.mmd:27`).

### 2. Current Public Runtime and Runtime Root

- **Location**: primary `lib/src/api/canvas_runtime.dart:20`; runtime root at
  `lib/src/runtime/runtime_root.dart:43`.
- **Description**: `CanvasRuntime` is the public facade class
  (`lib/src/api/canvas_runtime.dart:20`). Its constructor creates a private
  `RuntimeRoot` (`lib/src/api/canvas_runtime.dart:21`,
  `lib/src/api/canvas_runtime.dart:26`, `lib/src/api/canvas_runtime.dart:29`).
  Implemented public runtime members forward to `_root`, including document
  reads, state, edits, selection, camera, resources, actions, id generation, and
  disposal (`lib/src/api/canvas_runtime.dart:31`,
  `lib/src/api/canvas_runtime.dart:32`, `lib/src/api/canvas_runtime.dart:33`,
  `lib/src/api/canvas_runtime.dart:34`, `lib/src/api/canvas_runtime.dart:37`,
  `lib/src/api/canvas_runtime.dart:38`, `lib/src/api/canvas_runtime.dart:40`,
  `lib/src/api/canvas_runtime.dart:43`, `lib/src/api/canvas_runtime.dart:46`).
- **Dependencies**: The facade imports public contracts and the runtime root
  (`lib/src/api/canvas_runtime.dart:5`,
  `lib/src/api/canvas_runtime.dart:10`,
  `lib/src/api/canvas_runtime.dart:12`). `RuntimeRoot` imports internal
  contracts, public contracts, edit, resources, selection, store, and runtime
  support files (`lib/src/runtime/runtime_root.dart:13`,
  `lib/src/runtime/runtime_root.dart:24`,
  `lib/src/runtime/runtime_root.dart:30`,
  `lib/src/runtime/runtime_root.dart:34`,
  `lib/src/runtime/runtime_root.dart:35`,
  `lib/src/runtime/runtime_root.dart:36`,
  `lib/src/runtime/runtime_root.dart:37`).
- **Data flow**: `CanvasRuntime.readDocument()` -> `_root.readDocument()` ->
  `_store.readDocument()` -> `DocumentStoreKernel.readDocument()` returns the
  projection cache result (`lib/src/api/canvas_runtime.dart:31`,
  `lib/src/runtime/runtime_root.dart:197`,
  `lib/src/store/document_store_kernel.dart:47`).

`RuntimeRoot` implements `DocumentFactsPort`, `FrameFactsPort`,
`ResolverMutationGuard`, and `ResourceDirtyOutcomeSink`
(`lib/src/runtime/runtime_root.dart:43`, `lib/src/runtime/runtime_root.dart:45`,
`lib/src/runtime/runtime_root.dart:46`, `lib/src/runtime/runtime_root.dart:47`,
`lib/src/runtime/runtime_root.dart:48`). It composes `DocumentStoreKernel`,
`LoadDocumentPipeline`, `SelectionKernel`, `ValueNotifier<CanvasRuntimeState>`,
`EditKernel`, public runtime port adapters, `_StoreResourceCatalog`, and
`ResourceKernel` (`lib/src/runtime/runtime_root.dart:54`,
`lib/src/runtime/runtime_root.dart:87`, `lib/src/runtime/runtime_root.dart:92`,
`lib/src/runtime/runtime_root.dart:95`, `lib/src/runtime/runtime_root.dart:117`,
`lib/src/runtime/runtime_root.dart:125`, `lib/src/runtime/runtime_root.dart:128`,
`lib/src/runtime/runtime_root.dart:131`).

The current `RuntimeRoot.frameFactsPort` returns `this`
(`lib/src/runtime/runtime_root.dart:151`). Frame revision facts are copied from
store revisions into `FrameRevisionFacts` (`lib/src/runtime/runtime_root.dart:184`,
`lib/src/runtime/runtime_root.dart:186`, `lib/src/runtime/runtime_root.dart:193`,
`lib/src/contracts/internal/frame_facts_port.dart:8`). Element handles are copied
from store handles into `FrameElementHandle` values
(`lib/src/runtime/runtime_root.dart:216`,
`lib/src/runtime/runtime_root.dart:219`,
`lib/src/runtime/runtime_root.dart:220`,
`lib/src/store/document_store_kernel.dart:83`). Element resolution converts a
`FrameElementHandle` to `StoreElementHandle`, resolves through the store, and
copies every returned field into `FrameElementFacts`
(`lib/src/runtime/runtime_root.dart:233`,
`lib/src/runtime/runtime_root.dart:234`,
`lib/src/runtime/runtime_root.dart:246`,
`lib/src/runtime/runtime_root.dart:285`).

The graph source describes the future runtime/frame edge as a
`frame_facts_provider` from
`runtime.root` to `frame.renderer` (`docs/architecture/architecture_graph.yaml:583`,
`docs/architecture/architecture_graph.yaml:586`,
`docs/architecture/architecture_graph.yaml:587`,
`docs/architecture/architecture_graph.yaml:588`). Its source evidence says
"Frame rendering will consume runtime frame facts in P9"
(`docs/architecture/architecture_graph.yaml:592`,
`docs/architecture/architecture_graph.yaml:593`), and its actual expectation is
that the runtime implements `FrameFactsPort`
(`docs/architecture/architecture_graph.yaml:594`,
`docs/architecture/architecture_graph.yaml:596`).

### 3. Interaction, Preview, Geometry, and Tools Status

- **Location**: primary `lib/src/contracts/public/canvas_preview.dart:16`;
  future graph nodes at `docs/architecture/architecture_graph.yaml:380`.
- **Description**: Public preview shape exists as a sealed union with variants
  for none, marquee, selected move, pencil stroke, marker stroke, pending line
  start, line preview, and eraser (`lib/src/contracts/public/canvas_preview.dart:16`,
  `lib/src/contracts/public/canvas_preview.dart:18`,
  `lib/src/contracts/public/canvas_preview.dart:21`,
  `lib/src/contracts/public/canvas_preview.dart:23`,
  `lib/src/contracts/public/canvas_preview.dart:29`,
  `lib/src/contracts/public/canvas_preview.dart:35`,
  `lib/src/contracts/public/canvas_preview.dart:41`,
  `lib/src/contracts/public/canvas_preview.dart:47`). The current
  `CanvasRuntime.preview` getter is a throwing placeholder
  (`lib/src/api/canvas_runtime.dart:39`).
- **Dependencies**: `CanvasRuntimeState` contains `revisions` and `summary`
  (`lib/src/contracts/public/canvas_runtime.dart:42`,
  `lib/src/contracts/public/canvas_runtime.dart:43`,
  `lib/src/contracts/public/canvas_runtime.dart:44`,
  `lib/src/contracts/public/canvas_runtime.dart:45`). The public runtime revision
  object contains a `preview` revision field
  (`lib/src/contracts/public/canvas_runtime.dart:60`,
  `lib/src/contracts/public/canvas_runtime.dart:64`,
  `lib/src/contracts/public/canvas_runtime.dart:73`).
- **Data flow**: runtime preview revision counter -> `_runtimeState` ->
  `CanvasRuntimeRevisions.preview` (`lib/src/runtime/runtime_root.dart:111`,
  `lib/src/runtime/runtime_root.dart:444`,
  `lib/src/runtime/runtime_root.dart:450`,
  `lib/src/runtime/runtime_root.dart:573`,
  `lib/src/runtime/runtime_root.dart:577`).

The graph source marks `geometry.spatial_index`, `interaction.engine`,
`draw.tools`, and `eraser_context.request` as future
(`docs/architecture/architecture_graph.yaml:380`,
`docs/architecture/architecture_graph.yaml:386`,
`docs/architecture/architecture_graph.yaml:412`,
`docs/architecture/architecture_graph.yaml:418`,
`docs/architecture/architecture_graph.yaml:428`,
`docs/architecture/architecture_graph.yaml:434`,
`docs/architecture/architecture_graph.yaml:444`,
`docs/architecture/architecture_graph.yaml:450`). Current public
interaction-facing facade members for tools, commands, and context action
requests are also placeholders (`lib/src/api/canvas_runtime.dart:35`,
`lib/src/api/canvas_runtime.dart:36`, `lib/src/api/canvas_runtime.dart:41`).

P8 documents spatial implementation scope as future build scope, including
`SpatialKernel`, `TileIndex`, `OutlierIndex`, `SpatialMembership`, touched
spatial update, stale candidate rejection, and fallback budget behavior
(`docs/implementation/p8_geometry_and_spatial.md:16`,
`docs/implementation/p8_geometry_and_spatial.md:17`,
`docs/implementation/p8_geometry_and_spatial.md:18`,
`docs/implementation/p8_geometry_and_spatial.md:19`,
`docs/implementation/p8_geometry_and_spatial.md:20`,
`docs/implementation/p8_geometry_and_spatial.md:21`,
`docs/implementation/p8_geometry_and_spatial.md:22`). P10 documents selection
and move interaction scope, including selected move preview, interaction commits
through `EditKernel`, and batched immutable query ports
(`docs/implementation/p10_selection_and_move.md:5`,
`docs/implementation/p10_selection_and_move.md:21`,
`docs/implementation/p10_selection_and_move.md:27`,
`docs/implementation/p10_selection_and_move.md:28`).

P11 documents draw-mode preview and commit behavior through `EditKernel` and the
P10 cleanup coordinator seam (`docs/implementation/p11_draw_tools.md:5`,
`docs/implementation/p11_draw_tools.md:13`,
`docs/implementation/p11_draw_tools.md:17`,
`docs/implementation/p11_draw_tools.md:18`,
`docs/implementation/p11_draw_tools.md:25`,
`docs/implementation/p11_draw_tools.md:27`). P12 documents eraser preview,
eraser commit through `EditKernel`, exact-hit budget behavior, context-action
request routing, and `commitTextEdit` semantics
(`docs/implementation/p12_eraser_and_context_action_request.md:5`,
`docs/implementation/p12_eraser_and_context_action_request.md:12`,
`docs/implementation/p12_eraser_and_context_action_request.md:14`,
`docs/implementation/p12_eraser_and_context_action_request.md:15`,
`docs/implementation/p12_eraser_and_context_action_request.md:18`,
`docs/implementation/p12_eraser_and_context_action_request.md:24`).

### 4. Public/Internal Contracts and UI-Independent Core Boundaries

- **Location**: primary `tool/guardrails/src/owner_dag_import_checks.dart:326`;
  public barrel at `lib/iwb_canvas_engine.dart:1`.
- **Description**: The root public barrel exports `src/api/*` files
  (`lib/iwb_canvas_engine.dart:1`, `lib/iwb_canvas_engine.dart:17`). Core
  boundary checks permit root barrel exports only under `src/api/`
  (`tool/guardrails/src/core_boundary_checks.dart:323`,
  `tool/guardrails/src/core_boundary_checks.dart:328`). API facade exports may
  target only `lib/src/contracts/public/`
  (`tool/guardrails/src/core_boundary_checks.dart:336`,
  `tool/guardrails/src/core_boundary_checks.dart:338`,
  `tool/guardrails/src/core_boundary_checks.dart:347`).
- **Dependencies**: Internal contracts import public contract declarations, for
  example `FrameFactsPort` imports public element, geometry, ids, and metadata
  contracts (`lib/src/contracts/internal/frame_facts_port.dart:3`,
  `lib/src/contracts/internal/frame_facts_port.dart:4`,
  `lib/src/contracts/internal/frame_facts_port.dart:5`,
  `lib/src/contracts/internal/frame_facts_port.dart:6`).
  Public contract files import SDK/Flutter and sibling public files, not internal
  contracts in the observed source set (`lib/src/contracts/public/canvas_actions.dart:1`,
  `lib/src/contracts/public/canvas_actions.dart:3`,
  `lib/src/contracts/public/canvas_actions.dart:5`,
  `lib/src/contracts/public/canvas_document.dart:1`,
  `lib/src/contracts/public/canvas_document.dart:3`,
  `lib/src/contracts/public/canvas_document.dart:5`).
- **Data flow**: production Dart files under `lib` -> owner DAG parser ->
  owner-edge validation (`tool/guardrails/src/owner_dag_import_checks.dart:10`,
  `tool/guardrails/src/owner_dag_import_checks.dart:13`,
  `tool/guardrails/src/owner_dag_import_checks.dart:65`,
  `tool/guardrails/src/owner_dag_import_checks.dart:91`,
  `tool/guardrails/src/owner_dag_import_checks.dart:118`,
  `tool/guardrails/src/owner_dag_import_checks.dart:122`).

The owner DAG has separate owners for `contracts/public` and
`contracts/internal` (`tool/guardrails/src/owner_dag_import_checks.dart:275`,
`tool/guardrails/src/owner_dag_import_checks.dart:279`). It explicitly allows
`contracts/internal -> contracts/public`
(`tool/guardrails/src/owner_dag_import_checks.dart:326`,
`tool/guardrails/src/owner_dag_import_checks.dart:327`) and does not list the
reverse edge in the allowed-edge table
(`tool/guardrails/src/owner_dag_import_checks.dart:326`,
`tool/guardrails/src/owner_dag_import_checks.dart:385`). Tests assert production
sources obey the owner DAG (`test/guardrails/owner_dag_import_boundaries_test.dart:20`,
`test/guardrails/owner_dag_import_boundaries_test.dart:21`) and include the
same expected `contracts/internal -> contracts/public` policy entry
(`test/guardrails/owner_dag_import_boundaries_test.dart:247`,
`test/guardrails/owner_dag_import_boundaries_test.dart:249`).

`EditKernel` imports `dart:async`, internal contracts, public contracts, and
local edit files (`lib/src/edit/edit_kernel.dart:1`,
`lib/src/edit/edit_kernel.dart:3`, `lib/src/edit/edit_kernel.dart:5`,
`lib/src/edit/edit_kernel.dart:10`). The focused edit dependency test scans
`lib/src/edit` files (`test/edit/typed_effects_no_frame_dependency_test.dart:64`)
and forbids `package:flutter/` plus downstream owner references to
frame/geometry/resources/interaction/surface
(`test/edit/typed_effects_no_frame_dependency_test.dart:159`,
`test/edit/typed_effects_no_frame_dependency_test.dart:169`,
`test/edit/typed_effects_no_frame_dependency_test.dart:174`).
`DocumentStoreKernel` imports `dart:ui`, public contracts, and local store files
(`lib/src/store/document_store_kernel.dart:1`,
`lib/src/store/document_store_kernel.dart:8`,
`lib/src/store/document_store_kernel.dart:18`). Core boundary rules forbid store
imports of interaction, frame, and flutter bridge owners
(`tool/guardrails/src/core_boundary_checks.dart:658`,
`tool/guardrails/src/core_boundary_checks.dart:660`,
`tool/guardrails/src/core_boundary_checks.dart:661`,
`tool/guardrails/src/core_boundary_checks.dart:664`).

## Code References

- `docs/architecture/architecture_graph.yaml:42` - P7 phase entry begins in the
  graph source; generated views select P7 at
  `docs/diagrams/generated/current_phase.mmd:4`.
- `docs/architecture/architecture_graph.yaml:769` - future
  `interaction.engine -> geometry.spatial_index` hit-test boundary edge.
- `docs/architecture/architecture_graph.yaml:812` - future
  `draw.tools -> interaction.engine` preview-intent edge.
- `docs/architecture/architecture_graph.yaml:855` - future
  `eraser_context.request -> interaction.engine` preview-intent edge.
- `docs/architecture/architecture_graph.yaml:583` - future
  `runtime.root -> frame.renderer` FrameFactsPort provider edge.
- `lib/src/api/canvas_runtime.dart:20` - public `CanvasRuntime` facade
  declaration.
- `lib/src/api/canvas_runtime.dart:35` - current tools facade member is a future
  placeholder.
- `lib/src/api/canvas_runtime.dart:39` - current preview facade member is a
  future placeholder.
- `lib/src/runtime/runtime_root.dart:43` - `RuntimeRoot` implements internal
  ports and sinks.
- `lib/src/runtime/runtime_root.dart:151` - `RuntimeRoot.frameFactsPort` returns
  the runtime as a `FrameFactsPort`.
- `lib/src/runtime/runtime_root.dart:233` - frame element resolution copies from
  store facts through the runtime port.
- `lib/src/contracts/internal/frame_facts_port.dart:144` - internal frame facts
  port contract.
- `lib/src/contracts/public/canvas_preview.dart:16` - public preview sealed
  union declaration.
- `tool/guardrails/src/owner_dag_import_checks.dart:326` - owner DAG allowed
  edges begin with `contracts/internal -> contracts/public`.
- `tool/guardrails/src/core_boundary_checks.dart:336` - API facade export target
  restriction.
- `test/guardrails/owner_dag_import_boundaries_test.dart:20` - production owner
  DAG test.

## Observed Architecture Facts

- Pattern observed: public facade delegates to runtime composition root
  (`lib/src/api/canvas_runtime.dart:20`, `lib/src/api/canvas_runtime.dart:26`,
  `lib/src/runtime/runtime_root.dart:43`).
- Pattern observed: internal fact ports expose copied immutable facts instead of
  concrete store objects (`lib/src/runtime/runtime_root.dart:216`,
  `lib/src/runtime/runtime_root.dart:233`,
  `lib/src/runtime/runtime_root.dart:246`,
  `lib/src/contracts/internal/frame_facts_port.dart:144`).
- Data flow: public read -> runtime root -> document store projection
  (`lib/src/api/canvas_runtime.dart:31`,
  `lib/src/runtime/runtime_root.dart:197`,
  `lib/src/store/document_store_kernel.dart:47`).
- Data flow: resource dirty command -> resource kernel -> runtime dirty outcome
  sink -> active session invalidation -> public state/effects
  (`lib/src/resources/resource_kernel.dart:31`,
  `lib/src/resources/resource_kernel.dart:40`,
  `lib/src/runtime/runtime_root.dart:390`,
  `lib/src/runtime/runtime_root.dart:394`,
  `lib/src/runtime/runtime_root.dart:522`).
- Key dependency rule: internal contracts may import public contracts
  (`tool/guardrails/src/owner_dag_import_checks.dart:326`), while public/API
  exposure of internal contracts is rejected by boundary checks
  (`tool/guardrails/src/core_boundary_checks.dart:336`,
  `tool/guardrails/src/core_boundary_checks.dart:643`).
- Key phase fact: reviewed P8-P12 interaction/frame/tool edges are rendered in
  the future graph, not the current selected phase graph
  (`docs/diagrams/generated/future_target.mmd:17`,
  `docs/diagrams/generated/future_target.mmd:28`,
  `docs/diagrams/generated/current_phase.mmd:21`,
  `docs/diagrams/generated/current_phase.mmd:34`).

## Open Questions

- This snapshot contains public preview contracts and future graph/docs for
  interaction, geometry, frame, and tool owners
  (`lib/src/contracts/public/canvas_preview.dart:16`,
  `docs/architecture/architecture_graph.yaml:380`,
  `docs/architecture/architecture_graph.yaml:396`,
  `docs/architecture/architecture_graph.yaml:412`,
  `docs/architecture/architecture_graph.yaml:428`).
- This research did not evaluate future P8-P12 implementation behavior beyond
  the graph/docs, current public placeholders, current contracts, and guardrails
  cited above.
