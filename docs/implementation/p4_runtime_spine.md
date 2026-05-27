# P4 - runtime spine, store, and projection cache

## Purpose

Create the smallest working runtime spine: one `RuntimeRoot`, committed document
storage, revision facts, public document projection, and narrow read boundaries
that later edit, load, resource, frame, spatial, and interaction phases can use
without bypassing ownership.

## Build scope

- `RuntimeRoot` composition root beyond the P0 skeleton
- disposed-state lifecycle foundation
- `CommittedDocument`
- `ElementRegistry`
- `FamilyTables`
- `LayerTable`
- `SelectionKernel` as the internal runtime owner for selected ids and
  selectionRevision
- `RevisionState`
- public `ValueListenable<CanvasRuntimeState>` state publication foundation
- `DocumentProjectionCache`
- `CanvasRuntime.readDocument`
- `CanvasDocumentSummary`
- `CanvasRuntimeConfig` materialization for runtime-owned services
- runtime id generation backed by next-owned admission state
- narrow immutable document, frame, and selection read/query ports for later
  frame, spatial, resource, and interaction phases
- no edit session, load replacement, paint, resource resolver, pointer routing,
  or Flutter widget behavior yet.

## Dependencies on earlier phases

- P0 package boundaries and single-root guardrail are present.
- Donor registry identifies store/read donors.
- P2 public runtime and DTO API is frozen.
- P3 codec DTO validation exists for later import/load paths.

## Read first

- `section_02_architecture_model` -> `docs/architecture/01_runtime_ownership.md`
- `section_10_runtime_data_model` -> `docs/architecture/03_data_model.md`
- `section_06_validation_limits` -> `docs/contracts/validation_limits.md`
- `section_23_tests` -> `docs/verification/tests.md`

## Required donors

- `store_scene_controller_read_paths` - decision: `adapt`; target owner: DocumentStoreKernel committed read and candidate resolve through immutable query ports
- `dto_node_boundary_mapping` - decision: `adapt`; target owner: Codec and store mapping families
- `dto_document_helpers` - decision: `adapt`; target owner: DocumentStoreKernel, SelectionKernel, and EditKernel helpers

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
- `state_runtime_lifecycle` -> `docs/diagrams/state_runtime_lifecycle.mmd`

## Contracts satisfied by this phase

- runtime ownership and single composition root from `section_02_architecture_model`
- committed document tables, revisions, and projection cache from
  `section_10_runtime_data_model`
- public runtime state snapshot ownership from `section_10_runtime_data_model`
- runtime selection ownership and selectionRevision separation from
  `section_02_architecture_model` and `section_10_runtime_data_model`
- runtime config materialization from public constructor-validated config values,
  including `CanvasDiagnosticsVerbose` limits from `section_06_validation_limits`

## Tests and guardrails that prove this phase

- `test.runtime.dispose_lifecycle` -> `test/runtime/dispose_lifecycle_test.dart`
- `test.store.read_document_projection` -> `test/store/read_document_projection_test.dart`
- `test.selection.runtime_owner_separation` -> `test/selection/runtime_owner_separation_test.dart`
- `test.store.no_projection_hot_path` -> `test/store/no_projection_hot_path_test.dart`
- `test.store.public_document_is_projection_only` -> `test/store/public_document_is_projection_only_test.dart`
- `core.single_runtime_root`
- `store.no_public_document_live_state`
- `selection.owner_separate_from_document`
- `projection.only_explicit_read_paths`

## Exit gate

- runtime can be constructed and disposed without legacy runtime dependency
- runtime dispose leaves `state.value` readable, does not increment document
  revision, and delivers no public state notifications after dispose returns
- runtime state holder can produce coherent `CanvasRuntimeState` snapshots from
  owner-provided revision facts, while edit/load/interaction publication proof
  remains owned by later phases
- runtime config materialization preserves already-validated
  `CanvasDiagnosticsVerbose` preview and list-entry limits without pulling
  schema/codec ownership into RuntimeRoot
- `readDocument` projection matches committed DTO state
- projection lazy counters pass
- store public document state is projection-only
- later owners can obtain committed facts only through narrow immutable
  `contracts/internal/**` query ports, including `FrameFactsPort` for frame
  capture, row resolution, and descriptor snapshots, not concrete store tables
- later owners can obtain selection facts only through narrow immutable query
  ports, not concrete selection-owner internals
- `test/store/no_projection_hot_path_test.dart` passes.

## Risks and trade-offs

- Building too much runtime behavior here would create a hidden infrastructure
  phase. P4 must stop at runtime composition, config materialization, storage,
  revisions, projection, and read boundaries.
- Building too little would force later phases to bypass store ownership.

## Why this phase belongs here

Edit, load, resources, geometry, frame, and interaction all need committed
state, selection state, revisions, and read-only facts. This spine must exist
before feature phases can be implemented without direct cross-owner shortcuts.
