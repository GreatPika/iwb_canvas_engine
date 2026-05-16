---
name: plan-step-contract
description: Use when adding a new PLAN.md step that must be drafted with the change-contract skill and validated by a single reused contract_reviewer subagent before the planning work is considered complete.
---

# Plan Step Contract Mode

Use this skill when the user asks to add a new roadmap step, create a plan step,
or run plan-writing mode for this repository.

This skill coordinates authoring and validation only. Do not implement the
planned code change unless the user separately asks for implementation after
the contract is accepted.

## Workflow

1. Create the new step with `change-contract`.
   - Read `.agents/skills/change-contract/SKILL.md`.
   - Use the change-contract template and rules as the canonical structure for
     the new step file.
   - Add the step to the active conversation plan when the plan tool is
     available.
   - Add the step entry to root `PLAN.md`.
   - Write or update the linked step contract file required by `PLAN.md`.

2. After step 1 is complete, spawn exactly one `contract_reviewer` subagent.
   - Ask it to review the created step file.
   - Include a direct file reference in this form:
     `Проверь step_N вот ссылка: /absolute/path/to/step_N.md`
   - Do not spawn another `contract_reviewer` for later review rounds.

3. If `contract_reviewer` reports findings, repair the same step file and any
   related `PLAN.md` entry needed to satisfy the findings.
   - Keep the repair scoped to the contract and plan entry.
   - Reuse the already spawned `contract_reviewer` by sending it the updated
     file link and asking for another review.

4. Repeat the repair and re-review loop until the same `contract_reviewer`
   reports that no blocking or non-blocking findings remain.

## Reviewer Reuse Rule

There must be only one `contract_reviewer` subagent for the entire validation
loop. Reuse that same subagent for every follow-up review request. Starting a
fresh reviewer for each revision invalidates this workflow because review
state, prior findings, and convergence history are lost.

## Completion Criteria

The planning task is complete only when:

- the new step exists in root `PLAN.md`;
- the linked step contract file exists and follows `change-contract`;
- the active conversation plan reflects the new step when the plan tool is
  available;
- the single reused `contract_reviewer` has approved the final step file with
  no remaining findings.
