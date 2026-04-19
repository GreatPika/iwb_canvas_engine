---
name: maintain-architecture-md
description: Maintain `ARCHITECTURE.md`. Use when creating, updating, auditing, or reviewing the architecture document; when changes affect the package boundary, public barrel exports, schema versions, layer DAG, runtime seams, rendering or interaction ownership, execution flows, invariants, or architecture guardrails.
---

# Maintain ARCHITECTURE.md

Treat `ARCHITECTURE.md` as a maintained architectural contract for contributors.
Do not treat it as a tutorial, release note, migration guide, or design diary.

## Outcome

Produce an `ARCHITECTURE.md` that is:

- accurate to the checked-in repository state
- concise enough to stay navigable
- normative about ownership and boundaries
- explicit about architecture-critical invariants and enforcement
- consistent with the rest of the repository documentation map

## Source of truth

Read these sources before editing architecture content:

1. `AGENTS.md`
2. the current `ARCHITECTURE.md`
3. `lib/iwb_canvas_engine.dart`
4. affected files under `lib/src/**`
5. `tool/invariant_registry.dart`
6. `tool/check_import_boundaries.dart`
7. `tool/check_guardrails.dart`
8. architecture-facing tests under `test/**`
9. `API_GUIDE.md` only to avoid duplication, not as the primary source of truth

When code, tools, tests, and documentation disagree, prefer checked-in code and mechanical enforcement.

## Work mode

Classify the task before editing.

### 1. Narrow sync

Use this mode when the change is local:

- a public export changed
- a schema version changed
- a file or type name changed
- one layer responsibility shifted without restructuring the whole document
- one invariant or enforcement entry changed

Patch only the affected sections.
Do not rewrite the whole file.

### 2. Section refresh

Use this mode when one architectural area changed materially:

- layer DAG or allowed dependencies
- controller, interaction, render, serialization, or view seam ownership
- execution flow shape
- enforcement model

Rewrite only the affected section group so it reads cleanly as a whole.
Do not append caveats line by line if a short rewrite is cleaner.

### 3. Full rebuild

Use this mode only when:

- the current document is missing major sections
- multiple sections are stale or contradictory
- the user explicitly asks for a full rewrite

For a rebuild, start from `assets/ARCHITECTURE-template.md` and then fill it from repository evidence.

Default to the smallest mode that preserves clarity.

## Section contract

Preserve the current top-level structure unless the architecture has genuinely outgrown it.
Do not add new top-level sections casually.
Keep numbering stable.

### `## 1. Purpose`

State what the document is for, who it serves, and which repository artifacts define the real source of truth.
Keep this short.

### `## 2. Package boundary`

Record:

- the public package entrypoint
- schema read and write versions
- what the package owns
- what the package explicitly does not own

Do not put usage instructions here.

### `## 3. Architectural goals`

Keep only durable goals that shape design decisions.
Do not list temporary implementation preferences or roadmap items.
Prefer three to six goals.

### `## 4. Public API map`

Summarize the public architectural surface exported from `lib/iwb_canvas_engine.dart`.
Group symbols by responsibility.
Do not turn this section into full API reference documentation.
Do not list internal `src/**` symbols as supported public API.

### `## 5. Core architectural model`

Explain only the design-defining model splits and major seams, such as:

- immutable public boundary vs mutable runtime state
- canonical document shape
- read side vs write side
- host/runtime seam

Do not explain low-level helper classes unless they change the architectural model.

### `## 6. Layered architecture`

Keep this section strict and synchronized.
It must contain:

- the top-level layer table
- allowed dependency directions
- the Mermaid dependency graph
- the most important boundary rules
- any narrow exceptions that are intentionally allowed

If the layer table changes, update the graph and rules in the same edit.

### `## 7. Runtime building blocks`

Describe only top-level runtime owners, adapters, and read or write boundaries.
For each building block, explain its architectural responsibility, not its full method list.

### `## 8. Main execution flows`

Describe only architecture-significant flows.
Typical examples include:

- build or import
- committed write or transaction flow
- pointer or interaction flow
- paint flow
- serialization flow

Prefer five to eight short flows over exhaustive event narration.

### `## 9. Cross-cutting invariants`

Document durable invariants that contributors must not violate.
Prefer invariants that are mechanically enforced or explicitly covered by tests.
Keep them phrased as constraints, not aspirations.

### `## 10. Mechanical enforcement`

List the tools and tests that back the architecture.
Name exact files or categories that enforce the contract.
Do not copy large test inventories; summarize the enforcement surfaces.

### `## 11. Extension guidance`

State where new work should go, which seams are safe to extend, and which directions are forbidden.
This section should reduce architectural drift during feature work.

### `## 12. Decision records`

Link to ADRs if they exist.
If there are no ADRs, say so directly and briefly.
Do not invent rationale that is not recorded anywhere.

### `## 13. Summary`

End with a short synthesis of the architecture as it exists today.
Do not repeat the whole document.

## Writing rules

Follow these rules on every edit.

1. Describe the current checked-in state, not a possible future state.
2. Prefer direct statements like `owns`, `depends on`, `must`, `must not`, `exposes`, `does not expose`.
3. Use exact type, file, and layer names from the repository.
4. Prefer short paragraphs, tables, and compact bullet lists over essay-style prose.
5. Keep the document architecture-level. Remove details that belong in `API_GUIDE.md`, `README.md`, or code comments.
6. Replace stale text instead of stacking new exceptions after it.
7. Keep terminology stable across sections.
8. Keep one canonical explanation for each major concept. Cross-reference mentally; do not duplicate the same explanation in multiple sections.
9. Prefer grouped summaries over long symbol dumps.
10. Keep the document compact. Do not grow it substantially unless the architecture actually became more complex or the file was previously missing critical coverage.

## Anti-bloat rules

Do not let the document turn into a catch-all notes file.

Never add:

- TODO lists
- roadmap items
- release history
- migration instructions
- end-user examples
- speculative future architecture
- motivational filler
- glossary material for common Dart or Flutter concepts
- paragraphs that restate the same point in softer wording

When a section starts to feel crowded, delete stale detail before adding new text.

## Cross-document boundaries

Respect the documentation split:

- `README.md` owns package overview and getting started
- `API_GUIDE.md` owns public behavior, semantics, and migration-facing detail
- `CHANGELOG.md` owns released and unreleased user-visible changes
- `PLAN.md` owns future work and execution tracking
- `ARCHITECTURE.md` owns stable structure, ownership, dependencies, invariants, and enforcement

If a requested change belongs primarily in another document, update `ARCHITECTURE.md` only where the architecture contract actually changed.

## Synchronization rules

Apply these linked updates together.

- If the public barrel changes, review `## 2. Package boundary` and `## 4. Public API map` together.
- If schema versions change, review `## 2. Package boundary`, `## 5. Core architectural model`, and any serialization notes that mention compatibility.
- If layer ownership or allowed imports change, review all of `## 6. Layered architecture` together.
- If controller, interaction, render, or view seams change, review `## 5`, `## 7`, and the affected execution flows in `## 8` together.
- If invariants change in `tool/invariant_registry.dart`, review `## 9. Cross-cutting invariants` and `## 10. Mechanical enforcement` together.
- If a new tool or guardrail becomes architecture-critical, add it to `## 10. Mechanical enforcement`.
- If extension points or forbidden dependency directions change, update `## 11. Extension guidance`.

## Repository-specific architecture signals

For `iwb_canvas_engine`, keep these signals especially tight:

- The only supported public package import is `package:iwb_canvas_engine/iwb_canvas_engine.dart`.
- The top-level layer set is `contract`, `core`, `model`, `controller`, `interactive`, `render`, `serialization`, and `view`.
- `contract` owns the public boundary.
- `model` owns canonicalization and snapshot or runtime mapping.
- `controller` owns committed store and transactional write orchestration.
- `interactive` is the public controller-side runtime and must stay model-free.
- `render` is read-only.
- `view` is the Flutter host shell and should cross the architecture through runtime seams, not by reopening internal ownership directly.
- `tool/invariant_registry.dart`, `tool/check_import_boundaries.dart`, and `tool/check_guardrails.dart` are first-class architectural evidence, not incidental tooling.

If repository evidence no longer supports any of these statements, update the document carefully and consistently rather than preserving old wording.

## Editing discipline

Before finalizing, run this checklist.

- Every changed statement is backed by current repository evidence.
- No internal implementation detail was promoted to architecture importance without a clear reason.
- No public API claim includes private `src/**` details as if they were supported surface.
- The layer table, dependency graph, and boundary rules agree with each other.
- The runtime building blocks and execution flows use the same ownership model.
- Invariants and enforcement sections still align with the registry and tools.
- The document stayed concise and readable.
- Section numbering and headings stayed stable unless a structural rewrite was genuinely necessary.

If uncertain, leave the document narrower and more conservative rather than more expansive.
