# Architecture Design Rules

## 1. Purpose And Dispositions

Produce one self-contained design aligned with the accepted product outcome that closes
every material architecture choice needed by a future Change Contract, preserves the
exact blocker, or proves that design is unnecessary.

Use exactly one schema disposition:

- `READY_FOR_CONTRACT`: lock every applicable choice for owner/owning layer,
  scope/boundary, policy placement, source of truth, public API/compatibility, order,
  acceptance oracle, evidence constraints, architecture-required verification seam,
  state/data ownership, temporal behavior, all-or-nothing failure, bounded recognition,
  migration/retirement, and source-of-truth impact. Only local tactics inside those
  locks remain open. Two competent Change Contract authors must derive the same
  architecture.
- `ARCHITECTURE_GATE`: an unresolved product, user, or architecture choice.
- `NEEDS_RESEARCH`: a missing, stale, contradictory, or unverifiable fact.
- `DESIGN_NOT_REQUIRED`: repository evidence proves that none of the
  `READY_FOR_CONTRACT` choices, including public-API and state/data choices, remains
  unresolved.

`ARCHITECTURE_GATE` and `NEEDS_RESEARCH` prohibit Change Contract authoring and preserve
the exact missing choice or fact. A material lock left to the contract author is not
ready. Vagueness blocks only when owner, state, boundary, transition, source, oracle,
evidence constraint, or verification method remains indeterminate. The product outcome,
disposition, source inputs, evidence, selected form, locks, gates, proof, trace,
impacts, verification, handoff, diagrams, open decisions, and repository facts must
agree. Any contradiction blocks regardless of apparent completeness.

## 2. Global Artifact Boundary

Architecture design establishes readiness, not implementation completion.

Never include execution units, Gherkin, implementation status, completed checkboxes,
future step-file paths, proof IDs, test commands, commands as outcomes, private-shape
locks except the authorized organization axis below, or post-implementation claims.
Field names such as handoff, proof, or completion create no exception. Do not require or
accept completed units, passing verification, commits as behavior proof, reviewer
approval, roadmap closure, or other future implementation evidence. Confirmed repository
evidence used for architecture selection remains valid.

An explicit user decision about implementation organization is a material obligation
when organization is the approved axis and incidental identifiers, cardinality, and
decomposition remain open. It may require table-driven scenarios with shared mechanics
or prohibit independent paths from deciding the same semantic result; it may not require
exactly one helper, model, function, table, or class, and it is never an acceptance
oracle.

If the user mandates exact incidental shape, do not normalize or delete it. Preserve the
requirement, record its conflict with this rule, and use `ARCHITECTURE_GATE` /
`NEEDS_USER_DECISION` unless redesign of that exact axis is authorized.

## 3. Source Inputs, Authority, And Evidence

Read every source named by the request or active artifact, including prior design,
research, plan, and other declared repository surfaces. Record each used input in
`Source Inputs`; write `none` only when that kind was not used. Preserve accepted
upstream decisions by meaning unless redesign is authorized. Research is factual input,
never future source of truth.

For every explicit user decision, both `Source Inputs: Other` and `Decision Trace` state
by meaning what is mandatory and which incidental identifiers, cardinality, and
decomposition remain open. If exact incidental shape is mandated, both preserve it and
record the `NEEDS_USER_DECISION` conflict. Generic labels, topic summaries, and
unavailable chat references are insufficient; the design must be self-contained.

Historical, resolved, deferred, and genuinely out-of-scope mentions are not blockers.
Put each intentional exclusion in `Out of Scope`, map it through `Decision Trace`, and
support it with repository evidence or explicit user authority. Do not silently omit or
narrow a named source or accepted upstream decision.

Use only confirmed repository facts and explicit user decisions. Record evidence exactly
as:

```text
- `path/to/file.ext:line` / surface: observed fact -> design consequence.
```

Each row supports a candidate, selected form, boundary lock,
source-of-truth/compatibility/order decision, acceptance oracle, evidence constraint,
blocker, or handoff target. Stable text facts require exact `path:line`. Path-only
evidence is allowed only for a new file, generated output without stable lines, or a
command/configuration surface whose lines are meaningless; name the exception. Raw
search output, long quotations, research logs, and private reasoning transcripts are not
evidence.

If a required fact is unavailable, contradicted, stale, or unverifiable, do not infer
it: record the exact research question and use `NEEDS_RESEARCH`.

### Future-Pressure Input

Before selection, inspect the request, active plan and plan files, documentation,
historical research, code comments, tests, repository rules, and read-only source-query
output. Record each pressure's evidence and why it stresses the design; if none is
found, say so and do not claim future-proofing. A pressure that is not already an
accepted outcome or mandatory constraint cannot justify a present obligation; it may
only break a tie between forms that pass Solution Proportionality.

## 4. Applicability And Gate Registry

Use the `Hard Gate Check` structure and exact gate names from
`design-artifact-schema.json`.

`READY_FOR_CONTRACT` and `DESIGN_NOT_REQUIRED` include every core gate once and every
triggered conditional gate; omit only non-applicable conditional gates, and pass every
included row with evidence. A blocking disposition includes only gates evaluated before
the blocker plus the failed or unresolved applicable gate with its exact blocker. Do not
manufacture unassessed rows.

### Core Gates

- `Owner-Level Fix`: correct the owning cause, not a caller-level symptom.
- `Ownership`: behavior, policy, invariant, state, and durable meaning have one clear
  owner.
- `Source-Of-Truth Singularity`: durable meaning has one owner; cache/performance
  duplication requires a locked invariant, consumer, and evidence constraints.
- `Source-Truth Minimality`: no second durable signal merely certifies an already-owned
  value.
- `Boundary-Owned Policy`: validation, normalization, compatibility, redaction, and
  policy remain at the owning entry/exit boundary.
- `Dependency Direction`: preserve repository layer and import direction.
- `Outcome-Proof Fit`: every claim names its concrete failure, directly observable
  oracle, proxy risk, and evidence constraints.
- `Verification`: require directly observable outcomes and any seam that is itself
  architectural.
- `Future Pressure`: record each known pressure as absorbed, deferred, or rejected with
  accepted cost or migration risk.

`Source-Truth Minimality` forbids a second field, registry, allowlist, identity marker,
policy seam, token heuristic, proof-surface name, test name, comment, or duplicated
constant whose only purpose is certification. Negative proof may reject invalid shape,
stale mirrors, boundary violations, incoherent data, unauthorized consumers, or
source-of-truth drift; it may not reject a different coherent source-of-truth value
unless a named owner supplies a closed vocabulary or immutable allowlist.

Fixture-only identifiers, values, schemas, nodes, APIs, generated documentation, or
contracts must not enter production source-of-truth or public surfaces. Tests may
consume source truth but cannot own it; copied inventories and manual mirrors cannot
become authority. Private-shape inspection and prose parsing are not behavioral proof.

### Conditional Gates

For every triggered gate, record its complete closure in the Hard Gate row and owning
boundary lock(s); map its observable claim in Outcome-Proof Fit, cover it in
Verification Strategy, trace its material decisions, and preserve them in the handoff. A
bare gate-name reference is insufficient; a missing required field or oracle blocks
`READY_FOR_CONTRACT`.

#### `Negative Proof And Fixture Quarantine`

**WHEN:** A negative, bypass, or structural guarantee is claimed.

**REQUIRE:** Exact invalid state; owning production boundary; directly observable
oracle; evidence constraints; fixture-quarantine rule.

#### `State/Data Ownership`

**WHEN:** Committed, derived, cached, transient, or mutable state is affected.

**REQUIRE:** Relevant owner and lifecycle.

#### `Sequenced Migration And Retirement`

**WHEN:** A seam is replaced, migrated, or retired.

**REQUIRE:** Replacement; consumer order; retirement gate; migration checks; negative
proof.

#### `Temporal Surface Closure`

**WHEN:** Callbacks, listeners, observers, delivery, transactions, rollback, no-op
publication, or guard windows are involved.

**REQUIRE:** Temporal invariant; synchronous callback surfaces; guard owner; public
observation order; permitted reentrant/interleaved action; rejection or no-mutation
signal.

#### `All-Or-Nothing Failure Boundary`

**WHEN:** Correctness requires full effect or no mutation.

**REQUIRE:** Irreversible point; fallible work before it; permitted later work; failure
projection; directly observable oracle; evidence constraints.

#### `Bounded Recognition Scope`

**WHEN:** Only for analyzer, guardrail, schema-validator, structured-scanner,
generated-output, import-scan, or fixture-recognition architecture.

**REQUIRE:** Exact invalid state; target artifact; bounded recognizer surface; stop
rule.

**REJECT:** Open-ended recognition, arbitrary syntax coverage, arbitrary JSONPath, token
heuristics, a general analyzer for behavioral inconvenience, or a feature-local general
scanner that a stable central boundary should own.

## 5. Design Form Candidates

A design form is an architecture shape, not a Change Contract profile or execution plan.
It may extend an existing owner; move responsibility to its owner; create, replace,
split, consolidate, or retire a seam; add boundary validation or a port; separate or
consolidate state; remove duplicate durable truth; add bounded structural enforcement;
or schedule a later source-of-truth-documentation update.

Compare two or three materially different viable candidates. Use one only when
repository evidence proves every material alternative violates a hard constraint.

If a missing fact prevents comparison, use `NEEDS_RESEARCH` and these exact terminal
forms in `Design Form Candidates` and `Selected Form`:

```text
Not compared: <exact factual blocker>
Not selected: <exact factual blocker>
```

`DESIGN_NOT_REQUIRED` instead requires evidence that no architecture form needs
selection and never uses those forms. A product-preference choice without a recorded
user decision requires `ARCHITECTURE_GATE`.

Do not patch a caller-level symptom when a shared owner, invariant, seam, source of
truth, or boundary owns the cause. Do not add certainty metadata around an already-owned
decision; consumers read the owner directly unless a distinct durable concept has its
own owner, lifecycle, consumer, and validation rules.

## 6. Candidate Evaluation And Selection

Evaluate in order:

1. Reject hard-gate failures.
2. Compare viable forms by owner fit, hard constraints, migration cost, evidence
   strength, source-of-truth safety, compatibility, drift risk, and Solution
   Proportionality.
3. Use the evidence-backed future-change profile and Future Pressure only as
   tie-breakers when neither form is strictly simpler.
4. Select the surviving form or record the exact blocker.

### Solution Proportionality

Treat `Solution Proportionality` as a mandatory semantic gate, not a mechanically linted
`Hard Gate Check` row.

Accepted outcomes and mandatory constraints come only from explicit source inputs,
repository rules/invariants, verified evidence, and explicit user decisions that
independently predate or constrain the selected form. Mandatory constraints include
applicable correctness, security, compatibility, ownership, boundary, and
source-of-truth requirements. A candidate cannot authorize its own complexity by
restating its mechanism as an outcome, decision, Future Pressure, or downstream
source-of-truth update. An implementation artifact is downstream evidence, not
independent authority.

A **material obligation** adds observable behavior; state/lifecycle; coordination/order;
an owner, seam, or abstraction; compatibility, migration, or retirement; a verification
seam or failure family; or a durable artifact.

A viable alternative preserves every accepted outcome and mandatory constraint. It is
**strictly simpler** only when it removes at least one material obligation without
adding another or weakening an accepted outcome or mandatory constraint. Line count,
declaration count, and preference alone do not establish simplicity.

For every obligation unique to the selected form, require either independent authority
for that exact material axis or a concrete evidence-backed failure that violates an
accepted outcome/constraint, is prevented by the obligation, and is not also prevented
by a simpler repair.

Broad source intent does not require a particular mechanism. Precedent, implementation
convenience, ease of testing, speculative flexibility, and specification completeness
are insufficient by themselves.

- A strictly simpler viable alternative blocks with `DISPROPORTIONATE_SOLUTION`.
- An unsupported organizational preference removable without weakening accepted
  outcomes/constraints also blocks with `DISPROPORTIONATE_SOLUTION`; remove it rather
  than manufacture `NEEDS_USER_DECISION`.
- Incomparable material trade-offs between viable forms require `ARCHITECTURE_GATE` and
  the unresolved user or architecture decision; do not manufacture a verdict from
  reviewer preference. Reserve `NEEDS_USER_DECISION` for the required user choice and
  the exact-shape conflict in the Global Artifact Boundary.

There need not be one globally least-complex form. User approval covers only compared
material axes and deltas. A later material obligation requires a new decision unless
already forced by an accepted outcome or mandatory constraint. A mandatory constraint
may justify an in-scope obligation or block the design, but cannot expand approved
scope. Record whether each inspected Future Pressure is absorbed, deferred, or rejected
and its accepted cost or migration risk.

## 7. Selected-Form Closure And Boundary Locks

For `READY_FOR_CONTRACT`, `Boundary Locks For Change Contract` contains a non-empty lock
for `Owner`, `In Scope`, `Out of Scope`, `Source of Truth`, `Compatibility`, `Order
Constraints`, `Temporal Surface Closure`, `All-Or-Nothing Failure Boundary`, `Negative
Proof And Fixture Quarantine`, and `Bounded Recognition Scope`.

Use `Not applicable: <specific reason>` for a non-applicable lock; generic absence or
non-applicability is invalid.

Locks must agree with evidence, selected form, gates, Decision Trace, and handoff.
Behavior, policy, invariant, state, and durable meaning have one owner. The owning
entry/exit boundary owns validation, normalization, compatibility, redaction, and
policy. Cache/performance duplication requires its invariant, consumer, and evidence
constraints locked.

Copy each applicable conditional gate's full closure into the same-named lock or the
relevant owner, scope, source-of-truth, compatibility, or order lock. A summary or gate
reference is insufficient.

When applicable, the temporal lock names the invariant, synchronous callback surfaces,
guard owner, public observation order, permitted reentrant/interleaved action, and
rejection/no-mutation signal; the all-or-nothing lock names the irreversible point,
fallible-before work, permitted later work, failure projection, directly observable
oracle, and evidence constraints.

## 8. Outcome-Proof Fit

Map every selected-form claim as:

```text
Claim -> Concrete failure mode -> Acceptance oracle -> Proxy risk -> Evidence
constraints
```

The oracle is directly observable. Evidence constraints name admissible evidence
classes, coverage boundaries, and proxy risks without choosing non-architectural test
implementation. Name a verification seam only when it is an architecture decision.

Reject proxy-only proof unless the proxy is the claimed outcome. A command, passing
test, existing file/schema, constructed object, fired event, changed issue count,
registry entry, or successful compilation proves only that observation, not a broader
claim.

Do not lock private identifiers, helper calls, selectors, fixture implementation,
regular expressions, AST visitor shape, test layout, copied inventories, or prose
parsing as an oracle unless the mechanism is architectural. Prove an authorized
organization constraint without inspecting incidental identifiers, cardinality, or
private decomposition; authorization does not turn private shape into an oracle.

## 9. Diagram Decision

Diagrams are provisional explanations, not durable deliverables. Add a `Diagram
Requirements` row only when prose cannot make a design question clear enough; name the
schema-approved type, question, and reason. Otherwise use one exclusive `none` row.

A selected diagram must agree with ownership, boundaries, sequence, state, failure/no-op
behavior, effects, and public observation order. A later durable diagram is future
`SOURCE_OF_TRUTH_DOCS` Change Contract scope. Do not edit diagram catalogs or Mermaid
files during design.

## 10. Source-Of-Truth And ADR Impact

`Source-Of-Truth Impact` names every future durable documentation, diagram, registry,
contract, generated output, roadmap, schema, guardrail, or other normative surface that
a later Change Contract must update. No meaning-changing update may be optional,
conditional, or left for rediscovery. The active design and historical research do not
remain durable owners after implementation. Tests may consume but cannot own product,
model, schema, architecture, or documentation truth.

`ADR Impact` has exactly one schema-approved value: `none`, `create`, `supersede
ADR-NNNN[, ADR-NNNN...]`, or `retire ADR-NNNN[, ADR-NNNN...]`. Consult
`architecture/decisions/README.md`. Create, supersede, or retire only when the design
closes the durable decision; supersede/retire name exact IDs. Do not infer a later
lifecycle transition, silently replace a retired rationale, or conflict with an accepted
ADR without explicitly designed supersession.

Read `.agents/skills/change-contract/references/contract-vocabulary.json` completely.
Select `Profile` from `profiles` and material `Obligations` from `obligations`. Use
`no_obligation` alone only when no material obligation applies; never combine it with
another token.

## 11. Verification Strategy

For every claim and applicable gate, preserve its directly observable oracle, admissible
evidence classes, coverage boundary, proxy risks, and any architecture-required seam.
Cover applicable behavior, source-of-truth updates, seam migration, public
compatibility, bounded recognition and bypass risk, temporal behavior, all-or-nothing
failure, fixture quarantine, and documentation consistency.

Commands are not outcomes. A command checklist, generic success statement, source
existence, private-shape inspection, prose parsing, or copied inventory cannot replace
an observable oracle. Do not claim future implementation or verification evidence
already exists.

## 12. Decision Trace

Preserve:

```text
source input or repository fact -> design decision -> future contract handoff target
```

`READY_FOR_CONTRACT` uses stable IDs such as `D1`. Every material decision names exact
evidence and its exact handoff location: classification, boundary field, ordering rule,
acceptance oracle, evidence constraint, verification gate, or future unit family. No
locked decision may exist only in prose.

For each explicit user decision, restate the mandatory material axis and open incidental
shape; preserve exact incidental shape and its conflict when applicable. Map every
intentional `Out of Scope` exclusion to evidence or user authority. Blocking and
`DESIGN_NOT_REQUIRED` designs instead map the blocker, required user decision, or reason
no downstream mapping is required.

## 13. Open Decisions

For `READY_FOR_CONTRACT`, `Open Decisions` is `None`. For a blocking disposition, every
item states the needed decision, why it blocks, and required evidence or user choice;
factual blockers state exact research questions. Never guess a user or architecture
choice.

## 14. Change Contract Handoff

For `READY_FOR_CONTRACT`, the handoff lets `change-contract` proceed without
rediscovering architecture. It names the required profile/obligations, source inputs,
boundary locks, Decision Trace IDs/targets, acceptance oracles/evidence constraints,
applicable conditional-gate closures, source-of-truth/ADR impact, forbidden drift, and
exact missing conditions that become a Contract Blocker.

The handoff preserves decisions; it does not make them. It must agree with all earlier
sections and leave no owner, boundary, source of truth, compatibility posture, order,
verification seam, recognition scope, source-of-truth update, temporal rule, atomicity
rule, migration rule, or blocker condition to invent.

Do not include execution units, Gherkin, implementation status, completed checkboxes,
final gates, proof identifiers, future step-file paths, test commands as outcomes,
post-implementation claims, or Change Contract text.

## 15. Final Consistency Check

Before returning, confirm:

- The accepted product outcome agrees with the disposition, source inputs, evidence,
  selected form, locks, gates, proof, trace, impacts, verification, handoff, diagrams,
  open decisions, and repository facts.
- Exactly one evidence-supported disposition is present.
- Every named source and accepted upstream decision is preserved or explicitly
  authorized out of scope.
- Every applicable gate is included and closed.
- The selected form passes hard gates and proportionality.
- Every material decision appears in a lock and Decision Trace.
- Every claim has a concrete failure, direct oracle, proxy risk, and evidence
  constraints.
- Impacts, diagrams, verification, and handoff agree.
- `READY_FOR_CONTRACT` has `Open Decisions: None`.
- The handoff introduces no decision.
- No execution or completion content appears.
- Any contradiction blocks.
