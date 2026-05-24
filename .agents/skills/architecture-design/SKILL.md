---
name: architecture-design
description: Use before change-contract when a feature, fix, refactor, migration, source-of-truth documentation change, analyzer rule, public API change, or shared-seam change needs an evidence-backed design artifact in .design/ that selects an architecture form, explains alternatives, maps diagrams, and prepares an evidence-backed handoff for a future Change Contract without editing any repository file outside .design/.
---

# Architecture Design

Turn product intent and repository evidence into one design artifact under
`.design/`. Do not implement. Do not draft a Change Contract. Do not edit
any repository file outside `.design/` during the design phase.

## Workflow Position

```text
research-codebase -> architecture-design -> architecture-design-review -> change-contract
```

Use this skill when a design choice must be made before contract planning. Use
`change-contract` only after the design has a reviewable `.design/` artifact.

## Design Artifact Rule

The only file this skill may create or edit is:

```text
.design/YYYY-MM-DD-topic.md
```

Rules:

- Create `.design/` when needed.
- Derive `topic` from the user request in short kebab-case.
- Do not write to `PLAN.md`, `plan/`, `docs/`, source files, tests, registries,
  diagrams, or `.research/`.
- Do not use `.research/` for decisions. Research files are factual inputs only.
- If the design cannot be locked, still save a `.design/` artifact with the
  blocking disposition and exact next questions.

## Disposition

Every artifact must contain exactly one disposition:

- `READY_FOR_CONTRACT`: the design is locked enough for Change Contract authoring.
- `ARCHITECTURE_GATE`: a user/product decision is required.
- `NEEDS_RESEARCH`: repository facts are missing or contradicted.
- `DESIGN_NOT_REQUIRED`: the request is too small or already locked enough to
  go directly to `change-contract`; still create the `.design/` artifact and
  record why no design decision was needed.

## Target Contract Classification

Select the future Change Contract profile using the same priority order as the
contract workflow:

1. `ANALYZER_RULE`: analyzer, guardrail, rule engine, structural recognition, or
   fixtures.
2. `SOURCE_OF_TRUTH_DOCS`: normative docs, contracts, diagrams, registries,
   guardrails, indexes, or roadmap contracts, with no production implementation.
3. `REFACTOR`: ownership, placement, naming, decomposition, or dependency shape
   changes while observable behavior is preserved.
4. `BEHAVIOR_CHANGE`: production/runtime/API/data/user-visible behavior changes.

List future obligations in this stable order when applicable:

- `BUG_FIX`
- `SEAM_MIGRATION`
- `PUBLIC_API_CHANGE`

Obligations are not profiles. They add proof and sequencing pressure to the
selected profile.

## Evidence Policy

Use only confirmed facts from the request and inspected repository artifacts.
Prefer linked `.research/` notes for existing-state facts, then inspect the
owning docs, code, tests, plans, and local rules needed to confirm the design.
Research inputs must be truthful: if no `.research/` artifact was provided or
found, write that none was used and rely on direct repository evidence. If the
selected form cannot be proven without additional research, use
`NEEDS_RESEARCH`.

For every architecture claim that affects the selected form, cite exact
`path:line` evidence. If a fact cannot be proven, do not guess; use
`NEEDS_RESEARCH` or `ARCHITECTURE_GATE`.

## Design Form Selection

A design form is the selected architectural shape, not the contract profile.
Common forms include:

- extending an existing owner;
- moving responsibility to the correct owner;
- creating, replacing, or retiring a seam;
- adding boundary validation;
- adding a read-only port;
- separating or consolidating state ownership;
- replacing duplicate sources of truth with one owner;
- adding analyzer, guardrail, or structural enforcement;
- updating source-of-truth documentation later through a Change Contract.

### Hard Gates

Reject any candidate form that fails one of these gates:

- **Root cause**: fixes the owning cause, not only one downstream symptom.
- **Ownership**: gives the behavior, policy, invariant, or state one clear owner.
- **Source of truth**: avoids duplicate truth; any cache/performance duplication
  has an invariant and proof strategy.
- **Boundary**: names entry and exit boundaries and keeps validation at the
  boundary.
- **Dependency direction**: follows repository layer/import direction.
- **State/data**: names committed, derived, cached, transient, and mutable state
  owners when relevant.
- **Seam**: for shared seams, names successor or retired seam, consumer order,
  retirement gate, and negative proof strategy.
- **Temporal/reentrancy**: for call ordering, post-commit delivery,
  transaction, rollback, or no-op boundaries, observers, listeners, callbacks,
  guards, or public-state publication, names the temporal invariant, every
  synchronous callback surface in the window, the guard owner, the allowed
  public observation order, and the verification strategy for
  reentrant/interleaved mutation attempts.
- **Verification**: can be proven by executable, structural, semantic, analyzer,
  or documentation checks appropriate to the profile.
- **Future pressure**: does not make an obvious near-future change harder without
  an explicit trade-off.

### Comparison Criteria

When materially different forms are possible, compare two to four candidates.
Use compact prose or a table. Do not use numeric scores unless the user asks.

Compare:

- correctness and root-cause fit;
- cohesion with existing owner and nearby rules;
- minimal scope;
- maintainability and discoverability;
- reuse of established repository patterns;
- reversibility and migration cost;
- verification strength;
- compatibility impact;
- performance and sync/cache risk;
- observability of failures and drift.

Choose the simplest form that passes all hard gates and has the best future
change profile. If the choice depends on product preference rather than
repository evidence, use `ARCHITECTURE_GATE`.

### Future Pressure

Before selecting a form, name known future pressures from the user request,
`PLAN.md`, existing plan steps, docs, `.research/`, code comments, tests, or
repository rules. For each pressure, state:

- source evidence;
- why it could stress the design later;
- whether the selected form absorbs, defers, or rejects it;
- the future cost or migration risk accepted by the design.

If future pressure is unknown after targeted inspection, say so explicitly
rather than claiming the form is future-proof. If likely future pressure exists
but cannot be assessed from current evidence, use `NEEDS_RESEARCH` or
`ARCHITECTURE_GATE` instead of treating it as a passed gate.

## Diagram Need Assessment

Diagrams in `.design/` are provisional. They explain the design choice; they are
not durable `docs/diagrams/*.mmd` deliverables.

Include a diagram only when it answers a design question that prose cannot make
clear enough:

- ownership, layer, package, or component boundary changes -> `c4`;
- data flow, state ownership, cache, resource, or lifecycle movement ->
  `data_flow`;
- call ordering, lifecycle ordering, sync/async interaction, failure path, or
  migration order -> `sequence`;
- observer/listener/callback delivery, guard windows, public-state publication,
  or reentrancy-sensitive ordering -> `sequence`;
- modes, statuses, terminal states, sessions, or transition rules -> `state`;
- analyzer or guardrail pipeline -> `data_flow` or `sequence` only if a
  multi-stage recognition path is part of the design.

Every artifact must include `Diagram Need Assessment`, even when no diagram is
needed. The assessment must check the fixed trigger matrix from the artifact
template; do not replace it with a single informal "none" row. For each proposed
diagram, state the architectural question it answers. If a durable diagram will
eventually be required, record that as future
`SOURCE_OF_TRUTH_DOCS` scope for the Change Contract; do not edit the diagram
catalog or `.mmd` files during design.

## Artifact Template

Before writing the `.design/` artifact, open
`assets/design-artifact-template.md` and use it as the artifact shape. The
template is passive output structure only; routing, gate semantics, profile
selection, obligations, and design-form rules are owned by this `SKILL.md`.

When a design has temporal/reentrancy pressure, record the invariant,
synchronous callback surfaces, guard owner, public observation order, and
verification strategy in the existing selected form, hard gate, lock-required
facts, verification impact, and handoff sections. Do not add ad hoc template
sections.

## Completion Criteria

The design task is complete only when:

- this run created or updated exactly one `.design/YYYY-MM-DD-topic.md`
  artifact;
- no files outside `.design/` were edited by this design task; pre-existing
  unrelated changes are ignored and not reverted;
- the artifact has a disposition;
- every selected-form claim has evidence or is marked as a gate/research gap;
- materially different design forms were compared or the artifact explains why
  only one form is viable;
- diagram need was assessed;
- research inputs or their explicit absence are recorded, and future Change
  Contract handoff is present.
