# Design: Topic

---
date: YYYY-MM-DD
designer: Codex
commit: SHORT_COMMIT
branch: CURRENT_BRANCH
design_question: "Original user request"
---

## Disposition

READY_FOR_CONTRACT | ARCHITECTURE_GATE | NEEDS_RESEARCH | DESIGN_NOT_REQUIRED

## Product Outcome

Plain-language result and non-goals.

## Target Contract Classification

- Profile: ...
- Obligations: ...

## Research Inputs

- `.research/YYYY-MM-DD-topic.md` - fact supplied.
- Or: None provided; direct repository evidence used.

## Repository Evidence

- `path:line` - fact supplied.

## Design Form Candidates

### Candidate A. Name

- Form:
- Why it could work:
- Gate failures or risks:

### Candidate B. Name

- Form:
- Why it could work:
- Gate failures or risks:

## Known Future Pressures

| Pressure | Evidence | How the selected form responds | Accepted cost or risk |
|---|---|---|---|

## Selected Form

The chosen form and why it is the best fit.

## Hard Gate Check

| Gate | Result | Evidence |
|---|---|---|
| Root cause | pass/fail | ... |
| Ownership | pass/fail | ... |
| Source of truth | pass/fail | ... |
| Boundary | pass/fail | ... |
| Dependency direction | pass/fail | ... |
| State/data | pass/fail/not applicable | ... |
| Seam | pass/fail/not applicable | ... |
| Verification | pass/fail | ... |
| Future pressure | pass/fail/not found after targeted inspection | ... |

## Lock-Required Facts

- Owner:
- Owning layer/module/document family:
- Seam:
- Dependency/import direction:
- State/data ownership:
- Entry boundaries:
- Exit boundaries:
- File placement basis:
- Execution order constraints:
- Rejected alternatives:
- Verification strategy:

## Diagram Need Assessment

| Design question | Needed? | Diagram kind | Reason |
|---|---:|---|---|
| Does the design change ownership, layer, package, or component boundaries? | yes/no | c4/none | ... |
| Does it change data flow, state ownership, cache ownership, resource movement, or lifecycle movement? | yes/no | data_flow/none | ... |
| Does it depend on call order, lifecycle order, sync/async ordering, failure ordering, or migration order? | yes/no | sequence/none | ... |
| Does it introduce or alter modes, statuses, terminal states, sessions, or transition rules? | yes/no | state/none | ... |
| Does it create, replace, migrate, or retire a shared seam? | yes/no | c4/data_flow/sequence/none | ... |
| Does it change public API consumer flow, payload shape, or compatibility behavior? | yes/no | sequence/data_flow/none | ... |
| Does it introduce or change analyzer, guardrail, or structural-recognition pipeline behavior? | yes/no | data_flow/sequence/none | ... |

## Provisional Diagrams

Include Mermaid diagrams only when the assessment says they are needed.

## Source-Of-Truth Impact

Name future docs, diagrams, registries, contracts, or roadmap files that a later
Change Contract must update. Do not edit them now.

## Verification Impact

Name future tests, analyzers, guardrails, docs checks, semantic searches, or
other proof surfaces that a later Change Contract should use. Do not edit them
now.

## Verification Strategy

Describe proof strategy appropriate to the target profile and obligations.

## Change Contract Handoff

- Required profile:
- Required obligations:
- Decisions to carry forward:
- Evidence to cite:
- Contract constraints or sequencing facts:

## Open Decisions

Only decisions that block or constrain the next step.
