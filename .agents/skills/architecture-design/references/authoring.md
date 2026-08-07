# Architecture Design Authoring Procedure

## 1. Write Boundary

Create or update only one active design, from the template, at
`docs/planning/designs/YYYY-MM-DD-topic.md`. Before review, require the artifact
to be a direct child of `docs/planning/designs/`; directory membership is its
active registration.

Do not write or repair planning-map membership, research artifacts,
superpowers output, a Change Contract, an implementation plan, or any other
repository file.

## 2. Evidence And Entry Classification

Read explicit source inputs and targeted repository evidence. Evidence
collection is targeted read-only inspection, not an implicit
`$research-codebase` run or permission to create a research artifact.

- If a missing fact prevents viable comparison, record `NEEDS_RESEARCH` and
  the exact research questions in the active design; skip brainstorming.
- If evidence proves that no architecture choice exists, record
  `DESIGN_NOT_REQUIRED`; skip brainstorming.
- Otherwise continue to Candidate Development.

## 3. Candidate Development

Invoke `$superpowers:brainstorming` only when an architecture choice remains.
Ask one question at a time. For decision-bearing work, compare two or three
material options. For each option, expose its material-obligation deltas
against the other viable options and identify strict dominance when present.
Obtain approval only for the material axes and deltas actually presented.

Brainstorming must not create `docs/superpowers` or other superpowers output,
a commit, or an implementation plan inside this workflow.

## 4. Active Design Preparation

Create or update the active design after entry classification and any required
brainstorming. Before review:

1. In both `Source Inputs: Other` and `Decision Trace`, normalize every
   explicit user decision on a material axis. State its exact mandatory
   obligation and the incidental identifiers, cardinality, and decomposition
   that remain open.
2. If a decision mandates exact incidental shape, preserve it without
   normalization and enter `NEEDS_USER_DECISION` under `design-rules.md`.
3. Do not substitute a topic label or generic conversation reference. Do not
   give the reviewer the chat.
4. Run `design_lint.py` and repair all form findings.

## 5. Review, Admission, And Repair Cycle

Every validation, including every re-review, uses a new clean review-only
subagent with `fork_turns: none` and only the applicable exact prompt below. A
reviewer handles exactly one validation request and is never reused, regardless
of verdict.

For the initial review, substitute only the absolute path:

```text
Use $architecture-design in review-only mode:
/absolute/path/to/docs/planning/designs/YYYY-MM-DD-topic.md
```

Treat every finding as a hypothesis, not a repair instruction. Before any edit,
independently verify its evidence, applicability to the changed surface, and
repair authority. Reject unsupported or inapplicable findings; use
`NEEDS_RESEARCH` when applicability or prerequisites are uncertain; use
`NEEDS_USER_DECISION` when the smallest valid resolution changes an approved
decision or materially expands approved scope. An applicable pre-existing
problem is a prerequisite, not automatic repair scope.

Before editing, create this admission record for every reviewer finding. When a
finding or proposed repair mixes obligations that require different
dispositions, create one record for each disposition-bearing group:

```text
Finding: <independently repairable obligation>
Rule: <violated rule>
Evidence: <supporting artifact or repository evidence>
Recorded user decision affected: <Decision ID and exact constraint, or none>
Does Minimal Repair change that decision: <no, or yes with the exact change>
Disposition: <ADMIT | REJECT | NEEDS_RESEARCH | NEEDS_USER_DECISION>
```

If a finding or its proposed repair bundles obligations with different
dispositions, preserve the reviewer's wording and split those obligations before
disposition; do not silently narrow the proposal or use a partial or hybrid
disposition. Keep obligations with the same evidence, repair, and disposition
grouped as required by the review procedure.

Reject a group whose repair changes a recorded user decision, but separately
admit any supported violation with the smallest repair that preserves that
decision. Do not reject a supported finding because its proposed repair is
overbroad. A reviewer verdict, proposed `Minimal Repair`, or later `PASS` is not
repair authority. If current repository authority contradicts the recorded
decision, repair neither side; use `NEEDS_USER_DECISION`.

Explicit review-and-repair begins with the same complete audit as review-only
and requires the artifact to be a direct child of `docs/planning/designs/`
before that audit or any edit. Apply the semantic rules in `design-rules.md`,
repair only admitted in-scope findings, and apply all such repairs as one batch.

After each admission-and-repair cycle, retire the reviewer. For every re-review,
spawn another new clean review-only subagent with `fork_turns: none` and pass
this complete prompt. Never use the preceding or any earlier reviewer:

```text
Use $architecture-design in review-only mode and re-read the full current design:
/absolute/path/to/docs/planning/designs/YYYY-MM-DD-topic.md
Design diff since the preceding validation: <exact diff or none>
Finding admission records from the preceding validation:
<each required field and evidence-backed disposition>
Run the complete audit again; withdraw any earlier finding that no longer applies.
```

Repeat the complete audit, admission, batch repair, reviewer retirement, and
fresh re-review without a numeric limit. Repetition of a finding is not a stop
condition.

Stop only on a fresh `PASS`, confirmed `NEEDS_RESEARCH`, or confirmed
`NEEDS_USER_DECISION`.

## 6. Terminal State

Map a fresh `PASS` to stored `READY_FOR_CONTRACT` or
`DESIGN_NOT_REQUIRED`; map a confirmed `NEEDS_RESEARCH` blocker to stored
`NEEDS_RESEARCH`; and map a confirmed `NEEDS_USER_DECISION` blocker to stored
`ARCHITECTURE_GATE`. Never store `NEEDS_USER_DECISION` in frontmatter.

After a confirmed `NEEDS_RESEARCH` terminal, report the exact research
questions recorded in the active design. After a confirmed
`NEEDS_USER_DECISION` / `ARCHITECTURE_GATE` terminal, report the exact user
decision required.
