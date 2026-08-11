---
name: lead-unit-by-unit
description: Use when the user asks to implement an accepted active plan or Change Contract.
---

# Lead Unit By Unit

## Start With A Goal

Before any implementation action, ensure this thread has an active `/goal` for
the accepted `PLAN_FILE`. If no Goal exists, create it from this objective. If a
different unfinished Goal exists, stop and ask the user to resolve it; do not
replace or reinterpret it. Do not set a token budget unless the user supplied
one.

```text
/goal Execute the accepted Change Contract at PLAN_FILE completely, unit by
unit, through verified lifecycle closure.

Own the outcome of the entire contract. Before dispatching each unit or review
fix, choose the best defensible owner-level path: the simplest architecture-clean
solution that fully satisfies the contract, preserves compatibility and shared
invariants, and meets the resolved evidence obligations. Give the unit_worker
concrete direction while retaining every architectural and cross-unit decision.

Apply the same owner-level judgment to review findings. Never forward findings
mechanically or patch downstream symptoms when the cause belongs to a shared
boundary, invariant, source of truth, or owning module.

Complete only after every unit is separately committed with current
verification, the full committed range passes fresh final review, every finding
is dispositioned, terminal repository verification passes, and the plan is
moved to history.

If the contract conflicts with repository authorities or no defensible in-scope
path remains, stop with the evidence, attempted paths, exact blocker, and the
decision needed to continue.
```

Keep this Goal active until `Final Review And Closure` proves every completion
clause. Treat it as the persistent completion contract, not as a replacement for
the detailed workflow below.

## Invariants

- Keep one active `unit_worker` per unit for implementation, review fixes,
  verification repairs, and unit-attributable final fixes. Keep its agent id.
- Finish and commit the current unit before starting another. Never run unit
  workers in parallel.
- Use `.codex/agents/unit_worker.toml`; its model and reasoning effort are
  authoritative and must not be overridden at spawn time.
- Verify any alternative proposed by the worker and send an accept-or-reject
  decision with rationale before work diverges from the approved direction.
- Use a newly spawned reviewer for every pass after the latest relevant
  implementation changes: `code_reviewer` for a unit and `lead_code_reviewer`
  for the final committed range.
- Implement directly only for an unavoidable integration fix with no single
  unit owner, and state why it could not stay with a unit worker.

Handle worker recovery without asking the user for an operational decision. If
a unit worker is unavailable, resume it when possible. If it is deleted or
unrecoverable, spawn one recovery `unit_worker` with the plan, unit number,
working-tree state, changed files, verification state, reviewer findings, and
exact remaining task. It becomes the unit's only active worker.

## Evidence And Contract Boundary

Before assigning work, read the accepted plan and linked design or research
artifacts. Require the plan to be a direct child of `docs/planning/plans/` named
`YYYY-MM-DD-topic.md`; do not execute a legacy `step_`, order-prefixed, or
undated plan as active work. For every unchecked unit, resolve its
`Verification Profile` and
`Acceptance Outcomes` through the covering `Verification Matrix` rows to their
evidence and `Permanent Artifact Admissions` entries. Supply the witness,
evidence surface, pass signal, constraints, durable impact, artifact target, and
admission references as that unit's evidence obligations. For every evidence
key, also resolve the independent failure family, concrete forbidden green state
or false-positive case, required owner-seam falsification signal, and applicable
work-budget closure. Do not dispatch implementation when that evidence cannot
necessarily make its forbidden green state red at the real owner seam.

If the contract contradicts current code or repository enforcement, stop with
file-level evidence. Before a structural unit, resolve production structure
against `AGENTS.md` and `docs/architecture/`, or test structure against
`AGENTS.md`, `docs/architecture/02_package_boundaries.md`, and
`docs/verification/tests.md`; require a ready handoff that cannot amend accepted
scope. Do not otherwise rewrite the contract while implementing.

### Bounded Contract Amendment

When implementation exposes a new failure family that may require a permanent
test, fixture, structural rule, source scanner, or independent coverage concern,
require the worker to stop that part and report it. Verify the failure mode and
update only:

- the affected Acceptance Outcome, split only for an independent guarantee;
- its existing or new `Verification Matrix` row;
- the central admission entry required by `ADD` or `EXTEND_COVERAGE`.

Preserve the lookup from outcome through Matrix evidence to admission. Before
work resumes, run the contract linter and obtain one complete `PASS` from a fresh
`contract_reviewer` against the amended contract, its declared sources, and every
source explicitly named by the user. Any contract edit invalidates that verdict.

Do not use this amendment to change the accepted goal, behavior, owner, boundary,
compatibility, source of truth, implementation scope, or verification beyond the
affected failure family. If any must change, stop and report the contradiction or
missing decision.

## Review Finding Protocol

Before any implementation, worker instruction, or integration fix for a review
finding, use **REQUIRED SUB-SKILL:** superpowers:receiving-code-review and apply
its read-understand-verify-evaluate sequence. If it is unavailable, stop at this
gate.

Give every reviewer report exactly one disposition:

- `ACCEPTED_BLOCKING`: a confirmed contract, correctness, security,
  compatibility, reliability, diff-introduced maintainability,
  required-evidence, or stable-invariant defect;
- `ACCEPTED_ADVISORY`: a concrete improvement not required for safe completion;
- `REJECTED`: an unverified report, equivalent valid implementation, style or
  private-shape preference, speculative hardening, duplicate, unsupported debt,
  or permanent-artifact request without its required admission evidence.

Never derive blocking status from priority. Accept a permanent-artifact request
only with a concrete failure mode and, when `Permanent artifact required` is
`yes`, an `Admission basis` naming the exact existing admission key or exact
missing/incorrect admission. Omit that basis when the field is `no`.

```text
Admission basis: `<existing-admission-key>`
```

For every `ACCEPTED_BLOCKING` report, choose the best defensible owner-level fix
path. Record the restated requirement, evidence checked, technical verdict,
owning level, rejected local-patch option when relevant, and verification to
rerun. Then send the responsible worker a step-by-step instruction containing
the problem class, owning boundary or module, required fix level, constraints,
first inspection targets, and verification. Never send raw reviewer feedback as
the work instruction.

Do not implement `ACCEPTED_ADVISORY` or `REJECTED` reports merely to close the
review. Do not reject a concrete, evidence-backed, durable report solely for
being outside the contract. Route it through `Finding disposition` in the
active contract's `Verification Gate`, deduplicate it, or record it in
`docs/planning/FOLLOW_UPS.md` without interrupting the unit.

## Unit Loop

For the next unchecked unit:

1. Confirm its boundary and resolved evidence obligations. Choose the owner-level
   implementation path required by the active Goal and convert it into concrete
   first steps. Do not delegate architectural or cross-unit decisions.
2. Spawn its repository-local `unit_worker` and keep the agent id. Dispatch the
   dynamic assignment using the absolute plan path for `PLAN_FILE`:

```text
Implement unit N from PLAN_FILE.

Write scope: WRITE_SCOPE
Evidence obligations: RESOLVED_PROFILE_OUTCOMES_MATRIX_AND_ADMISSIONS
Forbidden green state: CONCRETE_FALSE_POSITIVE_CASES_BY_EVIDENCE_KEY
Required falsification signal: OWNER_SEAM_KILL_SIGNALS_BY_EVIDENCE_KEY
Implementation direction: OWNER_LEVEL_PATH_AND_FIRST_STEPS

Use the contract as the source of truth. Do not commit. Report changed files,
verification commands and results, and residual risks or blockers.
```

3. Intake only for coordination: compare the actual diff and reported evidence
   with each assigned forbidden green state and required falsification signal;
   a worker's green report alone is insufficient. Then compare the report,
   files, and verification with the unit boundary. Return wrong scope, missing
   evidence, unreported blockers, or incomplete work to the same worker. Do not
   perform a full code review during intake; preserve independent review. If a
   new failure family appears, use `Bounded Contract Amendment`. Run local
   verification here only when the worker's evidence is missing, stale, or
   needed for a trustworthy tree.
4. Spawn a fresh `code_reviewer` with only the absolute plan path substituted:
   `review unit N against PLAN_FILE`
5. Apply `Review Finding Protocol`. Send every accepted blocker to the same unit
   worker at the correct owning level, then rerun affected verification. After
   any implementation change, spawn another fresh `code_reviewer` with the same
   prompt. Repeat until no `ACCEPTED_BLOCKING` report remains.
6. Commit the unit only after required verification passes on the latest code
   and no accepted blocker remains. Use repository commit rules. Record the first
   unit implementation commit and the latest unit commit.

Repeat this loop for the next unit only after the current unit is committed and
has no uncommitted work or unresolved verification.

## Final Review And Closure

After all units are committed:

1. Set `START_COMMIT` to the first unit implementation commit and `END_COMMIT` to
   the latest commit containing all unit work. Spawn one fresh
   `lead_code_reviewer` with only:
   `review all unit commits together from START_COMMIT to END_COMMIT against PLAN_FILE`
2. Apply `Review Finding Protocol`. Route a unit-attributable blocker to that
   unit's active worker, using worker recovery when required. Handle a genuinely
   cross-unit fix yourself only when it has no single unit owner. Commit each
   accepted final fix in a follow-up commit after affected verification passes.
3. After implementation changes, keep `START_COMMIT` fixed, advance `END_COMMIT`
   through every fix commit, and repeat the full-range review with a fresh
   `lead_code_reviewer` until no `ACCEPTED_BLOCKING` report remains.
4. Before lifecycle closure, run every terminal check required by `AGENTS.md`
   and the contract's `Verification Matrix` and `Verification Gate`, except the
   checks whose subject is the lifecycle move itself. Repair every required
   failure or finding. If a repair changes implementation, commit it, keep
   `START_COMMIT` fixed, advance `END_COMMIT`, and return to step 1 for another
   fresh full-range review. Repeat until the latest committed range passes both
   final review and pre-closure terminal verification.
5. Mark all implemented units complete and move the plan with the same filename
   from `docs/planning/plans/` to `docs/history/plans/`. For every linked active
   design, verify that completed plans cover every in-scope Decision Trace and
   Change Contract Handoff target. Search every remaining direct-child active
   plan's `Source Inputs` `Design` rows for the design path. Move the design
   with the same filename to `docs/history/designs/` only when coverage is
   complete and no such row declares it; otherwise leave it active. Do not edit
   `docs/planning/README.md` during closure. Run the documentation and lifecycle
   checks triggered by these moves. Repair closure artifacts and commit the
   verified lifecycle closure. If a required repair changes implementation,
   move the plan back to its active path and return to step 1. Then prove every
   completion clause in the active Goal and mark it complete.
