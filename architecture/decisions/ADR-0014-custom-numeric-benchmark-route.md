# ADR-0014: Use a custom benchmark registry with numeric release gates

- Status: superseded
- Date: 2026-06-06
- Implementation state: implemented
- Source designs:
  - `docs/history/designs/2026-06-05-p14-release-readiness-benchmarks.md`
  - `docs/history/designs/2026-06-06-p14-benchmark-measurement-boundary.md`
- Current owners:
  - `docs/verification/performance.md`
  - `docs/verification/release_gates.md`
- Supersedes: none
- Superseded by: ADR-0015
- Retirement design: none
- Retired on: none

## Context

The package needed repeatable performance evidence and a release decision that
could be evaluated from durable machine-readable results. At the time, the
selected approach was to own a package-specific benchmark catalog, runner,
baselines, and numeric budget policy rather than rely on ad hoc manual timing.

The initial benchmark route also mixed setup and cleanup with timed work. That
made results sensitive to harness overhead and made it difficult to compare
runs or diagnose which part of a scenario consumed the budget.

## Decision

Use a custom structured benchmark registry and current-package runner as the
executable source of benchmark cases. Produce versioned machine-readable
reports, compare them with checked-in reference evidence, and evaluate numeric
release budgets and regression policy from those artifacts.

Each benchmark separates preparation, measured action, and cleanup. Only the
declared action contributes to the measurement, while setup and cleanup remain
explicit parts of the executable case contract.

## Rationale

A structured registry made benchmark identity and execution mechanically
discoverable. Versioned reports and reference evidence made comparisons
reproducible, while numeric gates converted observations into an explicit
release decision.

Separating lifecycle phases reduced harness noise and made the measurement
boundary reviewable without hiding setup or cleanup work.

## Consequences

- Benchmark cases, report compatibility, reference evidence, and release policy
  became package-owned maintenance responsibilities.
- Numeric pass/fail results depended on stable measurement boundaries and
  comparable environments.
- Setup and cleanup remained observable but outside the timed action.
- The decision reached implementation before a successor replaced the whole
  route; its former implementation paths are no longer current owners.

## Current owners and enforcement

`docs/verification/performance.md` and
`docs/verification/release_gates.md` are the live authorities for performance
evidence and release admission. They confirm that the custom registry, numeric
baseline, and numeric gate route described here is no longer current.

The implementation state records the maturity this decision reached before
supersession. Historical benchmark tools and reports are evidence only and are
not current enforcement surfaces.

## Source evidence

The 2026-06-05 design selected a custom structured benchmark registry,
machine-readable reports, reference comparisons, and numeric release gates.
The 2026-06-06 measurement-boundary design refined the same route by separating
preparation, measured action, and cleanup and by versioning the report shape.

Commit `162dfe35` recorded the initial execution Change Contract, and commit
`c8950386` on 2026-06-06 recorded the accepted full measurement-boundary form.
Commits `476f0efe`, `35d0f369`, `31b06496`, `be95a188`, and `0d3dd094`
implemented the selected route; `ce5b3301` recorded its closure. This evidence
establishes the header date and implemented state. The lifecycle header links
the later successor without rewriting this historical rationale.
