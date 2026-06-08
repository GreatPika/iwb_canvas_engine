---
name: repo-forensics
description: Use repository-local mechanical probes to investigate architecture, ownership, runtime flows, boundary bypasses, proof coverage, public surface drift, duplicate code, and DCM signals before making or reviewing non-trivial repository changes.
---

# Repository Forensics

Use this skill when you need mechanical evidence before a fix, refactor,
review, or architecture decision.

Start from the repository source of truth:

- `AGENTS.md`, `docs/**`, `tool/**`, and code/tests.

## Use It For

- `Owner-Level Fix` root-cause investigation
- `Boundary-Owned Policy` owner placement and boundary questions
- bypass and fast-path audits
- proof or invariant gaps
- duplicate-code and DCM signals

## Rules

1. Prefer repo-local probes over guessed call graphs.
2. Preserve `Evidence Consequence Link`: treat tool output as evidence, not as
   the design decision, and report which owner, boundary, proof, or review
   consequence the output supports.
3. Keep the probe set small: run only what answers the question.
4. If code, tests, docs, and guardrails disagree, report the drift explicitly.

## Tool Portability

Use these categories before choosing a probe:

- Universal: the mechanism is package-agnostic.
- Adaptable: the idea is reusable, but the route config, target path, required
  owner, or naming heuristic must be supplied from the package being
  investigated.

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

### Public Surface Exploration

- `dart run tool/trace_export_namespace.dart <public-entrypoint> --json`
  Inspect direct exports, effective exported symbols, and export owners.
  Use it as exploration evidence only; public API enforcement is owned by the
  target package's guardrails or contract tests.

### Duplication and DCM

- `dart run tool/analysis/find_similar_clones.dart [options] [rootPath]`
  Use the repository clone-analysis probe to find similar Dart code blocks for
  repeated bug-pattern or owner drift checks.

- `dcm analyze .`
  Run static analysis for maintainability and structural risk signals.

- `dcm calculate-metrics <path>`
  Inspect complexity, size, coupling, and maintainability for a suspect file.

## Adaptable Tools

These are reusable ideas, but they are evidence probes only when the target
config, path, owner, or naming heuristic comes from the package being
investigated.

- `dart run tool/audit_route_expectations.dart --config=<json>`
  Check known critical routes for required hops or forbidden bypasses. The
  config is mandatory and must belong to the package being investigated.

- `dart run tool/audit_terminal_cleanup_safety.dart [path-or-dir]`
  Find terminal handlers that call hazardous commit/action paths and clean up
  only after success instead of through `finally`. This is a targeted naming
  heuristic for `commit*`/`emit*` and `clear*`/`reset*`; choose the path from
  the package under investigation and treat hits as review leads.

- `dart run tool/audit_post_commit_cleanup_order.dart [path-or-dir]`
  Find flows where local cleanup sits after fallible post-commit
  `emit`/`notify`/`dispatch` work. This is a targeted naming heuristic, not an
  architecture contract by itself.

## Quick Recipes

### Root Cause

1. `rg` or `lsp_find_symbols` to find the entrypoint.
2. `lsp_trace_symbol` or `lsp_trace_flow` to map the route.
3. `lsp_find_boundary_bypasses` if a specific owner or validator must be hit.

## Reporting

Report four things:

- outcome
- evidence
- recommendation
- limits
