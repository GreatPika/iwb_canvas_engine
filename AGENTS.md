# Architecture rebuild mode

The repository root is the canonical target package for the `iwb_canvas_engine`
architecture rebuild. The current task is to build the new engine described in
`docs/`, not to maintain or extend the legacy package. `docs/README.md` is the documentation entry point.

## Plan workflow

- `PLAN.md` is the active roadmap and the source of truth for planned work.
- When adding a new step to `PLAN.md`, use `$change-contract` directly as the
  canonical step-contract template. Do not infer the required structure from
  existing plan steps.
- Follow the step contract as written during implementation. If a step contract
  conflicts with the current code, guardrails, tests, or repository-local
  boundary enforcement, stop implementation, report the exact contradiction with
  file-level evidence, and resolve the contract or enforcement before
  continuing. Do not silently reinterpret the plan.
- After completing a plan step, update the corresponding checkbox entries in
  `PLAN.md` and any linked step document so finished items are marked done in
  the same change.


## DCM metrics exceptions

- Treat DCM metrics as review signals, not design targets. Do not split,
  wrap, or otherwise reshape cohesive code only to satisfy a metric threshold.
- When a metric violation is an intentional architecture or readability
  trade-off, prefer a local DCM suppression comment over broad configuration
  changes. Use `// ignore: metrics` for a specific declaration, or
  `// ignore_for_file: type=metrics` only when the entire file has a stable
  reason to be excluded from metric violations.
- Every metrics suppression must have a nearby plain-language comment that
  explains why keeping the code together is clearer or safer than reshaping it
  for the metric.
- If the same kind of metrics suppression becomes repeated across several
  files, stop treating it as a local exception. Revisit the owning abstraction,
  file boundary, or repository-level DCM configuration before adding more
  suppressions.


## Verification

After each code change, run these checks from the repository root:

- `dart analyze`
- `dcm analyze .`
- `dcm calculate-metrics .`

Do not run these checks for documentation-only changes.
