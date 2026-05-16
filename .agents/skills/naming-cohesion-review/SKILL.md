---
name: naming-cohesion-review
description: Focused review pass for naming and file cohesion. Use when a code review, PR, or implementation needs an explicit check for misleading file names, declarations placed under the wrong owner, or fixture placement drift.
---

# Naming Cohesion Review

Run this after the normal code-review context is loaded. Do not replace the
repository naming rules; apply them to the current diff.

## Workflow

1. Compare the changed file list with the active plan, package layout, and
   relevant contracts.
2. For each new or renamed file, ask: "What is this file's single reason to
   change?" Then check whether its declarations all share that reason.
3. Treat public API symbol names as contract-owned. Flag their placement or file
   owner first; flag the symbol name only when the source of truth itself is
   being changed or contradicted.
4. Report only actionable naming/cohesion findings, not taste preferences.

## Decision Test

- If a file has one clear public owner, its name should match that owner or the
  exact responsibility it represents.
- If a file groups declarations, the name should describe the shared
  responsibility, not one arbitrary member.
- Keep small companion declarations together only when they are normally
  consumed together and still have one reason to change.
- Prefer a split when multiple public or boundary-facing declarations could
  reasonably evolve independently.
- Be skeptical of weak umbrella words unless the local source of truth makes
  that umbrella the clearest owner.

## Typical Findings

- A file name points to one concern but contains peer declarations from another
  owner.
- A grouped file uses an umbrella name where the repository already has a more
  precise owner.
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
