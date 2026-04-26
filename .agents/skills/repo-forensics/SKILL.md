---
name: repo-forensics
description: Use repository-local mechanical probes to investigate architecture, ownership, runtime flows, boundary bypasses, proof coverage, public surface drift, duplicate code, and DCM signals before making or reviewing non-trivial repository changes.
---

# Repository Forensics

Use this skill when you need mechanical evidence before a fix, refactor,
review, or architecture decision.

Start from repository sources of truth:
`AGENTS.md`, `ARCHITECTURE.md`, `docs/target_architecture/**`,
`tool/invariant_registry.dart`, and the relevant code/tests.

## Use It For

- root-cause investigation
- owner placement and boundary questions
- bypass and fast-path audits
- proof or invariant gaps
- duplicate-code and DCM signals

## Rules

1. Prefer repo-local probes over guessed call graphs.
2. Treat tool output as evidence, not as the design decision.
3. Keep the probe set small: run only what answers the question.
4. If code, tests, docs, and guardrails disagree, report the drift explicitly.

## Tool List

### Symbol and Flow

- `dart run tool/lsp_find_symbols.dart <query>`
  Find declarations and likely owners by name.

- `dart run tool/lsp_trace_symbol.dart <file> <symbol> --direction=both --depth=N --json`
  Trace incoming and outgoing call hierarchy for one symbol.

- `dart run tool/lsp_trace_flow.dart <file> <symbol> --depth=N`
  Follow the primary outgoing flow from one entrypoint.

### Boundary and Routing

- `dart run tool/audit_route_expectations.dart [--config=<json>]`
  Check known critical routes for required hops or forbidden bypasses.

- `dart run tool/lsp_find_boundary_bypasses.dart <file> <class> --must-pass=<OwnerOrMethod> --depth=N`
  Check whether class methods miss a required owner, gateway, or boundary.

- `dart run tool/lsp_find_thin_wrappers.dart <file-or-dir> --classification=pure-forwarder`
  Find forwarding shells that may hide duplicated routing or unclear ownership.

### Proof and Boundary Admission

- `dart run tool/audit_patch_field_admission.dart [path-or-dir]`
  Scan patch schema validators for direct passthrough of non-nullable
  `PatchField<T>` values.

- `dart run tool/trace_export_namespace.dart lib/iwb_canvas_engine.dart --json`
  Inspect direct exports, effective exported symbols, and export owners.

- `dart run tool/trace_proof_inventory.dart --json`
  Inspect invariant ownership, proof reachability, and guardrail coverage.

- `dart run tool/check_public_api_surface.dart`
  Enforce the public API golden surface.

- `dart run tool/check_guardrails.dart`
  Run repository architecture and API guardrails.

- `dart run tool/check_invariant_coverage.dart`
  Verify invariant registry and proof-marker coverage.

### Duplication and DCM

- `dart run tool/analysis/find_similar_clones.dart [options] [rootPath]`
  Find similar Dart code blocks for repeated bug-pattern or owner drift checks.

- `dcm check-code-duplication .`
  Cross-check duplicate implementation shapes with DCM.

- `dcm analyze .`
  Run static analysis for maintainability and structural risk signals.

- `dcm calculate-metrics <path>`
  Inspect complexity, size, coupling, and maintainability for a suspect file.

## Quick Recipes

### Root Cause

1. `rg` or `lsp_find_symbols` to find the entrypoint.
2. `lsp_trace_symbol` or `lsp_trace_flow` to map the route.
3. `lsp_find_boundary_bypasses` if a specific owner or validator must be hit.

### Known-Issue Sweep

1. Run `audit_route_expectations.dart` for critical-path bypass regressions.
2. Run `audit_patch_field_admission.dart` for patch boundary admission drift.
3. Compare results with `KNOWN_ISSUES.md`.

### Proof Gap

1. Run `trace_proof_inventory --json`.
2. Check the owning invariant and required proof paths.
3. Add or update behavioral proof before relying on prose.

## Reporting

Report four things:

- outcome
- evidence
- recommendation
- limits
