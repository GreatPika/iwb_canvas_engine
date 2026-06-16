# iwb_canvas_engine documentation

This portal routes task work to the current source-of-truth documentation for
the maintained package while generated navigation handles reverse lookup and
drift checks.

## Start by task

- Understand architecture: `docs/architecture/README.md`
- Plan a change: use a per-task Change Contract in the work item, Codex thread, or PR context
- Verify behavior: `docs/verification/`
- Find current owners: `docs/indexes/by_owner.md`
- Check subsystem contracts: `docs/indexes/by_subsystem.md`
- Find guardrail coverage: `docs/indexes/by_guardrail.md`
- Find test coverage: `docs/indexes/by_test_area.md`
- Find diagram coverage: `docs/indexes/by_diagram.md`
- Update diagrams: `docs/diagrams/catalog.md`
- Prepare release work: `docs/indexes/by_release.md` and `docs/verification/release_gates.md`
- Use generated lookup: `docs/indexes/`

## Source of truth

- Normative architecture: `docs/architecture/`
- Normative contracts: `docs/contracts/`
- Verification policy: `docs/verification/`
- Structured relationships: `docs/_registry/`
- Generated navigation: `docs/indexes/` and `docs/diagrams/catalog.md`
- Evidence inputs: `.design/` and `.research/`, when a task needs prior design
  decisions or codebase research

`.design/` and `.research/` are evidence and source-input layers only. They do
not own active package behavior, release policy, guardrails, roadmaps, external
routes, removed planning routes, or runtime contracts.

## Checks

```bash
dart run docs/tool/sync_generated_docs.dart --check
dart run docs/tool/check_docs.dart
dart run tool/architecture_graph/generate_views.dart --check
```

## Local entrypoints

- `docs/architecture/README.md`
- `docs/contracts/`
- `docs/verification/`
- `docs/diagrams/catalog.md`
- `docs/indexes/by_owner.md`
- `docs/indexes/by_subsystem.md`
- `docs/indexes/by_guardrail.md`
- `docs/indexes/by_test_area.md`
- `docs/indexes/by_diagram.md`
- `docs/indexes/by_release.md`
