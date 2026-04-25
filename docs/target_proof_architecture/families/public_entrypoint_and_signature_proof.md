# Public Entrypoint And Signature Proof

## Purpose

This family fixes the target shape for proof around the public entrypoint:
which symbols are publicly visible, where those symbols really live, and which
owners must be scanned for public-signature hermeticity.

## Target Rules

- Treat the effective public namespace of `lib/iwb_canvas_engine.dart` as the
  source of truth for public-symbol visibility.
- Keep direct export-target files as barrel-layout policy only; they must not
  silently define the full signature-proof universe.
- Resolve every exported public symbol to its real owner file before checking
  public member signatures.
- Preserve `show` / `hide` semantics when comparing barrel layout, golden
  surface, and signature-proof scope.

## Owners

- `tool/check_public_api_surface.dart`
- `tool/src/guardrails/rules/public/public_surface_rules.dart`
- `tool/src/guardrails/rules/public/public_signature_rules.dart`
- `tool/goldens/public_api_symbols.txt`

## Forbidden Shapes

- One proof path uses the effective entrypoint namespace while another proof
  path scans only local declarations of direct export targets.
- Transitively re-exported public symbols are visible in the golden public
  surface but absent from signature hermeticity coverage.
- Barrel-layout policy and effective public-symbol ownership are treated as the
  same proof universe.

## Mechanical Evidence

- `dart run tool/trace_export_namespace.dart lib/iwb_canvas_engine.dart --json-out=docs/target_proof_architecture/evidence/public_export_namespace.json --md-out=docs/target_proof_architecture/evidence/public_export_namespace.md`
- `dart run tool/check_public_api_surface.dart`
- `dart run tool/check_guardrails.dart`

## Status

- `provisional`
- Current mechanical evidence shows transitively exported public owner files
  under `snapshot.dart` and `validated.dart`, while the public-signature
  guardrail still depends on a direct-export surface artifact.
