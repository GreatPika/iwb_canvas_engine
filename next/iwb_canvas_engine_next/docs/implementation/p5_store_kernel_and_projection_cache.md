# P5 - store kernel and projection cache

## Build

- CommittedDocument
- ElementRegistry
- FamilyTables
- LayerTable
- SelectionStore
- RevisionState
- DocumentProjectionCache.

## Read first

- `section_02_architecture_model` -> `docs/architecture/01_runtime_ownership.md`
- `section_10_runtime_data_model` -> `docs/architecture/03_data_model.md`

## Required donors

- `store_scene_controller_read_paths` - decision: `adapt`; target owner: DocumentStoreKernel committed read and candidate resolve
- `dto_node_boundary_mapping` - decision: `adapt`; target owner: Codec and store mapping families
- `dto_document_helpers` - decision: `adapt`; target owner: DocumentStoreKernel and EditKernel helpers

## Forbidden donor structure

- `avoid_scene_controller_facades` - decision: `avoid`
- `avoid_interactive_runtime_whole` - decision: `avoid`
- `avoid_scene_builder_public_architecture` - decision: `avoid`
- `avoid_scene_codec_whole` - decision: `avoid`
- `avoid_scene_store_controller_whole` - decision: `avoid`

## Diagrams to read or update

- `c4_component_runtime` -> `docs/diagrams/c4_component_runtime.mmd`
- `c4_container` -> `docs/diagrams/c4_container.mmd`
- `dfd_cache_invalidation` -> `docs/diagrams/dfd_cache_invalidation.mmd`

## Guardrails

- `core.single_runtime_root` - exactly one production RuntimeRoot
- `store.no_public_document_live_state` - store owns compact committed tables, not a live mutable CanvasDocument
- `projection.only_explicit_read_paths` - projection is built only by read/encode/test/tool or explicit draft-read paths

## Tests

- `test.store.read_document_projection` -> `readDocument projection and cache tests`
- `test.store.no_projection_hot_path` -> `no projection in hot path tests`
- `test.store.public_document_is_projection_only` -> `test/store/public_document_is_projection_only_test.dart`

## Exit gate

- readDocument projection matches DTO state
- projection lazy counters pass
- store public document state is projection-only
- no projection in hot path tests pass.
