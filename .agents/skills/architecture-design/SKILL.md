---
name: architecture-design
description: Internal authoring step for creating or repairing one evidence-backed .design/YYYY-MM-DD-topic.md artifact before Change Contract authoring. Normally invoked by architecture-design-workflow. Use directly only when the user explicitly asks to draft or repair a design artifact without running the review loop. Selects a design form, records evidence, maps Decision Trace handoff, assesses diagrams, and edits no files outside .design/.
---

# Architecture Design

Turn product intent and repository evidence into one design artifact under
`.design/`. This is the authoring step for `architecture-design-workflow`, not
the review loop. Do not implement. Do not draft a Change Contract. Do not edit
any repository file outside `.design/` during the design phase.

## Workflow Position

```text
research-codebase -> architecture-design-workflow -> change-contract
architecture-design-workflow = architecture-design -> architecture-design-review loop
```

Use this skill when a design choice must be made before contract planning. For
normal design-mode requests, prefer `architecture-design-workflow` so the same
artifact is reviewed after every repair. Use `change-contract` only after the
design has a reviewable `.design/` artifact and the workflow's latest reviewer
has accepted it, or when the user explicitly bypasses the review loop.

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
- `DESIGN_NOT_REQUIRED`: the request is too small or already locked enough to go
  directly to `change-contract`; still create the `.design/` artifact and record
  why no design decision was needed.

`Decision Closure` means owner, boundary, source of truth, compatibility,
execution order, proof seam or fixture strategy, mandatory source-of-truth
updates, temporal/reentrancy behavior, all-or-nothing boundary, migration or
retirement strategy, and completion signal are settled before implementation.
Use `ARCHITECTURE_GATE` or `NEEDS_RESEARCH` when design cannot close those
decisions from current repository evidence and user input.

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

`Evidence Consequence Link`: every cited fact must state the architecture
decision, contract handoff, proof surface, or review consequence it supports.
Use exact evidence when the fact exists in stable repository text; name the
exception when a fact comes from a new file, generated output, or
command/config surface without stable lines.

For every architecture claim that affects the selected form, cite exact
`path:line` evidence unless it has one of those named exceptions. If a fact
cannot be proven, do not guess; use `NEEDS_RESEARCH` or `ARCHITECTURE_GATE`.

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

- **Owner-Level Fix**: fixes the owning cause, not only one downstream symptom
  or one-off call-site patch.
- **Ownership**: gives the behavior, policy, invariant, or state one clear owner.
- **Source-Of-Truth Singularity**: durable meaning has one owning source of
  truth and a real human or machine consumer. Duplicated truth is allowed only
  as explicit cache/performance duplication with an invariant and proof
  strategy.
- **Boundary-Owned Policy**: names entry and exit boundaries and keeps
  validation, normalization, compatibility, and policy decisions at the owning
  boundary.
- **Negative Proof And Fixture Quarantine**: negative, bypass, or structural
  proof uses a real production seam or future contract-named test seam, and
  fixture-only names, values, schemas, declarations, or data do not enter
  production source-of-truth files, public APIs, schemas, durable contracts,
  generated docs, or public surfaces.
- **Dependency direction**: follows repository layer/import direction.
- **State/data**: names committed, derived, cached, transient, and mutable state
  owners when relevant.
- **Sequenced Migration And Retirement**: for shared seams, names successor or
  retired seam, consumer order, replacement paths, retirement gate, migration
  checks, and `Negative Proof And Fixture Quarantine` strategy.
- **Temporal Surface Closure**: for call ordering, post-commit delivery,
  transaction, rollback, or no-op boundaries, observers, listeners, callbacks,
  guards, or public-state publication, names the temporal invariant, every
  synchronous callback surface in the window, the guard owner, the allowed public
  observation order, and the expected rejection/no-mutation signal for
  reentrant/interleaved mutation attempts.
- **All-Or-Nothing Failure Boundary**: when correctness relies on a change
  either fully taking effect or leaving prior state unchanged, names the
  irreversible point, places fallible work before it, and proves later work is
  infallible, failure-contained, or already part of the accepted result; also
  names the failure projection and proof surface.
- **Outcome-Proof Fit**: applies the shared `Claim -> Direct outcome -> Proxy
  risk -> Required proof` rule. For every selected-form claim about behavior,
  invariant, owner responsibility, source-of-truth update, migration, guardrail,
  or compatibility promise, names the direct owner-observable or external
  outcome, the proxy signals that would be insufficient, and the `Required proof`
  as a future proof surface or strategy that would expose the failure if the
  claimed outcome is false. A proxy is sufficient only when it is itself the
  claimed outcome or the claim is explicitly scoped to that proxy.
- **Verification**: can be proven by executable, structural, semantic, analyzer,
  or documentation checks appropriate to the profile.
- **Future pressure**: does not make an obvious near-future change harder without
  an explicit trade-off.

### Comparison Criteria

When materially different forms are possible, compare two to four candidates.
Use compact prose or a table. Do not use numeric scores unless the user asks.

Compare correctness, owner cohesion, minimal scope, maintainability,
discoverability, established repository patterns, reversibility, migration cost,
verification strength, compatibility impact, performance/sync/cache risk, and
observability of failure or drift.

Choose the simplest form that passes all hard gates and has the best future
change profile. If the choice depends on product preference rather than
repository evidence, use `ARCHITECTURE_GATE`.

## Future Pressure

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

## Decision Trace

Every artifact must include `Decision Trace` to keep `Decision Chain Of
Custody` into the future Change Contract. `Decision Chain Of Custody` is the
invariant that source inputs, research/design facts, and repository-derived
decisions must be preserved into the next stage's local fields, execution
units, or proof surfaces:

```text
repository evidence or research fact -> design decision -> contract handoff target
```

For `READY_FOR_CONTRACT`, use stable decision ids such as `D1`, `D2`, and `D3`.
Each row must name the decision, exact evidence, and the future Change
Contract target: the contract field, execution unit, or proof surface that must
carry it forward. For `NEEDS_RESEARCH`, `ARCHITECTURE_GATE`, or
`DESIGN_NOT_REQUIRED`, keep the section and record the blocker, user
decision, or reason no downstream mapping is required. Do not leave design
decisions only in prose when they constrain a future contract.

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
eventually be required, record that as future `SOURCE_OF_TRUTH_DOCS` scope for
the Change Contract; do not edit the diagram catalog or `.mmd` files during
design.

## Artifact Template

Before writing the `.design/` artifact, open
`assets/design-artifact-template.md` and use it as the artifact shape. The
template is passive output structure only; routing, gate semantics, profile
selection, obligations, and design-form rules are owned by this `SKILL.md`.

When a design has `Temporal Surface Closure` pressure, record the invariant,
synchronous callback surfaces, guard owner, public observation order, expected
rejection/no-mutation signal, and verification strategy in the selected form,
hard gate, lock-required facts, Decision Trace, verification impact, and handoff
sections. When a design relies on `All-Or-Nothing Failure Boundary`, also record
the irreversible point, fallible work before that point, the later
failure-containment rule, failure projection, and the proof strategy in those
same sections. Do not add ad hoc template sections.

## Completion Criteria

The design task is complete only when:

- this run created or updated exactly one `.design/YYYY-MM-DD-topic.md` artifact;
- no files outside `.design/` were edited by this design task; pre-existing
  unrelated changes are ignored and not reverted;
- `Completion Evidence Boundary` is preserved: design completion only means the
  design artifact is ready for its next local route, not that downstream
  contract or implementation work is complete;
- the artifact has exactly one disposition;
- every selected-form claim has evidence or is marked as a gate/research gap;
- materially different design forms were compared or the artifact explains why
  only one form is viable;
- every applicable hard gate is represented in the hard-gate table;
- for each selected-form claim, `Outcome-Proof Fit` records `Claim`, `Direct
  outcome`, `Proxy risk`, and `Required proof` as a proof surface or strategy,
  explicitly scopes the claim to the checked proxy, or records that the checked
  proxy is the claimed outcome;
- diagram need was assessed;
- `Decision Trace` maps locked decisions to future contract fields, execution
  units, or proof surfaces;
- research inputs or their explicit absence are recorded;
- future Change Contract handoff is present.
