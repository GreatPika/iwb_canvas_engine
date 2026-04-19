---
name: maintain-readme-md
description: Maintain `README.md`. Use when creating, updating, auditing, or reviewing the package landing page; when changes affect package scope, requirements, installation, supported imports, quick start, common integration points, hosted-doc links, or other first-contact user documentation.
---

# Maintain README.md

Treat `README.md` as the package landing page for first-time evaluators and integrators.
Do not treat it as a full API reference, architecture spec, release log, or design diary.

## Outcome

Produce a `README.md` that is:

- accurate to the checked-in main branch
- concise enough to stay scannable on GitHub and pub.dev
- useful to a developer deciding whether and how to adopt the package
- explicit about supported entrypoints and non-goals
- synchronized with the rest of the repository documentation map

## Source of truth

Read these sources before editing README content:

1. `AGENTS.md`
2. the current `README.md`
3. `pubspec.yaml`
4. `lib/iwb_canvas_engine.dart`
5. `tool/goldens/public_api_symbols.txt`
6. `tool/check_public_api_surface.dart`
7. `example/README.md` and any example code you plan to reference
8. affected files under `lib/src/**` only as evidence for current behavior
9. `API_GUIDE.md` only to avoid duplication, not as the primary source of truth
10. `CHANGELOG.md` only for release wording or historical context, not as the README source of truth

When code, tools, tests, and documentation disagree, prefer checked-in code and mechanical enforcement.

## Work mode

Classify the task before editing.

### 1. Narrow sync

Use this mode when the change is local:

- package summary wording is stale
- requirements changed
- installation or hosted-doc links changed
- supported import wording changed
- one quick-start symbol or one integration note changed

Patch only the affected sections.
Do not rewrite the whole file.

### 2. Section refresh

Use this mode when one landing-page area changed materially:

- package scope or non-goals shifted
- the quick start is no longer representative
- core concepts or serialization rules changed enough that the section reads awkwardly
- common integration points changed

Rewrite only the affected section group so it reads cleanly as a whole.
Do not append disclaimers line by line if a short rewrite is cleaner.

### 3. Full rebuild

Use this mode only when:

- the current README is missing major landing-page sections
- multiple sections are stale or contradictory
- the user explicitly asks for a full rewrite

For a rebuild, start from `assets/README-template.md` and fill it from repository evidence.

Default to the smallest mode that preserves clarity.

## Section contract

Preserve the current top-level structure unless the package contract has genuinely outgrown it.
Do not add new top-level sections casually.

### Title and opening summary

Keep the package title first.
Use a short one-paragraph summary that states what the package is and what it provides.
Optional badges are allowed only when they point to real package or CI URLs and stay minimal.

### `## What the package includes`

List the supported package-level capabilities.
Use public contract terms such as `SceneSnapshot`, `SceneController`, `SceneView`, `SceneWriteTxn`, `SceneBuilder`, and `encodeScene*` / `decodeScene*` when they are central to the package story.
Do not turn this section into an exhaustive API dump.

### `## What the package does not include`

List explicit non-goals that prevent incorrect adoption assumptions.
Prefer product-boundary statements such as app UI, backend logic, sync, and app-level history storage.

### `## Requirements`

Take Dart and Flutter constraints from `pubspec.yaml`.
Do not claim platforms, SDK ranges, or runtime assumptions that the repository does not currently support.

### `## Installation`

Keep this short.
Show the canonical package install command only.
Do not add unrelated setup steps unless the package truly requires them.

### `## Supported import`

Show the single supported public import.
State clearly that `src/**` imports are unsupported internal detail.

### `## Quick start`

Keep one minimal example that reflects the supported public surface.
The example must:

- use only `package:iwb_canvas_engine/iwb_canvas_engine.dart`
- use currently exported public symbols
- compile in principle for a normal Flutter integration
- stay short enough to scan quickly

Prefer a single happy-path example over a feature tour.

### `## Core concepts`

Summarize the package model in a few bullets.
Cover only the concepts an adopter needs early: immutable scene documents, layer model, node families, runtime root, view, transactions, import/export, and stable error handling.

### `## Serialization and validation`

Record the current public schema facts and validation expectations that are important during adoption.
Do not dump every codec rule here; keep deeper detail in `API_GUIDE.md`.

### `## Common integration points`

List the host-facing hooks that integrators are likely to need first.
Typical examples include action streams, text-edit requests, image resolution, and repaint notifications for host-owned visual resources.

### `## Documentation`

Link only to real, maintained documents or hosted docs.
Keep this section as the map to deeper material.

### `## License`

State the current repository license and link to `LICENSE`.

## Writing rules

Follow these rules on every edit.

1. Describe the checked-in main branch, not a hypothetical future package.
2. Write for package evaluators and integrators, not for maintainers already deep in the codebase.
3. Use exact public type and symbol names from the supported surface.
4. Prefer direct statements like `provides`, `supports`, `does not support`, `use`, and `do not import`.
5. Keep paragraphs short and prefer compact bullet lists where they improve scanability.
6. Replace stale text instead of stacking exceptions after it.
7. Keep one canonical explanation for each concept; do not repeat the same explanation across sections.
8. Keep performance, compatibility, and behavioral claims conservative unless the repository has hard evidence.
9. Keep quick-start code short enough to be copied mentally.
10. Keep the file compact. If a detail belongs in `API_GUIDE.md`, move it there conceptually instead of expanding the README.

## Anti-bloat rules

Never add:

- exhaustive symbol inventories
- architecture layer diagrams or deep module-boundary discussion
- release history or unreleased change lists
- roadmap items or TODOs
- large migration sections
- internal file paths unless they are the supported public import path
- implementation chronology
- filler paragraphs that restate the package summary in softer wording

When a section starts to feel crowded, delete stale detail before adding new text.

## Cross-document boundaries

Respect the documentation split:

- `README.md` owns package overview, scope, requirements, installation, quick start, and the documentation map
- `API_GUIDE.md` owns public API reference, runtime semantics, schema details, error model, and migration-facing detail
- `ARCHITECTURE.md` owns structure, ownership, invariants, and enforcement
- `CHANGELOG.md` owns released and unreleased user-visible changes
- `PLAN.md` owns future work and execution tracking

If a requested change belongs primarily in another document, update `README.md` only where the landing-page contract actually changed.

## Synchronization rules

Apply these linked updates together.

- If package scope, public runtime roots, or primary entrypoints change, review the opening summary, `What the package includes`, `Supported import`, `Core concepts`, and `Documentation` together.
- If Dart or Flutter constraints change, review `Requirements` and `Installation` together.
- If the preferred onboarding path changes, review `Quick start`, `Core concepts`, and `Common integration points` together.
- If the schema or public error contract changes, review `Core concepts` plus `Serialization and validation` together.
- If hosted docs, example docs, or repository docs move, update `Documentation` in the same edit.
- If a quick-start example symbol is no longer exported, update the example before finalizing the README.

## Repository-specific signals

For `iwb_canvas_engine`, keep these signals especially tight:

- The only supported public import is `package:iwb_canvas_engine/iwb_canvas_engine.dart`.
- The package is Flutter-first and not a pure Dart engine.
- `SceneSnapshot` is the immutable public document boundary.
- Public scene data uses a dedicated `backgroundLayer` plus ordered content `layers`.
- `SceneController` is the public runtime root, `SceneView` is the preferred host widget, and `SceneWriteTxn` is the transactional write surface.
- `SceneBuilder`, `encodeScene*`, and `decodeScene*` are the supported import/export entrypoints.
- `SceneDataException` and `SceneDataErrorCode` are the stable machine-readable scene-data failure contract.
- The package does not own app UI, persistence, sync/collaboration, or app-level undo/redo storage.

If repository evidence no longer supports any of these statements, update the README carefully and consistently rather than preserving old wording.

## Editing discipline

Before finalizing, run this checklist.

- Every changed statement is backed by current repository evidence.
- `Requirements` and hosted-doc links still match `pubspec.yaml`.
- The quick start uses only supported public imports and currently exported symbols.
- The package summary and non-goals agree with `AGENTS.md` and the checked-in codebase.
- No `src/**` detail is presented as supported integration surface.
- No section drifted into API reference, architecture, roadmap, or changelog territory.
- The file stayed concise and easy to scan.

If uncertain, leave the README narrower and more conservative rather than more expansive.
