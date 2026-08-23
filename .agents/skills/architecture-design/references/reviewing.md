# Architecture Design Terminal Review Procedure

## 1. Review Scope And Target

Review-only is terminal whole-design audit only: it audits exactly one complete active
architecture design after full lint and emits only the validation artifact in Output
Contract. It never reviews a partial prefix or substitutes for a section checkpoint;
`checkpoint-reviewing.md` owns that work. It performs no writes, brainstorming,
subagent creation, or downstream contract work.

- Path supplied: review exactly that path.
- No path: infer only when exactly one relevant active design exists; otherwise request
  the path.
- Never infer a historical target.

## 2. Mechanical And Evidence Gates

Run full `python3 .agents/skills/architecture-design/scripts/design_lint.py <artifact>`
first, never `--checkpoint`. On failure, return only `INVALID_DESIGN_ARTIFACT` findings
and stop before semantic review. Do not duplicate lint with a prose parser.

On lint success, follow `design-rules.md` and read all four additional semantic rule
modules. That file and the modules collectively own the semantic rules. Independently
read the complete artifact, every declared `S`, every current durable owner and its
direct consumers, and the repository surfaces needed to verify every `E/R` claim.
Re-check locators, facts, repository decisions, exclusions, and mirror status. Do not
request or consume checkpoint verdicts, prior terminal verdicts, re-review diffs, or
admission records. The design's claims, copied inventories, and parity validators are
not authority.

## 3. Ordered Semantic Audit

Audit every applicable item in order and enforce whole-graph consistency throughout.
Complete the audit even after finding a blocker so output contains all independent
blocking obligations.

### 3.1 Disposition, Sources, And Accepted Norms

1. Confirm the disposition matches the actual state. For `BLOCKED`, require one
   correctly typed `B` per unresolved fact or decision.
2. Verify `S`, `E`, Source Coverage, and `R` against the source, evidence, authority,
   user-decision, and exclusion rules in `design-rules-basis-candidates.md`.
3. Reject omissions, stale evidence, hidden mirrors, duplicate norms, self-supporting
   mechanisms, and placeholder prose. Route missing or contradictory facts to
   `NEEDS_RESEARCH`, incompatible choices to `NEEDS_USER_DECISION`, and duplicate
   durable truth to `UNSAFE_SOURCE_OF_TRUTH`.

### 3.2 Candidate Reconstruction And Solution Proportionality

Run this audit independently in every review; a complete artifact or passing Gate
Closure row cannot substitute for it.

1. Derive constraints from independent `R/E`, not from the recorded `F/M/P` set.
2. Reconstruct viable alternatives and every material-obligation axis; do not trust the
   recorded set or assume one global minimum.
3. Test each form against accepted outcomes, mandatory constraints, repository
   authority, compatibility, boundaries, and applicable gates.
4. Reconstruct strict dominance and `P` treatment under
   `design-rules-basis-candidates.md`. Split mixed concerns into independently
   repairable obligations; group only those removed by the same viable alternative and
   repaired identically.

Use `DISPROPORTIONATE_SOLUTION` for strict dominance or an unsupported organizational
constraint removable without weakening accepted norms. Use `NEEDS_USER_DECISION` for
an unresolved incomparable material trade-off or an explicit exact-incidental-shape
conflict. Never manufacture a user decision to preserve unsupported complexity.

When `Minimal Repair` touches an authorized decision, state how it preserves that
decision and its open incidental shape. Report an already weakened or removed decision
as a separate blocker. Route a decision that itself requires forbidden exact
incidental shape to `NEEDS_USER_DECISION`; do not rewrite it.

### 3.3 Decisions, Closure, And Gates

1. Reconstruct the selected architecture and authority-to-contract trace from `D`, not
   from derived views. Verify ownership, concern closure, implementation freedom,
   `R/E/F/M` basis, contract targets, rationale, and dependency order.
2. Verify Architecture Closure in both directions and require concrete `R/E` for every
   non-applicable concern.
3. Audit every core gate, each conditional gate's applicability, and the complete
   conditional semantics required by `design-rules-decisions-gates.md`. Gate Closure is
   a view, not proof.

### 3.4 Impact Register

Audit top-level Impact Register before assurance. Confirm every durable transition is
one complete `I` with exact target, action, surface, requiring decisions, resulting
authority, and future contract requirement. Confirm every ADR transition agrees with
its `I` on target, action, durable surface, resulting authority, and future contract
requirement. Action-only agreement is insufficient.

### 3.5 Assurance And Direct Oracles

For each independent observable failure family, verify one canonical `A` under the
Assurance rules in `design-rules-decisions-gates.md`. Require exact coverage for every
outcome, assurance-required `D/<concern>`, and observable `I`, with each `A` in the
correct gate.

Reject proxy-only or infeasible evidence. A command, passing test, file, schema,
constructed object, event, count, registry, private-shape check, copied inventory, or
prose parser proves the claim only when that observation is itself the claimed outcome.

### 3.6 Stop Conditions, Diagrams, And Final Consistency

1. Audit top-level Stop Conditions after assurance. Confirm every ready design has a
   meaningful canonical `H` that identifies future evidence or conditions invalidating
   specified `D`, `A`, or `I` records and requiring architecture re-entry.
2. Confirm each `DG` is necessary, supports canonical records, and agrees with their
   ownership, boundary, order, state, failure, and observation semantics. Diagrams are
   explanatory only. Evidence-backed `None` is valid when no diagram is needed.
3. For `BLOCKED`, ensure only pre-blocker-valid work remains and Candidate Result lists
   every `B`. A partial matrix ends at the matching failed/unresolved gate, references
   every blocker there, and does not manufacture closure.
4. Reconcile frontmatter outcome/disposition, all canonical records, derived views,
   repository facts, diagrams, and the exact `Impacts`-to-`I` and `Stops`-to-`H`
   projections. Any contradiction blocks even when lint passes.

### 3.7 Contract Interface And Handoff Simulation

Confirm Contract Interface is a duplicate-free exact typed projection, never a second
prose owner. Profile/Obligations use canonical Change Contract vocabulary; ADR Impact
matches exact `I`; all `S/R/D/A/I/H` sets and concern-required targets are complete.
It contains no nested impact or stop records: `Impacts` projects top-level Impact
Register and `Stops` projects top-level Stop Conditions exactly.

Mentally author the next Change Contract from the interface and canonical records.
Confirm it can classify work, assign owner/scope/boundaries, preserve compatibility and
order, carry state/lifecycle/temporal/atomicity/recognition decisions, define direct
acceptance and evidence, derive one complete failure-family route per `A`, carry every
applicable work-budget and cost-displacement constraint, sequence durable transitions,
and identify stop conditions without inventing architecture. `CONTRACT` alone never
proves consumability. If any material choice remains, use `HANDOFF_NOT_CONSUMABLE`.

## 4. Blocked Routes

For `BLOCKED`, assign exactly one applicable route to each finding. Different findings
may use different routes:

- `INVALID_DESIGN_ARTIFACT` — deterministic form or unsupported value;
- `NEEDS_RESEARCH` — missing, stale, contradictory, or unverifiable fact;
- `NEEDS_USER_DECISION` — unresolved product or architecture choice;
- `CONTRADICTS_REPO` — selected form conflicts with a current owner;
- `WRONG_OWNER` — responsibility is assigned outside its owner;
- `UNSAFE_SOURCE_OF_TRUTH` — conflicting durable truth remains or is created;
- `UNSAFE_ORDER` — migration, publication, mutation, or retirement order is unsafe;
- `INSUFFICIENT_PROOF` — the oracle/evidence cannot detect the claimed outcome;
- `DISPROPORTIONATE_SOLUTION` — a strictly simpler viable form preserves accepted
  outcomes and mandatory constraints;
- `HANDOFF_NOT_CONSUMABLE` — downstream contract work must invent an architecture
  decision.

## 5. Output Contract

Verdicts are only `PASS` and `BLOCKED`; never `REVISE`. `PASS` means Change Contract
authoring can consume the design without a new architecture decision.

Return only the validation artifact. Do not list passed sections, optional
improvements, preferences, or non-blocking advice. `Blocking Findings` contains only
actual violations. Put any decision that `Minimal Repair` must preserve inside that
repair, not in a second protective finding.

Return exactly this Markdown shape:

```markdown
# Architecture Design Validation

Verdict: `PASS | BLOCKED`

## Blocking Findings

- `<short issue title>`
  Route: `<one blocked route>`
  Location: `<frontmatter field, section, field, table row, diagram, or source>`
  Rule: `<violated rule>`
  Evidence: `<artifact text or repository evidence>`
  Minimal Repair: `<smallest evidence-backed repair>`

## Contract Readiness

`<one short paragraph>`
```

For `PASS`, omit `Blocking Findings`.
