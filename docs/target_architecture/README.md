# Target Architecture Map

This directory is the working target map for ADR 0001.

## Document Roles

- [`docs/adr/0001_target_engine_architecture.md`](/Users/blackpika/iwb_canvas_engine/docs/adr/0001_target_engine_architecture.md)
  fixes the accepted top-level target.
- [`overview.md`](overview.md) shows the target owner map and the family
  coverage status.
- [`execution_flows.md`](execution_flows.md) shows the target control and data
  flows.
- [`families/*.md`](families) decompose one target family into code-facing
  owner buckets and local cut lines.
- [`PLAN.md`](/Users/blackpika/iwb_canvas_engine/PLAN.md) records execution
  order; it does not redefine the target architecture.

## When Planning A Slice

1. Confirm the top-level target in ADR 0001.
2. Use [overview.md](overview.md) to choose the family that still has the
   relevant mismatch.
3. Use the family doc to choose the concrete cut.
4. Record that cut in `PLAN.md`.

## Tooling

Use the repository-local LSP helpers when the current task needs a live view of
real call paths before deciding whether the code or the target map is wrong.

- `dart run tool/lsp_find_symbols.dart <query>`
  searches the current package through `dart language-server` and is the
  fastest way to find likely starting symbols for a flow.
- `dart run tool/lsp_trace_symbol.dart <file> <symbol> --depth=N`
  traces incoming and outgoing call hierarchy for one symbol, keeps the output
  repo-local by default, and is the primary probe for checking whether a live
  flow still matches the intended family boundary. Use `--json-out=...` or
  `--mermaid-out=...` when a slice needs a saved artifact.
- `dart run tool/lsp_trace_flow.dart <file> <symbol> --depth=N`
  follows one stitched primary outgoing path and inserts interface-to-
  implementation hops when the runtime seam is unique. Use it when a tree trace
  is too noisy and the current task needs one probable owner-to-owner path.
- `dart run tool/lsp_find_boundary_bypasses.dart <file> <class> --must-pass=...`
  checks whether the public methods of one owner class still pass through a
  required seam such as `SceneControllerMutationBoundary`.
- `dart run tool/lsp_find_thin_wrappers.dart <file-or-dir>`
  scans for thin forwarding wrappers that may be candidates for cleanup or
  evidence that the current family cut is over-shimmed.

The tooling is intentionally small and code-first:

- start from a live trace
- compare the trace with the target family document
- only then decide whether the next change is code cleanup or a target-map
  correction

## Index

- Current checked-in architecture:
  [`ARCHITECTURE.md`](/Users/blackpika/iwb_canvas_engine/ARCHITECTURE.md)
- Accepted target:
  [`docs/adr/0001_target_engine_architecture.md`](/Users/blackpika/iwb_canvas_engine/docs/adr/0001_target_engine_architecture.md)
- Post-target optimization scope:
  [`docs/adr/0002_post_target_optimization_scope.md`](/Users/blackpika/iwb_canvas_engine/docs/adr/0002_post_target_optimization_scope.md)
- Target overview:
  [overview.md](overview.md)
- Target flows:
  [execution_flows.md](execution_flows.md)
- Family maps:
  - [composition_root_and_facade.md](families/composition_root_and_facade.md)
  - [view_runtime_and_render_seam.md](families/view_runtime_and_render_seam.md)
  - [interaction_runtime.md](families/interaction_runtime.md)
  - [mutation_gateway.md](families/mutation_gateway.md)
  - [store_and_commit_path.md](families/store_and_commit_path.md)
