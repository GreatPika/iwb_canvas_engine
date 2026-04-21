---
name: api-guide-sync
description: Maintain `API_GUIDE.md`. Use when creating, updating, auditing, or reviewing the public API guide; when changes affect the supported import surface, exported symbols, document model, runtime behavior, `SceneView`, transactions, schema/serialization contract, error model, or migration guidance.
---

# Maintain API_GUIDE.md

Treat `API_GUIDE.md` as the normative integration guide for the supported public package surface.
Do not treat it as a dartdoc dump, architecture essay, changelog, or internal source tour.

## Outcome

Produce an `API_GUIDE.md` that is:

- accurate to the current supported public surface
- synchronized with the public barrel and public API golden
- explicit about runtime semantics, schema rules, and failure contracts
- concise enough to stay usable as an integration reference
- consistent with the repository documentation split

## Source of truth

Read these sources before editing API-guide content:

1. `AGENTS.md`
2. the current `API_GUIDE.md`
3. `lib/iwb_canvas_engine.dart`
4. `tool/goldens/public_api_symbols.txt`
5. `tool/check_public_api_surface.dart`
6. affected public contract files under `lib/src/contract/**`
7. affected public runtime files under `lib/src/interactive/**`, `lib/src/view/**`, `lib/src/model/scene_builder_api.dart`, and `lib/src/serialization/**`
8. relevant public-facing tests under `test/public_api/**`, `test/serialization/**`, `test/controller/**`, `test/interactive/**`, `test/view/**`, and `test/entrypoints/**`
9. `README.md`, `ARCHITECTURE.md`, and `CHANGELOG.md` only to avoid duplication or wording drift, not as the primary source of truth

When code, tools, tests, and documentation disagree, prefer checked-in code, public exports, and mechanical enforcement.

## Work mode

Classify the task before editing.

### 1. Narrow sync

Use this mode when the change is local:

- one exported symbol changed
- one constructor parameter or method contract changed
- one schema fact changed
- one error code or one runtime note changed
- one example or migration bullet is stale

Patch only the affected sections.
Do not rewrite the whole file.

### 2. Section refresh

Use this mode when one contract area changed materially:

- document model
- write model or patch semantics
- runtime integration
- `SceneView` behavior
- transactions
- serialization or error model
- migration guidance

Rewrite only the affected section group so it reads cleanly as a whole.
Do not append caveats line by line if a short rewrite is cleaner.

### 3. Full rebuild

Use this mode only when:

- the guide is missing major integration sections
- multiple sections are stale or contradictory
- the public barrel changed so much that the current guide no longer maps cleanly
- the user explicitly asks for a full rewrite

For a rebuild, start from `assets/API_GUIDE-template.md` and fill it from repository evidence.

Default to the smallest mode that preserves clarity.

## Section contract

Preserve the current numbered top-level structure unless the public contract has genuinely outgrown it.
Keep numbering stable.
Do not add new top-level sections casually.

### `## 1. Support policy`

State the supported import and the package-scope ownership rules.
Record the current schema write version and read set if they are public contract.
Keep this section policy-level and short.

### `## 2. Public API map`

Summarize the exported public surface grouped by responsibility.
Base this section on `lib/iwb_canvas_engine.dart` and the public API golden.
Do not list internal `src/**` symbols as supported API.

### `## 3. Scene document model`

Document the stable public document boundary.
Cover root snapshot shape, layer model, node families, and any document-model rules an integrator must know early.

### `## 4. Creating and updating scene data`

Explain the supported creation and patch model.
Cover `NodeSpec`, `NodePatch`, `PatchField`, and validated value objects only to the depth needed for correct integration.

### `## 5. Runtime integration`

Document `SceneController` and its public owned subsurfaces.
Group behavior by `controller.scene`, `controller.selection`, `controller.interaction`, and event delivery.
Prefer meaning and contract over exhaustive member dumps.

### `## 6. \`SceneView\``

Document the supported host widget contract and its relationship to the runtime.
Keep this section focused on integrator-facing behavior.

### `## 7. Transactions with \`SceneWriteTxn\``

Document the transactional write boundary.
Call out lifecycle, sync-only callback rules, state visibility, and high-value transaction verbs.

### `## 8. Serialization and import`

Document the supported builders and codecs, current schema facts, validation behavior, and canonicalization guarantees.

### `## 9. Error model`

Document the stable public error taxonomy.
Be explicit about when callers should expect `ArgumentError`, `StateError`, or `SceneDataException`.

### `## 10. Migration notes for older integrations`

Keep this section short and action-oriented.
List only still-relevant adaptation steps from older public integrations.
Do not turn it into full historical release notes.

### `## 11. Minimal integration example`

Keep one minimal example that reflects the current supported public surface.
The example must use only the supported public import and currently exported symbols.

## Writing rules

Follow these rules on every edit.

1. Document only the supported public surface exported from `lib/iwb_canvas_engine.dart`.
2. Use the public API golden as a mechanical check that the symbol map is still correct.
3. Use exact public type, method, and property names from the repository.
4. Describe behavior, ownership, and failure semantics; do not narrate internal file layout or helper-class history.
5. Prefer grouped tables and compact bullet lists over long prose.
6. Replace stale text instead of stacking exceptions after it.
7. Keep one canonical explanation for each public concept.
8. Keep schema versions, runtime lifecycle rules, and error semantics explicit when they are part of the contract.
9. Keep migration notes limited to still-useful public deltas.
10. Keep the file compact. If a detail belongs in dartdoc or deep architecture discussion, do not expand the guide to hold it.

## Anti-bloat rules

Never add:

- unsupported internal `src/**` imports or symbols
- exhaustive per-member documentation for every trivial getter
- architecture-layer commentary that belongs in `ARCHITECTURE.md`
- release history or issue chronology
- roadmap notes or speculative future API
- large blocks of copied implementation detail
- duplicate explanations already covered in nearby sections

When a section starts to feel crowded, delete stale detail before adding new text.

## Cross-document boundaries

Respect the documentation split:

- `README.md` owns package overview, setup, quick start, and the documentation map
- `API_GUIDE.md` owns supported public API, runtime semantics, schema/codec rules, error model, and migration-facing detail
- `ARCHITECTURE.md` owns structure, boundaries, invariants, and enforcement
- `CHANGELOG.md` owns release history and user-visible change tracking
- `PLAN.md` owns future work and execution tracking

If a requested change belongs primarily in another document, update `API_GUIDE.md` only where the public integration contract actually changed.

## Synchronization rules

Apply these linked updates together.

- If the public barrel or API golden changes, review `## 1. Support policy`, `## 2. Public API map`, and every affected deep section together.
- If snapshot/spec/patch types or semantics change, review `## 2`, `## 3`, `## 4`, and the minimal example together.
- If `SceneController`, selection, interaction, scene, or async delivery changes, review `## 2`, `## 5`, `## 6`, `## 7`, and the minimal example together.
- If serialization entrypoints, schema versions, or validation behavior change, review `## 1`, `## 8`, `## 9`, and `## 10` together.
- If the supported error contract changes, review `## 8`, `## 9`, and any migration guidance together.
- If the only supported public import or package boundary policy changes, review `## 1`, `## 2`, `## 10`, and `## 11` together.

## Repository-specific signals

For `iwb_canvas_engine`, keep these signals especially tight:

- The only supported import is `package:iwb_canvas_engine/iwb_canvas_engine.dart`.
- The supported public surface is the exported symbol set from `lib/iwb_canvas_engine.dart`, mechanically mirrored by `tool/goldens/public_api_symbols.txt`.
- `SceneSnapshot` is the immutable public document boundary.
- Public scene data uses a dedicated `backgroundLayer` plus content-only `layers`.
- `NodeSpec`, `NodePatch`, and `PatchField` are the public creation/update model.
- `SceneController` is the public runtime root, with `scene`, `selection`, and `interaction` as public owned subsurfaces.
- `SceneView` is the preferred host widget surface.
- `SceneWriteTxn` is valid only inside the active synchronous `write(...)` callback.
- `SceneBuilder`, `encodeScene*`, `decodeScene*`, `schemaVersionWrite`, and `schemaVersionsRead` are public serialization/import contract.
- `SceneDataException.code`, `path`, and `details` are the machine-readable scene-data failure contract.

If repository evidence no longer supports any of these statements, update the guide carefully and consistently rather than preserving old wording.

## Editing discipline

Before finalizing, run this checklist.

- Every changed statement is backed by current repository evidence.
- `## 2. Public API map` agrees with `lib/iwb_canvas_engine.dart` and `tool/goldens/public_api_symbols.txt`.
- No unsupported internal `src/**` symbol is presented as supported public API.
- Schema facts and error-model claims agree with the current code and tests.
- The minimal example uses only supported public imports and currently exported symbols.
- Migration guidance is still relevant to real older integrations and is not just copied changelog history.
- The file stayed concise, structured, and readable.

If uncertain, leave the guide narrower and more conservative rather than more expansive.
