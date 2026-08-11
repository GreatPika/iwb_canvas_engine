# Change Contract Authoring

Use this procedure for `create-or-update` and, after its complete audit, for
`review-and-repair`. Apply `contract-rules.md` at every gate.

## Closed authoring sequence

1. Read every explicit source and repository instruction route. Reconstruct
   `Source Inputs` from those sources rather than trusting an inherited table;
   represent each source once using its category, stable ID, and location or
   authority.
2. Before forming units, confirm that the sources permit authoring and
   reconstruct a private source-decision ledger. For every design input,
   reconstruct its `Outcome-Proof Fit` rows before relying on the design's
   summary or handoff. Derive each independently falsifiable failure family
   from the source decisions and fit rows, then reserve one
   decision/family/outcome/evidence route for it. Run the source-conflict gate
   and stop on an incompatible or missing material decision or family.
3. Select exactly one profile and all material obligations. Select
   `WORK_BUDGET_CLOSURE` whenever the reconstructed families constrain scans,
   copies, rebuilds, materialization, publication, allocation, amortized work,
   or cost displacement. Write a one-paragraph
   `Goal` that describes only the final intended repository state after all
   units, never planning, linting, reviewing, or intermediate work.
4. Stabilize boundaries and publish the obligation ledger as Decision Trace.
   For `WORK_BUDGET_CLOSURE`, close every applicable construction/import/reset,
   mutation/update/replay, freeze/publication/install, query/read, and
   cleanup/rollback phase with its bound, allowed full pass, and forbidden cost
   transfer. Verify every named owner, package, path, document, registry,
   schema, generated output, public API, and consumer exists now or is
   explicitly a future artifact.
5. Build independently committable units, combining all sides of an atomic
   public-seam migration when separation would not compile. Assign semantic
   outcome keys and complete every direct Matrix mapping.
6. Before lint or review, write one concrete false-positive implementation or
   state and its direct kill signal for every Matrix row. Simulate the declared
   evidence against that wrong implementation: if it can stay green, strengthen
   the owner-level evidence or restore the omitted source-derived family; do not
   defer the gap to implementation. Add one complete admission per independent
   new permanent failure family and only cross-unit and repository closure to
   the Verification Gate.
7. Render from the template, lint, and complete the semantic self-audit in
   `contract-rules.md`. Source/conflict closure precedes units; unit closure
   precedes outcomes, evidence, admissions, and gate; lint and review closure
   are terminal gates, not substitutes for earlier ones.
8. Complete the fresh-review closure below. Repair only evidence-backed
   findings; every edit returns to lint and invalidates the review verdict.

Run path-based mechanical lint from the repository root:

```bash
python3 .agents/skills/change-contract/scripts/contract_lint.py <contract-file>
```

## Fresh review closure

Dispatch one fresh `contract_reviewer` agent. It must not receive an intended
verdict, suspected defect, repair history, or prior conclusion. Use this prompt
only, replacing `PLAN_FILE` with the absolute active-plan path:

```text
Review active plan at PLAN_FILE using $change-contract in review-only mode.
Report only findings that make the contract non-implementable.
A request for a permanent verification artifact is invalid unless the
contract's required admission is missing or incorrect.
```

When a specific `docs/planning/designs/...` design is a contract input, add
`against design DESIGN_FILE` after `PLAN_FILE` in the first line. Do not add
this suffix unless that artifact is a source input. Do not add any other
context, explanations, links, source lists, comments, or instructions to this
prompt.

Terminate after the reviewer returns `PASS`. Any later contract edit invalidates
that verdict and requires lint plus one new fresh review.

## Review-and-repair boundary

Begin with a complete review-only audit. Repair only the smallest
evidence-backed change that closes each finding, and only in the supplied active
contract. If a finding needs missing product, architecture, API, error-taxonomy,
verification, or other authority, make no edit at all: preserve the artifact
byte-for-byte and return `BLOCKED` with the applicable finding route. Do not
turn missing authority into a Contract Blocker, a preferred repair, or an
invented decision.

## Contract Blocker output

On an authoring source conflict or missing material decision, do not store a
partial active contract. Return exactly the five sections in
`contract-rules.md`: `Goal`, `Source Inputs`, `Blocking Decisions`, and
`Repository Evidence` under `# Contract Blocker`. `Blocking Decisions` is one
table with the exact columns `Decision ID`, `Blocking decision`, `Blocks
because`, and `Needed evidence or authority`. Each independent unresolved
decision occupies one unique keyed row. The blocker contains no provisional
boundary, unit, outcome, Matrix row, verification gate, preferred repair, or
implementation choice; its final-state Goal does not choose an answer.
