# Change Contract Reviewing

Use this one complete procedure for every `review-only` request. In
`review-and-repair`, finish this audit before any repair. A review never accepts
a narrower scope.

## Complete review procedure

1. Run mechanical lint first. For a filesystem artifact, pass its absolute path:

   ```bash
   python3 .agents/skills/change-contract/scripts/contract_lint.py /absolute/path/to/contract.md
   ```

   For inline content, pipe the exact supplied bytes, without normalization,
   through standard input:

   ```bash
   python3 .agents/skills/change-contract/scripts/contract_lint.py -
   ```

   A deterministic lint failure returns only `INVALID_CONTRACT_ARTIFACT`
   findings and stops semantic review.
2. Read `Source Inputs` first, then independently reconstruct that table from
   every source explicitly named by the user, every declared source, governing
   repository instructions, and current surfaces needed to verify its claims.
   Do not treat the contract's table, trace, or Matrix as authority for this
   reconstruction. For every design input, reconstruct its `Outcome-Proof Fit`
   rows before relying on the contract's rendering of the design.
3. Before treating the remainder of the contract as evidence, build an
   independent review ledger from the reconstructed sources: source decision,
   independently falsifiable failure family, required outcome, and the evidence
   that would kill a concrete wrong implementation. Compare it with Decision
   Trace, outcomes, and Matrix. An omitted source-derived family is a separate
   `SOURCE_DECISION_DROPPED` finding, even when a neighboring broad outcome,
   source citation, or green suite remains.
4. Compare the user-named sources with `Source Inputs`; block omission,
   substitution, narrowing, or an unreadable location. Recheck cited Repository
   Evidence, verify every named owner, package, path, document, registry,
   schema, generated output, public API, and consumer exists or is explicitly
   future, and apply the source-conflict gate. Do not convert ambiguity into a
   preferred repair. For a full contract, verify classification, obligations,
   Decision Trace, all boundaries, source authority, and that every material
   decision reaches a boundary, outcome, evidence constraint, admission, or
   gate.
5. Apply the Design Proportionality Backstop to every material obligation added
   or strengthened by the contract.
6. For a full contract, simulate the repository state after every unit; audit
   commit-safe unit closure, real produced/consumed DAG surfaces, all outcome
   parts, direct evidence, witnesses, rejected proxies, impacts, targets,
   admissions, profile obligations, cross-unit closure, repository checks,
   finding disposition, and the pre-implementation evidence boundary. For each
   Matrix row, independently simulate the simplest concrete wrong
   implementation or state that could satisfy its visible result, then apply
   only that row's evidence surface and pass signal. Report
   `INCOMPLETE_VERIFICATION` when the declared evidence and kill signal can stay
   green under the wrong implementation. Derive the wrong implementation and
   required signal only from the current contract's accepted sources; do not
   import a failure family, counterexample, or domain vocabulary from another
   contract. For `WORK_BUDGET_CLOSURE`, check every
   applicable construction/import/reset, mutation/update/replay,
   freeze/publication/install, query/read, and cleanup/rollback phase for its
   bound, allowed full pass, forbidden cost displacement, and family-level
   evidence. For each phase, construct the simplest violation that preserves
   the observable result while exceeding its accepted bound or displacing
   prohibited work into another phase. Evidence scoped to one phase does not
   close another unless its declared signal directly observes the constrained
   work there. Report any unrepresented source-derived phase family as
   `SOURCE_DECISION_DROPPED`; report represented but non-killing evidence as
   `INCOMPLETE_VERIFICATION`.
7. For a Contract Blocker instead, verify every request-supplied source is
   represented; each independent unresolved decision has one unique key; each
   missing authority or contradiction is evidence-backed; requested authority
   would resolve it; no provisional boundary, unit, verification row, preferred
   repair, or implementation choice appears; and the final-state Goal does not
   choose a blocked decision. A valid blocker is not deficient because full
   contract sections are absent. Block an unnecessary blocker when available
   sources and repository facts already resolve every decision sufficiently to
   author a full contract.

`PASS` means the inspected latest bytes passed lint and either a full contract
can execute without inventing a material decision, has direct admissible
evidence that kills every source-derived family, and closes every applicable
work-budget phase, or a Contract Blocker correctly exposes all unresolved
decisions. Structural lint is a stop gate, not semantic closure. Any material
defect is `BLOCKED`.

## Routes and output

Use only these routes:

- `INVALID_CONTRACT_ARTIFACT`
- `SOURCE_CONFLICT`
- `SOURCE_DECISION_DROPPED`
- `WRONG_OWNER`
- `UNSAFE_SOURCE_OF_TRUTH`
- `UNSAFE_ORDER`
- `NON_IMPLEMENTABLE_UNIT`
- `INCOMPLETE_VERIFICATION`
- `INVALID_PERMANENT_ARTIFACT_ADMISSION`
- `HANDOFF_NOT_IMPLEMENTABLE`

Return exactly:

```markdown
# Change Contract Validation

Verdict: `PASS | BLOCKED`

## Blocking Findings

- <concise title>
  Route: `<blocked route>`
  Location: `<artifact location>`
  Rule: `<violated rule>`
  Evidence: `<specific source or repository fact>`
  Minimal Repair: `<smallest evidence-backed repair>`

## Summary

<one short paragraph>
```

For `PASS`, omit `Blocking Findings`. Every independent finding carries its own
Route, Location, Rule, Evidence, and Minimal Repair; there is no global route.
Return no passed-section inventory, optional improvement, preference,
implementation test result, source-decision proposal, methodology, preface, or
postscript.
