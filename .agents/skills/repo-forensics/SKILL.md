---
name: repo-forensics
description: Use repository-local mechanical probes to investigate architecture, ownership, runtime flows, boundary bypasses, proof coverage, public surface drift, duplicate code, and DCM signals before making or reviewing non-trivial repository changes.
---

# Repository Forensics

Use this skill when you need mechanical evidence before a fix, refactor,
review, or architecture decision.

Start from the source of truth for the package you are investigating:

- Workspace/root decisions: root `AGENTS.md`.
- Legacy oracle or donor questions: `legacy/iwb_canvas_engine/AGENTS.md`,
  legacy docs, legacy `tool/**`, and legacy code/tests.
- Next architecture questions: `next/iwb_canvas_engine_next/docs/**`, next
  code/tests, and only tools that have been ported or explicitly parameterized
  for the next package.

Do not run legacy architecture/proof audits against `next/iwb_canvas_engine_next`.
Legacy findings are oracle or donor evidence, not next-architecture contracts.

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
5. Run legacy-only probes from `legacy/iwb_canvas_engine`, not from the
   workspace root.
6. For `next`, use only universal probes or probes that have a next-owned
   config, golden, package name, and path set.

## Tool Portability

Use these categories before choosing a probe:

- Universal: the mechanism is package-agnostic. It can be used for legacy or
  next once the tool exists in that package or is invoked with the correct root.
- Adaptable: the idea is reusable, but current defaults, config, package names,
  or path assumptions belong to the legacy package.
- Legacy-only: the tool encodes legacy architecture, guardrails, invariants, or
  schema concepts. Use it only for old behavior, oracle checks, and donor
  analysis.

## Universal Tools

### Symbol and Flow

- `dart run tool/lsp_find_symbols.dart <query>`
  Find declarations and likely owners by name.

- `dart run tool/lsp_trace_symbol.dart <file> <symbol> --direction=both --depth=N --json`
  Trace incoming and outgoing call hierarchy for one symbol.

- `dart run tool/lsp_trace_flow.dart <file> <symbol> --depth=N`
  Follow the primary outgoing flow from one entrypoint.

- `dart run tool/lsp_find_boundary_bypasses.dart <file> <class> --must-pass=<OwnerOrMethod> --depth=N`
  Check whether class methods miss a required owner, gateway, or boundary.
  Universal only when the required owner or gateway is supplied from the target
  package's architecture.

- `dart run tool/lsp_find_thin_wrappers.dart <file-or-dir> --classification=pure-forwarder`
  Find forwarding shells that may hide duplicated routing or unclear ownership.

### Duplication and DCM

- `dart run tool/analysis/find_similar_clones.dart [options] [rootPath]`
  Find similar Dart code blocks for repeated bug-pattern or owner drift checks.

- `dcm check-code-duplication .`
  Cross-check duplicate implementation shapes with DCM.

- `dcm analyze .`
  Run static analysis for maintainability and structural risk signals.

- `dcm calculate-metrics <path>`
  Inspect complexity, size, coupling, and maintainability for a suspect file.

## Adaptable Tools

These are reusable ideas, but the current legacy implementations must not be
treated as next-package contracts without next-owned config or parameterization.

- `dart run tool/audit_route_expectations.dart [--config=<json>]`
  Check known critical routes for required hops or forbidden bypasses.

- `dart run tool/audit_terminal_cleanup_safety.dart [path-or-dir]`
  Find terminal handlers that call hazardous commit/action paths and clean up
  only after success instead of through `finally`.

- `dart run tool/audit_post_commit_cleanup_order.dart [path-or-dir]`
  Find flows where local cleanup sits after fallible post-commit
  `emit`/`notify`/`dispatch` work.

- `dart run tool/trace_export_namespace.dart <public-entrypoint> --json`
  Inspect direct exports, effective exported symbols, and export owners.

- `dart run tool/check_public_api_surface.dart`
  Enforce the public API golden surface. Adapt before using outside legacy:
  package name, public entrypoint, and golden path must belong to the target
  package.

### Schema and Materialization Concepts

Use these only after rewriting the matchers for the target package's schema and
validation model.

- `dart run tool/audit_validated_materialization_paths.dart [path-or-dir]`
  Find validated wrappers that jump straight to raw materialization.

- `dart run tool/audit_validated_backing_structure.dart [path-or-dir]`
  Find validated builders that return a backing type with a separate structure
  validator without reaching that validator.

- `dart run tool/audit_schema_family_parity.dart [path-or-dir]`
  Check schema-family return shapes and backing propagation for field drift.

## Legacy-Only Tools

Run these only from `legacy/iwb_canvas_engine`. They encode legacy architecture,
legacy invariants, or old schema concepts.

- `dart run tool/audit_patch_field_admission.dart [path-or-dir]`
  Scan patch schema validators for direct passthrough of non-nullable
  `PatchField<T>` values.

- `dart run tool/audit_bridge_surfaces.dart [path-or-dir]`
  Check allowed bridge surfaces for raw backing and materialization-from-backing
  export leaks.

- `dart run tool/run_repository_audits.dart [--tool=<name>]`
  Run the main standalone audits together; keep `--tool=` for targeted runs.

- `dart run tool/trace_proof_inventory.dart --json`
  Inspect invariant ownership, proof reachability, and guardrail coverage.

- `dart run tool/check_guardrails.dart`
  Run repository architecture and API guardrails.

- `dart run tool/check_invariant_coverage.dart`
  Verify invariant registry and proof-marker coverage.

## Quick Recipes

### Root Cause

1. `rg` or `lsp_find_symbols` to find the entrypoint.
2. `lsp_trace_symbol` or `lsp_trace_flow` to map the route.
3. `lsp_find_boundary_bypasses` if a specific owner or validator must be hit.

### Legacy Known-Issue Sweep

1. Change directory to `legacy/iwb_canvas_engine`.
2. Run `run_repository_audits.dart` for the full standalone audit bundle.
3. Re-run one narrow tool when you need focused evidence for one defect class.
4. Compare active findings with `KNOWN_ISSUES.md`.

### Legacy Proof Gap

1. Change directory to `legacy/iwb_canvas_engine`.
2. Run `trace_proof_inventory --json`.
3. Check the owning invariant and required proof paths.
4. Add or update behavioral proof before relying on prose.

## Reporting

Report four things:

- outcome
- evidence
- recommendation
- limits
