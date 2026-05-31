---
name: architecture-design-review
description: Review a .design/ architecture design artifact before Change Contract authoring. Use when checking whether the selected design form, evidence, alternatives, future-pressure analysis, diagram assessment, source-of-truth impact, decision traceability, and contract handoff are strong enough to proceed. Return a chat verdict only; do not edit files.
---

# Architecture Design Review

Review the design decision, not implementation and not a full Change Contract.
Return findings in chat only. Do not edit the `.design/` artifact or any other
repository file.

Use `change-contract-check` instead when a full Change Contract already exists.

## Inputs

Review one `.design/YYYY-MM-DD-topic.md` artifact. If the user did not provide a
path, ask for the design artifact path.

Inspect:

- the design artifact;
- cited `.research/` inputs when present;
- repository evidence cited by the design;
- nearby source-of-truth docs, code, tests, plans, diagrams, and local rules
  needed to verify claims;
- the paired `architecture-design` skill when available, for expected artifact
  shape and design responsibilities;
- the paired `architecture-design/assets/design-artifact-template.md` template
  when available.

The paired authoring skill owns routing, gate semantics, profile selection,
obligations, and design-form rules. The paired template owns artifact shape
only.

Do not require or invent a future step contract path. Linking a future
`plan/step_N_*.md` back to `.design/` belongs to the later contract workflow,
not this review.

## Verdicts

Return exactly one verdict:

- `PASS`: the design can be converted into a Change Contract without requiring
  the contract author to make a new architecture decision about owner, source of
  truth, boundary, proof seam, fixture strategy, migration order, compatibility
  posture, temporal/reentrancy behavior, all-or-nothing boundary, or durable
  documentation impact.
- `REVISE`: the design direction is sound, but the artifact needs non-blocking
  repair before contract authoring.
- `BLOCKED`: do not write a Change Contract yet.

For `BLOCKED`, include exactly one primary route:

- `NEEDS_RESEARCH`
- `NEEDS_USER_DECISION`
- `CONTRADICTS_REPO`
- `WRONG_OWNER`
- `INSUFFICIENT_VERIFICATION`
- `INVALID_DESIGN_ARTIFACT`

Use `BLOCKED` when the artifact would force contract authoring to make a core
architecture, proof, sequencing, or source-of-truth decision.

## Substance And Executability Standard

Do not treat template compliance, populated hard-gate rows, or cited evidence as
sufficient for `PASS`.

A `READY_FOR_CONTRACT` design is passable only when the future Change Contract
can be authored as execution planning, not architecture discovery. Review the
selected form as an implementable system change:

- Can the chosen owner actually accept the responsibility without creating a
  second source of truth?
- Can the proposed verification be built using existing test/tool seams, or does
  the artifact name the small seam that must be introduced?
- Can negative proof be written without polluting production source-of-truth
  files, public API, schemas, durable docs, or real registries with fixture-only
  data?
- Are required source-of-truth updates mandatory when the selected form changes
  what a registry, contract, guardrail, or diagram means?
- Would two competent implementers produce the same architecture from this
  artifact, even if their code organization differs?
- Does `Decision Trace` preserve every locked design decision into a contract
  field, execution unit, or proof surface?

## What Not To Review

Do not require:

- Change Contract template compliance;
- vertical slices;
- proof IDs;
- final gates;
- exact implementation file inventories;
- future step file paths, commit hashes, or completed unit evidence.

Those belong to `change-contract`, `change-contract-check`, and `unit-by-unit`.
Do require design-level `Decision Trace` rows that map locked decisions to
future contract fields, execution units, or proof surfaces; that is part of the
design-to-contract handoff, not implementation metadata.

## Blocking Checks

Mark the review `BLOCKED` when any of these are true:

1. The artifact is not under `.design/` or does not follow
   `.design/YYYY-MM-DD-topic.md`.
2. The artifact includes lifecycle status metadata or treats status as a
   required document state.
3. The design phase edited or requires editing files outside `.design/`.
4. The disposition is missing, unsupported, or inconsistent with the content.
5. The artifact omits required sections from the paired template, keeps template
   placeholders as final content, or changes fixed hard-gate or
   diagram-assessment rows in a way that prevents review.
6. Research inputs are false, decorative, or point to nonexistent files without
   saying no research artifact was used.
7. A selected-form claim lacks exact repository evidence and is not marked as
   `NEEDS_RESEARCH` or `ARCHITECTURE_GATE`.
8. The artifact uses `READY_FOR_CONTRACT` while any hard gate is failed,
   missing, unsupported by evidence, or marked as needing more research or a
   user/product decision.
9. The artifact uses `NEEDS_RESEARCH` or `ARCHITECTURE_GATE`; the artifact may
   be useful, but it is not contract-ready.
10. The artifact uses `DESIGN_NOT_REQUIRED` while repository evidence shows a
    real unresolved owner, boundary, state, seam, verification, public API, or
    source-of-truth decision.
11. The artifact uses `DESIGN_NOT_REQUIRED` without an evidence-backed
    explanation that no unresolved owner, boundary, state/data, seam,
    verification, public API, source-of-truth, or materially different
    design-form decision exists, and without a `Decision Trace` entry explaining
    why no downstream mapping is required.
12. The target profile is missing, unsupported, or inconsistent with the owner,
    change type, and required proof mode.
13. Required obligations are missing, or listed obligations are unsupported by
    the request and repository evidence.
14. `Decision Trace` is missing, keeps template placeholders, omits a locked
    decision, cites only broad files when exact `path:line` evidence is
    available, or fails to map a decision to a future contract boundary,
    execution unit, or proof surface.
15. Owner, owning layer, seam, boundary, dependency direction, state/data
    ownership, or verification strategy is unresolved.
16. The selected form patches a downstream call site when the weakness belongs
    to a shared owner, invariant, contract, or boundary.
17. The selected form puts validation, normalization, policy, or compatibility
    handling away from the owning boundary without explicit evidence and
    trade-off.
18. The selected form violates repository dependency/import direction, layer
    ownership, or documented source-of-truth ownership.
19. The design creates a second source of truth without an invariant and proof
    strategy.
20. A shared-seam change lacks successor or retired seam, consumer order,
    retirement gate, or negative proof strategy.
21. A public API change lacks compatibility, migration, or contract-owner
    reasoning.
22. A bug-fix design lacks root-cause owner and reproducer strategy.
23. A refactor design lacks behavior-preservation or characterization strategy.
24. An analyzer or guardrail design lacks positive and negative recognition
    forms or bypass/false-positive risk reasoning.
25. Future pressure is likely from cited evidence but the artifact does not
    assess it or route to `NEEDS_RESEARCH` / `ARCHITECTURE_GATE`.
26. The selected form ignores a known future pressure in a way that will
    predictably force duplicate state, sync glue, public API churn, broad
    migration, or source-of-truth drift.
27. Diagram assessment omits a required trigger from the fixed matrix or misses
    a diagram needed to understand ownership, state flow, sequence, seam,
    public API, or analyzer pipeline decisions.
28. A provisional diagram contradicts, reorders, omits, or overstates an
    architecture-relevant fact about ownership, boundaries, ordering, effects,
    rollback/no-op behavior, or public observation.
29. Repository docs, durable diagrams, registries, or contracts disagree with
    each other on an architecture-relevant fact. Mark `BLOCKED` with
    `CONTRADICTS_REPO` unless the artifact explicitly routes the contradiction
    to source-of-truth repair before Change Contract authoring.
30. The artifact treats provisional `.design/` diagrams as durable
    `docs/diagrams/*.mmd` deliverables.
31. A durable docs, diagram, registry, contract, or roadmap impact is implied by
    the selected form but missing from `Source-Of-Truth Impact`.
32. A required test, analyzer, guardrail, docs check, semantic search, or other
    proof surface is implied by the selected profile or obligations but missing
    from `Verification Impact` or `Verification Strategy`.
33. The Change Contract handoff contains or requires slices, proof IDs, final
    gates, or contract text.
34. The recommended form is one of multiple materially different viable options,
    but the choice depends on product preference and no user decision is routed.
35. Materially different candidate forms were possible, but the artifact neither
    compares them nor explains why only one form is viable.
36. A materially better form is visible from repository evidence because it has a
    stronger owner fit, lower future migration cost, clearer verification, or
    less source-of-truth risk, and the artifact does not reject it with evidence.
37. The selected form introduces or changes call ordering, post-commit delivery,
    observer/listener/callback invocation, transaction, rollback, no-op
    boundaries, public-state publication, or runtime mutation guards, but does
    not name the temporal invariant, every synchronous callback surface in that
    window, the guard owner, the allowed public observation order, and a
    verification strategy for reentrant/interleaved mutation attempts.
38. The selected form relies on all-or-nothing behavior, but does not identify
    the irreversible point, what fallible work must happen before it, what later
    work is infallible, failure-contained, or already accepted, and how that
    boundary will be proven.
39. The artifact is formally complete but leaves the future Change Contract to
    decide how the selected form can be implemented or proven at the owning
    seam.
40. The verification strategy requires a negative fixture, bypass proof, or
    structural proof but does not identify a feasible proof mechanism using
    existing repository seams, or explicitly name the small seam that must be
    introduced.
41. The proof strategy would require fixture-only data to be added to a real
    production source of truth, public API registry, schema, durable contract, or
    public surface.
42. A selected form changes the normative meaning of a registry, contract,
    guardrail, generated index, or diagram, but the source-of-truth update is
    optional, conditional, or left for the contract author to rediscover.
43. The handoff contains correct decisions but is not operational enough to
    write a Change Contract without re-reading broad repository context to infer
    proof seams, source-of-truth updates, or sequencing constraints.

## Non-Blocking Weaknesses

Use `REVISE` when the design can proceed after small artifact repair, for
example:

- valid evidence is thin but sufficient;
- one candidate comparison is terse but the rejected form is still clear;
- a diagram reason is weak but the diagram does not mislead;
- a provisional diagram has a minor wording issue only when the intended owner,
  boundary, ordering, rollback/no-op behavior, effects, and public observation
  semantics remain unambiguous;
- future pressure was checked but could be worded more concretely;
- source-of-truth impact and verification impact are slightly mixed but the
  future contract handoff remains usable;
- the handoff is missing minor evidence that is already present elsewhere in the
  artifact.

## Review Procedure

1. Read the full `.design/` artifact before judging it.
2. Read the paired authoring skill and artifact template when available.
3. Re-open cited `.research/` inputs and repository evidence. Do not trust
   citations at face value.
4. Check that the artifact follows the paired template and records truthful
   research inputs or explicit absence of research inputs.
5. Verify every hard gate row from the authoring skill: root cause, ownership,
   source of truth, boundary, dependency direction, state/data, seam,
   temporal/reentrancy, all-or-nothing behavior, verification, and future
   pressure. A `READY_FOR_CONTRACT` artifact must pass every applicable gate
   with evidence.
6. Check `Decision Trace`. Every material selected-form decision must have a
   stable decision id, exact evidence, and a future Change Contract handoff
   target. Do not require exact future unit numbers unless the artifact already
   names them.
7. Reconstruct viable alternatives from the artifact and evidence. If a
   materially better form is visible, mark the review `BLOCKED`.
8. Before accepting `READY_FOR_CONTRACT`, mentally simulate authoring the next
   Change Contract. Do not require actual slices, proof IDs, final gates, or an
   exact file inventory, but confirm that the artifact gives enough locked facts
   to derive them mechanically.
9. Check the diagram need assessment against the fixed trigger matrix and audit
   every provisional diagram semantically.
10. For designs with ordering, delivery, observer/listener/callback surfaces,
    public-state publication, transactions, rollback/no-op paths, or mutation
    guards, reconstruct the full synchronous execution window.
11. For designs that rely on all-or-nothing behavior, reconstruct the failure
    domains around the irreversible point.
12. Confirm source-of-truth and verification impacts match the selected form,
    profile, and obligations.
13. Confirm the handoff contains only facts needed by a future Change Contract:
    profile, obligations, Decision Trace rows, evidence, proof surfaces, and
    sequencing constraints.
14. Return the verdict and findings. Do not repair the artifact in this review
    workflow. If the user asks for repair, return the review verdict first and
    handle edits only in a separate authoring workflow.

## Output Format

If there are findings:

```markdown
Verdict: PASS | REVISE | BLOCKED
Route: required only for BLOCKED

Findings

- [blocking|non-blocking] Location: rule violated. Evidence. Minimal repair.

Contract Readiness

Plain-language statement of what can or cannot happen next.
```

If there are no findings:

```markdown
Verdict: PASS

Findings

No findings.

Contract Readiness

The design can be converted into a Change Contract without new architecture
decision-making.
```

## Self-Check

Before returning, confirm:

- Did you avoid editing files?
- Did you review the `.design/` artifact rather than a future contract?
- Did you check the paired template shape when available?
- Did you re-check cited evidence?
- Did you read diagrams as architecture claims, not decoration?
- Could a future Change Contract be written from this artifact as planning work,
  without making a new architecture decision?
- Did every material selected-form decision have a Decision Trace row with
  evidence and a future contract handoff target?
- Did you verify that every required proof is practically constructible in this
  repository?
- Did you check that negative fixtures do not contaminate real source-of-truth
  surfaces?
- Did you distinguish "evidence exists" from "the selected form is executable"?
- Did you avoid requiring slices, proof IDs, final gates, future step paths, or
  implementation commits?
- Did the verdict match the strongest finding?
