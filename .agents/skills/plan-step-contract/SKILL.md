---
name: plan-step-contract
description: Use when adding a new PLAN.md step that must be drafted with the change-contract skill, validated by one reused primary contract_reviewer, and then approved by a different second contract_reviewer before planning work is complete.
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
   - Use the current `change-contract` mode/profile/obligation routing, active
     template, and rules as the canonical structure for the new step file.
   - Do not infer the step shape from historical `plan/step_*.md` files.
   - Add the step to the active conversation plan when the plan tool is
     available.
   - Add the step entry to root `PLAN.md`.
   - Write or update the linked step contract file required by `PLAN.md`.

2. After step 1 is complete, spawn exactly one primary `contract_reviewer`
   subagent.
   - Ask it to review the created step file.
   - Give it the absolute path to the created step contract file.
   - Use this prompt only: `review step N at STEP_FILE`
   - Replace `N` and `STEP_FILE` with the step number and concrete step file
     path.
   - Do not add other context, explanations, links, comments, or extra
     instructions.
   - If the step contract is authored from a specific implementation phase
     document under `docs/implementation`, include that concrete phase document
     path in the same prompt using this exact form:
     `review step N at STEP_FILE against phase PHASE_FILE`
   - Replace `PHASE_FILE` with the concrete `docs/implementation/...` document
     path.
   - Do not include a phase document unless that specific implementation phase
     document is the contract input.
   - If the step contract is authored from a specific architecture design
     document under `.design`, include that concrete design document path in
     the same prompt using this exact form:
     `review step N at STEP_FILE against design DESIGN_FILE`
   - Replace `DESIGN_FILE` with the concrete `.design/...` document path.
   - Do not include a design document unless that specific design document is
     the contract input.
   - Do not spawn another primary `contract_reviewer` for later review rounds.

3. If the primary `contract_reviewer` reports findings, repair the same step
   file and any related `PLAN.md` entry needed to satisfy the findings.
   - Keep the repair scoped to the contract and plan entry.
   - Reuse the already spawned `contract_reviewer` by sending it the updated
     prompt in the same exact form used for the first review.
   - Do not add other context, explanations, links, comments, or extra
     instructions to follow-up review requests.

4. Repeat the repair and re-review loop until the same primary
   `contract_reviewer` reports that no blocking or non-blocking findings
   remain.

5. After the primary `contract_reviewer` accepts the step contract, spawn one
   second `contract_reviewer`.
   - This must be a different reviewer from the primary reviewer.
   - Give it the absolute path to the created step contract file.
   - Use this prompt only:
     `review step N at STEP_FILE`
   - Replace `N` and `STEP_FILE` with the step number and concrete step file
     path.
   - Do not add other context, explanations, links, comments, or extra
     instructions.
   - If the step contract is authored from a specific implementation phase
     document under `docs/implementation`, include that concrete phase document
     path in the same prompt using this exact form:
     `review step N at STEP_FILE against phase PHASE_FILE`
   - Replace `PHASE_FILE` with the concrete `docs/implementation/...` document
     path.
   - Do not include a phase document unless that specific implementation phase
     document is the contract input.
   - If the step contract is authored from a specific architecture design
     document under `.design`, include that concrete design document path in
     the same prompt using this exact form:
     `review step N at STEP_FILE against design DESIGN_FILE`
   - Replace `DESIGN_FILE` with the concrete `.design/...` document path.
   - Do not include a design document unless that specific design document is
     the contract input.
   - If it reports findings, repair the same step file and any related
     `PLAN.md` entry needed to satisfy the findings, then reuse the same
     second reviewer with the same exact prompt form until it reports no
     findings.
   - Do not add other context, explanations, links, comments, or extra
     instructions to follow-up review requests.

## Reviewer Reuse Rule

There must be only one primary `contract_reviewer` subagent for the primary
validation loop, followed by one different second `contract_reviewer` after the
primary reviewer accepts the contract. Reuse the same primary reviewer for
primary follow-up review requests and the same second reviewer for second
follow-up review requests. Starting a fresh reviewer for each revision
invalidates this workflow because review state, prior findings, and convergence
history are lost.

## Completion Criteria

The planning task is complete only when:

- the new step exists in root `PLAN.md`;
- the linked step contract file exists and follows `change-contract`;
- the active conversation plan reflects the new step when the plan tool is
  available;
- the single reused primary `contract_reviewer` has approved the step file with
  no remaining findings;
- a different second `contract_reviewer` has approved the same step file
  with no remaining findings.
