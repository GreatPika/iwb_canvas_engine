# Target Proof Architecture Map

## Purpose

This directory is the verification-first target map for the repository proof
layer: public-surface checks, guardrail runner state, invariant reachability,
and the regression surfaces that keep those guarantees executable.

It keeps the target form short and code-backed:

- `docs/target_proof_architecture/**` fixes the accepted target shape for the
  proof layer.
- [`ARCHITECTURE.md`](/Users/blackpika/iwb_canvas_engine/ARCHITECTURE.md)
  remains the checked-in current-state engine architecture contract, not the
  proof target map.
- [`PLAN.md`](/Users/blackpika/iwb_canvas_engine/PLAN.md) and
  [`plan/*.md`](/Users/blackpika/iwb_canvas_engine/plan) remain execution-order
  artifacts, not target-map levels.

## Directory Roles

- [`overview.md`](overview.md) is Level 1: the proof-family registry plus the
  shared verification-status vocabulary.
- [`families/*.md`](families) are Level 2: one compact family contract per
  proof family using `Purpose`, `Target Rules`, `Owners`, `Forbidden Shapes`,
  `Mechanical Evidence`, and `Status`.
- [`proof_flows.md`](proof_flows.md) is the short registry of mechanically
  supported proof-layer flows and inventories.
- [`evidence/`](evidence) is the committed machine-generated evidence layer.
- [`PLAN.md`](/Users/blackpika/iwb_canvas_engine/PLAN.md) and
  [`plan/*.md`](/Users/blackpika/iwb_canvas_engine/plan) record migration order
  and slice contracts only.

## Mechanical Evidence

All proof-map flow, namespace, and inventory references must come from
repository-local commands and committed artifacts.

Use only repository-local commands:

- `dart run tool/trace_export_namespace.dart lib/iwb_canvas_engine.dart --json-out=<file> --md-out=<file>`
- `dart run tool/trace_proof_inventory.dart --json-out=<file> --md-out=<file>`
- `dart run tool/check_public_api_surface.dart`
- `dart run tool/check_guardrails.dart`
- `dart run tool/check_invariant_coverage.dart`
- `dart run tool/run_tool_tests.dart test/tool/target_proof_architecture_map_tool_test.dart`

Target-map documents do not carry hand-written namespace inventories or
hand-written proof graphs. They point to committed evidence under
[`evidence/`](evidence) instead.

## Verification Workflow

1. Use [`overview.md`](overview.md) to choose the proof family and current
   verification status.
2. Use [`proof_flows.md`](proof_flows.md) and the relevant family doc to choose
   the matching namespace or inventory probe.
3. Regenerate the committed evidence artifact named by the family doc whenever
   the checked-in proof layer changes.
4. Decide whether the drift is in the code, the guardrails, the regression
   surfaces, or the target map before opening a cleanup plan step.

## Update Rules

- Keep this directory short and normative; long mismatch narratives belong in
  execution contracts and evidence artifacts, not in the target map.
- Keep target-state proof rules here and executable current-state checks in
  `tool/*.dart` plus `test/tool/**`.
- Add a new proof family only after it has a stable owner and at least one
  committed mechanical evidence source.
- Keep the shared verification-status vocabulary in [`overview.md`](overview.md)
  aligned with every family doc.
