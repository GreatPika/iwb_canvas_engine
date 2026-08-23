# Architecture Design Checkpoint Review Procedure

## 1. Scope And Input

Review one completed prefix of one active `architecture-design/v4` artifact. The first
turn provides its absolute path, one exact checkpoint section, and the declared sources
and current repository authority needed to verify that prefix. A continuation turn
provides one exact next checkpoint section in the same artifact. Review exactly one
section per turn. The schema alone owns which sections are applicable and their order.

Run `python3 .agents/skills/architecture-design/scripts/design_lint.py --checkpoint
"<exact section>" <artifact>` first. Return mechanical findings and stop before semantic
review. A finding may name an earlier sealed section as its repair location and
revalidation point. Only when lint has no findings, read the completed prefix, its
declared sources, and the current owners and direct consumers needed to test its claims.
Do not require future sections or records, write, brainstorm, spawn another reviewer,
propose a terminal disposition, or claim Contract Readiness.

Before semantic review, follow `design-rules.md` and load the cumulative rule modules
required by the actual completed prefix. On each continuation, load any newly triggered
module before reviewing the next section.

## 2. Shared Checkpoint Algorithm

Review the completed prefix against the loaded semantic rules, its preceding sealed
records, and the following section contract. Check downstream sufficiency only:
later sections may consume the prefix but may not supply its missing meaning. Do not
duplicate the schema's mechanical grammar or terminal audit. Return each semantic
discovery as an ordinary checkpoint finding. When its minimum repair changes an earlier
sealed section, name that section in `Revalidate from`. Return `CHECKPOINT_PASS` only
when no finding exists.

| Checkpoint section | Seal when the completed section establishes | Do not require or create |
| --- | --- | --- |
| Basis | Complete `S`/`E`/`R` and Source Coverage; trustworthy facts and norms; enough accepted input for candidate work or disposition. | Candidate invention. |
| Candidate Analysis | Complete viable `F`/`M`/`P` comparison, result, and basis; a selected form or the exact `B` set; enough material axes for decisions. | `D`/`I`/`A` records. |
| Decision Register | Complete selected concerns, locks, open freedom, basis, form, realization, dependencies, and contract targets; explicit downstream needs; enough for Impact. | `I` or `A` bodies. |
| Impact Register | Every durable transition is a complete `I`, exactly caused by `D` or an owning `R`; `D` durable-impact correspondence is complete; enough fixed transitions for Assurance. | `A` records. |
| Assurance Register | Outcomes and assurance-required decisions are covered, and every observable `I` has direct `A` coverage; enough for stops and verification. | `H` records. |
| Stop Conditions | Meaningful `H` records invalidate exact `D`/`A`/`I` and require architecture re-entry; enough for handoff. | Contract Interface meaning. |
| Contract Interface | Duplicate-free exact projection using canonical Profile, Obligations, and ADR impact; handoff consumable without inventing architecture. | Record bodies or new meaning. |
| Diagrams | Explanatory `DG` records, or evidence-backed `None`, agree with `D`/`A`/`I`. | New norms. |
| Readiness Matrix | Exact derived architecture and gate closure from canonical records; no manufactured closure or readiness. | New closure meaning. |
| Open Blockers | Disposition-exact final blocker state: `READY_FOR_CONTRACT` and `DESIGN_NOT_REQUIRED` have none; `BLOCKED` has the exact `B` set and only permitted partial limits; terminal prefix/orphan closure is coherent. | A terminal verdict or a replacement for full-design audit. |

## 3. Sequential Reviewer Session And Output

A fresh clean reviewer starts one sequential session at the first checkpoint, after a
finding, or after a session reset. It handles exactly one section per turn. A pass seals
the exact section; return the result, end the current turn, and remain available for the
authoring orchestration to send the next section through `followup_task`. Any mechanical
or semantic finding ends the session immediately. The authoring orchestration verifies
semantic findings, reproduces mechanical findings through checkpoint lint, and repairs
only confirmed findings. It starts a new clean reviewer at the earliest among all
changed sections and supported `Revalidate from` sections. When no finding is confirmed
and no content changes, a new reviewer retries only the same unsealed checkpoint.

Changing sealed content, declared sources, a recorded user decision, or current
repository authority ends the session and requires a new clean reviewer from the
earliest affected section. Mechanical repair confined to the current section before it
is submitted does not reset the session. If a session is lost, unavailable, or lacks
demonstrably complete context, a replacement reviewer loads the cumulative rule set for
the actual current prefix, reads that prefix once, and returns a verdict only for the
next due section; it does not repeat unaffected checkpoint verdicts.

When neither mechanical nor semantic findings exist, return exactly:

```text
CHECKPOINT_PASS — <exact section>
```

Otherwise return only this shape; each finding must be independently actionable:

```markdown
CHECKPOINT_FINDINGS — <exact section>

- <short issue title>
  Code: `<stable code>`
  Section/Location: `<section, field, record, table row, diagram, or source>`
  Evidence: `<artifact or repository evidence>`
  Missing/Contradiction: `<what prevents the section from sealing>`
  Minimal Repair: `<smallest evidence-backed repair>`
  Revalidate from: `<earliest section changed by the repair>`
```

Never include a terminal route, terminal disposition, Contract Readiness statement,
passed-section list, optional improvement, or non-blocking advice. After all applicable
sections are sealed, end the checkpoint reviewer session. A separate fresh terminal
reviewer independently runs the whole-design audit in `reviewing.md`; checkpoint
verdicts and checkpoint reviewer context are not evidence for that audit.
