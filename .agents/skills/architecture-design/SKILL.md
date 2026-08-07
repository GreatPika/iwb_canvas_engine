---
name: architecture-design
description: "Use when the requested outcome requires creating or editing an architecture design artifact. For read-only work, use only when the user's own message contains 'review' or 'ревью' and names the architecture design artifact as the review target."
---

# Architecture Design

Decide architecture for future Change Contract authoring. Do not implement,
draft a Change Contract, or claim implementation evidence.

## Authority Preflight — Hard Gate

Before selecting or accepting a design form, identify the current owner of every
affected durable value and inspect its direct consumers for manual mirrors,
including copied inventories and exact-parity validators.

A pre-existing mirror cannot be treated as evidence, baseline, or out of scope
when the design consumes, preserves, modifies, or claims singular ownership of
that concern.

The selected form must either remove the mirror or explicitly define intentional
duplication with its distinct owner, lifecycle, consumers, invariant, and direct
verification. Otherwise the design cannot receive `READY_FOR_CONTRACT` or
`PASS`; review-only returns `UNSAFE_SOURCE_OF_TRUTH`.

Review-only must repeat this preflight independently. The design's own claims
are not evidence that the preflight passed.

## Mode Selection

- Create or update: read `references/design-rules.md` and
  `references/authoring.md`; execute the complete reviewed workflow.
- Review only: read `references/design-rules.md` and
  `references/reviewing.md`; do not write, brainstorm, or spawn subagents.
- Review and repair: only on explicit repair intent; read all three references,
  make the minimum permitted repair, then use a clean review-only subagent with
  the admission context required by `references/authoring.md`.

## Common Boundaries

Read explicit source inputs and repository evidence. Run only read-only source
queries and `scripts/design_lint.py`; do not run implementation tests, builds,
formatters, generators, migrations, package installation, or completion checks.
Use `assets/design-artifact-template.md` when writing. Run
`scripts/design_lint.py`, which owns mechanical validation through
`references/design-artifact-schema.json`. Read the schema directly only when
diagnosing lint or changing the artifact form. Read
`../change-contract/references/contract-vocabulary.json` for Profile and
Obligations values.

In write-capable modes, write only the one active design. Its direct-child
location under `docs/planning/designs/` is its active registration. Do not edit
implementation, product sources of truth, ADRs, active plans, or a Change
Contract.

`docs/planning/README.md` owns design lifecycle and naming. Write a new design
as `docs/planning/designs/YYYY-MM-DD-topic.md`; never use step or sequence
numbering. Historical designs under `docs/history/designs/` are read-only
evidence and do not own current behavior. This skill never archives a design;
the workflow closing the last active plan that consumes its completed scope
owns the guarded move to history.

## Terminal Outcomes

`READY_FOR_CONTRACT` and `DESIGN_NOT_REQUIRED` require `PASS` on the latest
content from review-only, including its mandatory Solution Proportionality
audit. `NEEDS_RESEARCH` requires a matching fresh `BLOCKED` review.
`ARCHITECTURE_GATE` requires a fresh `BLOCKED` review with
`NEEDS_USER_DECISION`; the latter is a workflow report, never stored metadata.
Continue admitted in-scope repairs without a numeric limit.

## Resource Ownership

| Resource                                                 | Stable concern                | Consumers                                   | Update trigger                                                                 | Verification owner                         |
| -------------------------------------------------------- | ----------------------------- | ------------------------------------------- | ------------------------------------------------------------------------------ | ------------------------------------------ |
| `references/design-rules.md`                             | Semantic readiness            | Authoring and review modes                  | A disposition, gate, evidence, decision, diagram, or handoff rule changes      | Independent semantic review                |
| `references/design-artifact-schema.json`                 | Mechanical active-design form | Linter and template validation              | Frontmatter, sections, labels, tables, or deterministic enums change           | Design-lint tests and template/active lint |
| `references/authoring.md`                                | Write-capable procedure       | Create/update and repair modes              | Intake, brainstorming, registration, repair, or reviewer orchestration changes | Whole-skill inspection and real use        |
| `references/reviewing.md`                                | Audit protocol                | Review modes                                | Evidence checks, routes, output, or repair boundaries change                   | Whole-skill inspection and real use        |
| `../change-contract/references/contract-vocabulary.json` | Profile and obligation tokens | Contract/design authoring, review, and lint | A token is introduced, renamed, or retired                                     | Contract-lint and design-lint tests        |

## Review Recursion Guard

In review-only mode, return one validation artifact and stop. Never invoke
brainstorming, edit files, create a reviewer, or start downstream work.
