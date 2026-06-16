---
name: lead-unit-by-unit
description: "Use when implementing an accepted Change Contract or plan step through a lead-managed unit workflow: keep one active gpt-5.5 medium worker per execution unit for all unit work and fixes, review every pass with fresh reviewer subagents, route reviewer findings through the lead for owner-level fix guidance, commit each approved unit, then run full-range final reviews plus a naming-cohesion-review pass."
---

# Lead Unit By Unit

Use this skill when the user wants a Change Contract or plan step implemented
unit by unit with you acting as lead instead of implementing every unit
directly.

As lead, own sequencing, architectural judgment, review-finding interpretation,
verification integrity, and commits. Workers own bounded implementation.
Reviewers own independent findings. Do not turn reviewer feedback into
mechanical patch requests when the right fix belongs in a shared invariant,
boundary, source of truth, or owning module.

`Single Active Unit Worker Rule` means each execution unit has one active worker
at a time for initial implementation, review fixes, verification repairs, and
any later final-review fixes attributable to that unit. Do not run parallel
workers for the same unit.

`Worker Recovery Rule` means the lead handles worker loss without asking the
user for an operational decision. First try to resume the same worker when the
tool supports it. If the worker is deleted or unrecoverable, spawn one
`worker` recovery subagent with `model: gpt-5.5` and `reasoning_effort:
medium`, pass the step contract, unit number, current working-tree state,
changed file list, verification status, reviewer findings, and exact remaining
task. The recovery worker becomes the only active worker for that unit.

`Fresh Reviewer Rule` means every review pass uses a newly spawned reviewer:
initial unit review, unit follow-up review, final committed-range review,
final follow-up review, and naming-cohesion review. Do not reuse a reviewer
after any implementation or fix changes.

## Workflow

1. Establish the implementation boundary.
   - Read the accepted step contract, active plan entry, and linked design or
     research artifacts when present.
   - Identify the unchecked execution units and their proof obligations.
   - Do not rewrite the contract while implementing. If current code or
     repository-local enforcement contradicts the contract, stop and report the
     contradiction with file-level evidence before spawning workers.
   - Stay on lead duties. Perform direct implementation only for unavoidable
     integration or coordination fixes, and state why the work could not stay
     with the unit worker.

2. For exactly one unchecked execution unit, spawn its active `worker` subagent.
   - Use `model: gpt-5.5` and `reasoning_effort: medium`.
   - Keep its agent id available for all review fixes and later
     unit-attributable final-review fixes.
   - Assign a concrete unit number, contract file, write ownership, and proof
     obligations.
   - Tell the worker it is not alone in the codebase, must not revert edits made
     by others, must adapt to current repository state, and must not commit.
   - Use this prompt shape:

```text
Implement unit N from STEP_FILE.

You are the worker for this unit only. Use the contract as the source of truth.
Own WRITE_SCOPE. Stay inside the unit scope and its proof obligations.

You are not alone in the codebase: do not revert edits made by others, and
adapt your implementation to the current repository state.

Run the relevant verification for this unit. Do not commit. In your final
response, report changed files, verification commands and results, and any
residual risks or blockers.
```

3. Intake the worker result before review.
   - Check the worker's final report, changed file list, and verification
     results against the unit boundary.
   - Do not perform a full code review before the reviewer. Use this gate only
     to catch obvious coordination failures: wrong unit, wrong write scope,
     missing required proof, unreported blockers, or incomplete work.
   - If the result has an obvious coordination failure, redirect the same worker
     with lead guidance before requesting review.
   - Otherwise, send the unit to a fresh reviewer. Run local verification before
     review only when the worker's verification is missing, stale, or needed to
     keep the repository working tree trustworthy.

4. Spawn a fresh `code_reviewer` subagent for the unit.
   - Use a new clean reviewer for every review request.
   - Give it the absolute path to the step contract file.
   - Use this prompt only: `review unit N against STEP_FILE`
   - Replace `N` and `STEP_FILE` with the concrete unit number and path.
   - Do not add other context, explanations, links, or extra instructions.

5. If the reviewer reports findings, route them through lead judgment before
   asking the worker to fix them.
   - Classify each finding as valid, needing lead interpretation, duplicate, or
     not actionable under the contract and repository rules.
   - For valid findings, identify the expected fix level: boundary validation,
     shared invariant, source-of-truth update, owning module behavior, test
     coverage, observability, or narrow call-site correction.
   - Tell the worker what problem class to close and where the owner appears to
     be. Do not merely forward the finding as a patch request.
   - Prefer one owner-level fix over multiple local symptoms when findings point
     to the same abstraction or invariant.
   - Send all unit review fixes to the active unit worker. If that worker is
     blocked or has lost necessary context, clarify, narrow, or supply the
     missing context.
   - If the active unit worker is closed, resume it when possible. If it is
     deleted or unrecoverable, follow `Worker Recovery Rule`.
   - Re-run verification when the fix can affect behavior or proof.
   - Spawn a new clean `code_reviewer` after every worker fix. Continue until
     the latest fresh reviewer reports no findings.

6. Commit the approved unit implementation.
   - Commit only after the latest fresh unit reviewer reports no findings and
     required verification has passed after the latest code changes.
   - Commit the completed unit before beginning implementation of the next unit.
   - Use the repository commit-message rules.
   - Record the first unit commit hash and the latest unit commit hash for final
     committed-range review.

7. Move to the next unchecked unit and repeat steps 2-6.
   - Each new unit gets one active `worker`.
   - Do not begin another unit while the current unit has uncommitted
     implementation work, unresolved verification, or unresolved review
     findings.

8. After all units are committed, run final committed-range review.
   - Set `START_COMMIT` to the first unit implementation commit.
   - Set `END_COMMIT` to the latest commit that includes all unit work.
   - Spawn the number of fresh final `code_reviewer` subagents needed for the
     risk and breadth of the range.
   - Always spawn at least one broad final reviewer with this prompt only:
     `review all unit commits together from START_COMMIT to END_COMMIT against STEP_FILE`
   - Add more final reviewers when the range spans multiple owners, public API
     surfaces, persistence/config formats, generated artifacts, architecture
     boundaries, or high-risk behavior. Give each added reviewer the same commit
     range and contract file, plus one specific review focus. Do not duplicate
     the same broad prompt across multiple reviewers.
   - In parallel, spawn one fresh default subagent with `model: gpt-5.5` and
     `reasoning_effort: medium` for naming cohesion. Pass the
     `naming-cohesion-review` skill and use this prompt shape:

```text
Use $naming-cohesion-review at /Users/blackpika/iwb_canvas_engine/.agents/skills/naming-cohesion-review/SKILL.md to review all unit commits together from START_COMMIT to END_COMMIT against STEP_FILE.

Report only code-review style Findings.
```

9. Resolve final-review and naming-cohesion findings through the lead.
   - Triage findings before assigning fixes, using the same owner-level guidance
     rule from step 5.
   - Route unit-attributable fixes to that unit's active worker. If that worker
     is deleted or unrecoverable, follow `Worker Recovery Rule`.
   - Use a lead integration fix only when a final finding is genuinely
     cross-unit and has no single unit owner. Do not let any fix patch a symptom
     in a downstream call site when the finding identifies a shared owner.
   - Commit each accepted final-review fix in a follow-up commit.
   - For every follow-up final review, keep `START_COMMIT` as the first unit
     implementation commit and update `END_COMMIT` to the latest commit that
     includes all fixes.
   - Re-run fresh final reviewers and a fresh naming-cohesion reviewer for the
     updated range until the latest required review passes with no actionable
     findings.

## Completion Criteria

The implementation task is complete only when:

- every contract execution unit has been implemented by a bounded worker or by
  an explicitly justified lead integration fix;
- every contract execution unit had at most one active worker at a time, with
  any worker recovery reconstructed from the contract, current diff, reviewer
  findings, and verification state;
- every unit has passed its required verification after the latest changes;
- every unit has been approved by a fresh `code_reviewer` after the latest unit
  changes;
- every approved unit has its own commit before the next unit begins;
- reviewer findings were triaged by the lead and resolved at the right owner
  level instead of as unexamined local patches;
- the full committed range from the first unit commit through the latest fix
  commit has passed the required final `code_reviewer` set;
- the same full committed range has passed one fresh `naming-cohesion-review`
  subagent on `gpt-5.5` medium;
- every review pass used a fresh reviewer created after the latest relevant code
  changes;
- all follow-up fixes are committed and included in the final reviewed range.
