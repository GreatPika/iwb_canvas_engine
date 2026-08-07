# Layer 2 — Proof and Anti-Slop Review

Use this layer for code, tests, guardrails, plans, designs, documentation, verification claims, proof fixtures, generated truth, source-of-truth artifacts, completion claims, readiness claims, migration proof, compatibility proof, structural enforcement, negative proof, or any artifact that can create false confidence.

## Purpose

Find mismatch between what an artifact claims to provide and what it actually provides.

Do not label something as slop just because it is small, simple, prose-based, incomplete, or weak. Label it as slop only when it creates false confidence, maintenance cost, duplicated truth, decision noise, or ceremony without a concrete consumer or useful guarantee.

## Core Question

What useful work disappears if this artifact is removed?

Useful work can be behavior, enforcement, proof, simplification, decision value, migration safety, onboarding value, operational value, or an explicit release gate. If only a checklist stays green, suspect slop.

## Outcome-Proof Fit

`Outcome-Proof Fit` is the shared rule used by design, contract, and review skills.

For every claim about behavior, invariant, owner responsibility, source-of-truth
update, migration, guardrail, compatibility promise, completion state, or
readiness state, identify the concrete failure mode and acceptance oracle that
would expose fake or incomplete work.

Under the pre-implementation completion boundary, completion and readiness
claims still require admissible evidence against the acceptance oracle.
Planning artifacts are not authoritative evidence of post-implementation
completion.

Verification must expose the concrete failure mode when the claim is false. A
proxy signal is not sufficient when it can pass while the acceptance oracle
remains unmet. Proxy checks are valid only when the artifact explicitly scopes
the claim to that proxy, or when the proxy is itself the claimed outcome.

Use the same five-part trace everywhere:

- `Claim`: what behavior, invariant, responsibility, or outcome is promised?
- `Concrete failure mode`: what bad state remains possible when the claim is
  false?
- `Acceptance oracle`: what owner-observable or external result distinguishes
  the accepted outcome?
- `Proxy risk`: what weaker signal could pass while the claim is false?
- `Evidence constraints`: what evidence classes, coverage boundaries, and proxy
  exclusions make the oracle trustworthy without prescribing private shape?

Trace each accepted outcome key through the corresponding `Verification Matrix`
evidence key and then to its admission semantic key. Verify that the named
evidence surface and pass signal satisfy the oracle and constraints. Use each
row's durable impact and artifact target to determine whether the contract
permits no durable change, an update, or a new or expanded permanent artifact.
When a coverage finding requires a permanent artifact, its conditional
`Admission basis` must cite an exact existing semantic admission key or identify
the exact missing or incorrect admission for a concrete new failure family.

## Review Algorithm

`Concrete Failure Mode Standard`: a concern becomes a finding only when it identifies the concrete missed failure mode, affected consumer, scenario, or behavior. Slop signals are investigation prompts, not automatic findings.

1. Identify the claim.
   - What does the artifact say or imply it proves, enforces, guarantees, explains, simplifies, or decides?
   - Look at names, docs, test descriptions, guardrail ids, CI placement, checklist wording, and review language.
   - Strong words raise the bar: `complete`, `proof`, `guardrail`, `contract`, `source of truth`, `integration`, `functional`, `locked`, `enforced`.

2. Identify the actual work.
   - What does it physically do?
   - Does it run code, compile a consumer, validate a schema, check a real boundary, generate output, document a decision, or only compare text or lists?
   - Who or what consumes it: runtime, CI, analyzer, tests, docs tooling, reviewer, product owner, migration process, external user?

3. Compare claim vs work.
   - If the actual work matches the claim, it is not slop.
   - If the work is useful but the claim is too strong, classify it as misnamed or overstated.
   - If the work has little value relative to cost or creates false confidence, classify it as slop.
   - Apply `Outcome-Proof Fit`: can the admissible execution evidence pass while
     the acceptance oracle remains unmet? If yes, the claim must narrow to the
     checked proxy or strengthen its evidence constraints and execution evidence.

4. Apply `Concrete Failure Mode Standard`.
   - What bad state does this artifact catch?
   - What bad state can still happen while it passes?
   - Do not make a strong finding without a concrete missed failure mode, consumer, scenario, or behavior affected.

5. Check `Negative Proof And Fixture Quarantine`.
   - Be suspicious when docs prove docs, lists prove lists, tests only check ids, or guardrails only check that another checklist mentions the same thing.
   - This may still be valid registry parity, but it is not behavioral proof.
   - Negative, bypass, fixture, and structural proof must satisfy the acceptance
     oracle and evidence constraints at a real production seam or an
     architecture-required verification seam when applicable, not only through
     self-referential proof.

6. Ask the deletion question.
   - If removed, what real guarantee or workflow breaks?
   - If only another self-referential artifact breaks, the value is probably overstated.

7. Recommend the smallest honest fix.
   - Keep it if useful.
   - Rename or scope it down if the claim is too strong.
   - Connect it to admissible execution evidence if the guarantee matters.
   - Replace duplicated manual truth with one source of truth or generation.
   - Delete it only when no useful consumer or guarantee remains.

## Test Structure Audit

When the diff changes test structure, read `AGENTS.md`,
`docs/architecture/02_package_boundaries.md`, and `docs/verification/tests.md`,
then audit the final diff independently. Derive the transforming owner,
exhaustive scenario ownership, downstream proof, support consumers, import and
export boundaries, and independent oracle without trusting the pre-edit handoff
or contract assertion. Treat duplicated downstream proof, a production-derived
expected result, a test barrel, or a private cross-package test import as
ordinary Layer 2 candidates. Leave path and naming findings to Layer 3 and emit
no separate structural verdict.

## Permanent Artifact Admissions Review

Review every new failure family against all nine fields of its central
admission entry:

- `Covers`;
- `Impact`;
- `Failure family`;
- `Failure mode or stable invariant`;
- `Verification owner`;
- `Current verification gap`;
- `Failing witness`;
- `Durable and refactor-stable value`;
- `Artifact target`.

Flag missing, vague, mismatched, or wrongly owned fields. Flag a permanent test,
fixture, structural rule, source scanner, or independent coverage concern that
falls outside the applicable resolved Matrix row, including a worker's
unadmitted expansion. When implementation exposes a concrete failure mode that
needs a new permanent verification artifact, require a bounded amendment to the
affected outcome when it must be split, the corresponding Matrix row or new
row, and the corresponding central admission entry for `ADD` or
`EXTEND_COVERAGE`. Flag any such amendment that also changes accepted scope,
product behavior, ownership, boundaries, compatibility, source of truth, or
implementation scope.

Every coverage finding must contain the five unconditional fields below. When
`Permanent artifact required` is `yes`, it must also contain `Admission basis`:

```text
Failure mode or stable invariant:
Current verification gap:
Minimum execution evidence:
Permanent artifact required:
Admission basis: [required only when Permanent artifact required is yes]
Verification owner:
```

When a Change Contract governs the finding, also cite the exact semantic
outcome key and evidence key from the resolved Matrix row. If the required row
or admission is missing or incorrect, identify that exact defect instead of
inventing a key.

`Admission basis` must either cite an existing admission as `Admission basis:`
followed by its exact semantic key, or identify the exact missing or incorrect
admission for a newly discovered failure family. A concrete failure mode alone
does not justify a new permanent artifact. When `Permanent artifact
required` is `no`, omit `Admission basis`; do not invent admission text for
execution evidence that does not require durable expansion. Report the coverage
evidence without assigning a lead disposition.

## Negative Proof And Fixture Quarantine

For structural, bypass, negative-fixture, analyzer, or guardrail changes, verify
the acceptance oracle and evidence constraints at the production seam or an
architecture-required verification seam when applicable. Flag self-referential
proofs that would pass while the forbidden shape still bypasses the real path.

Keep guardrail and analyzer review contract-scoped. A guardrail is not weak
merely because it is not a complete code analyzer. First identify the contracted
guarantee, stable invariant, invalid state, owner, consumer, acceptance oracle,
evidence constraints, and architecture-required verification seam when
applicable. A nonarchitectural fixture strategy does not define review scope and
cannot justify a permanent-artifact request. Flag broad parsing,
semantic-analysis, or exhaustive-recognition gaps only when they make that
contracted guarantee false, or when the artifact itself claims general analyzer
coverage.

Flag fixture-only names, values, schemas, declarations, or public data added to real production source-of-truth surfaces unless the contract explicitly makes them durable product or API data.

## Slop Signals

Treat these as investigation prompts, not automatic findings:

- Markdown or prose parsing presented as behavior proof.
- Tests that only check ids, headings, or manual lists.
- Guardrails that pass while the bad state they imply they prevent remains possible.
- Compile-only fixtures described as functional, behavioral, or integration proof.
- Multiple manual lists that must stay synchronized.
- Documentation that only repeats code or other docs without decision, onboarding, migration, or operational value.
- Plans that add artifacts but do not make a new bad state impossible.
- Single-callsite abstractions with no boundary, safety, readability, or reuse value.
- `Source-Of-Truth Singularity` violations: source-of-truth artifacts with no
  consumer, duplicate truth outside explicit cache or performance duplication,
  or duplicated truth without an invariant and evidence constraints.
- Checks whose only failure mode is the checklist wording changed.
- Proxy-only proof: cache key shape, revision churn, registry presence, object construction, method call order, rebuild count, compile success, event delivery, schema presence, or guardrail registration used to prove a broader behavior that could still be false.
- A test treated as authority for product behavior instead of proof of an owning
  requirement or invariant.
- Handwritten parsers for private declarations or implementation shape.
- Copied model inventories that duplicate an owning source of truth.
- Feature-local recursive source scans instead of one central production-tree
  gate.
- Path-specific scanner exceptions that hide semantic scope gaps.
- Default suites kept intentionally red.
- Giant mixed-owner tests that combine independent policy or failure families.
- Assertions that preserve private implementation shape rather than an
  observable guarantee.

## False Positive Guardrails

Do not call something slop when:

- It is honestly labeled as a note, draft, smoke test, compile check, checklist, or onboarding material.
- It has a clear human or machine consumer.
- It supports a real decision, migration, audit, handoff, or operational workflow.
- It is temporary but has an owner and removal condition.
- It prevents a real regression within its stated scope.
- It is a central structural rule with one production-tree gate and focused
  accepted, rejected, and false-positive fixtures for the stable invariant.
- The only issue is naming. Classify that as `Misnamed`, not `Slop`, and use Layer 3 when placement or ownership matters.

## Verdicts For Standalone Artifact Review

Use one verdict when the user asks for standalone anti-slop review instead of code-review findings:

- `Useful`: claim matches actual value.
- `Weak but valid`: limited guarantee, honestly scoped, real consumer.
- `Misnamed`: useful artifact, overstated name or description.
- `Slop`: little useful value relative to maintenance or review cost.
- `Harmful slop`: creates false confidence, duplicated truth, misleading gates, blocked fixes, or decision noise.

Prefer questions over findings when the claim, consumer, or failure mode is unclear.

## Proof Candidate Format

Record code-review candidate findings for Layer 4 synthesis as:

```text
Layer: 2 — Proof, verification, and anti-slop
Priority: [P0/P1/P2/P3]
Location: path:line
Claim:
Concrete failure mode:
Acceptance oracle:
Actual evidence or value:
Proxy risk or gap:
Evidence constraints:
Expected fix direction:
```

For a coverage finding, include the required coverage block, including the
conditional `Admission basis` field when a permanent artifact is required, in
the finding body in addition to this candidate evidence.
