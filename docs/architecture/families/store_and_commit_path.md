# Store And Commit Path

## Purpose

This family defines which owners may hold committed scene state, expose
committed reads, and execute transactional writes.

The checked-in code already keeps committed state in the store family and
routes transactional writes through a dedicated commit runtime.

## Target Rules

- `SceneStoreController` remains the committed store facade for snapshot reads,
  revision metadata, signals, debug projection, committed queries, and write
  entrypoints.
- `SceneStoreController` does not expose `SceneCommands`, `MoveCommands`, or
  `DrawCommands` as facade-owned public fields.
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
- Do not reintroduce command-owner bags on `SceneStoreController`; direct
  command-owner construction around `writeWithSceneWriter` is the successor
  seam.

## Mechanical Evidence

- `dart run tool/lsp_trace_symbol.dart lib/src/interactive/scene_controller_scene.dart SceneControllerSceneOwner.replaceScene --direction=outgoing --depth=5 --json-out=docs/architecture/evidence/replace_scene_write_flow.json --mermaid-out=docs/architecture/evidence/replace_scene_write_flow.md`
  Evidence:
  [replace_scene_write_flow.json](../evidence/replace_scene_write_flow.json),
  [replace_scene_write_flow.md](../evidence/replace_scene_write_flow.md)
- `flutter test --no-pub test/model test/controller test/interactive`

## Proof Links

- Proof family: [public entrypoint and signature proof](../../proof_architecture/families/public_entrypoint_and_signature_proof.md)
- Proof family: [guardrail runner and artifact model](../../proof_architecture/families/guardrail_runner_and_artifact_model.md)
- Guardrail: `dart run tool/check_guardrails.dart`
- Import boundaries: `dart run tool/check_import_boundaries.dart`
- Invariant: `INV-ENG-WRITE-ONLY-MUTATION`
- Invariant: `INV-ENG-CONTROLLER-NO-FULL-VIEW-RENDER-STATE`
- Invariant: `INV-ENG-TXN-WRITER-LIFETIME`
- Invariant: `INV-ENG-TXN-ATOMIC-COMMIT`
- Invariant: `INV-ENG-COMMITTED-SELECTION-REVISION-ALIGNMENT`
- Invariant: `INV-ENG-TXN-FINALIZED-BEFORE-COMMIT-PLAN`
- Invariant: `INV-ENG-TXN-COPY-ON-WRITE`
- Invariant: `INV-ENG-WRITE-PROTOCOL`
- Invariant: `INV-ENG-SIGNALS-AFTER-COMMIT`
- Invariant: `INV-ENG-WRITE-NUMERIC-GUARDS`
- Invariant: `INV-ENG-DISPOSE-FAIL-FAST`
- Invariant: `INV-ENG-CONTROLLER-COMMIT-RUNTIME-BOUNDARY`
- Invariant: `INV-ENG-SCENE-WRITE-TXN-ADAPTER-BOUNDARY`
- Invariant: `INV-ENG-CLEAR-SCENE-RESULT-REMOVED-NODE-IDS-IMMUTABLE`
- Invariant: `INV-ENG-COMMITTED-READ-SIDE-HERMETICITY`

## Status

- `locked`
- The checked-in store facade now matches the accepted narrow owner form while
  the commit runtime remains the write kernel.

## Update Triggers

- Refresh this family when its listed owners, evidence commands, or linked proof surfaces change.
