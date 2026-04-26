language: english

# Known Issues

Confirmed active defects only.

## Rules

- Keep entries short.
- One entry per root cause.
- Use repository-local IDs in the format `KI-1`, `KI-2`, `KI-3`, ...
- Do not put feature ideas, vague risks, or temporary notes here.
- If an issue is listed here, it is unresolved.
- Do not track status here.
- Remove an entry in the same change that fixes it and adds regression proof.
- This file is not an archive.

## Entry Template

- `ID`
- `Severity`
- `Summary`
- `Detection`
- `Evidence`
- `Next action`

## Active Issues

### KI-1

- ID: `KI-1`
- Severity: `P1`
- Summary: Some non-nullable public `NodePatch` fields accept
  `PatchField.nullValue()` and fail later in transactional patch application
  instead of being rejected at the boundary.
- Detection: `dart run tool/audit_patch_field_admission.dart`
- Evidence:
  - `lib/src/contract/internal/node_boundary_schema_patch.dart`
  - Current detections:
    `validatePatchCommonSchemaFields.isVisible`,
    `validatePatchCommonSchemaFields.isSelectable`,
    `validatePatchCommonSchemaFields.isLocked`,
    `validatePatchCommonSchemaFields.isDeletable`,
    `validatePatchCommonSchemaFields.isTransformable`,
    `validateTextNodePatchSchemaFields.color`,
    `validateTextNodePatchSchemaFields.align`,
    `validateTextNodePatchSchemaFields.textDirection`,
    `validateTextNodePatchSchemaFields.isBold`,
    `validateTextNodePatchSchemaFields.isItalic`,
    `validateTextNodePatchSchemaFields.isUnderline`,
    `validateStrokeNodePatchSchemaFields.color`,
    `validateLineNodePatchSchemaFields.color`,
    `validatePathNodePatchSchemaFields.fillRule`
- Next action: Reject direct passthrough for those non-nullable patch fields
  and add regression tests.

### KI-2

- ID: `KI-2`
- Severity: `P2`
- Summary: Validated snapshot fast-path materialization can expose
  `SceneSnapshot` and `NodeSnapshot` objects built from raw backing without
  full value validation.
- Detection:
  `dart run tool/audit_route_expectations.dart`,
  `dart run tool/audit_validated_materialization_paths.dart`,
  `dart run tool/audit_bridge_surfaces.dart`
- Evidence:
  - `tool/audit/route_expectations_boundary_audit.json`
  - `lib/src/contract/internal/snapshot_materialization.dart`
  - `lib/src/contract/internal/snapshot_fast_path.dart`
  - Current detections:
    `nodeSnapshotFromValidatedBacking` does not reach
    `validateSnapshotCommonSchemaFields`;
    `sceneSnapshotFromValidatedBacking` does not reach
    `sceneValidateImportDraftValues`;
    `snapshot_fast_path.dart` exports raw backing and
    materialization-from-backing helpers
- Next action: Add full value validation before validated snapshot
  materialization or narrow the fast-path surface.

### KI-3

- ID: `KI-3`
- Severity: `P1`
- Summary: Interactive draw terminal cleanup is not exception-safe, so draw
  session, preview, or buffer state can survive a failing terminal commit path.
- Detection:
  `dart run tool/audit_terminal_cleanup_safety.dart`,
  `dart run tool/audit_post_commit_cleanup_order.dart`
- Evidence:
  - `lib/src/interactive/internal/interactive_draw_terminal_router.dart`
  - `lib/src/interactive/internal/interactive_draw_stroke_engine.dart`
  - `lib/src/interactive/internal/interactive_draw_line_engine.dart`
  - `lib/src/interactive/internal/interactive_draw_eraser_engine.dart`
  - Broad `lib/src` sweep currently adds no extra families beyond draw terminal
    cleanup; `InteractiveMoveSession._moveHandleUp` already uses `finally`.
  - Current terminal-cleanup detections:
    `InteractiveDrawTerminalRouter.handleUp`,
    `InteractiveDrawStrokeEngine.commitOnUp`,
    `InteractiveDrawLineEngine._commitDraggedLine`,
    `InteractiveDrawEraserEngine.commitOnUp`
  - Current post-commit cleanup-order detections:
    `InteractiveDrawTerminalRouter.handleUp`,
    `InteractiveDrawStrokeEngine.commitOnUp`,
    `InteractiveDrawLineEngine._commitDraggedLine`
- Next action: Guarantee terminal draw cleanup through `finally` at the draw
  owner seam and add regression tests for failing stroke, line, and eraser
  commits.

### KI-4

- ID: `KI-4`
- Severity: `P2`
- Summary: Runtime stroke value diagnostics do not enforce the same upper
  `sceneThicknessMax` bound as snapshot/backing validation, so oversized
  `StrokeNode.thickness` can escape runtime invariant reporting.
- Detection: Compare runtime/snapshot/backing stroke validators in
  `lib/src/model/scene_value_validation_node_stroke.dart`
- Evidence:
  - `lib/src/model/scene_value_validation_node_stroke.dart`
  - `lib/src/model/scene_value_validation_node_line.dart`
  - Current detections:
    `sceneValidateStrokeNode` checks positive finite thickness but skips
    `sceneValidateDoubleInRange(... max: sceneThicknessMax)`;
    `sceneValidateStrokeNodeSnapshot` and
    `sceneValidateStrokeNodeSnapshotBacking` do enforce the upper bound;
    `sceneValidateLineNode` already keeps runtime/snapshot/backing thickness
    validation aligned through `_sceneValidateLineNodeFields`
- Next action: Add the missing runtime `sceneThicknessMax` range check for
  stroke thickness and cover it with runtime diagnostic tests.

### KI-5

- ID: `KI-5`
- Severity: `P2`
- Summary: Direct model-level scene insertion trusts caller-supplied derived
  locator/index state as the sole uniqueness and budget source, so stale or
  incomplete maps can admit duplicate ids or undercount node budget.
- Detection: Inspect topology mutation helpers in
  `lib/src/model/document_scene_insert.dart` against derived locator builders
  in `lib/src/model/document_locator.dart`
- Evidence:
  - `lib/src/model/document_scene_insert.dart`
  - `lib/src/model/document_locator.dart`
  - Current detections:
    `txnInsertNodeInScene` uses `nodeLocator.containsKey(node.id)` for
    uniqueness and `nodeLocator.length` for node budget;
    `txnInsertContentLayerInScene` uses
    `layerIndexById.containsKey(layerId)` for uniqueness;
    both paths can bypass topology invariants when caller-provided derived
    indexes are stale or incomplete
- Next action: Move uniqueness and budget checks to actual scene topology or
  make the fast-path freshness precondition explicit and enforced.

### KI-6

- ID: `KI-6`
- Severity: `P2`
- Summary: Fill-only path hit-testing applies `hitPadding` to coarse candidate
  bounds but not to the precise path hit-test, so touch padding around filled
  paths is inconsistent with other node families.
- Detection: Compare path candidate-bounds inflation with precise path hit-test
  in `lib/src/core/node_geometry.dart`
- Evidence:
  - `lib/src/core/hit_test.dart`
  - `lib/src/core/node_geometry.dart`
  - Current detections:
    `nodeGeometryCandidateBoundsWorld` and
    `nodeSnapshotGeometryCandidateBoundsWorld` inflate by
    `hitPadding + kHitSlop`;
    `_hitTestPathGeometry` only accepts fill hits through
    `localPath.contains(localPoint)`;
    `_pathStrokeRadiusLocal` returns `0` for fill-only paths, so padding never
    reaches the precise check when `strokeColor == null`
- Next action: Align fill-only path precise hit-testing with shared
  `hitPadding` semantics and add runtime/snapshot hit-test regression cases.

### KI-7

- ID: `KI-7`
- Severity: `P3`
- Summary: Paint candidate admission uses different edge-touch predicates in
  committed spatial queries and snapshot-local fallback, so committed paint
  plans can include ordinary candidates that snapshot fallback excludes.
- Detection: Compare committed paint admission in
  `lib/src/core/scene_spatial_index.dart` with snapshot fallback admission in
  `lib/src/core/scene_snapshot_paint_candidates.dart`
- Evidence:
  - `lib/src/core/scene_spatial_index.dart`
  - `lib/src/core/scene_snapshot_paint_candidates.dart`
  - Current detections:
    committed paint queries resolve candidates through an inclusive boundary
    predicate;
    snapshot-local fallback uses strict `Rect.overlaps`;
    painter culling is also strict, so the drift currently affects candidate
    plan parity and staging work rather than confirmed pixels
- Next action: Choose one shared paint admission boundary policy, codify it in
  tests, and remove the committed-vs-snapshot drift.
