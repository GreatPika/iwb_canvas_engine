# Proof Flows

## Purpose

This document records the compact registry of mechanically supported proof
flows and inventories that back the proof atlas.

## Proof-Flow Registry

| Flow / inventory | What it verifies | Committed evidence |
| --- | --- | --- |
| Public export namespace | Direct export targets, effective exported owner files, and transitively exported symbols visible from `lib/iwb_canvas_engine.dart`. | [public_export_namespace.md](evidence/public_export_namespace.md) |
| Guardrail runner artifact pipeline | Rule order, invariant ownership, and shared runner-artifact read/write edges. | [proof_inventory.md](evidence/proof_inventory.md) |
| Invariant proof registry | Required proof step coverage, guardrail-backed invariants, and required-code-change reachability. | [proof_inventory.md](evidence/proof_inventory.md) |
| Verification contract and workflow drift | Changed-path routing, verification preset contracts, and executable workflow coverage. | Command-only proof: `dart run tool/check_verification_contract.dart` and `dart run tool/run_tool_tests.dart test/tool/verification_contract_tool_test.dart` |

## Update Rules

- Keep this file limited to short proof-flow names and evidence links.
- Do not embed long rule narratives, raw JSON, or hand-written diagrams here.
- Add a new generated proof-flow entry only after a committed
  machine-generated evidence artifact exists under [`evidence/`](evidence).
- Command-only proof-flow entries must name their repository-local checker and
  focused tool-test command directly.

## Evidence Commands

- `dart run tool/trace_export_namespace.dart lib/iwb_canvas_engine.dart --json-out=docs/proof_architecture/evidence/public_export_namespace.json --md-out=docs/proof_architecture/evidence/public_export_namespace.md`
- `dart run tool/trace_proof_inventory.dart --json-out=docs/proof_architecture/evidence/proof_inventory.json --md-out=docs/proof_architecture/evidence/proof_inventory.md`
