# Architecture Design Core Rules And Loading

Always read this file completely. It owns the core semantic rules and the loading route
for additional rule modules. Read each required module completely when its trigger
first applies, then keep it loaded for the rest of the current authoring or reviewer
session.

## Additional Rule Modules

| Module | Semantic concern |
| --- | --- |
| `design-rules-basis-candidates.md` | Sources, evidence, requirements, authority, candidate comparison, and proportionality. |
| `design-rules-decisions-gates.md` | Decision closure, implementation freedom, gates, assurance, and conditional semantics. |
| `design-rules-handoff.md` | Impacts, assurance ordering, stop conditions, Contract Interface, and diagrams. |
| `design-rules-final-consistency.md` | Whole-artifact semantic reconciliation before a terminal result. |

## Create Or Update

1. Start with `design-rules-basis-candidates.md`.
2. Before authoring the first Decision Register or Readiness Matrix, add
   `design-rules-decisions-gates.md`.
3. Before authoring the first Impact Register, Assurance Register, Stop Conditions,
   Contract Interface, or Diagrams section, add `design-rules-decisions-gates.md` and
   `design-rules-handoff.md`, skipping any module already loaded.
4. Open Blockers adds no module. Keep the modules already required by the actual
   preceding sections.
5. After clean full lint and before the Final Consistency Check, add
   `design-rules-final-consistency.md`.

## Checkpoint Review

Scan every section actually present in the completed prefix and load its cumulative
triggers:

- Basis or Candidate Analysis: add `design-rules-basis-candidates.md`.
- Decision Register or Readiness Matrix: add `design-rules-basis-candidates.md` and
  `design-rules-decisions-gates.md`.
- Impact Register, Assurance Register, Stop Conditions, Contract Interface, or
  Diagrams: add `design-rules-basis-candidates.md`,
  `design-rules-decisions-gates.md`, and `design-rules-handoff.md`.
- Open Blockers: add `design-rules-basis-candidates.md`, then add only the further
  modules triggered by preceding sections that are actually present.

A continuing sequential reviewer keeps its loaded modules. A replacement reviewer
loads the cumulative set for the current actual prefix; it does not infer omitted
optional sections.

## Terminal Review And Repair

After clean full lint and before terminal semantic review, review-and-repair, or
terminal re-review, read all four additional rule modules completely.

## 1. Purpose, Authority, And Dispositions

Produce one self-contained architecture decision graph for future Change Contract
authoring. The artifact closes every material architecture choice needed downstream,
preserves the exact blocker set, or demonstrates that no new design choice exists. It is
readiness evidence, never implementation or completion evidence.

`design-artifact-schema.json` solely owns the exact `architecture-design/v4` grammar,
shape, profiles, field vocabulary, reference types, cardinality, ordering, mappings,
projections, and deterministic closure declarations. `design_lint.py` is only their
mechanical verifier; it does not co-own their definition. This file and the additional
semantic rule modules collectively own sufficiency and truth. Lint success is required
but cannot prove that evidence is true, an architecture is proportional, an oracle is
direct, or a handoff is consumable.

Use exactly one schema disposition:

- `READY_FOR_CONTRACT`: every applicable architecture concern and gate is closed; only
  local implementation tactics inside the recorded locks remain open. Two competent
  Change Contract authors can derive the same architecture without inventing a choice.
- `BLOCKED`: at least one required fact or material choice remains unresolved. Each
  independently resolvable reason is a separate `B.Kind=research` or
  `B.Kind=user_decision`; both kinds may coexist.
- `DESIGN_NOT_REQUIRED`: evidence shows the current architecture already closes the
  outcome and no new owner, boundary, public contract, state, lifecycle, temporal,
  atomicity, recognition, verification-seam, migration, or durable-authority choice is
  required.

`BLOCKED` prohibits Change Contract authoring. A material decision left to
the contract author is not ready. Vagueness blocks only when a material owner, state,
boundary, transition, source, oracle, evidence constraint, or verification method
remains indeterminate.

## 2. Artifact Boundary And Canonical Ownership

### Canonical Records

The canonical records own meaning once:

| Record | Sole semantic responsibility |
| --- | --- |
| `S` | Input identity, kind, locator or authority, and intended use. |
| `E` | One observed fact and its exact location inside one `S`. |
| `R` | One accepted outcome, constraint, user decision, repository rule, or exclusion, including any intentionally open shape. |
| `F` | One viable architecture form and its principal trade-off. |
| `M` | One material obligation axis across the compared forms. |
| `P` | One known future pressure, its treatment, closure, and accepted cost or risk. |
| `D` | Selected architecture, locked concerns, implementation freedom, basis, dependency, realization, rationale, and contract targets. |
| `I` | Impact Register alone owns one durable authority transition and its complete future contract requirement. |
| `A` | Assurance Register alone owns one independently observable claim/failure/oracle boundary and its exact `R`, `D/<concern>`, or `I` subject. |
| `H` | Stop Conditions alone own one future condition that invalidates accepted design and requires architecture re-entry. |
| `B` | One current blocking fact or choice and its resolution requirement. |
| `DG` | One explanatory diagram and the canonical records it supports. |

### Derived Projections

Source Coverage, Architecture Closure, Gate Closure, and Contract Interface are
non-owning typed projections of canonical records. `CONTRACT` is a synthetic Gate
Closure reference only; it owns no architecture meaning and cannot establish handoff
consumability. `design-rules-handoff.md` owns the exact Contract Interface projection
rules.

### Single Semantic Ownership

Do not paraphrase the same norm in multiple canonical records. A common mandatory
comparison obligation uses its owning `R` as the `M` obligation instead of restating
it. Role-specific causal statements are allowed—for example, an `E` may state an
observed fact and a `D.Rationale` may explain how that fact affects selection—but they
must not create another editable norm. A duplicate or contradictory owner blocks.

### Artifact Grammar Boundary

Never put architecture in free prose, unknown headings, diagrams, projection views, or
field suffixes. Every non-empty artifact line must belong to the schema-owned grammar.
Bare placeholders, template markers, empty values, and generic `none`/`n/a` prose
cannot manufacture readiness or a blocker.

### Forbidden Content

Never include execution units, Gherkin, implementation status, completed checkboxes,
future step-file paths, proof IDs, test commands as outcomes, private-shape locks except
an explicitly authorized organization axis, Change Contract prose, or
post-implementation claims. Do not require completed units, passing verification,
commits as behavior proof, reviewer approval, roadmap closure, or other future
implementation evidence.

## 8. Blocked Disposition And Partial Closure

A current blocker is a canonical `B`, not placeholder prose. It states the blocker
kind, affected gate, exact fact or decision needed, why comparison or closure cannot
continue, required resolution, and related records.

`B.Kind=research` contains exact answerable questions. `B.Kind=user_decision` states an
unresolved choice without guessing its answer. `BLOCKED` may contain either or both;
Candidate Result lists every `B`.

The blocking profile contains only analysis valid before the blockers. A partial
Readiness Matrix ends at one failed or unresolved gate and references every `B` at that
gate. Omit it when nothing was safely evaluable. Never manufacture closure.

`DESIGN_NOT_REQUIRED` has no current blocker and proves existing closure with current
`R/E` authority. It cannot be used merely because implementation looks small.
