# Architecture Design Review Procedure

## 1. Review Scope And Target

Review-only audits exactly one active design artifact and emits only the validation
artifact in `Output Contract`. It performs no writes, brainstorming, subagent creation,
or downstream contract work.

- Path supplied: review only that path.
- No path: infer only when exactly one relevant active design exists; otherwise request
  the path.
- Never infer a historical target.

## 2. Form And Evidence Gates

Run `design_lint.py` first. On failure, return only `INVALID_DESIGN_ARTIFACT` findings
and stop before semantic review. On success, `design-rules.md` is the single semantic
rule owner.

Then read the complete artifact, every declared source input, and the repository
surfaces needed to independently verify its cited facts. Re-check every citation and
every current owner or decision source used. On re-review, the diff and finding
admission records are context only, never evidence or authority. Continue only after a
clean evidence re-check.

## 3. Semantic Audit

Apply the matching `design-rules.md` section to each audit item below, in this order,
and enforce cross-section consistency throughout.

### 3.1 Disposition And Evidence

1. Disposition and decision closure.
2. Source inputs and evidence.

### 3.2 Candidates, Selected Form, And Solution Proportionality

Run this audit in every review-only run; general completeness cannot substitute for it.
`Solution Proportionality` in `design-rules.md` solely owns its definitions and decision
criteria.

1. Candidate comparison and selected form, followed by the complete Solution
   Proportionality audit below.
2. Derive comparison inputs from independent sources and evidence.
3. Reconstruct concrete viable alternatives; do not trust the author's candidate set or
   assume one global minimum.
4. Compare material-obligation deltas and test every claimed justification.
5. Split mixed concerns into independently evaluable obligations before output. Emit
   only independent blockers, complete the audit, and do not stop at the first. Group
   obligations removed by the same viable alternative into one finding. Unsupported
   exact helper, model, function, table, or class cardinality locks removed by one
   simpler form belong to one finding.
6. When repair touches text containing an authorized decision, `Minimal Repair` must
   explicitly preserve that decision; do not emit the preserved decision separately. If
   the design already removed or weakened an explicit recorded decision, emit that loss
   as a separate blocker. For an authorized organizational decision whose incidental
   shape is open, restore the decision while retaining that openness. A grouped
   cardinality-lock repair removes the exact locks while preserving any authorized
   organizational obligation in the same text.
7. If a recorded user decision itself requires exact incidental shape, return
   `NEEDS_USER_DECISION` for the rule conflict; do not restore, remove, or normalize
   that decision.
8. Use `DISPROPORTIONATE_SOLUTION` for strict dominance and `NEEDS_USER_DECISION` for an
   unresolved incomparable material trade-off. If no explicit authority or
   evidence-backed failure supports an organizational constraint and a viable simpler
   form omits it, remove the constraint through `DISPROPORTIONATE_SOLUTION`; do not
   create a user decision merely to preserve it.

### 3.3 Closure, Gates, Proof, And Trace

1. Boundary locks and source of truth.
2. Gate applicability and ordering.
3. Outcome-Proof Fit.
4. Decision Trace.

### 3.4 Pressure, Impact, Verification, And Handoff

1. Future pressure and selected diagram requirements.
2. Source-of-truth and ADR impact.
3. Verification strategy.
4. Change Contract handoff and open decisions.

Finally, mentally simulate authoring the next Change Contract. If it still requires
inventing a material architecture decision, return `BLOCKED` with
`HANDOFF_NOT_CONSUMABLE`.

## 4. Blocked Routes

For `BLOCKED`, select exactly one route:

- `INVALID_DESIGN_ARTIFACT` — deterministic form or unsupported value;
- `NEEDS_RESEARCH` — missing, stale, contradictory, or unverifiable fact;
- `NEEDS_USER_DECISION` — unresolved product or architecture choice;
- `CONTRADICTS_REPO` — selected form conflicts with a current owner;
- `WRONG_OWNER` — responsibility is assigned outside its owner;
- `UNSAFE_SOURCE_OF_TRUTH` — conflicting durable truth remains or is created;
- `UNSAFE_ORDER` — migration, publication, mutation, or retirement order is unsafe;
- `INSUFFICIENT_PROOF` — the oracle/evidence cannot detect the claimed outcome;
- `DISPROPORTIONATE_SOLUTION` — a strictly simpler viable form preserves the accepted
  outcomes and mandatory constraints;
- `HANDOFF_NOT_CONSUMABLE` — downstream contract work would have to invent an
  architecture decision.

## 5. Output Contract

Verdicts are only `PASS` and `BLOCKED`; never `REVISE`. `PASS` means Change Contract
authoring can consume the design without a new architecture decision.

Return only the validation artifact. Do not list passed sections, optional improvements,
preferences, or non-blocking advice. `Blocking Findings` contains only actual
violations. Put any decision that `Minimal Repair` must preserve inside that repair, not
in a second protective finding.

Return exactly this Markdown shape:

```markdown
# Architecture Design Validation

Verdict: `PASS | BLOCKED`

Route: `<one blocked route>`

## Blocking Findings

- `<short issue title>`
  Location: `<frontmatter field, section, field, table row, diagram, or source>`
  Rule: `<violated rule>`
  Evidence: `<artifact text or repository evidence>`
  Minimal Repair: `<smallest evidence-backed repair>`

## Contract Readiness

`<one short paragraph>`
```

For `PASS`, omit `Route` and `Blocking Findings`.
