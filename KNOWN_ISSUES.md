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
