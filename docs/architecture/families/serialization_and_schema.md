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

## Proof Links

- Proof family: [invariant registry and proof reachability](../../proof_architecture/families/invariant_registry_and_proof_reachability.md)
- Invariant: `INV-G-LAYER-BOUNDARIES`

## Status

- `docs stale`
- This slice creates the atlas route; the family is completed in the engine
  family atlas slice.

## Update Triggers

- Refresh when schema versions, codecs, or schema validators change.
