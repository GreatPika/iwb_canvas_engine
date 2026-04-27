# Contract Document Model And Validated Fast Paths

## Purpose

This family owns immutable contract document objects and validated fast-path
materialization rules.

## Target Rules

- Boundary data remains immutable and validated before public exposure.
- Validated fast paths must not bypass full value validation unless the
  precondition is explicit and mechanically enforced.

## Owners

- `lib/src/contract/**`
- `tool/audit_validated_materialization_paths.dart`
- `tool/audit_bridge_surfaces.dart`

## Forbidden Shapes

- Do not expose raw backing helpers as supported public materialization paths.
- Do not describe KI-2 as target architecture.

## Mechanical Evidence

- `dart run tool/audit_validated_materialization_paths.dart lib/src/contract`
- `dart run tool/audit_bridge_surfaces.dart lib/src/contract`
- `flutter test --no-pub test/contract`

## Proof Links

- Proof family: [guardrail runner and artifact model](../../proof_architecture/families/guardrail_runner_and_artifact_model.md)
- Invariant: `INV-ENG-NO-EXTERNAL-MUTATION`
- Invariant: `INV-ENG-PUBLIC-SNAPSHOT-GLOBAL-VALIDITY`
- Invariant: `INV-ENG-SHARED-SCENE-METADATA-CONTRACT`
- Invariant: `INV-ENG-CONTRACT-ARCHITECTURE-BOUNDARY`
- Invariant: `INV-ENG-BOUNDARY-HERMETIC-CONCRETE-TYPES`

## Status

- `known issue`
- Validated fast-path materialization remains tracked by
  [KI-2](../../../KNOWN_ISSUES.md#ki-2); this family keeps the intended rule
  explicit while the defect stays unresolved.

## Update Triggers

- Refresh when contract snapshot/spec/patch materialization or bridge surfaces
  change.
