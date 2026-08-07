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
2. Read the complete artifact, every source explicitly named by the user, every
   declared source, governing repository instructions, and current surfaces
   needed to verify its claims.
3. Compare the user-named sources with `Source Inputs`; block omission,
   substitution, narrowing, or an unreadable location. Reconstruct the
   accepted-source obligation ledger, recheck cited Repository Evidence, and
   verify every named owner, package, path, document, registry, schema,
   generated output, public API, and consumer exists or is explicitly future.
4. Apply the source-conflict gate. Do not convert ambiguity into a preferred
   repair. For a full contract, verify classification, obligations, Decision
   Trace, all boundaries, source authority, and that every material decision
   reaches a boundary, outcome, evidence constraint, admission, or gate.
5. Apply the Design Proportionality Backstop to every material obligation added
   or strengthened by the contract.
6. For a full contract, simulate the repository state after every unit; audit
   commit-safe unit closure, real produced/consumed DAG surfaces, all outcome
   parts, direct evidence, witnesses, rejected proxies, impacts, targets,
   admissions, profile obligations, cross-unit closure, repository checks,
   finding disposition, and the pre-implementation evidence boundary.
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
can execute without inventing a material decision and has direct admissible
evidence for every claimed outcome, or a Contract Blocker correctly exposes all
unresolved decisions. Any material defect is `BLOCKED`.

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
