---
name: naming-cohesion-review
description: Focused review pass for naming and file cohesion. Use when a code review, PR, or implementation needs an explicit check for misleading file names, declarations placed under the wrong owner, or fixture placement drift. Can run after code-review or standalone by loading the current diff and relevant contracts first.
---

# Naming Cohesion Review

Run this after the normal code-review context is loaded when available. When
invoked standalone, first load the current diff, changed file list, active plan,
linked contracts, and relevant local naming/source-of-truth rules before
reviewing. Do not replace repository naming rules; apply them to the reviewed
diff.

Use `Source-Of-Truth Singularity` when naming or placement depends on a
governing local source of truth: durable meaning has one owner, duplicate truth
requires an explicit cache/performance invariant and proof strategy, and the
artifact must have a real human or machine consumer.

## Workflow

1. When invoked standalone, inspect the current diff, changed file list, active
   plan, linked contracts, and relevant source-of-truth rules before judging
   names.
2. Compare the changed file list with the active plan, package layout, linked
   contracts, and source-of-truth docs that govern the touched area.
3. For each new or renamed file, ask: "What is this file's single reason to
   change?" Then check whether its declarations all share that reason.
4. For each new or renamed directory, ask: "What stable owner or subdomain does
   this directory introduce?" Then check whether its immediate children are
   facets of that owner instead of unrelated files collected for neatness.
5. Treat public API symbol names as contract-owned. Flag their placement or file
   owner first under `Boundary-Owned Policy`; flag the symbol name only when the
   source of truth itself is being changed or contradicted.
6. Report only actionable naming/cohesion findings, not taste preferences.

## Decision Test

- Apply `Owner-Level Fix`: if a file has one clear public owner, its name should
  match that owner or the exact responsibility it represents.
- If a file groups declarations, the name should describe the shared
  responsibility, not one arbitrary member.
- Keep small companion declarations together only when they are normally
  consumed together and still have one reason to change.
- Prefer a split when multiple public or boundary-facing declarations could
  reasonably evolve independently.
- Create a directory when several files share a stable owner, lifecycle,
  dependency boundary, or source-of-truth contract, and each child file names a
  distinct facet of that owner.
- Prefer a directory over scattered flat files when related files need repeated
  prefixes, are usually reviewed together, or become hard to find without their
  shared parent owner.
- Do not create a directory only because there are many files, two files happen
  to be adjacent, or a vague bucket such as `common`, `shared`, `state`, or
  `types` would hide unrelated owners.
- Be skeptical of weak umbrella words unless the local source of truth makes
  that umbrella the clearest owner.

## Typical Findings

Apply `Negative Proof And Fixture Quarantine` when reviewing fixture placement:
fixture-only names, values, schemas, declarations, or data must stay in an
approved fixture location unless the governing contract makes them durable
product/API data.

- A file name points to one concern but contains peer declarations from another
  owner.
- A grouped file uses an umbrella name where the repository already has a more
  precise owner.
- Several flat files share a real owner through repeated prefixes or shared
  review scope, but the parent directory does not name that owner.
- A new directory collects unrelated files and lacks one clear reason to change.
- A reusable fixture lives outside the repository-approved fixture location.

## Review Output

When reporting issues, use code-review style findings:

```markdown
Findings

[P2] path/to/file.dart:31 Explain why the name or file boundary is misleading, name the scenario that makes it matter, and point to the expected ownership direction without writing a patch.
```

If there are no actionable issues:

```markdown
Findings

No findings.
```
