# Public Package Boundary

## Purpose

This family owns the package entrypoint and the public import surface.

## Target Rules

- Public callers import `package:iwb_canvas_engine/iwb_canvas_engine.dart`.
- Public symbols remain backed by the public API proof surface.
- Mutable internal runtime owners do not become public API types.

## Owners

- `lib/iwb_canvas_engine.dart`
- `tool/check_public_api_surface.dart`

## Forbidden Shapes

- Do not add a second supported public import path.
- Do not expose internal mutable runtime owners through public signatures.

## Mechanical Evidence

- `dart run tool/check_public_api_surface.dart`
- `dart run tool/trace_export_namespace.dart lib/iwb_canvas_engine.dart --json-out=docs/proof_architecture/evidence/public_export_namespace.json --md-out=docs/proof_architecture/evidence/public_export_namespace.md`

## Proof Links

- Proof family: [public entrypoint and signature proof](../../proof_architecture/families/public_entrypoint_and_signature_proof.md)
- Invariant: `INV-G-PUBLIC-ENTRYPOINTS`
- Invariant: `INV-ENG-PUBLIC-SIGNATURE-HERMETICITY`

## Status

- `docs stale`
- This slice creates the atlas route; the family is completed in the engine
  family atlas slice.

## Update Triggers

- Refresh when public exports, golden surface files, or public signature rules
  change.
