# iwb_canvas_engine documentation

This portal routes task work to the current source-of-truth documentation for
the maintained package while generated navigation handles reverse lookup and
drift checks.

## Start by task

- Understand architecture: `docs/architecture/README.md`
- Plan a change: use a per-task Change Contract with current docs and registries as inputs
- Verify behavior: `docs/verification/`
- Find current owners: `docs/indexes/by_owner.md`
- Check subsystem contracts: `docs/indexes/by_subsystem.md`
- Find guardrail coverage: `docs/indexes/by_guardrail.md`
- Find test coverage: `docs/indexes/by_test_area.md`
- Find benchmark coverage: `docs/indexes/by_benchmark.md`
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
- `docs/indexes/by_benchmark.md`
- `docs/indexes/by_diagram.md`
- `docs/indexes/by_release.md`
