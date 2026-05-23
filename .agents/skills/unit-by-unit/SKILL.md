---
name: unit-by-unit
description: "Use when implementing a step contract unit by unit: complete one contract execution unit, review it with one reused code_reviewer for that unit, fix all findings, commit, then continue to the next unit until every unit is complete."
---

# Unit By Unit

Use this skill when the user asks to implement a Change Contract or plan step
unit by unit.

## Workflow

1. Implement exactly one execution unit from the accepted step contract.
   - Stay inside the unit scope and its proof obligations.
   - Run the relevant verification required for that unit.

2. After the unit implementation and verification are complete, spawn exactly
   one `code_reviewer` subagent for that unit.
   - The reviewer name must include the unit number.
   - Give it the absolute path to the step contract file.
   - Use this prompt only: `review unit N against STEP_FILE`
   - Replace `N` and `STEP_FILE` with the unit number and concrete step file
     path.
   - Do not add other context, explanations, links, or extra instructions.

3. If the reviewer reports findings, fix them in the same unit scope.
   - Reuse the same `code_reviewer` for every follow-up review of that unit.
   - Do not spawn a second reviewer for the same unit.
   - Continue the fix and re-review loop until that same reviewer reports no
     findings.

4. Commit the approved unit.
   - Commit only after the unit reviewer has no remaining findings.
   - Use the repository commit-message rules.

5. Move to the next unit and repeat the same workflow.

6. After every unit has been committed, spawn one final `code_reviewer`.
   - This must be a different reviewer from the per-unit reviewers.
   - Give it the first and last unit commit hashes and the absolute path to
     the step contract file.
   - Use this prompt only:
     `review all unit commits together from START_COMMIT to END_COMMIT against STEP_FILE`
   - Replace `START_COMMIT`, `END_COMMIT`, and `STEP_FILE` with the concrete
     commit hashes and step file path.
   - Do not add other context, explanations, links, or extra instructions.
   - If it reports findings, fix them in a follow-up commit after the unit
     commits, then reuse the same final reviewer until it reports no findings.

## Completion Criteria

The implementation task is complete only when every unit in the step contract:

- has been implemented within its stated scope;
- has passed its required verification;
- has been approved by its own single reused `code_reviewer`;
- has been committed before work begins on the next unit;
- the full set of unit commits has been approved by a different final
  `code_reviewer` using the explicit unit commit range and step contract file.
