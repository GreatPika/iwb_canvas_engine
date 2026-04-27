# Contract Document Model And Validated Fast Paths

## Purpose

This family owns immutable contract document objects and validated fast-path
materialization rules.

## Target Rules

- Boundary data remains immutable and validated before public exposure.
- Validated fast paths must not bypass full value validation unless the
  precondition is explicit and mechanically enforced.
- `snapshot_fast_path.dart` may expose raw backing carriers and typed
  validated helpers, but not generic backing-to-public snapshot materializers.

## Owners

- `lib/src/contract/**`
- `tool/audit_validated_materialization_paths.dart`
- `tool/audit_bridge_surfaces.dart`

## Forbidden Shapes

- Do not expose generic `*FromValidatedBacking` snapshot materializers through
  bridge surfaces.
- Do not treat raw backing carriers as public-object validation proof.

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

- `locked`
- Validated snapshot fast paths keep carrier access separate from public
  snapshot projection; the bridge-surface and validated-materialization audits
  enforce that split.

## Update Triggers

- Refresh when contract snapshot/spec/patch materialization or bridge surfaces
  change.
