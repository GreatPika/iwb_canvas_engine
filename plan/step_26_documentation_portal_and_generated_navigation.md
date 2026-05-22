# Change Contract

## Goal

Redesign `docs/` into a task-oriented documentation portal with checked-in
generated navigation, so readers start from stable task routes while reverse
lookups, diagram catalog metadata, and context summaries are derived from
structured owners and checked for staleness. Normative architecture, contract,
verification, donor, implementation, and diagram meaning must remain in
Markdown owners; registries and docs tooling own relationship metadata and
generated Markdown output.

## Evidence

- `.design/2026-05-22-docs-documentation-portal.md` / selected form: the design is `READY_FOR_CONTRACT` and selects Documentation Portal + Generated Navigation -> implement this form rather than reopening the product choice.
- `.design/2026-05-22-docs-documentation-portal.md:17` / product outcome: docs should become easier to enter by task and harder to drift while keeping normative prose in Markdown -> the step must change entrypoints and generated navigation, not rewrite architecture meaning.
- `.design/2026-05-22-docs-documentation-portal.md:121` / successor seam: `docs/indexes/*` manual reverse views must become checked-in generated Markdown from `_registry/sections.yaml`, `_registry/donors.yaml`, `_registry/diagrams.yaml`, and any explicit proof inventory -> generated index ownership is in scope.
- `.design/2026-05-22-docs-documentation-portal.md:123` / locked index set: generated indexes are `by_phase.md`, `by_subsystem.md`, `by_guardrail.md`, `by_test_area.md`, and `donor_to_phase.md` -> no other index remains a stable documentation entrypoint.
- `.design/2026-05-22-docs-documentation-portal.md:131` / context coverage: `context_coverage.md` should move to checks or generated diagnostics -> it must not remain a handwritten entrypoint.
- `.design/2026-05-22-docs-documentation-portal.md:137` / README inventory: only `docs/README.md` and `docs/architecture/README.md` are approved target README files -> the checker must enforce the README inventory.
- `.design/2026-05-22-docs-documentation-portal.md:144` / root portal contract: `docs/README.md` must contain the exact root task-portal content groups -> the root README rewrite has a fixed boundary.
- `.design/2026-05-22-docs-documentation-portal.md:153` / architecture router contract: `docs/architecture/README.md` must contain the exact architecture-router content groups -> architecture README rewrite has a fixed boundary.
- `.design/2026-05-22-docs-documentation-portal.md:162` / diagram catalog migration: `docs/diagrams/README.md` must move to `docs/_registry/diagrams.yaml` plus generated `docs/diagrams/catalog.md`, then be removed after links migrate -> diagram metadata migration order is fixed.
- `.design/2026-05-22-docs-documentation-portal.md:185` / generated state: generated Markdown indexes are derived state and must be checked like existing context capsule generation -> stale-output enforcement is required.
- `.design/2026-05-22-docs-documentation-portal.md:200` / migration order: add and verify generated Markdown indexes before deleting or demoting manual index files; keep old links until successor route exists -> cleanup must come after successor routes are in place.
- `.design/2026-05-22-docs-documentation-portal.md:311` / common generated-docs gate: a single generated-docs command with write and check modes is required, and may delegate to focused tools -> one command must own generated docs freshness.
- `docs/README.md:3` / root source claim: `docs/` is the durable source of truth for the new-engine transition and target architecture -> the root portal remains the documentation entrypoint.
- `docs/README.md:72` / current checks: docs checks currently run context capsule generation and `check_docs.dart` -> the new check path must preserve these existing documentation checks.
- `docs/architecture/README.md:10` / architecture read path: architecture work currently has a local ordered read path -> keeping an architecture README is justified as a router, not a catalog.
- `docs/tool/check_docs.dart:1` / checker boundary: the checker is structural and rejects free-form Markdown wording and Mermaid edge text as invariant sources -> new enforcement must use structural formats, registries, generated markers, or narrow parsers.
- `docs/tool/check_docs.dart:13` / current inputs: docs checks currently parse sections, donors, and `docs/diagrams/README.md` -> the diagram catalog input must move to a diagram registry plus generated catalog.
- `docs/tool/check_docs.dart:65` / current index treatment: `docs/indexes` is scanned as Markdown, not generated or parity-checked -> generated index parity must be added.
- `docs/tool/check_docs.dart:162` / required entrypoints: required files currently include root README, architecture README, registries, and the diagram README catalog -> required entrypoints must change when the generated catalog replaces the diagram README.
- `docs/tool/generate_context_capsules.dart:121` / generation precedent: section registry fields already render into human-readable context blocks -> generated docs tooling can build from registries without moving semantics into YAML.
- `docs/tool/generate_context_capsules.dart:189` / stale-output precedent: `--check` fails when generated context differs from registry output -> generated navigation and diagram catalog must use the same stale-output model.
- `docs/_registry/sections.yaml:2` / section registry shape: section entries own ids and relationship fields including phases, must-read, donors, diagrams, guardrails, tests, and do-not-assume -> section-derived indexes should use this source first.
- `docs/indexes/by_subsystem.md:1` / current subsystem map: subsystem membership exists only as a manual Markdown reverse lookup over section ids -> subsystem membership must move into a structured field before `by_subsystem.md` can be generated.
- `docs/_registry/donors.yaml:2` / donor registry shape: donor records own source paths, decisions, target phases, target owners, tests, blocks, and related sections -> donor reverse navigation should use this registry.
- `docs/donors/00_reuse_rules.md:4` / donor canonical source: donor rules declare `_registry/donors.yaml` canonical -> donor generated maps must not be maintained from donor prose.
- `docs/diagrams/README.md:10` / generated graph precedent: generated graph-backed Mermaid files already declare `architecture_graph.yaml` as source -> diagram catalog generation must preserve the handwritten semantic diagram versus generated topology split.
- `.research/2026-05-22-docs-structure-and-entrypoints.md:16` / drift source: manual reverse-index views are the highest synchronization pressure and current tooling does not generate or semantically validate them -> the implementation must remove this manual seam.
- `.research/2026-05-22-docs-structure-and-entrypoints.md:76` / current verification state: context capsule generation can catch drift that `check_docs.dart` misses -> the common generated-docs gate must close this class of drift.

## Boundaries

Owner:

`docs/` source-of-truth documentation system, specifically `docs/README.md`,
`docs/architecture/README.md`, `docs/_registry/*`, `docs/tool/*`,
checked-in generated Markdown under `docs/indexes/`, and checked-in generated
diagram catalog output at `docs/diagrams/catalog.md`.

In Scope:

- Rewrite `docs/README.md` as the task-oriented root portal with exactly the
  content groups required by the design.
- Rewrite `docs/architecture/README.md` as the architecture local router with
  exactly the content groups required by the design.
- Add `docs/_registry/diagrams.yaml` as the structured owner for diagram id,
  kind, file path, semantic/generated classification, related phases,
  related sections, graph-view source metadata, and any diagram catalog
  metadata currently maintained in Markdown.
- Add one generated-docs command under `docs/tool/` with write and `--check`
  modes that owns freshness for context capsules, generated indexes, generated
  diagram catalog output, and generated graph-view output.
- Generate and check the locked index set under `docs/indexes/`:
  `by_phase.md`, `by_subsystem.md`, `by_guardrail.md`, `by_test_area.md`, and
  `donor_to_phase.md`.
- Add a `subsystems` relationship field to `docs/_registry/sections.yaml` as
  the structured owner for `docs/indexes/by_subsystem.md`; migrate the current
  manual subsystem map into that field before generating the subsystem index.
- Move useful `docs/indexes/context_coverage.md` checks into
  `docs/tool/check_docs.dart` or generated diagnostics, then remove it as a
  documentation entrypoint.
- Generate `docs/diagrams/catalog.md` from `docs/_registry/diagrams.yaml`,
  `docs/_registry/sections.yaml`, and graph-view metadata.
- Use `docs/_registry/diagrams.yaml` as the source for generated index output
  only when a specific index renderer includes diagram metadata; otherwise it
  owns the generated diagram catalog rather than the locked reverse-index set.
- Update `docs/tool/check_docs.dart` to enforce required portal entrypoints,
  README inventory and shape, generated-output markers, registry coverage,
  diagram registry/catalog parity, link validity, and retirement of manual
  reverse-index ownership.
- Update documentation links and source claims only where needed to route to the
  new portal, generated indexes, generated diagram catalog, and generated-docs
  check command.
- Remove `docs/diagrams/README.md` only after the generated catalog exists,
  links have migrated, and checks require the new catalog path.

Out of Scope:

- Rewriting engine architecture, runtime code, public API behavior, schema
  formats, persistence, package boundaries, or implementation phase semantics.
- Moving normative contract, architecture, verification, donor policy, or
  implementation meaning into YAML.
- Parsing free-form architecture prose, contract text, or Mermaid edge text as a
  source of semantic invariants.
- Replacing handwritten semantic Mermaid diagrams or generated graph-backed
  topology views with new diagram semantics.
- Adding a query command as the primary documentation entrypoint; a query
  command may only be convenience over the same registry data if the generated
  Markdown entrypoints remain canonical.
- Creating additional README files under `docs/**` unless a later Change
  Contract proves a complex ordered read path and updates the approved README
  inventory.
- Adding runtime tests for this documentation-only migration unless a docs-tool
  parser or generator needs focused unit coverage.

Source of Truth:

Normative prose remains in `docs/architecture/`, `docs/contracts/`,
`docs/verification/`, `docs/donors/`, `docs/implementation/`, and semantic
diagram files. Relationship metadata lives in `docs/_registry/*`; section
subsystem membership specifically lives in `docs/_registry/sections.yaml` as a
`subsystems` field. Generated indexes and `docs/diagrams/catalog.md` are
derived checked-in Markdown. `docs/tool/*` owns writing and checking generated
documentation output.

During the diagram migration, `docs/_registry/diagrams.yaml` becomes the
structured owner as soon as it is introduced. Until Unit 3 replaces the reader
catalog with `docs/diagrams/catalog.md`, `docs/diagrams/README.md` remains only
as a temporary generated compatibility reader mirror for the existing checker
and old links. It must be rendered from the diagram registry and parity-checked;
it must not remain an independent handwritten catalog source.

Compatibility:

Existing reader routes must remain discoverable until successor generated routes
exist. Public runtime APIs, schema formats, and production package boundaries
must not change. Documentation commands must continue to run from the repository
root. The existing context capsule generation behavior must be preserved or
delegated by the new common generated-docs command.

Order Constraints:

1. Establish structured owners and the generated-docs command before replacing
   reader links or deleting old files. When `docs/_registry/diagrams.yaml` is
   introduced, render `docs/diagrams/README.md` from that registry as a
   temporary compatibility catalog until Unit 3 replaces it.
2. Generate successor indexes and diagram catalog before retiring manual
   reverse-index files or `docs/diagrams/README.md`.
3. Update portal links only after successor outputs exist and are checked.
4. Remove manual-source claims and old entrypoints only after structural checks
   enforce the new inventory.
5. Keep docs verification green after each migration slice that changes
   checked-in generated output or required entrypoints.

## Execution Units

### [x] Unit 1: Generated docs command and diagram registry owner

Owner:

`docs/tool/*` and `docs/_registry/diagrams.yaml`.

Boundary:

Introduce the structured diagram metadata source and the common generated-docs
command without yet deleting existing reader entrypoints.

Change:

Create `docs/_registry/diagrams.yaml` as the structured owner for diagram id,
kind, file path, related phase, related section, semantic/generated
classification, and graph-view source metadata currently maintained in
`docs/diagrams/README.md`. Convert `docs/diagrams/README.md` into a temporary
generated compatibility catalog rendered from `docs/_registry/diagrams.yaml`
for existing links and for the checker path that still expects that file. Add a
single generated-docs command under `docs/tool/` with write and `--check` modes.
The command must delegate to or preserve existing context capsule generation and
must delegate to or wrap `dart run tool/architecture_graph/generate_views.dart --phase P4`
in write mode and
`dart run tool/architecture_graph/generate_views.dart --phase P4 --check` in
check mode. It must fail if the temporary `docs/diagrams/README.md` catalog
differs from the registry-rendered output.

Completion Check:

From the repository root, `dart run docs/tool/sync_generated_docs.dart` writes
the generated outputs, then `dart run docs/tool/sync_generated_docs.dart --check`
exits 0 and reports stale context capsules, generated graph views, or diagram
metadata output as failures. `dart run docs/tool/check_docs.dart` still exits 0
while the old diagram README remains as a temporary generated compatibility
reader route. Because this unit changes Dart docs tooling, `dart analyze`,
`dcm analyze .`, and `dcm calculate-metrics .` also exit 0.

Depends On:

None.

### [x] Unit 2: Generated reverse navigation indexes

Owner:

`docs/tool/*`, `docs/indexes/`, `docs/_registry/sections.yaml`, and
`docs/_registry/donors.yaml`.

Boundary:

Replace manual reverse lookup maintenance with checked-in generated Markdown for
the locked useful index set.

Change:

Add a `subsystems` list field to each section entry in
`docs/_registry/sections.yaml` and migrate the current
`docs/indexes/by_subsystem.md` section-id groupings into that field. Generate
`docs/indexes/by_phase.md`, `docs/indexes/by_subsystem.md`,
`docs/indexes/by_guardrail.md`, `docs/indexes/by_test_area.md`, and
`docs/indexes/donor_to_phase.md` from `docs/_registry/sections.yaml`,
`docs/_registry/donors.yaml`, and the new `subsystems` field. The generated
`docs/indexes/donor_to_phase.md` must include donor id, decision, target
phases, and `target_owner` from `docs/_registry/donors.yaml`. Introduce a
separate structured proof inventory only if a kept generated guardrail or test
index column needs facts that are not present in those registries. Each
generated index must carry a structural generated-output marker that the
generated-docs command can check. Move the useful validation signals from
`docs/indexes/context_coverage.md` into docs tooling or generated diagnostics:
every section entry must have explicit coverage for `must_read`, `donors`,
`diagrams`, `tests`, and `guardrails`, using either concrete ids or explicit
`none`. The `do_not_assume` field remains covered by the generated context
capsule check, because it is registry-owned context text rather than a reverse
lookup dimension. Remove `context_coverage.md` as an entrypoint.

Completion Check:

From the repository root, `dart run docs/tool/sync_generated_docs.dart --check`
fails if any kept `docs/indexes/*.md` file differs from generated output, lacks
the generated marker, or if `docs/indexes/context_coverage.md` remains as a
handwritten entrypoint. `dart run docs/tool/check_docs.dart` exits 0 and
validates that all generated index dimensions have structured owners for
phases, sections, donors, tests, guardrails, and subsystems; subsystem coverage
is checked from the `subsystems` field in `docs/_registry/sections.yaml`, not
from the generated Markdown index. It also validates that
`docs/indexes/donor_to_phase.md` is generated from donor id, decision, target
phases, and `target_owner`, and that `target_owner` remains a required
structured field for donor records. It validates explicit coverage for
`must_read`, `donors`, `diagrams`, `tests`, and `guardrails` on every section
entry, and the generated-docs check preserves `do_not_assume` through context
capsules. Because this unit changes Dart docs tooling, `dart analyze`,
`dcm analyze .`, and `dcm calculate-metrics .` also exit 0.

Depends On:

Unit 1.

### [x] Unit 3: Generated diagram catalog migration

Owner:

`docs/_registry/diagrams.yaml`, `docs/diagrams/catalog.md`, `docs/tool/*`, and
diagram catalog links in documentation.

Boundary:

Move the diagram catalog role from a README file to structured registry data
plus generated catalog output.

Change:

Generate checked-in `docs/diagrams/catalog.md` from
`docs/_registry/diagrams.yaml`, `docs/_registry/sections.yaml`, and graph-view
metadata. Update documentation links, phase diagram references, architecture
routes, and docs checks to use `docs/diagrams/catalog.md` as the catalog path.
Remove `docs/diagrams/README.md` after no link or checker still depends on it.

Completion Check:

From the repository root, `dart run docs/tool/sync_generated_docs.dart --check`
fails when `docs/diagrams/catalog.md` is stale or not generated from the diagram
registry. `dart run docs/tool/check_docs.dart` exits 0 and proves
`docs/tool/check_docs.dart` reads `docs/_registry/diagrams.yaml`, validates
registry/catalog/section symmetry, requires diagram id, kind, file path,
semantic/generated classification, related phases, related sections, and
graph-view source metadata where applicable, rejects orphan or missing `.mmd`
files, and no longer requires or links to `docs/diagrams/README.md`. Because
this unit changes Dart docs tooling, `dart analyze`, `dcm analyze .`, and
`dcm calculate-metrics .` also exit 0.

Depends On:

Unit 1.

### [x] Unit 4: Task portal and architecture router

Owner:

`docs/README.md`, `docs/architecture/README.md`,
`docs/tool/check_docs.dart`, and docs link consumers.

Boundary:

Rewrite approved README files as routers only, after generated successor routes
exist.

Change:

Convert `docs/README.md` into the root task portal with exactly these groups:
title, one short purpose paragraph, `Start by task`, `Source of truth`,
`Checks`, and `Local entrypoints`. Convert `docs/architecture/README.md` into
the architecture local router with exactly these groups: title, one short scope
paragraph, `Read path`, `Work routes`, `Boundary`, and `Checks`. Link routes to
existing normative owners, generated indexes, `docs/diagrams/catalog.md`, and
the common generated-docs check command. Remove README content that duplicates
registries, generated indexes, diagram catalogs, contract text, migration
history, audit notes, or implementation plans.

Completion Check:

From the repository root, `dart run docs/tool/check_docs.dart` exits 0 and
fails if any approved README is missing a required group, contains a forbidden
manual reverse lookup or catalog section, contains any top-level content group
outside the exact allowed group set for that README, or links to a retired
generated-index or diagram-catalog path. `dart run docs/tool/sync_generated_docs.dart --check`
also exits 0 with portal links targeting generated outputs that exist. Because
this unit changes Dart docs tooling, `dart analyze`, `dcm analyze .`, and
`dcm calculate-metrics .` also exit 0.

Depends On:

Units 2 and 3.

### [x] Unit 5: Structural enforcement and retired seam proof

Owner:

`docs/tool/check_docs.dart`, `docs/tool/*`, `docs/indexes/`, `docs/diagrams/`,
and documentation source claims.

Boundary:

Close the migration by making the new source-of-truth boundaries mechanically
enforced and proving old handwritten derivative seams are gone.

Change:

Harden `docs/tool/check_docs.dart` and generated-docs checks so the target docs
tree permits only `docs/README.md` and `docs/architecture/README.md` as README
files, requires generated markers on generated indexes and
`docs/diagrams/catalog.md`, rejects unowned handwritten reverse-index source
claims, rejects old "Feeds indexes" claims outside generated output, validates
all generated output links, and confirms no removed entrypoint remains required.
Update source-of-truth prose only where needed to describe the new enforced
owners and commands.

Completion Check:

From the repository root, these commands exit 0:
`dart run docs/tool/sync_generated_docs.dart --check`,
`dart run docs/tool/check_docs.dart`,
`dart run tool/architecture_graph/generate_views.dart --phase P4 --check`,
`dart analyze`,
`dcm analyze .`, and `dcm calculate-metrics .`. This exact search exits 1:
`rg -n "docs/diagrams/README\\.md|docs/indexes/context_coverage\\.md|Feeds indexes" docs --glob "*.md" --glob "!docs/indexes/by_phase.md" --glob "!docs/indexes/by_subsystem.md" --glob "!docs/indexes/by_guardrail.md" --glob "!docs/indexes/by_test_area.md" --glob "!docs/indexes/donor_to_phase.md" --glob "!docs/diagrams/catalog.md"`.
It proves the retired paths and handwritten "Feeds indexes" source claims are
absent from active handwritten docs while excluding generated outputs and
historical plan/design/research artifacts.

Depends On:

Units 1, 2, 3, and 4.
