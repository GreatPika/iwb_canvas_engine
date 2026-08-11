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
2. Read `Source Inputs` first, then reconstruct it from every user-named and
   declared source, repository instruction, and required current surface without
   trusting the contract's table, trace, or Matrix. Reconstruct each design's
   `Outcome-Proof Fit`, block source omission, substitution, narrowing, or an
   unreadable location, recheck `Repository Evidence` and named surfaces, and
   apply the source-conflict gate.
3. Before treating the remainder of the contract as evidence, build an
   independent review ledger from the reconstructed sources: source decision,
   independently falsifiable failure family, required outcome, and the evidence
   that would kill a concrete wrong implementation. Compare it with Decision
   Trace, outcomes, and Matrix. An omitted source-derived family is a separate
   `SOURCE_DECISION_DROPPED` finding, even when a neighboring broad outcome,
   source citation, or green suite remains.
4. Apply the Design Proportionality Backstop to every material obligation added
   or strengthened by the contract.
5. For a full contract, simulate the repository state after every unit and
   audit all consistency requirements in `contract-rules.md`. Independently
   apply its adversarial audit to every Matrix row and required work-budget
   phase, deriving cases only from the current sources. Report an unrepresented
   family as `SOURCE_DECISION_DROPPED` and represented but non-killing evidence
   as `INCOMPLETE_VERIFICATION`.
6. For a Contract Blocker instead, verify every request-supplied source is
   represented; each independent unresolved decision has one unique key; each
   missing authority or contradiction is evidence-backed; requested authority
   would resolve it; no provisional boundary, unit, verification row, preferred
   repair, or implementation choice appears; and the final-state Goal does not
   choose a blocked decision. A valid blocker is not deficient because full
   contract sections are absent. Block an unnecessary blocker when available
   sources and repository facts already resolve every decision sufficiently to
   author a full contract.

`PASS` requires lint plus either a full contract satisfying
`contract-rules.md` or a valid Contract Blocker. Lint is not semantic closure;
any material defect is `BLOCKED`.

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
