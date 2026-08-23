# Architecture Design Authoring Procedure

## 1. Write Boundary

Create or update only one active `architecture-design/v4` artifact, from
`assets/design-artifact-template.md`, at
`docs/planning/designs/YYYY-MM-DD-topic.md`. Before review, require the artifact to be
a direct child of `docs/planning/designs/`; directory membership is its active
registration.

Do not write or repair planning-map membership, research artifacts, superpowers output,
a Change Contract, implementation plan, implementation, product truth, ADR, or any
other repository file.

## 2. Evidence And Entry Classification

Read every explicit source input and targeted repository evidence required by the
source, evidence, requirement, and authority rules in
`design-rules-basis-candidates.md`. Evidence collection is read-only inspection, not
an implicit `$research-codebase` run or permission to create a research artifact.

Build the canonical basis in dependency order: `S` -> `E` -> `R`, then complete Source
Coverage from the final `S` set. Apply the source, evidence, authority, user-decision,
and open-shape rules from `design-rules-basis-candidates.md`.

Classify before brainstorming:

- Missing, stale, contradictory, or unverifiable facts that prevent viable comparison:
  prepare `BLOCKED` with an exact `B.Kind=research`; skip brainstorming.
- Evidence that no new architecture choice exists: prepare `DESIGN_NOT_REQUIRED` with
  existing `R/E` closure; skip brainstorming.
- A remaining material architecture choice: continue to Candidate Development.

## 3. Candidate Development

Invoke `$superpowers:brainstorming` only when classification leaves a material
architecture choice. Ask one question at a time and develop the complete candidate
comparison required by `design-rules-basis-candidates.md`, including `F`, `M`,
applicable `P`, strict dominance, and incomparable trade-offs.

Obtain approval only for the material axes and deltas actually presented. Brainstorming
must not create `docs/superpowers` or other superpowers output, a commit, a Change
Contract, or an implementation plan inside this workflow.

## 4. Sequential Authoring And Checkpoint Cycle

Prepare only sections allowed by the selected disposition, in template order. Do not
replace that sequence with vertical `D`/`I`/`A`/`H` packages.

Before authoring each section, load any newly triggered rule module through
`design-rules.md`. Keep previously loaded modules for the rest of the authoring run.

### Checkpoint Invalidation

A `CHECKPOINT_PASS` seals the section and allows authoring to continue, but it does not
prove that the whole design is ready. If a sealed section or its inputs change, discard
that pass and every affected later pass, then restart checkpoint review from that
section with a fresh reviewer. Keep earlier unaffected passes. Fixing the current
section before it passes does not restart the reviewer session.

### Per-Section Cycle

For each next allowed section, use this complete cycle before starting another section:

1. Author only that section from already sealed earlier records. Do not use a later
   section to create, repair, or redefine earlier meaning.
2. Run `python3 .agents/skills/architecture-design/scripts/design_lint.py --checkpoint
   "<exact section>" <artifact>`. Repair every mechanical finding in the current
   unsealed prefix, then repeat the command. If a finding requires changing an earlier
   sealed section, make the minimum supported repair and apply the checkpoint
   invalidation rule above.
3. Only after clean checkpoint lint, submit that checkpoint. For the first checkpoint
   in a clean sequence, dispatch one fresh reviewer with `fork_turns: none`, using the
   initial prompt contract below. After a preceding `CHECKPOINT_PASS`, send the next
   checkpoint to the same reviewer with `followup_task` and the continuation contract.
   The reviewer handles exactly one section per turn.
4. On `CHECKPOINT_PASS — <exact section>`, seal that section. The reviewer returns the
   result and becomes idle for `followup_task`; author the next schema-allowed section
   and repeat this cycle.
5. Any checkpoint finding ends the reviewer session.
   - Reproduce mechanical findings through step 2 and independently verify semantic
     findings.
   - Repair only reproduced mechanical findings and supported semantic findings.
   - Choose the earliest changed section or supported `Revalidate from` section.
     Discard any existing pass for that section and every affected later pass, rerun
     checkpoint lint, then start a fresh reviewer there.
   - If no finding is confirmed and no content changes, retry only the same unsealed
     section with a fresh reviewer.

Repeat without a numeric limit until every affected section again returns
`CHECKPOINT_PASS — <exact section>`.

### Reviewer Prompts

Use this initial prompt contract, substituting every bracketed value:

```text
Use $architecture-design in checkpoint review mode.
Artifact: <absolute path>
Checkpoint section: <exact section>
Declared sources and current repository authority: <complete verification context>
Review exactly this section against the full current prefix.
This starts a sequential checkpoint reviewer session.
After CHECKPOINT_PASS, return the result and remain available for `followup_task`.
```

After a pass, use this continuation prompt with `followup_task`:

```text
Continue the same checkpoint reviewer session.
Checkpoint section: <exact next section>
No previously reviewed sealed content, declared sources, recorded user decision, or
current repository authority has changed.
Review exactly this section against the extended current prefix.
After CHECKPOINT_PASS, return the result and remain available for `followup_task`.
```

### Session Recovery

If a reviewer session is lost, unavailable, or no longer has demonstrably complete
context, start a new clean reviewer with `fork_turns: none` at the next due checkpoint.
Tell it the last unaffected sealed section and require it to read the full current
prefix once, return a verdict only for the due section, and continue without repeating
unaffected checkpoint verdicts.

### Terminal Handoff

After every applicable section passes:

1. Run full `scripts/design_lint.py <artifact>`.
2. Load `design-rules-final-consistency.md` and apply its complete Final Consistency
   Check.
3. Retire the checkpoint reviewer; it must not serve as the terminal reviewer.
4. Start a fresh independent terminal whole-design review in `reviewing.md`.

If full lint or the Final Consistency Check requires a repair, apply Checkpoint
Invalidation and restart Terminal Handoff after every affected section passes again.

Terminal review re-reads all declared sources and current owners. Checkpoint results
are not evidence and do not reduce that audit.

## 5. Terminal Review, Admission, And Repair Cycle

### Terminal Reviewer

Each terminal cycle uses one fresh review-only subagent with `fork_turns: none`. Give it
exactly this prompt, substituting only the absolute path. It performs one complete audit
and is retired regardless of verdict. Never reuse an earlier reviewer or pass prior
findings, verdicts, diffs, or admission records.

```text
Use $architecture-design in terminal review-only mode:
/absolute/path/to/docs/planning/designs/YYYY-MM-DD-topic.md
```

### Finding Admission

Before admitting findings, load every additional semantic rule module through
`design-rules.md`.

Treat every finding as a hypothesis, not a repair instruction. Before editing,
independently verify its evidence, applicability to the changed surface, and repair
authority. Reject unsupported or inapplicable findings. Use `NEEDS_RESEARCH` when
applicability or prerequisites are uncertain. Use `NEEDS_USER_DECISION` when the
smallest valid resolution changes an approved decision or materially expands approved
scope. An applicable pre-existing problem is a prerequisite, not automatic repair
scope.

Create this admission record for every finding before any edit. Split obligations that
require different `Admission` values:

```text
Finding: <independently repairable obligation>
Rule: <violated rule>
Evidence: <supporting artifact or repository evidence>
Recorded user decision affected: <R ID and exact constraint, or none>
Does Minimal Repair change that decision: <no, or yes with the exact change>
Admission: <ADMIT | REJECT | NEEDS_RESEARCH | NEEDS_USER_DECISION>
```

Preserve the reviewer's wording when splitting mixed obligations. Never silently narrow
a proposal or collapse different routes. Group only matching evidence, repair, and
`Admission`.

When deciding admission:

- Reject a proposed repair that changes a recorded user decision.
- Still admit a supported violation when its smallest repair preserves that decision.
- Do not reject a supported finding merely because its proposed repair is overbroad.
- Do not treat a reviewer verdict, proposed `Minimal Repair`, or later `PASS` as repair
  authority.
- If current repository authority contradicts a recorded decision, repair neither
  side; use `NEEDS_USER_DECISION`.

### Repair And Re-Review

Review-and-repair begins with the same complete terminal audit as review-only. Before
the audit or any edit, require the artifact to be a direct child of
`docs/planning/designs/`. Apply all admitted in-scope minimum repairs as one batch. If a
repair changes a passed section, declared sources, a recorded user decision, or current
repository authority, apply the checkpoint invalidation rule in Section 4. Run full
lint before terminal re-review.

Repeat this cycle without a numeric limit. Stop only on a fresh `PASS` or a terminal
state below.

## 6. Terminal State

- A fresh `PASS` confirms the artifact's stored `READY_FOR_CONTRACT` or
  `DESIGN_NOT_REQUIRED` disposition.
- After all `ADMIT` findings are repaired and all `REJECT` findings are discarded, if
  one or more unresolved findings remain and each uses `NEEDS_RESEARCH` or
  `NEEDS_USER_DECISION`, store `BLOCKED`. Create one `B` per independent reason:
  `research` for the former and `user_decision` for the latter. Both may coexist.
  Candidate Result lists every `B`; frontmatter never stores review routes.

If a confirmed terminal result changes the stored disposition, the author must update
the artifact to record that disposition and repair every affected section. Complete a
new checkpoint reviewer session from the earliest affected section, run full
`scripts/design_lint.py <artifact>`, and obtain a matching fresh terminal review-only
result on that latest content before reporting the terminal state.

For `BLOCKED`, report every research question and user decision in its `B` records.
