# Change Contract

## 1. Change Mandate

Replace the internal `frameMetaRevision` aggregate with precise background and grid revision facts for frame/cache invalidation while keeping surface styles as captured paint inputs.

## 2. Change Boundary

### Change Surface Summary

Mode: documentation and architecture contract update. Primary surfaces: runtime data model, frame rendering contract, cache policy, operation matrix, diagrams, verification guardrails, phase guidance, and backlog cleanup. Production/test status: no production Dart or Dart test implementation exists in the root package yet; this step updates the target architecture before those owners are implemented.

### Included in the Change

- Define internal `backgroundRevision` and `gridRevision` as persisted document metadata revision families owned by the document/store revision state.
- Replace accepted target references to `frameMetaRevision` in active architecture, frame, cache, operation, diagram, implementation-phase, and verification guidance.
- State that `CanvasSurface.gridStyle` and `CanvasSurface.selectionStyle` remain captured style values and cache-key inputs where relevant, not document revision families and not public runtime revisions.
- Align `StaticBackgroundCache`, `CapturedMainFrame`, `CapturedOverlayFrame`, `SelectionDecorationPlan`, repaint/invalidation diagrams, guardrail wording, and planned tests with the split.
- Clean up the backlog note that proposed a broader `surfaceStyleRevision`, preserving the decision as rejected rather than active backlog.

### Not Included in the Change

- No production Dart implementation under `lib/**`.
- No Dart test implementation under `test/**`.
- No public `CanvasRuntimeRevisions` fields for `backgroundRevision`, `gridRevision`, style revisions, or frame/cache facts.
- No `surfaceStyleRevision`, `gridStyleRevision`, or `selectionStyleRevision` runtime owner.
- No change to runtime view camera ownership, persisted document camera ownership, resource visual revision ownership, selection ownership, or preview ownership.
- No change to public DTO shapes except explanatory text that internal cache/projection revision examples have changed.
- No broad rewrite of unrelated phase contracts, donor records, or legacy package files.

## 3. Surrounding Code Review

### Inspected Artifacts

- `docs/architecture/03_data_model.md:116` lists internal revision families and currently includes `frameMetaRevision`.
- `docs/architecture/03_data_model.md:131` states that public runtime revisions expose stable public domains while internal cache/projection revisions remain private.
- `docs/architecture/03_data_model.md:146` keeps runtime view camera in `state.revisions.viewCamera` and outside document/projection mutation.
- `docs/architecture/03_data_model.md:153` explicitly says `frameMetaRevision` is a v1 aggregate that may later split into background and grid revision families without public API changes.
- `docs/contracts/frame_rendering.md:59` lists `CapturedMainFrame` with `frameMetaRevision`.
- `docs/contracts/frame_rendering.md:77` lists `CapturedOverlayFrame` with `selectionStyle`.
- `docs/contracts/frame_rendering.md:95` requires runtime view camera changes to repaint frame surfaces without invalidating ordinary paint plans or public document projection.
- `docs/contracts/frame_rendering.md:98` routes background/grid changes through internal frame-meta facts.
- `docs/contracts/cache_policy.md:46` keys `StaticBackgroundCache` by background/grid/view-camera-bucket/devicePixelRatio plus `frameMetaRevision` and `viewCameraRevision`.
- `docs/contracts/cache_policy.md:47` keeps `PaintPlanCache` keyed by structural, bounds, element visual, viewport, and device inputs.
- `docs/contracts/cache_policy.md:64` states ordinary paint-plan records and keys exclude selection-only state, `frameMetaRevision`, runtime view camera facts, and selected-move deltas.
- `docs/contracts/operation_matrix.md:61` keeps persisted document camera in the document/projection edit path.
- `docs/contracts/operation_matrix.md:62` keeps `CanvasCameraPort.setOffset/panBy` in runtime view camera state.
- `docs/contracts/operation_matrix.md:63` and `docs/contracts/operation_matrix.md:64` route `setBackgroundColor` and `setGrid` through internal `frameMeta`.
- `docs/contracts/edit_kernel.md:139` and `docs/contracts/edit_kernel.md:140` already distinguish `backgroundChanged` and `gridChanged` in `TouchedSet`.
- `docs/contracts/public_api_v1.md:374` defines public `CanvasRuntimeRevisions` without background, grid, frame meta, or style revision fields.
- `docs/contracts/public_api_v1.md:409` states public runtime revisions are application-observation domains only and internal cache/projection revisions are not public API.
- `docs/contracts/public_api_v1.md:489` defines `CanvasSelectionStyle` and `CanvasGridStyle` as public visual style values.
- `docs/diagrams/seq_main_paint.mmd:17` captures main paint request inputs from `CanvasSurface`, `FrameEngine`, `DocumentStoreKernel`, runtime view camera, and selection facts.
- `docs/diagrams/dfd_main_paint_frame.mmd:40` describes `CapturedMainFrame` with frame meta.
- `docs/diagrams/dfd_main_paint_frame.mmd:52` describes `StaticBackgroundCache` as background/grid/view-camera-bucket/devicePixelRatio owned.
- `docs/diagrams/dfd_cache_invalidation.mmd:38` has a `FrameMetaRevision` node.
- `docs/diagrams/dfd_cache_invalidation.mmd:79` already names static background invalidation as view camera bucket, background, and grid.
- `docs/verification/guardrails.md:179` requires cache keys to use next-owned revision facts and stable inputs.
- `docs/verification/guardrails.md:180` currently names `cache.frame_meta_not_element_visual`.
- `docs/indexes/by_guardrail.md:251` maps `cache.frame_meta_not_element_visual` to frame rendering, cache policy, machine checks, release gates, and `test.frame.camera_pan_preserves_ordinary_paint_plan`.
- `docs/verification/tests.md:374` specifies that camera pan preserves the ordinary paint plan while still repainting affected surfaces.
- `docs/implementation/p9_frame_rendering_and_caches.md:10` owns future frame rendering and render cache implementation guidance.
- `redesign.md:1` preserves the open backlog note that proposed splitting background, grid, and surface-style facts later.
- `test ! -d lib && test ! -d test` confirms the root package currently has no production `lib/` or test `test/` directory, so this step is documentation/architecture only.

### Current Entry Path

The current accepted entry path for the future runtime is document edits and surface paint:

- `CanvasEdit.setBackgroundColor` and `CanvasEdit.setGrid` enter through edit/document metadata mutation and produce exact touched facts through `CommitCompiler`.
- `CanvasCameraPort.setOffset/panBy` enters through runtime view camera state and must remain outside document revision semantics.
- `CanvasSurface` supplies visual style values such as `CanvasGridStyle` and `CanvasSelectionStyle` at the paint boundary.
- `FrameEngine` captures frame facts once and routes ordinary element records, static background cache work, selection decoration, and overlay paint without live runtime reads in painters.

### Current Owner

The current owner is the architecture/documentation source of truth for the new engine. Within the target runtime architecture, the future owner is split:

- `DocumentStoreKernel` / internal `RevisionState` owns persisted document metadata revisions.
- `FrameEngine` owns frame capture, `StaticBackgroundCache`, `PaintPlanCache`, and selection decoration cache policy.
- `CanvasSurface` owns surface style input delivery, but not document revision counters.
- Public `CanvasRuntimeState` owns only public application-observation revision domains.

### Adjacent Abstractions

- `documentRevision`, `structuralRevision`, `boundsRevision`, `elementVisualRevision`, `projectionRevision`, `resourceRevision`, and `resourceVisualRevision` are existing internal revision families in the data model.
- `selectionRevision` is owned separately by `SelectionKernel` and is consumed by selection decoration without entering ordinary paint-plan keys.
- `viewCameraRevision` is public runtime state for runtime camera observation and repaint scheduling, not persisted document camera state.
- `PaintPlanCache`, `StaticBackgroundCache`, `SelectionDecorationPlan`, and `SelectedOrderCache` already have separate cache-policy rows with independent key and invalidation ownership.
- `TouchedSet.backgroundChanged` and `TouchedSet.gridChanged` already provide separate edit facts that can drive separate revisions.

### Existing Tests

No root-package `test/**` Dart files exist yet. The planned verification docs already name future tests in `docs/verification/tests.md`, including `test.frame.main_overlay_capture`, `test.frame.cache_keys_do_not_use_legacy_snapshot_shape`, `test.frame.cache_capacity_eviction_policy`, `test.frame.paint_plan_excludes_preview_delta`, `test.frame.paint_plan_excludes_selection_state`, and `test.frame.camera_pan_preserves_ordinary_paint_plan`.

### Analogous Implementation Path

The closest accepted target-architecture pattern is existing separation by owner:

- `SelectionKernel` owns `selectionRevision`, and selection decoration consumes selection facts without polluting ordinary paint-plan keys.
- Runtime view camera changes use public `state.revisions.viewCamera`, repaint affected surfaces, and do not mutate persisted document camera or public document projection.
- `TouchedSet` already differentiates background and grid changes, so the split can be driven by existing exact invalidation facts rather than adding caller-side synchronization.

### Governing Repository Rules

- `PLAN.md` is the active roadmap and each step uses a dedicated contract file.
- Repository documentation under `docs/` is the durable source of truth for the new-engine transition and target architecture.
- Documentation changes do not require `dart analyze`, `dcm analyze .`, or `dcm calculate-metrics .`.
- Documentation navigation and registry consistency are checked with `dart run docs/tool/generate_context_capsules.dart --check` and `dart run docs/tool/check_docs.dart`.
- Public communication and to-do lists are Russian; repository documentation is English.

### Rejected Misleading Local Patterns

- The existing `frameMetaRevision` wording is a temporary aggregate, not the target owner for precise cache invalidation.
- The `redesign.md` backlog proposal for `surfaceStyleRevision` is broader than the selected design and must not become accepted architecture.
- Public `CanvasRuntimeRevisions` is a public observation summary, not a dump of internal cache revision counters.
- Legacy package static layer cache files under `legacy/` are donor/reference material only and are not implementation targets in this step.
- Old plan step files are historical records and are not the template source for this contract.

## 4. Architecture

### 4A. Locked Architectural Form

#### Problem Ownership Level

The problem belongs at the internal document revision and frame cache contract level. Persisted background and grid facts are document metadata; surface styles are paint-boundary inputs; ordinary element paint plans are element-record caches and must not own either concern.

#### Selected Architectural Form

Retire the accepted target use of `frameMetaRevision` and replace it with two internal persisted-document revision families:

```text
backgroundRevision -> persisted document background color changes
gridRevision       -> persisted CanvasGrid enabled/cellSize/color changes
```

`CanvasGridStyle` and `CanvasSelectionStyle` remain immutable captured values. `CanvasGridStyle.strokeWidth` is a `StaticBackgroundCache` key value when it affects recorded grid output. `CanvasSelectionStyle` remains a `SelectionDecorationPlan` and overlay capture input. Neither style family gets a revision counter in this step.

#### Owning Layer or Module

- `DocumentStoreKernel` / `RevisionState` owns `backgroundRevision` and `gridRevision`.
- `CommitCompiler` owns deriving exact background/grid invalidation effects from `TouchedSet.backgroundChanged` and `TouchedSet.gridChanged`.
- `FrameEngine` owns consuming those revisions for `CapturedMainFrame`, `StaticBackgroundCache`, repaint routing, and ordinary paint-plan exclusion rules.
- `CanvasSurface` owns delivery of `gridStyle`, `selectionStyle`, viewport, and device pixel inputs to frame capture.
- `CanvasRuntimeState` remains the public state owner and does not expose these internal revisions.

#### Architectural Dependency / Import Direction

Edit/document boundaries produce typed revision and invalidation facts; frame/cache owners consume those facts through narrow capture inputs. `FrameEngine` must not depend on concrete edit compilation internals, and `CommitCompiler` must not depend on concrete `FrameEngine`. `CanvasSurface` passes style values into frame capture and must not mutate document revision state.

#### State and Data Ownership

- Persisted background color and `CanvasGrid` values are document state.
- `backgroundRevision` and `gridRevision` are internal revision counters derived from persisted document metadata changes.
- Runtime view camera offset/revision is runtime state.
- Persisted document camera is document/projection state.
- `gridStyle`, `selectionStyle`, viewportRect, and devicePixelRatio are paint/surface inputs captured for a frame, not stored document state.

#### Entry and Exit Boundaries

- Entry: `CanvasEdit.setBackgroundColor`, `CanvasEdit.setGrid`, document replacement/load, `CanvasCameraPort.setOffset/panBy`, and `CanvasSurface` paint requests.
- Exit: public `CanvasRuntimeState` publication, frame repaint intents, `CapturedMainFrame` and `CapturedOverlayFrame` values, cache keys, guardrail/test expectations, and diagrams.

#### Permitted Extension Seam

Future public observation of background or grid changes may be added only through a separate public API decision. Future surface-style revision ownership may be added only if the repository introduces a real runtime owner for surface styles; it must not be simulated by document revision state or a generic surface-style aggregate.

#### Rejected Alternatives

- Keep `frameMetaRevision`: rejected because it continues to mix background and grid invalidation and preserves the over-broad aggregate the backlog identified.
- Add `surfaceStyleRevision`: rejected because surface styles are paint inputs today, not persisted document facts or runtime-owned state.
- Add `gridStyleRevision` and `selectionStyleRevision`: rejected because it creates revision owners without a corresponding state owner and still risks unrelated invalidation between grid and selection styling.
- Add fields to `CanvasRuntimeRevisions`: rejected because these are internal cache/projection facts, not stable public application-observation domains.
- Key `StaticBackgroundCache` by raw `viewCameraRevision`: rejected as the default target because camera pan should schedule repaint and use a camera bucket or captured offset semantics without forcing a cache miss for every revision when the recorded picture can be reused.

#### Why This Level Is Correct

The edit contract already separates `backgroundChanged` and `gridChanged`, and the frame/cache contracts already exclude frame metadata from ordinary element paint plans. Splitting the internal persisted document facts at the store/revision boundary solves the invalidation precision once, while keeping style values at the surface/frame boundary prevents document state, runtime state, and paint configuration from collapsing into one revision family.

#### Verification Strategy

Semantic proof is documentation-level until production code exists: targeted searches must show accepted contracts describe `backgroundRevision` and `gridRevision`, surface styles as values, and no active target dependency on `surfaceStyleRevision` or `frameMetaRevision`. Structural proof uses documentation tooling plus targeted index/registry checks to ensure generated navigation and guardrail references remain coherent.

## 5. Locked Decisions

- `backgroundRevision` and `gridRevision` are internal only.
- `CanvasRuntimeRevisions` remains unchanged.
- `CanvasSurface.gridStyle` and `CanvasSurface.selectionStyle` are captured values, not revision families.
- `StaticBackgroundCache` uses background/grid revisions and stable device/surface inputs; it does not use selection style.
- `SelectionDecorationPlan` may use captured selection style as a key input; it does not use background/grid revisions.
- `PaintPlanCache` remains keyed by ordinary committed element facts,
  viewportRect, and devicePixelRatio only.
- Runtime view camera remains runtime state and must not be folded back into document metadata or frame-meta semantics.
- Persisted document camera remains document/projection state and is not affected by this split.
- The obsolete `surfaceStyleRevision` backlog proposal must be closed or rewritten as a rejected alternative.

## 6. Result Requirements

- Active architecture docs name `backgroundRevision` and `gridRevision` as the precise persisted document metadata revision families.
- Active frame rendering docs capture background/grid revision facts without `frameMetaRevision`.
- Active cache policy docs specify a `StaticBackgroundCache` key that separates background, grid, surface style values, view camera bucket or equivalent camera reuse input, viewportRect, and devicePixelRatio.
- Active cache policy docs keep ordinary paint-plan keys free of background, grid, view camera, preview, selection, and style-only facts.
- Active operation matrix docs route `setBackgroundColor` to `backgroundRevision` and `setGrid` to `gridRevision`.
- Active diagrams show separate background/grid revision flow into static background invalidation.
- Active guardrails and planned test descriptions no longer rely on `frameMetaRevision` as accepted terminology.
- The shared guardrail id `cache.frame_meta_not_element_visual` is retired in favor of `cache.background_grid_not_element_visual`.
- Backlog cleanup no longer presents `surfaceStyleRevision` as the selected or expected future design.

## 7. Execution Order and Gates

### Preconditions

- Work starts from the repository root.
- Confirm the worktree before editing and preserve unrelated changes, including untracked `.research/**` files.
- Do not inspect old plan step files as templates; use this contract and the active source-of-truth docs.

### Required Order

1. Lock the internal revision ownership in architecture and public API explanatory text.
2. Align frame rendering, cache policy, and operation matrix contracts.
3. Align diagrams, verification docs, indexes, implementation-phase guidance, and backlog cleanup.
4. Run documentation structural checks and targeted semantic searches.

### Successor Seam and Retirement Gates

- Retired shared guardrail id: `cache.frame_meta_not_element_visual`.
- Successor shared guardrail id: `cache.background_grid_not_element_visual`.
- Consumer migration order: update the guardrail source row, then phase references, then indexes, then registry/release-gate references, then run the retirement proof.
- Retirement gate: no active docs, registry, index, phase, release-gate, or audit reference may contain `cache.frame_meta_not_element_visual` after Slice 3.

### Seam Migration Matrix

| Changed seam | Successor seam | Affected consumers or documents | Migration slice | Retirement proof |
|---|---|---|---|---|
| `cache.frame_meta_not_element_visual` guardrail id | `cache.background_grid_not_element_visual` | `docs/contracts/frame_rendering.md`, `docs/contracts/cache_policy.md`, `docs/verification/guardrails.md`, `docs/implementation/p9_frame_rendering_and_caches.md`, `docs/indexes/by_guardrail.md`, `docs/indexes/by_test_area.md`, `docs/verification/release_gates.md`, `docs/_registry/sections.yaml`, `audit.md` | Slice 3, with `docs/contracts/frame_rendering.md`, `docs/contracts/cache_policy.md`, and `docs/implementation/p9_frame_rendering_and_caches.md` aligned by Slice 2 before final guardrail retirement | targeted `rg` proof in Slice 3 and final verification finds the successor id and rejects the retired id |

### Cross-Slice Finalization

- Complete guardrail id migration in one finalization pass; do not leave mixed old/new guardrail ids across docs, indexes, registry, or release gates.
- Refresh generated context/navigation artifacts only through repository docs tooling; do not hand-edit generated output unless the tool identifies it as a source file.

### Deferred Broad Verification

Slice-local proof may run targeted semantic checks and documentation structural checks as soon as a slice changes the relevant source files. The final gate must repeat the broad documentation structural checks after all slices and cleanup are complete. `dart analyze`, `dcm analyze .`, and `dcm calculate-metrics .` are intentionally outside this documentation-only step.

## 8. Implementation Rules

### Protected Invariants

- Public runtime observation domains remain `document`, `selection`, `preview`, `viewCamera`, `resourceVisual`, `interaction`, and `epoch`.
- Background/grid changes and runtime view camera changes must not invalidate ordinary committed element paint plans.
- Surface styles must not be represented as persisted document metadata.
- Selection style changes must not invalidate static background cache.
- Grid style stroke width may affect static background cache identity only as a stable captured value.
- Camera pan must not become document metadata, projection state, or raw ordinary paint-plan cache identity.
- No generic global invalidation may replace exact `backgroundChanged` and `gridChanged` facts.

### Required Proof

- Use targeted semantic proof to show the accepted target docs use `backgroundRevision` and `gridRevision` and no longer describe `surfaceStyleRevision` as planned architecture.
- Use targeted negative proof to show active frame/cache/operation docs no longer depend on `frameMetaRevision`.
- Use targeted migration proof to show `cache.background_grid_not_element_visual` replaced `cache.frame_meta_not_element_visual` everywhere in active guardrail references.
- Use documentation structural proof to keep registries, indexes, diagrams catalog, and context capsules coherent.

### Allowed Change Surface

- `docs/architecture/03_data_model.md`
- `docs/contracts/public_api_v1.md`
- `docs/contracts/edit_kernel.md`
- `docs/contracts/operation_matrix.md`
- `docs/contracts/frame_rendering.md`
- `docs/contracts/cache_policy.md`
- `docs/diagrams/seq_main_paint.mmd`
- `docs/diagrams/dfd_main_paint_frame.mmd`
- `docs/diagrams/dfd_cache_invalidation.mmd`
- `docs/implementation/p9_frame_rendering_and_caches.md`
- `docs/implementation/p13_flutter_surface.md` only if surface-style wording needs alignment
- `docs/verification/guardrails.md`
- `docs/verification/tests.md`
- `docs/verification/release_gates.md`
- `docs/indexes/by_guardrail.md`
- `docs/indexes/by_test_area.md`
- `docs/_registry/sections.yaml`
- `redesign.md`
- `audit.md` only for stale checklist cleanup directly tied to this revision split

### Forbidden Moves

- Do not add production code or tests in this step.
- Do not introduce a public API field for background, grid, frame meta, or style revisions.
- Do not add `surfaceStyleRevision`, `gridStyleRevision`, or `selectionStyleRevision`.
- Do not change camera ownership semantics.
- Do not use legacy package implementation files as edit targets.
- Do not satisfy this by only renaming text while leaving cache keys or frame capture semantics ambiguous.

## 9. Vertical Slices

### Slice 1. [x] Lock Background And Grid Revision Ownership

#### Slice Contract

The data model and public API explanatory text define `backgroundRevision` and `gridRevision` as private internal document metadata facts and remove `frameMetaRevision` as the accepted aggregate.

#### Files

- Primary edit: `docs/architecture/03_data_model.md` - update internal revision list and explanatory ownership text.
- Primary edit: `docs/contracts/public_api_v1.md` - update internal revision examples without adding public fields.
- Alignment edit: `docs/contracts/edit_kernel.md` - align exact touched invalidation wording if needed.
- Verify-only check: `docs/tool/check_docs.dart` - repository documentation structure checker.

#### Change

Replace the v1 aggregate description with precise background/grid revision families. Keep public runtime revision domains unchanged and explicitly state that surface styles are not document revision facts.

#### Slice Verification

##### Semantic Proof

Proves the internal revision list contains the selected families and the public API contract still exposes only public observation domains:

```bash
bash -lc 'set -e
rg -q "backgroundRevision" docs/architecture/03_data_model.md
rg -q "gridRevision" docs/architecture/03_data_model.md
rg -q "backgroundRevision" docs/contracts/public_api_v1.md
rg -q "gridRevision" docs/contracts/public_api_v1.md
rg -q "final int document;" docs/contracts/public_api_v1.md
rg -q "final int selection;" docs/contracts/public_api_v1.md
rg -q "final int preview;" docs/contracts/public_api_v1.md
rg -q "final int viewCamera;" docs/contracts/public_api_v1.md
rg -q "final int resourceVisual;" docs/contracts/public_api_v1.md
rg -q "final int interaction;" docs/contracts/public_api_v1.md
rg -q "final int epoch;" docs/contracts/public_api_v1.md
! rg -n "final int (background|grid|frameMeta|surfaceStyle|gridStyle|selectionStyle)" docs/contracts/public_api_v1.md'
```

Proves the accepted data model no longer describes `frameMetaRevision` as the target aggregate:

```bash
bash -lc 'set -e
! rg -n "frameMetaRevision|surfaceStyleRevision|gridStyleRevision|selectionStyleRevision" docs/architecture/03_data_model.md docs/contracts/public_api_v1.md'
```

##### Structural Proof

Proves the docs source still passes repository navigation and registry checks after the ownership text changes:

```bash
dart run docs/tool/check_docs.dart
```

#### Closure Gate

Slice closes when architecture/public API docs make the private background/grid split explicit and do not add public runtime revision fields.

### Slice 2. [x] Align Frame Capture And Cache Policy

#### Slice Contract

Frame capture and cache policy consume `backgroundRevision` and `gridRevision` separately, keep surface styles as captured values, and preserve ordinary paint-plan exclusion rules.

#### Files

- Primary edit: `docs/contracts/frame_rendering.md` - update `CapturedMainFrame`, `CapturedOverlayFrame`, and paint-plan exclusion rules.
- Primary edit: `docs/contracts/cache_policy.md` - update `StaticBackgroundCache`, `PaintPlanCache`, and `SelectionDecorationPlan` key/invalidation wording.
- Primary edit: `docs/contracts/operation_matrix.md` - route `setBackgroundColor` and `setGrid` to their precise internal revisions.
- Alignment edit: `docs/implementation/p9_frame_rendering_and_caches.md` - align phase build scope, tests, and guardrail wording.
- Alignment edit: `docs/implementation/p13_flutter_surface.md` - align surface-style guidance only if current wording implies style revision ownership.
- Verify-only check: `docs/tool/check_docs.dart` - repository documentation structure checker.

#### Change

Update frame/cache contracts so `StaticBackgroundCache` is keyed by background revision, grid revision, grid style stroke width where it affects grid recording, viewportRect, devicePixelRatio, and the selected view-camera bucket or equivalent captured camera reuse input. Keep raw `viewCameraRevision`, selection style, selected ids, selected-move delta, preview delta, and background/grid revisions out of ordinary `PaintPlanCache` identity.

#### Slice Verification

##### Semantic Proof

Proves frame/cache contracts contain the selected split and style-as-value design:

```bash
bash -lc 'set -e
for file in docs/contracts/frame_rendering.md docs/contracts/cache_policy.md docs/contracts/operation_matrix.md docs/implementation/p9_frame_rendering_and_caches.md; do
  rg -q "backgroundRevision" "$file"
  rg -q "gridRevision" "$file"
done
rg -q "gridStrokeWidth" docs/contracts/cache_policy.md
rg -q "gridStrokeWidth" docs/contracts/frame_rendering.md
rg -q "selectionStyle" docs/contracts/frame_rendering.md
rg -q "SelectionDecorationPlan" docs/contracts/cache_policy.md
rg -q "PaintPlanCache key must not include" docs/contracts/frame_rendering.md
rg -q "^\| StaticBackgroundCache \|.*backgroundRevision.*gridRevision.*gridStrokeWidth" docs/contracts/cache_policy.md
rg -q "^\| PaintPlanCache \|.*structural/bounds/elementVisual" docs/contracts/cache_policy.md
! rg -n "^\| PaintPlanCache \|.*(backgroundRevision|gridRevision|viewCameraRevision|selectionStyle)" docs/contracts/cache_policy.md
rg -q "^\| setBackgroundColor \|.*backgroundRevision" docs/contracts/operation_matrix.md
rg -q "^\| setGrid \|.*gridRevision" docs/contracts/operation_matrix.md'
```

Proves active frame/cache contracts no longer depend on the retired aggregate or rejected style revisions:

```bash
bash -lc 'set -e
! rg -n "frameMetaRevision|surfaceStyleRevision|gridStyleRevision|selectionStyleRevision" docs/contracts/frame_rendering.md docs/contracts/cache_policy.md docs/contracts/operation_matrix.md docs/implementation/p9_frame_rendering_and_caches.md docs/implementation/p13_flutter_surface.md'
```

##### Structural Proof

Proves repository docs structure remains valid after contract alignment:

```bash
dart run docs/tool/check_docs.dart
```

#### Closure Gate

Slice closes when frame/cache docs have one unambiguous cache and capture design and ordinary paint-plan invalidation remains protected.

### Slice 3. [x] Align Diagrams, Verification, And Backlog

#### Slice Contract

Diagrams, guardrails, test inventory, indexes, release gates, and backlog notes use the selected background/grid split and no longer present `surfaceStyleRevision` as future accepted architecture.

#### Files

- Primary edit: `docs/diagrams/seq_main_paint.mmd` - update store-to-frame captured revision facts and paint-plan exclusion note.
- Primary edit: `docs/diagrams/dfd_main_paint_frame.mmd` - update captured frame and static background cache labels/edges.
- Primary edit: `docs/diagrams/dfd_cache_invalidation.mmd` - replace `FrameMetaRevision` flow with background/grid revision flow.
- Primary edit: `docs/verification/guardrails.md` - update or rename the frame/cache guardrail.
- Primary edit: `docs/verification/tests.md` - align planned test descriptions with background/grid split and style-as-value behavior.
- Alignment edit: `docs/indexes/by_guardrail.md` - update guardrail mapping.
- Alignment edit: `docs/indexes/by_test_area.md` - update guardrail references to the successor id.
- Alignment edit: `docs/verification/release_gates.md` - update guardrail references to the successor id.
- Alignment edit: `docs/_registry/sections.yaml` - update guardrail references to the successor id.
- Primary edit: `redesign.md` - close or rewrite the stale backlog note.
- Alignment edit: `audit.md` - update only stale checklist text that still requires `frameMetaRevision`.
- Verify-only evidence: `docs/contracts/frame_rendering.md` - already aligned in Slice 2 and included in the guardrail retirement proof.
- Verify-only evidence: `docs/contracts/cache_policy.md` - already aligned in Slice 2 and included in the guardrail retirement proof.
- Verify-only evidence: `docs/implementation/p9_frame_rendering_and_caches.md` - already aligned in Slice 2 and included in the guardrail retirement proof.
- Verify-only check: `docs/tool/generate_context_capsules.dart` - context capsule synchronization checker.
- Verify-only check: `docs/tool/check_docs.dart` - repository documentation structure checker.

#### Change

Make the docs ecosystem tell the same story as the contract: background/grid document facts are separate, surface styles are values, camera pan is runtime view camera state, and ordinary paint plans stay independent of frame/static-background facts.

#### Slice Verification

##### Semantic Proof

Proves active diagrams and verification docs no longer describe the retired aggregate or rejected style revision family:

```bash
bash -lc 'set -e
! rg -n "frameMetaRevision|surfaceStyleRevision|gridStyleRevision|selectionStyleRevision" docs/diagrams/seq_main_paint.mmd docs/diagrams/dfd_main_paint_frame.mmd docs/diagrams/dfd_cache_invalidation.mmd docs/verification/guardrails.md docs/verification/tests.md docs/indexes/by_guardrail.md docs/indexes/by_test_area.md docs/verification/release_gates.md docs/_registry/sections.yaml redesign.md audit.md'
```

Proves the selected terms are present in diagrams, verification guidance, and backlog cleanup:

```bash
bash -lc 'set -e
for file in docs/diagrams/seq_main_paint.mmd docs/diagrams/dfd_main_paint_frame.mmd docs/diagrams/dfd_cache_invalidation.mmd docs/verification/guardrails.md docs/verification/tests.md redesign.md; do
  rg -q "backgroundRevision" "$file"
  rg -q "gridRevision" "$file"
done
rg -q "gridStrokeWidth" docs/diagrams/dfd_main_paint_frame.mmd
rg -q "selectionStyle" docs/verification/tests.md
rg -q "viewCamera" docs/diagrams/seq_main_paint.mmd
for file in docs/contracts/frame_rendering.md docs/contracts/cache_policy.md docs/verification/guardrails.md docs/implementation/p9_frame_rendering_and_caches.md docs/indexes/by_guardrail.md docs/indexes/by_test_area.md docs/verification/release_gates.md docs/_registry/sections.yaml; do
  rg -q "cache.background_grid_not_element_visual" "$file"
done
! rg -n "cache.frame_meta_not_element_visual" docs/contracts/frame_rendering.md docs/contracts/cache_policy.md docs/verification/guardrails.md docs/implementation/p9_frame_rendering_and_caches.md docs/indexes/by_guardrail.md docs/indexes/by_test_area.md docs/verification/release_gates.md docs/_registry/sections.yaml audit.md'
```

##### Structural Proof

Proves context capsules and docs navigation remain synchronized:

```bash
dart run docs/tool/generate_context_capsules.dart --check
dart run docs/tool/check_docs.dart
```

#### Closure Gate

Slice closes when all active docs, diagrams, verification references, and backlog notes agree on the selected split and no stale accepted `frameMetaRevision` or `surfaceStyleRevision` language remains in the touched active surfaces.

## 10. Final Verification

Final verification for this documentation-only step:

```bash
dart run docs/tool/generate_context_capsules.dart --check
dart run docs/tool/check_docs.dart
```

Targeted semantic verification:

```bash
bash -lc 'set -e
for file in docs/architecture/03_data_model.md docs/contracts/frame_rendering.md docs/contracts/cache_policy.md docs/contracts/operation_matrix.md docs/diagrams/seq_main_paint.mmd docs/diagrams/dfd_main_paint_frame.mmd docs/diagrams/dfd_cache_invalidation.mmd docs/verification/guardrails.md docs/verification/tests.md redesign.md; do
  rg -q "backgroundRevision" "$file"
  rg -q "gridRevision" "$file"
done'
bash -lc 'set -e
! rg -n "surfaceStyleRevision|gridStyleRevision|selectionStyleRevision" docs/architecture/03_data_model.md docs/contracts/frame_rendering.md docs/contracts/cache_policy.md docs/contracts/operation_matrix.md docs/diagrams/seq_main_paint.mmd docs/diagrams/dfd_main_paint_frame.mmd docs/diagrams/dfd_cache_invalidation.mmd docs/implementation/p9_frame_rendering_and_caches.md docs/implementation/p13_flutter_surface.md docs/verification/guardrails.md docs/verification/tests.md docs/indexes/by_guardrail.md docs/indexes/by_test_area.md docs/verification/release_gates.md docs/_registry/sections.yaml redesign.md audit.md'
bash -lc 'set -e
! rg -n "frameMetaRevision" docs/architecture/03_data_model.md docs/contracts/frame_rendering.md docs/contracts/cache_policy.md docs/contracts/operation_matrix.md docs/diagrams/seq_main_paint.mmd docs/diagrams/dfd_main_paint_frame.mmd docs/diagrams/dfd_cache_invalidation.mmd docs/implementation/p9_frame_rendering_and_caches.md docs/verification/guardrails.md docs/indexes/by_guardrail.md redesign.md audit.md'
bash -lc 'set -e
for file in docs/contracts/frame_rendering.md docs/contracts/cache_policy.md docs/verification/guardrails.md docs/implementation/p9_frame_rendering_and_caches.md docs/indexes/by_guardrail.md docs/indexes/by_test_area.md docs/verification/release_gates.md docs/_registry/sections.yaml; do
  rg -q "cache.background_grid_not_element_visual" "$file"
done
! rg -n "cache.frame_meta_not_element_visual" docs/contracts/frame_rendering.md docs/contracts/cache_policy.md docs/verification/guardrails.md docs/implementation/p9_frame_rendering_and_caches.md docs/indexes/by_guardrail.md docs/indexes/by_test_area.md docs/verification/release_gates.md docs/_registry/sections.yaml audit.md'
```

Do not run `dart analyze`, `dcm analyze .`, or `dcm calculate-metrics .` for this step unless production Dart files are added contrary to this contract.

## 11. Acceptance Criteria

- `PLAN.md` links this step and the step remains unchecked until executed.
- Active architecture docs define `backgroundRevision` and `gridRevision` as internal document-owned revision families.
- Active frame and cache contracts consume background/grid revision facts separately and keep surface styles as captured values.
- Public runtime revisions remain unchanged.
- Diagrams, guardrails, planned tests, indexes, release gates, implementation guidance, and backlog notes no longer present `frameMetaRevision` or `surfaceStyleRevision` as accepted target architecture.
- Active guardrail references use `cache.background_grid_not_element_visual`, and `cache.frame_meta_not_element_visual` is retired from active contracts, docs, indexes, registry, release gates, and audit references.
- Documentation structural checks and targeted semantic verification pass.
