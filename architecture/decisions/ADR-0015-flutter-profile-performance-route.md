# ADR-0015: Gate releases on the official Flutter profile route and artifact integrity

- Status: accepted
- Date: 2026-06-16
- Implementation state: implemented
- Source designs:
  - `docs/history/designs/2026-06-16-flutter-performance-verification-route.md`
  - `docs/history/designs/2026-06-16-android-flutter-performance-benchmark-redesign.md`
  - `docs/history/plans/2026-06-16-flutter-performance-verification-route.md`
  - `docs/history/plans/2026-06-16-android-flutter-performance-benchmark-redesign.md`
  - `docs/history/research/2026-06-16-flutter-performance-docs-ssot.md`
  - `docs/history/research/2026-06-16-android-performance-hotspot-paths.md`
- Current owners:
  - `docs/verification/performance.md`
  - `docs/verification/release_gates.md`
- Supersedes: ADR-0014
- Superseded by: none
- Retirement design: none
- Retired on: none

## Context

The custom benchmark route coupled release admission to package-defined timing
budgets, checked-in baselines, and a bespoke runner. Those numeric judgments
were not portable enough across Flutter profile environments and could imply
regression or CPU conclusions that the collected evidence did not justify.

The replacement needed to exercise the real public Flutter surface from an
external consumer, use Flutter-supported profiling output, preserve raw
evidence, and validate that the supported official route completed with
conforming artifacts without turning local timings into universal release
thresholds.

## Decision

Use the official Flutter profile integration route from the external public
consumer example. The executable scenario catalog is the machine-readable
source for scenario groups and their phase and repetition structure. The driver
collects Flutter timeline evidence and writes generated local artifacts that
preserve raw output and enough manifest information to validate the run.

Release admission checks successful route completion and artifact integrity. It
does not compare numeric baselines, apply timing thresholds, emit performance
pass/fail claims, or infer CPU behavior from unsupported evidence.

Scenario groups expand into explicit preparation, warm-up, steady-state, and
single-run forms as appropriate. Repeated steady-state work starts from the
catalog-defined prepared state, and artifact identity follows the executable
catalog rather than a manually duplicated list.

This decision supersedes ADR-0014's custom registry and numeric release-gate
route. The later phase/repetition redesign refined the artifact and execution
shape inside this official Flutter route; it did not restore the superseded
numeric policy or create a separate architectural decision.

## Rationale

The official profile route measures the supported Flutter integration in the
environment that owns the relevant timeline semantics. Importing the executable
catalog into artifact validation keeps scenario identity in one source rather
than synchronizing prose, driver, and verifier lists.

Completion and integrity are claims the repository can verify reliably.
Leaving timings as evidence for analysis avoids presenting environment-specific
numbers as portable release truth.

## Consequences

- Performance verification requires the supported Flutter profile environment
  and an external public-consumer route.
- Raw and summarized artifacts remain generated local evidence rather than
  checked-in baselines or semantic documentation.
- Release gates reject incomplete, malformed, or otherwise nonconforming
  artifact sets without converting timings into numeric regression policy.
- Scenario lifecycle and repetition remain explicit in executable catalog and
  driver behavior.
- Introducing a future numeric performance policy would require new evidence
  and a new architecture decision rather than silently extending this gate.

## Current owners and enforcement

`docs/verification/performance.md` owns the supported profile route, evidence
meaning, and artifact contract. `docs/verification/release_gates.md` owns release
admission and the limits of its performance claim.

The executable catalog is
`example/lib/perf/performance_scenario_catalog.dart`; the external integration
and profile driver live under `example/integration_test/` and
`example/test_driver/`. `tool/check_flutter_performance_artifacts.dart` validates
artifacts against the executable catalog and rejects unsupported numeric,
baseline, and performance pass/fail claims. Current route and artifact proofs
remain with these owners.

## Source evidence

The 2026-06-16 research established Flutter-supported profiling and current
hotspot evidence. The paired designs and plans selected the external profile
route, executable scenario ownership, generated artifacts, and a
completion-and-integrity release gate, then refined execution into explicit
phases and repetitions.

Commit `28f4a54b` on 2026-06-16 recorded the initial execution Change Contract;
`03715e96`, `c36c2c77`, `e67df7d8`, and `d8c0fcb2` implemented the current docs,
catalog, driver, and gate. Commit `d6645817` recorded the phase/repetition
refinement, followed by `42740861`, `bda59b93`, `fce06724`, `8f29ad14`,
`acf41dcf`, and `f60ac385` implementing and hardening it. Commit `c58d67c1`
removed the former custom route as part of the transition. Together this
evidence establishes the header date, implemented state, and supersession of
ADR-0014.
