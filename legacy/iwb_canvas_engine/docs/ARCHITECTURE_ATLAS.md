# Architecture Atlas

This is the single entrypoint for repository architecture navigation.

## Routes

- Engine architecture: [architecture/overview.md](architecture/overview.md)
- Proof architecture: [proof_architecture/overview.md](proof_architecture/overview.md)
- Rationale: [adr/0001_target_engine_architecture.md](adr/0001_target_engine_architecture.md)
  and [adr/0002_post_target_optimization_scope.md](adr/0002_post_target_optimization_scope.md)
- Active confirmed defects: [KNOWN_ISSUES.md](../KNOWN_ISSUES.md)
- Execution order for planned work: [PLAN.md](../PLAN.md)

## Evidence Rules

- Family documents own local target rules and update triggers.
- Evidence artifacts live under `architecture/evidence/` and
  `proof_architecture/evidence/`.
- Generated evidence must name the repository-local command that reproduces it.
- Known defects belong in `KNOWN_ISSUES.md` and may be linked from family
  status sections.
