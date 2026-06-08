# Maintained package mode

The repository root is the canonical maintained package for
`iwb_canvas_engine`. `docs/README.md` is the documentation entry point for
architecture, contracts, verification policy, release gates, generated indexes,
and registries.

## Change planning

- Plan future implementation work with a per-task Change Contract in the work
  item, Codex thread, or PR context.
- `PLAN.md` is the retained current roadmap index. Keep it limited to current
  retained work, and keep `plan/` limited to linked current step contracts.
- Use current code, docs, registries, guardrails, tests, `.design/`, and
  `.research/` as source inputs when they are relevant to the task.
- Do not create a completed contract archive, phase route, or donor route as a
  replacement planning surface.
- Follow the task contract as written during implementation. If it conflicts
  with current code, docs, guardrails, tests, registries, or repository-local
  boundary enforcement, stop implementation, report the exact contradiction
  with file-level evidence, and resolve the contract or enforcement before
  continuing. Do not silently reinterpret the task.
- Treat `.design/` and `.research/` as evidence and source-input layers only.
  They do not own active package behavior, release policy, guardrails,
  benchmarks, roadmaps, donor routes, phase routes, or runtime contracts.


## DCM metrics exceptions

- Treat DCM metrics as review signals, not design targets. Do not split,
  wrap, or otherwise reshape cohesive code only to satisfy a metric threshold.
- When a metric violation is an intentional architecture or readability
  trade-off, suppress only the specific metric on the specific declaration that
  needs the exception. Use exact metric names such as
  `// ignore: halstead-volume, source-lines-of-code`; do not use broad
  `// ignore: metrics`, file-level metric suppression, or repository-level
  threshold/configuration changes to silence localized exceptions.
- Every metrics suppression must have a nearby plain-language comment that
  explains why keeping the code together is clearer or safer than reshaping it
  for the metric.
- If the same kind of metrics suppression becomes repeated across several
  files, stop treating it as a local exception. Revisit the owning abstraction,
  file boundary, or repository-level DCM configuration before adding more
  suppressions.


## Verification

After each Dart code change, including production, test, and tool code, run
these checks from the repository root:

- `dart analyze`
- `dcm analyze .`
- `dcm calculate-metrics` for the changed owners, starting with separate
  production, test, and tool scopes such as `lib/src/<owner>`,
  `test/<area>`, and `tool/<area>`.

Also run the focused tests that cover the changed behavior or changed tool.

For architecture changes, run the architecture graph checks from the repository
root:

- `dart run tool/architecture_graph/check.dart`
- `dart run tool/architecture_graph/generate_views.dart --check`

Run the architecture checks when changing architecture-owned production seams,
`docs/architecture/architecture_graph.yaml`, generated architecture diagrams,
architecture documentation, or release gates that depend on current graph
closure.

For documentation-only changes, do not run the Dart/DCM code checks above.
Instead, run the documentation checks from the repository root:

- `dart run docs/tool/sync_generated_docs.dart --check`
- `dart run docs/tool/check_docs.dart`

Run the documentation checks when changing anything under `docs/` or changing
documentation generation/checking tools. If the generated-docs check reports
stale output, run `dart run docs/tool/sync_generated_docs.dart`, review the
generated diff, and then rerun the documentation checks.

For mixed code and documentation changes, run the relevant code checks, focused
tests, architecture checks when triggered above, and documentation checks.
