# iwb_canvas_engine documentation

This portal routes task work to the current source-of-truth documentation for
the new engine rebuild while generated navigation handles reverse lookup and
drift checks.

## Start by task

- Understand architecture: `docs/architecture/README.md`
- Implement a phase: `docs/indexes/by_phase.md`
- Verify behavior: `docs/verification/`
- Check subsystem contracts: `docs/indexes/by_subsystem.md`
- Find guardrail coverage: `docs/indexes/by_guardrail.md`
- Find test coverage: `docs/indexes/by_test_area.md`
- Review donor decisions: `docs/indexes/donor_to_phase.md`
- Update diagrams: `docs/diagrams/catalog.md`
- Prepare release work: `docs/verification/release_gates.md`
- Use generated lookup: `docs/indexes/`
- Find Change Contracts: `PLAN.md` and `plan/`

## Source of truth

- Normative architecture: `docs/architecture/`
- Normative contracts: `docs/contracts/`
- Verification policy: `docs/verification/`
- Implementation sequencing: `docs/implementation/`
- Donor policy and evidence: `docs/donors/`
- Structured relationships: `docs/_registry/`
- Generated navigation: `docs/indexes/` and `docs/diagrams/catalog.md`

## Checks

```bash
dart run docs/tool/sync_generated_docs.dart --check
dart run docs/tool/check_docs.dart
dart run tool/architecture_graph/generate_views.dart --phase P5 --check
```

## Local entrypoints

- `docs/architecture/README.md`
- `docs/implementation/`
- `docs/contracts/`
- `docs/verification/`
- `docs/donors/`
- `docs/diagrams/catalog.md`
- `docs/indexes/by_phase.md`
- `docs/indexes/by_subsystem.md`
- `docs/indexes/by_guardrail.md`
- `docs/indexes/by_test_area.md`
- `docs/indexes/donor_to_phase.md`
