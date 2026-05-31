---
name: anti-slop-review
description: Review code, tests, guardrails, plans, designs, and documentation for artifacts that look useful but do not provide meaningful behavior, enforcement, proof, simplification, or decision value. Use when checking for fake proof, weak guardrails, overclaimed tests, duplicated source-of-truth, useless abstractions, bloated plans, or documentation that creates false confidence.
---

# Anti-Slop Review

Use this skill to find mismatch between what an artifact claims to provide and
what it actually provides.

Do not label something as slop just because it is small, simple, prose-based,
incomplete, or weak. Label it as slop only when it creates false confidence,
maintenance cost, duplicated truth, decision noise, or ceremony without a
concrete consumer or useful guarantee.

## Core Question

What useful work disappears if this artifact is removed?

Useful work can be behavior, enforcement, proof, simplification, decision value,
migration safety, onboarding value, operational value, or an explicit release
gate. If only a checklist stays green, suspect slop.

## Outcome-Proof Fit

`Outcome-Proof Fit` is the shared rule used by design, contract, and review
skills:

For every claim about behavior, invariant, owner responsibility,
source-of-truth update, migration, guardrail, compatibility promise, completion
state, or readiness state, identify the direct outcome that would be false if
the claimed work were fake or incomplete. Under `Completion Evidence Boundary`,
completion and readiness claims still require direct outcome proof; this skill
does not make planning artifacts authoritative for post-implementation
completion.

Verification must prove that direct outcome. A proxy signal is not sufficient
when it can pass while the claimed outcome remains false. Proxy checks are valid
only when the artifact explicitly scopes the claim to that proxy, or when the
proxy is itself the claimed outcome.

Use the same four-part frame everywhere:

- `Claim`: what behavior, invariant, responsibility, or outcome is promised?
- `Direct outcome`: what owner-observable or external result would be false?
- `Proxy risk`: what weaker signal could pass while the claim is false?
- `Required proof`: what check, proof surface, or proof strategy fails or
  exposes failure when the outcome is false?

## Review Algorithm

1. Identify the claim.
   - What does the artifact say or imply it proves, enforces, guarantees,
     explains, simplifies, or decides?
   - Look at names, docs, test descriptions, guardrail ids, CI placement,
     checklist wording, and review language.
   - Strong words raise the bar: `complete`, `proof`, `guardrail`, `contract`,
     `source of truth`, `integration`, `functional`, `locked`, `enforced`.

2. Identify the actual work.
   - What does it physically do?
   - Does it run code, compile a consumer, validate a schema, check a real
     boundary, generate output, document a decision, or only compare text/lists?
   - Who or what consumes it: runtime, CI, analyzer, tests, docs tooling,
     reviewer, product owner, migration process, external user?

3. Compare claim vs work.
   - If the actual work matches the claim, it is not slop.
   - If the work is useful but the claim is too strong, classify it as
     misnamed or overstated.
   - If the work has little value relative to cost or creates false confidence,
     classify it as slop.
   - Apply `Outcome-Proof Fit`: can the proof pass while the claimed outcome
     remains false? If yes, the claim must narrow to the checked proxy or add
     direct outcome proof.

4. Find the concrete failure mode.
   - What bad state does this artifact catch?
   - What bad state can still happen while it passes?
   - Do not make a strong finding without a concrete missed failure mode.

5. Check for self-referential proof.
   - Be suspicious when docs prove docs, lists prove lists, tests only check
     ids, or guardrails only check that another checklist mentions the same
     thing.
   - This may still be valid registry parity, but it is not behavioral proof.

6. Ask the deletion question.
   - If removed, what real guarantee or workflow breaks?
   - If only another self-referential artifact breaks, the value is probably
     overstated.

7. Recommend the smallest honest fix.
   - Keep it if useful.
   - Rename or scope it down if the claim is too strong.
   - Connect it to real proof if the guarantee matters.
   - Replace duplicated manual truth with one source of truth or generation.
   - Delete it only when no useful consumer or guarantee remains.

## Slop Signals

Treat these as investigation prompts, not automatic findings:

- Markdown or prose parsing presented as behavior proof.
- Tests that only check ids, headings, or manual lists.
- Guardrails that pass while the bad state they imply they prevent remains
  possible.
- Compile-only fixtures described as functional, behavioral, or integration
  proof.
- Multiple manual lists that must stay synchronized.
- Documentation that only repeats code or other docs without decision,
  onboarding, migration, or operational value.
- Plans that add artifacts but do not make a new bad state impossible.
- Single-callsite abstractions with no boundary, safety, readability, or reuse
  value.
- "Source of truth" artifacts with no consumer.
- Checks whose only failure mode is "the checklist wording changed".
- Proxy-only proof: cache key shape, revision churn, registry presence, object
  construction, method call order, rebuild count, compile success, event
  delivery, schema presence, or guardrail registration used to prove a broader
  behavior that could still be false.

## False Positive Guardrails

Do not call something slop when:

- It is honestly labeled as a note, draft, smoke test, compile check, checklist,
  or onboarding material.
- It has a clear human or machine consumer.
- It supports a real decision, migration, audit, handoff, or operational
  workflow.
- It is temporary but has an owner and removal condition.
- It prevents a real regression within its stated scope.
- The only issue is naming. Classify that as `Misnamed`, not `Slop`.

## Verdicts

Use one verdict:

- `Useful`: claim matches actual value.
- `Weak but valid`: limited guarantee, honestly scoped, real consumer.
- `Misnamed`: useful artifact, overstated name or description.
- `Slop`: little useful value relative to maintenance/review cost.
- `Harmful slop`: creates false confidence, duplicated truth, misleading gates,
  blocked fixes, or decision noise.

## Output Format

For general review:

```text
Verdict: Useful / Weak but valid / Misnamed / Slop / Harmful slop

Claim:
...

Direct outcome:
...

Actual proof or value:
...

Proxy risk / gap:
...

Concrete failure mode:
...

Recommendation:
...
```

For code review, report only actionable findings:

```text
Findings

[P2] path/file.ext:123 This claims to prove X, but only checks Y. In scenario Z, the artifact still passes while the bad state remains possible, so rename/scope it down or connect it to real proof.
```

Prefer questions over findings when the claim, consumer, or failure mode is
unclear.
