# Import Build Materialization

## Purpose

This family owns scene import, build validation, and canonicalization before
runtime materialization.

## Target Rules

- External input is validated at the import/build boundary.
- Import diagnostics remain stable and path-aware.

## Owners

- `lib/src/model/**`
- `lib/src/serialization/**`
- `tool/audit_route_expectations.dart`

## Forbidden Shapes

- Do not materialize unvalidated external input deep in model code.
- Do not duplicate import diagnostic path assembly across callers.

## Mechanical Evidence

- `dart run tool/audit_route_expectations.dart`
- `dart run tool/check_guardrails.dart`

## Proof Links

- Proof family: [guardrail runner and artifact model](../../proof_architecture/families/guardrail_runner_and_artifact_model.md)
- Invariant: `INV-ENG-VALIDATED-IMPORT-MATERIALIZATION-BOUNDARY`

## Status

- `docs stale`
- This slice creates the atlas route; the family is completed in the engine
  family atlas slice.

## Update Triggers

- Refresh when import, build, or materialization ownership changes.
