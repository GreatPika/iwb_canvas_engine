# Layer 3 — Naming and Cohesion Review

Use this layer for misleading file names, declarations placed under the wrong owner, directory cohesion drift, public API symbol placement, fixture placement drift, ownership boundaries, umbrella names, or explicit naming review.

Run this after the normal code-review context is loaded when available. When invoked standalone, first load the current diff, changed file list, active plan, linked contracts, and relevant local naming or source-of-truth rules before reviewing. Do not replace repository naming rules; apply them to the reviewed diff.

Use `Source-Of-Truth Singularity` when naming or placement depends on a governing local source of truth: durable meaning has one owner, duplicate truth requires an explicit cache or performance invariant and concrete evidence constraints that make correctness reviewable, and the artifact must have a real human or machine consumer.

## Workflow

1. When invoked standalone, inspect the current diff, changed file list, active plan, linked contracts, and relevant source-of-truth rules before judging names.
2. Compare the changed file list with the active plan, package layout, linked contracts, and source-of-truth docs that govern the touched area.
3. For each new or renamed file, ask: "What is this file's single reason to change?" Then check whether its declarations all share that reason.
4. For each new or renamed directory, ask: "What stable owner or subdomain does this directory introduce?" Then check whether its immediate children are facets of that owner instead of unrelated files collected for neatness.
5. For each added, removed, moved, or renamed public or boundary-facing symbol,
   identify its exact contract owner, responsibility, direct consumers, and
   established domain vocabulary. For removal, verify that current contract
   and compatibility owners authorize retirement. For other changes, flag a
   name that implies the wrong owner, operation, or public contract; do not flag
   equivalent precise wording only as taste.
6. Report only actionable naming and cohesion findings, not taste preferences.

## Production Structure Audit

When the diff changes production structure, read `AGENTS.md`,
`docs/architecture/02_package_boundaries.md`, and, when architecture graph nodes
or edges change, `docs/architecture/architecture_graph.yaml`. Apply those
authorities in audit posture:

1. Classify the actual final diff.
2. Reread current authorities and independently derive the expected names,
   declaration boundaries, owner, placement, node lifecycle, and policy.
3. Do not trust the pre-edit handoff, a contract assertion, or a reported Graph
   check.
4. Compare the final diff with the independently derived result.
5. Record mismatches only as ordinary Layer 3 candidates for Layer 4 synthesis.

This layer remains the sole post-implementation semantic review owner. Do not
emit a separate structural verdict.

## Test Structure Audit

When the diff changes test structure, read `AGENTS.md`,
`docs/architecture/02_package_boundaries.md`, and `docs/verification/tests.md`,
then independently derive the expected proof-owner path, filename, support
location, shared support API, and import/export boundary from the final diff.
Do not trust the pre-edit handoff or contract assertion. Record mismatches only
as ordinary Layer 3 candidates; Layer 2 owns duplicated proof and oracle
independence. Do not emit a separate structural verdict.

## Decision Test

- Apply `Owner-Level Fix`: if a file has one clear public owner, its name should match that owner or the exact responsibility it represents.
- If a file groups declarations, the name should describe the shared responsibility, not one arbitrary member.
- Keep small companion declarations together only when they are normally consumed together and still have one reason to change.
- Prefer a split when multiple public or boundary-facing declarations could reasonably evolve independently.
- Create a directory when several files share a stable owner, lifecycle, dependency boundary, or source-of-truth contract, and each child file names a distinct facet of that owner.
- Prefer a directory over scattered flat files when related files need repeated prefixes, are usually reviewed together, or become hard to find without their shared parent owner.
- A directory groups ownership; it never justifies an ambiguous file or public symbol name.
- Do not create a directory only because there are many files, two files happen to be adjacent, or a vague bucket such as `common`, `shared`, `state`, or `types` would hide unrelated owners.
- Be skeptical of weak umbrella words unless the local source of truth makes that umbrella the clearest owner.

## Public API And Boundary Ownership

Treat exported and boundary-facing names as contract-owned. Verify that they
use the owner’s established domain terms and describe the actual responsibility
without implying a broader or competing contract. For a non-exported public
top-level declaration, require a precise implementation responsibility and a
concrete consumer-facing failure before flagging its name. Flag placement or
owner first when that is the owning defect.

Apply `Boundary-Owned Policy`: validation and policy should live at the boundary owner rather than being pushed into callers.

## Fixture Placement

Apply `Negative Proof And Fixture Quarantine` when reviewing fixture placement. Fixture-only names, values, schemas, declarations, or data must stay in an approved fixture location unless the governing contract makes them durable product or API data.

## Typical Findings

- A file name points to one concern but contains peer declarations from another owner.
- A grouped file uses an umbrella name where the repository already has a more precise owner.
- A new public or boundary-facing symbol implies a broader or different contract than the responsibility it implements.
- Several flat files share a real owner through repeated prefixes or shared review scope, but the parent directory does not name that owner.
- A new directory collects unrelated files and lacks one clear reason to change.
- A reusable fixture lives outside the repository-approved fixture location.

## Naming Candidate Format

Record candidate findings for Layer 4 synthesis as:

```text
Layer: 3 — Naming, ownership, and cohesion
Priority: [P0/P1/P2/P3]
Location: path:line
Misleading name, placement, or boundary:
Scenario that makes it matter:
Expected ownership direction:
```
