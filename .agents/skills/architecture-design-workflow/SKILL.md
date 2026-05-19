---
name: architecture-design-workflow
description: "Use when running repository design mode: create or update one .design/YYYY-MM-DD-topic.md artifact with architecture-design, then validate it with one reused architecture-design-review subagent before moving to research, a user decision, or future Change Contract authoring."
---

# Architecture Design Workflow

Use this skill when the user asks to run the design workflow, prepare an
architecture design, or pair design authoring with design review.

This skill coordinates design authoring and validation only. Do not implement
code. Do not draft a Change Contract. Do not edit files outside `.design/`.

## Workflow

1. Create or update the design artifact with `architecture-design`.
   - Read `.agents/skills/architecture-design/SKILL.md`.
   - Read `.agents/skills/architecture-design/assets/design-artifact-template.md`.
   - Use the current `architecture-design` rules and template as canonical.
   - Write exactly one `.design/YYYY-MM-DD-topic.md` artifact.
   - Do not write to `PLAN.md`, `plan/`, `docs/`, source files, tests,
     registries, diagrams, or `.research/`.

2. After the design artifact exists, spawn exactly one reviewer subagent.
   - Use a default subagent when no dedicated design-reviewer role exists.
   - Ask it to use `architecture-design-review`.
   - Include a direct file reference in this form:
     `Проверь design artifact через architecture-design-review: /absolute/path/to/.design/YYYY-MM-DD-topic.md`
   - Do not spawn another reviewer for later review rounds.

3. If the reviewer reports `PASS`, the workflow is complete.
   - Do not start `change-contract`.
   - Report that the design is ready for future Change Contract authoring.

4. If the reviewer reports `REVISE`, repair the same `.design/` artifact.
   - Keep repairs scoped to that one `.design/YYYY-MM-DD-topic.md` file.
   - Reuse the same reviewer subagent for every follow-up review.
   - Repeat until the reviewer returns `PASS`, or until the reviewer identifies
     a blocking route that cannot be repaired from current evidence.

5. If the reviewer reports `BLOCKED`, classify the route before editing.
   - For `NEEDS_RESEARCH`, always stop and report the exact research questions.
     Do not repair the artifact until a separate research pass provides the
     missing facts.
   - For `NEEDS_USER_DECISION`, stop and ask for the product/architecture
     decision. Do not choose on the user's behalf.
   - For `CONTRADICTS_REPO`, `WRONG_OWNER`, `INSUFFICIENT_VERIFICATION`, or
     `INVALID_DESIGN_ARTIFACT`, repair the same `.design/` artifact when the fix
     is knowable from current repository evidence, then reuse the same reviewer.
   - If the artifact intentionally has disposition `NEEDS_RESEARCH` and the
     reviewer confirms `BLOCKED` with `NEEDS_RESEARCH`, treat the workflow as
     complete but not contract-ready, and report the exact research questions.
   - If the artifact intentionally has disposition `ARCHITECTURE_GATE`, treat it
     as terminal only when the reviewer returns `BLOCKED` with
     `NEEDS_USER_DECISION`; report the exact user decision required.

## Reviewer Reuse Rule

There must be only one reviewer subagent for the entire design validation loop.
Reuse that same subagent for every follow-up review request. Starting a fresh
reviewer for each revision invalidates the workflow because review state, prior
findings, and convergence history are lost.

## Completion Criteria

The design workflow is complete only when:

- exactly one `.design/YYYY-MM-DD-topic.md` artifact was created or updated by
  this workflow;
- no files outside `.design/` were edited by this workflow;
- the single reused reviewer has returned one of these terminal outcomes:
  - `PASS`, meaning the design can proceed to future Change Contract authoring;
  - `BLOCKED` with `NEEDS_RESEARCH`, meaning more factual research is required;
  - `BLOCKED` with `NEEDS_USER_DECISION`, meaning the user must choose;
  - `BLOCKED` with `NEEDS_RESEARCH` matching an intentional `NEEDS_RESEARCH`
    artifact disposition;
  - `BLOCKED` with `NEEDS_USER_DECISION` matching an intentional
    `ARCHITECTURE_GATE` artifact disposition;
- every repairable reviewer finding has either been fixed in the same `.design/`
  artifact or explicitly reported as blocked by missing evidence or a user
  decision.
