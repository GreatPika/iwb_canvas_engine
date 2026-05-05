# P1 - old capability inventory and oracle lock

## Build

- old_to_next_functional_matrix.md
- docs/donors/ and docs/_registry/donors.yaml
- old oracle file list
- donor file list with copy/adapt/rewrite-reference decisions
- example scenario inventory
- action/event inventory
- pointer/preview inventory
- geometry/spatial inventory
- codec/limits inventory
- benchmark baseline inventory.

## Read first

- `section_08_functional_ledger` -> `docs/verification/functional_ledger.md`

## Legacy evidence inputs

Use these workspace paths when checking old behavior for the P1 inventory:

```text
legacy/iwb_canvas_engine/lib/iwb_canvas_engine.dart
legacy/iwb_canvas_engine/lib/src/contract/snapshot.dart
legacy/iwb_canvas_engine/lib/src/contract/node_spec.dart
legacy/iwb_canvas_engine/lib/src/contract/node_patch.dart
legacy/iwb_canvas_engine/lib/src/contract/scene_contract_limits.dart
legacy/iwb_canvas_engine/lib/src/contract/pointer_input.dart
legacy/iwb_canvas_engine/lib/src/contract/canvas_pointer_input.dart
legacy/iwb_canvas_engine/lib/src/contract/scene_data_exception.dart
legacy/iwb_canvas_engine/lib/src/core/action_events.dart
legacy/iwb_canvas_engine/lib/src/core/scene_limits.dart
legacy/iwb_canvas_engine/lib/src/core/tool_defaults.dart
legacy/iwb_canvas_engine/lib/src/core/node_geometry.dart
legacy/iwb_canvas_engine/lib/src/core/hit_test.dart
legacy/iwb_canvas_engine/lib/src/core/scene_spatial_index.dart
legacy/iwb_canvas_engine/lib/src/core/paint_candidate_admission.dart
legacy/iwb_canvas_engine/lib/src/interactive/scene_controller.dart
legacy/iwb_canvas_engine/lib/src/interactive/scene_controller_scene.dart
legacy/iwb_canvas_engine/lib/src/interactive/scene_controller_interaction.dart
legacy/iwb_canvas_engine/lib/src/interactive/scene_controller_selection.dart
legacy/iwb_canvas_engine/lib/src/interactive/internal/scene_controller_interaction_config.dart
legacy/iwb_canvas_engine/lib/src/interactive/internal/interactive_event_dispatcher.dart
legacy/iwb_canvas_engine/lib/src/interactive/internal/interactive_move_commit_coordinator.dart
legacy/iwb_canvas_engine/lib/src/interactive/internal/interactive_move_selection_coordinator.dart
legacy/iwb_canvas_engine/lib/src/interactive/internal/interactive_draw_action_emitter.dart
legacy/iwb_canvas_engine/lib/src/interactive/internal/scene_controller_mutation_boundary.dart
legacy/iwb_canvas_engine/lib/src/controller/scene_controller_commit_write_runner.dart
legacy/iwb_canvas_engine/lib/src/controller/scene_controller_commit_runtime.dart
legacy/iwb_canvas_engine/lib/src/controller/scene_controller_committed_mutation_access.dart
legacy/iwb_canvas_engine/lib/src/model/scene_builder_decode_*.dart
legacy/iwb_canvas_engine/lib/src/serialization/scene_codec.dart
legacy/iwb_canvas_engine/lib/src/view/scene_view_interactive.dart
legacy/iwb_canvas_engine/lib/src/view/scene_view_interactive_overlay_painter.dart
legacy/iwb_canvas_engine/lib/src/contract/scene_view_render_state.dart
legacy/iwb_canvas_engine/example/lib/ui/canvas_example/view_models/canvas_example_view_model.dart
legacy/iwb_canvas_engine/tool/goldens/public_api_symbols.txt
```

These files identify the old behavior surface and supporting evidence for P1.
Specific reusable implementation donors are owned by `docs/_registry/donors.yaml`.

## Donor inventory focus

P1 must close the donor inventory before deep runtime implementation starts.
Use the donor registry and donor docs to cover these important donor families:

- geometry kernel: `Transform2D`, numeric policy, geometry helpers, and local
  bounds;
- hit-test/eraser: node geometry rules, path/stroke hit-test, and eraser
  projection;
- spatial/render: uniform grid index, paint admission, frame read, and render caches;
- DTO/validation: limits, structured errors, value validators, immutability,
  tri-state update semantics, and structure validation;
- codec: JSON guards, path-aware readers, primitive parsers, and schema-family
  decode/encode behavior;
- interaction/edit: pointer tracker/router/normalizer, gesture ownership,
  action/text events, mutation boundary, and staged `loadDocument` semantics.

## Required donors

- `interaction_public_controller_behavior` - decision: `rewrite_reference`; target owner: Behavioral checklist only

## Forbidden donor structure

- `avoid_scene_controller_facades` - decision: `avoid`
- `avoid_interactive_runtime_whole` - decision: `avoid`
- `avoid_scene_builder_public_architecture` - decision: `avoid`
- `avoid_scene_codec_whole` - decision: `avoid`
- `avoid_scene_store_controller_whole` - decision: `avoid`

## Diagrams to read or update

- none

## Guardrails

- `new_api.functional_ledger_complete` - every functional ledger row has API + tests

## Tests

- `test.functional_ledger.row_specific_tests` -> `functional-ledger row-specific tests`

## Exit gate

- functional ledger rows are complete
- each row has oracle file(s), new API target and test id
- each reusable donor has a decision, target phase and required ported tests
- copy/adapt donors are linked from the relevant implementation phase
- no implementation proceeds without green inventory guardrail.
