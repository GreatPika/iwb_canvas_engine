---
name: unit-by-unit
description: "Use when implementing a step contract unit by unit: complete one contract execution unit, verify it, review it with a fresh code_reviewer, commit the approved unit, and continue until the final committed range is reviewed with no findings."
---

# Unit By Unit

Use this skill when the user asks to implement a Change Contract or plan step
unit by unit.

## Workflow

1. Implement exactly one unchecked execution unit from the accepted step
   contract.
   - Stay inside the unit scope and its proof obligations.
   - Run the relevant verification required for that unit.
   - Do not begin another unit while the current unit has uncommitted
     implementation work, unresolved verification, or unresolved review
     findings.

2. After the unit implementation and verification are complete, spawn a new
   clean `code_reviewer` subagent for that unit review request.
   - Give it the absolute path to the step contract file.
   - Use this prompt only: `review unit N against STEP_FILE`
   - Replace `N` and `STEP_FILE` with the unit number and concrete step file
     path.
   - Do not add other context, explanations, links, or extra instructions.

3. If the reviewer reports findings, fix them in the same unit scope.
   - For every follow-up review request, spawn a new clean `code_reviewer`.
   - Use the same unit review prompt and constraints from step 2.
   - Re-run the verification required for the unit when the fix can affect the
     verified behavior or proof surface.
   - Continue the fix and re-review loop until the latest fresh reviewer reports
     no findings.

4. Commit the approved unit implementation.
   - Commit only after the latest fresh unit reviewer has no remaining findings.
   - Use the repository commit-message rules.
   - Keep the resulting implementation commit hash available for the final
     committed-range review.

5. Move to the next unit and repeat the same workflow only after the current
   unit's implementation commit exists.

6. After every unit has been committed, start final review by spawning a new
   clean final `code_reviewer`.
   - This must be a new clean reviewer, separate from all previous review
     requests.
   - Set `START_COMMIT` to the first unit implementation commit.
   - Set `END_COMMIT` to the latest commit that includes all unit work.
   - Give it the first and latest commit hashes and the absolute path to the
     step contract file.
   - Use this prompt only:
     `review all unit commits together from START_COMMIT to END_COMMIT against STEP_FILE`
   - Replace `START_COMMIT`, `END_COMMIT`, and `STEP_FILE` with the concrete
     commit hashes and step file path.
   - Do not add other context, explanations, links, or extra instructions.
   - If it reports findings, fix them in a follow-up commit after the unit
     commits, then spawn a new clean final `code_reviewer` for each follow-up
     review request until the latest fresh reviewer reports no findings.
   - For every final follow-up review, keep `START_COMMIT` as the first unit
     implementation commit and update `END_COMMIT` to the latest commit that
     includes all final-review fixes. Never reuse an old `END_COMMIT` after
     creating a follow-up commit.

## Completion Criteria

The implementation task is complete only when every unit in the step contract:

- has been implemented within its stated scope;
- has passed its required verification;
- has been approved by a fresh `code_reviewer` review request after its latest
  implementation changes;
- has a unit implementation commit before work begins on the next unit;
- every unit and final follow-up review request used a new clean
  `code_reviewer`;
- the full committed range from the first unit implementation commit through the
  latest unit or follow-up fix commit has been approved by a fresh final
  `code_reviewer` using the explicit commit range and step contract file.
