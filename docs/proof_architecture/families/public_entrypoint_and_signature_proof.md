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
- `tool/src/guardrails/rules/public/public_export_namespace_support.dart`
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

- `dart run tool/trace_export_namespace.dart lib/iwb_canvas_engine.dart --json-out=docs/proof_architecture/evidence/public_export_namespace.json --md-out=docs/proof_architecture/evidence/public_export_namespace.md`
- `dart run tool/check_public_api_surface.dart`
- `dart run tool/check_guardrails.dart`
- `dart run tool/run_tool_tests.dart test/tool/trace_export_namespace_tool_test.dart`

## Status

- `locked`
- The public-surface golden tool and public-signature hermeticity guardrail both
  use the effective public namespace of `lib/iwb_canvas_engine.dart` for symbol
  visibility and real owner resolution.
- Direct export-target files remain a separate barrel-layout proof surface;
  they no longer define the full public-signature scan scope.

## Update Triggers

- Refresh this family when its listed proof tools, evidence artifacts, or registry-backed invariants change.
