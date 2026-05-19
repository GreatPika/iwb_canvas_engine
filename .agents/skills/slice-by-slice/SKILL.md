---
name: slice-by-slice
description: Use when implementing a step contract slice by slice: complete one contract slice, review it with one reused code_reviewer for that slice, fix all findings, commit, then continue to the next slice until every slice is complete.
---

# Slice By Slice

Use this skill when the user asks to implement a Change Contract or plan step
slice by slice.

## Workflow

1. Implement exactly one slice from the accepted step contract.
   - Stay inside the slice scope and its proof obligations.
   - Run the relevant verification required for that slice.

2. After the slice implementation and verification are complete, spawn exactly
   one `code_reviewer` subagent for that slice.
   - The reviewer name must include the slice number.
   - Use this prompt only: `review slice N`
   - Replace `N` with the slice number.
   - Do not add context, explanations, links, or extra instructions.

3. If the reviewer reports findings, fix them in the same slice scope.
   - Reuse the same `code_reviewer` for every follow-up review of that slice.
   - Do not spawn a second reviewer for the same slice.
   - Continue the fix and re-review loop until that same reviewer reports no
     findings.

4. Commit the approved slice.
   - Commit only after the slice reviewer has no remaining findings.
   - Use the repository commit-message rules.

5. Move to the next slice and repeat the same workflow.

## Completion Criteria

The implementation task is complete only when every slice in the step contract:

- has been implemented within its stated scope;
- has passed its required verification;
- has been approved by its own single reused `code_reviewer`;
- has been committed before work begins on the next slice.
