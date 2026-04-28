# Serialization And Schema

## Purpose

This family owns JSON schema versions, encode/decode behavior, and schema
validation parity.

## Target Rules

- Schema version compatibility remains explicit.
- Runtime, snapshot, and backing validators stay aligned where the schema
  requires parity.

## Owners

- `lib/src/serialization/**`
- `lib/src/model/scene_value_validation_*.dart`
- `tool/audit_schema_family_parity.dart`

## Forbidden Shapes

- Do not silently widen accepted serialized data.
- Do not describe KI-4 as target architecture.

## Mechanical Evidence

- `dart run tool/audit_schema_family_parity.dart lib/src`
- `dart run tool/check_guardrails.dart`
- `flutter test --no-pub test/serialization test/model`

## Proof Links

- Proof family: [invariant registry and proof reachability](../../proof_architecture/families/invariant_registry_and_proof_reachability.md)
- Invariant: `INV-G-LAYER-BOUNDARIES`
- Invariant: `INV-ENG-SHARED-SCENE-METADATA-CONTRACT`
- Invariant: `INV-SER-JSON-NUMERIC-VALIDATION`
- Invariant: `INV-SER-IMPORT-DIAGNOSTIC-SURFACE`
- Invariant: `INV-SER-JSON-GRID-PALETTE-CONTRACTS`
- Invariant: `INV-SER-SHARED-STROKE-POINT-LIMIT`
- Invariant: `INV-SER-SHARED-PALETTE-ITEM-LIMIT`
- Invariant: `INV-SER-TEXT-DIRECTION-EXPLICIT`
- Invariant: `INV-SER-TYPED-LAYER-SPLIT`
- Invariant: `INV-SER-CANONICAL-BACKGROUND-LAYER`
- Invariant: `INV-SER-SCHEMA-VERSION-CONTRACT`
- Invariant: `INV-SER-UNSUPPORTED-SCHEMA-VERSION-CODE`

## Status

- `locked`
- Runtime, snapshot, and backing vector-width validation share the model-owned
  width contract for stroke thickness, line thickness, rectangle
  `strokeWidth`, and path `strokeWidth`.

## Update Triggers

- Refresh when schema versions, codecs, or schema validators change.
