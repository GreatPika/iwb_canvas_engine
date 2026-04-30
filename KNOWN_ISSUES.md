language: english

# Known Issues

Confirmed active defects only.

## Rules

- Keep entries short.
- One entry per root cause.
- Use repository-local IDs in the format `KI-<number>`.
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

### KI-15

- `ID`: KI-15
- `Severity`: P2
- `Summary`: `sceneSnapshotBackingFromValidated` returns a
  `SceneSnapshotBacking` without proving global scene structure, even though
  `SceneSnapshotBacking` has a separate structure validator and can represent
  duplicate layer or node ids before safe materialization.
- `Detection`: `dart run tool/audit_validated_backing_structure.dart lib/src/contract`
- `Evidence`: the audit reports
  `lib/src/contract/internal/snapshot_backing.dart:297`, and
  `test/contract/validated_fast_path_contract_test.dart` proves safe
  producers reject malformed backing while raw internal materialization can
  preserve it.
- `Next action`: split or rename the backing helper/surface so structure-proof
  and raw backing construction are mechanically distinct, then keep the audit
  green.
