---
name: repo-forensics
description: Use repository-local mechanical probes to investigate architecture, ownership, runtime flows, boundary bypasses, proof coverage, public surface drift, duplicate code, and DCM signals before making or reviewing non-trivial repository changes.
---

# Repository Forensics

Use this skill when a task needs mechanical repository investigation before a
fix, refactor, review, or architecture decision.

This skill is for evidence gathering and decision support. It is not a mandate
to run every tool. Pick the smallest probe set that can answer the question.

## When To Use

Use `repo-forensics` for requests like:

- find the root cause of a behavior or architecture issue
- decide which layer or owner should contain a fix
- check whether a change fits `docs/target_architecture/**`
- trace runtime, pointer, render, mutation, or public API flows
- look for boundary bypasses or unexpected direct dependencies
- inspect proof, invariant, guardrail, or public export coverage
- find duplicate or near-duplicate implementation shapes
- interpret DCM findings as architecture or maintainability signals

Do not use this skill for routine one-file edits where the owner and behavior
are already obvious.

## Operating Rules

1. Start from repository sources of truth:
   `AGENTS.md`, `ARCHITECTURE.md`, `docs/adr/**`,
   `docs/target_architecture/**`, `tool/invariant_registry.dart`, and relevant
   code/tests.
2. Prefer repo-local mechanical probes over hand-drawn call graphs or guessed
   ownership.
3. Treat tool output as evidence, not as an automatic design decision.
4. Use DCM and clone analysis as signals, not goals. Do not split, wrap, or
   rename code only to improve a metric.
5. If code, target docs, guardrails, and tests disagree, identify the drift
   explicitly before changing the code.
6. Keep generated evidence artifacts current only when the target/proof map
   explicitly owns them.

## Tool Selection

### Symbol and Flow Probes

Use these when the question is "where does this go", "who calls this", or
"what boundary does this cross".

- `dart run tool/lsp_find_symbols.dart <query>`
  Find declarations and candidate owners by symbol name.

- `dart run tool/lsp_trace_symbol.dart <file> <symbol> --direction=both --depth=N --json`
  Trace incoming and outgoing call hierarchy for a specific symbol.

- `dart run tool/lsp_trace_flow.dart <file> <symbol> --depth=N`
  Follow the primary outgoing flow from an entrypoint.

Use `--json-out=<file>` and `--mermaid-out=<file>` only when refreshing a
target-map evidence artifact that already names those outputs.

### Boundary and Wrapper Probes

Use these when the risk is architectural drift, direct bypasses, or excess
forwarding layers.

- `dart run tool/lsp_find_boundary_bypasses.dart <file> <class> --must-pass=<OwnerOrMethod> --depth=N`
  Check that methods route through the required owner, boundary, or gateway.

- `dart run tool/lsp_find_thin_wrappers.dart <file-or-dir> --classification=pure-forwarder`
  Find forwarding shells and wrapper noise that may hide ownership or
  duplicate routing.

Add `--include-private` only when private helpers are part of the question.

### Proof and Public Surface Probes

Use these when the question is "what proof backs this", "is the public surface
stable", or "which invariant should own this".

- `dart run tool/trace_export_namespace.dart lib/iwb_canvas_engine.dart --json`
  Inspect direct exports, effective exported symbols, and transitive exported
  owners.

- `dart run tool/trace_proof_inventory.dart --json`
  Inspect guardrail rules, invariant ownership, proof reachability, and
  required-code-change preset coverage.

- `dart run tool/check_public_api_surface.dart`
  Enforce the public API golden surface.

- `dart run tool/check_guardrails.dart`
  Enforce architecture and API guardrails.

- `dart run tool/check_invariant_coverage.dart`
  Enforce invariant registry and proof marker coverage.

### Clone and Duplication Probes

Use these when a bug may exist in repeated logic, parallel owners, or copied
test/implementation shapes.

- `dart run tool/analysis/find_similar_clones.dart [options] [rootPath]`
  Find similar Dart code blocks with the repository-local clone detector.

Useful forms:

```sh
dart run tool/analysis/find_similar_clones.dart lib
dart run tool/analysis/find_similar_clones.dart --clusters --top 10 lib
dart run tool/analysis/find_similar_clones.dart --exclude-main test 60 30 5 4 0.70 10
```

- `dcm check-code-duplication .`
  Use DCM's duplication detector as a second signal.

Do not merge code only because two blocks are similar. Merge only when they
share a real responsibility and one owner should hold the behavior.

### DCM Probes

Use DCM when the question involves maintainability, complexity, unused code,
dependency drift, or static-analysis risk.

- `dcm analyze .`
  Run DCM static analysis.

- `dcm calculate-metrics <path>`
  Inspect complexity, size, coupling, and maintainability metrics for changed
  or suspect files.

- `dcm check-unused-code .`
  Find unused declarations.

- `dcm check-unused-files .`
  Find unused files.

- `dcm check-dependencies .`
  Check dependency usage and drift.

- `dcm check-exports-completeness .`
  Check export completeness when export ownership is in scope.

Run DCM narrowly when possible. For new production files under `lib/**`, follow
the repository verification rule and run `dcm calculate-metrics` for those
files.

## Common Investigation Recipes

### Root Cause or Owner Placement

1. Find the entrypoint with `lsp_find_symbols` or `rg`.
2. Trace the call graph with `lsp_trace_symbol` or `lsp_trace_flow`.
3. Compare the path with `ARCHITECTURE.md` and `docs/target_architecture/**`.
4. If an owner boundary matters, run `lsp_find_boundary_bypasses`.
5. Decide whether the fix belongs at the caller, boundary, shared abstraction,
   or invariant/proof layer.

### Target Architecture Fit

1. Read `docs/adr/0001_target_engine_architecture.md`.
2. Read the relevant `docs/target_architecture/families/*.md`.
3. Use the command named in that family doc.
4. Compare new flow output with committed evidence under
   `docs/target_architecture/evidence/`.
5. If evidence drift is real, decide whether the code or the target map is
   stale before editing.

### Proof or Invariant Gap

1. Run `trace_proof_inventory --json`.
2. Find the invariant that should own the behavior.
3. Check required proof paths and `// INV:<id>` markers.
4. Run `check_invariant_coverage` when changing invariant wording or proof
   surfaces.
5. Add or update behavioral tests before relying on prose-only rules.

### Duplication or Repeated Bug Pattern

1. Run `find_similar_clones` on the smallest relevant subtree.
2. Cross-check with `dcm check-code-duplication` if the result matters.
3. Inspect whether the repeated logic has one stable owner.
4. Consolidate only if it improves correctness or ownership clarity.

## Reporting

When reporting results, separate:

- outcome: what decision or risk the evidence supports
- evidence: exact commands or files used
- recommendation: the smallest architecture-compatible next step
- limits: probes not run, stale evidence, or ambiguous owner docs

Do not paste long JSON reports into chat. Summarize the relevant facts and
name the command that produced them.
