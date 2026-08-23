# Architecture Design Handoff Rules

## 7. Impact Register, Assurance Register, Stop Conditions, And Contract Interface

### Dependency Order

For a ready design, canonical causality is one forward sequence: `D` -> top-level
Impact Register `I` -> Assurance Register `A` (including every exact `I` assurance) ->
top-level Stop Conditions `H` -> Contract Interface projection. Later stages consume
finished canonical records; they do not create or alter earlier-stage meaning.

### Impact Register

Impact Register is the sole canonical owner of every future durable documentation,
diagram, registry, contract, generated output, roadmap, schema, guardrail, ADR, source,
or other normative transition as one `I`.
`I.Action`, `I.Surface`, `I.Required by`, `I.Resulting authority`, and
`I.Contract requirement` together own the transition. `I.Surface` includes the exact
target identity; do not rely on an action verb alone.

For a ready selected form, every `D` that targets `durable_impact` is named by at least
one `I.Required by`; every decision named there targets `durable_impact`. An impact may
instead be required only by its owning `R`; that does not invent a `D` correspondence.
This correspondence preserves `I` as the sole owner of the durable transition.

### ADR Transitions

Every ADR transition must agree with its Impact Register `I` on target, action, durable surface,
resulting authority, and future contract requirement. Consult the current ADR owner;
create, supersede, or retire only when the design closes the durable decision. Do not
infer a lifecycle transition, silently replace retired rationale, or conflict with an
accepted ADR without explicit supersession. Every observable durable transition has
exact `A.Verifies=I-NNN` coverage.

### Assurance Ordering

Assurance Register is the sole canonical owner of `A`. Create `A` only after the complete
Impact Register: every observable `I` then has exact `A.Verifies=I-NNN` coverage.

### Stop Conditions

Stop Conditions are the sole canonical owner of `H`. Every ready design has at least
one meaningful `H` there; it defines future evidence or conditions that invalidate
specified canonical decisions, assurances, or impacts and require architecture
resolution. It prevents a future contract from redesigning around contradiction; it is
not a current blocker.

### Durable Authority

The active design and historical research do not remain durable owners after
implementation. Tests may consume but cannot own product, model, schema, architecture,
or documentation truth. No meaning-changing impact may be optional or left for later
rediscovery.

### Contract Interface

Contract Interface is a duplicate-free typed index. Read
`../../change-contract/references/contract-vocabulary.json` for its canonical Profile,
Obligations, and no-obligation token; do not copy those tokens into another owner. Use
the no-obligation token alone and never combine it with an obligation. Its Sources,
Requirements, Commitments, Assurance, Impacts, and Stops exactly project their
canonical sets before set equality:
`Impacts` projects only Impact Register `I` records and `Stops` projects only Stop
Conditions `H` records. It contains neither nested records nor duplicated `I`/`H`
bodies.
The Assurance projection preserves each `A` as a separate independently falsifiable
architecture failure family. The downstream contract maps each family to a complete
Decision Trace and evidence route without weakening its claim, failure, oracle, proxy
risk, evidence constraints, or architecture seam.

When an accepted `R` or `D` establishes a work bound or prohibits displacement of work
between lifecycle phases, Contract Interface Obligations includes
`WORK_BUDGET_CLOSURE`, and an `A` covers each independently observable budget failure.
The normal projections carry the owning and covering records. The token classifies
accepted meaning; it does not invent a work-budget requirement.
Its ADR Impact matches the exact applicable `I` transitions. Each `D.Contract targets`
contains every schema-required target for its concerns.

The interface preserves decisions; it does not make them. It must expose exact
classification, owner, scope, source of truth, compatibility, ordering, policy,
dependency, state/lifecycle, acceptance, evidence, verification, durable-impact, and
unit-family commitments required by the selected concerns. It contains no content
prohibited by `design-rules.md`.

## 9. Diagrams

Diagrams explain canonical decisions; they never own architecture. Add one or more
`DG` records only when prose cannot make a material design question clear enough. Each
`DG` names a schema-approved type, exact question, and canonical support references,
and owns exactly one non-empty fence in the schema-mapped language. Otherwise use the
exclusive evidence-backed `None` form. There is no document-wide one-`DG` limit.

Every diagram agrees with the supporting `D/A/I` records on ownership, boundaries,
sequence, state, failure/no-op behavior, effects, and public observation order. A later
durable diagram is future `SOURCE_OF_TRUTH_DOCS` contract scope, represented by `I`; do
not edit diagram catalogs or Mermaid owners during design.
