# Store And Commit Path

## Purpose

This family defines which owners may hold committed scene state, expose
committed reads, and execute transactional writes.

The checked-in code already keeps committed state in the store family and
routes transactional writes through a dedicated commit runtime.

## Target Rules

- `SceneStoreController` remains the committed store facade for snapshot reads,
  committed queries, and write entrypoints.
- `SceneControllerCommitRuntime` remains the write kernel that owns
  transactional execution, commit planning, and post-commit lifecycle.
- `TxnContext` remains the copy-on-write workspace for transactional writes.
- Interaction and view families may consume committed reads, but they do not
  become committed scene owners.

## Owners

- Low-level committed state carrier:
  `lib/src/controller/store.dart`
- Committed store facade:
  `lib/src/controller/scene_store_controller.dart`
- Write kernel and commit lifecycle:
  `lib/src/controller/scene_controller_commit_runtime.dart` and
  `lib/src/controller/scene_controller_commit_write_runner.dart`
- Transaction workspace:
  `lib/src/controller/txn_context.dart`
- Interaction-side adapter into the store family:
  `lib/src/controller/scene_controller_committed_mutation_access.dart`

## Forbidden Shapes

- Do not let interaction or view owners hold committed scene state directly.
- Do not create a second committed-write kernel outside
  `SceneControllerCommitRuntime`.
- Do not let the store facade absorb interaction-side gateway behavior or view
  responsibilities.

## Mechanical Evidence

- `dart run tool/lsp_trace_symbol.dart lib/src/interactive/scene_controller_scene.dart SceneControllerSceneOwner.replaceScene --direction=outgoing --depth=5 --json-out=docs/target_architecture/evidence/replace_scene_write_flow.json --mermaid-out=docs/target_architecture/evidence/replace_scene_write_flow.md`
  Evidence:
  [replace_scene_write_flow.json](../evidence/replace_scene_write_flow.json),
  [replace_scene_write_flow.md](../evidence/replace_scene_write_flow.md)

## Status

- `locked, needs slimming`
- The store/write split is stable, but `SceneStoreController` remains the most
  obvious local slimming target inside the family.
