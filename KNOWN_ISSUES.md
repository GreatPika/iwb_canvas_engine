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
- Detection: `dart run tool/audit_route_expectations.dart`
- Evidence:
  - `tool/audit/route_expectations_boundary_audit.json`
  - `lib/src/contract/internal/snapshot_materialization.dart`
  - Current detections:
    `nodeSnapshotFromValidatedBacking` does not reach
    `validateSnapshotCommonSchemaFields`;
    `sceneSnapshotFromValidatedBacking` does not reach
    `sceneValidateImportDraftValues`
- Next action: Add full value validation before validated snapshot
  materialization or narrow the fast-path surface.
