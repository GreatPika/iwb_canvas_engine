# P1 - legacy capability inventory and oracle lock

## Purpose

Lock the old engine as a functional oracle and donor inventory before new
runtime implementation starts, without allowing the legacy public API or legacy
runtime shape to become the new package architecture.

## Build scope

- `docs/verification/legacy_capability_inventory.md`
- `docs/donors/` and `docs/_registry/donors.yaml`
- legacy oracle file list
- donor file list with `copy`, `copy/adapt`, `adapt`, `adapt/rewrite`, and
  `rewrite-reference` decisions
- example scenario inventory
- action/event inventory
- pointer/preview inventory
- geometry/spatial inventory
- codec/limits inventory
- benchmark baseline inventory.

## Dependencies on earlier phases

- P0 package skeleton and no-legacy guardrails are present.

## Read first

- `section_08_legacy_capability_inventory` -> `docs/verification/legacy_capability_inventory.md`
- `docs/donors/00_reuse_rules.md`
- `docs/_registry/donors.yaml`

## Legacy evidence inputs

Use these workspace paths when checking legacy behavior for the P1 inventory:

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

These files identify the legacy behavior surface and supporting evidence for P1.
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

- `interaction_public_controller_behavior` - decision: `rewrite-reference`; target owner: Behavioral checklist only

## Forbidden donor structure

- `avoid_scene_controller_facades` - decision: `avoid`
- `avoid_interactive_runtime_whole` - decision: `avoid`
- `avoid_scene_builder_public_architecture` - decision: `avoid`
- `avoid_scene_codec_whole` - decision: `avoid`
- `avoid_scene_store_controller_whole` - decision: `avoid`

## Diagrams to read or update

- none.

## Contracts satisfied by this phase

- legacy capability inventory completeness from
  `section_08_legacy_capability_inventory`
- donor rule that every implementation donor has a phase, owner, decision, and
  ported or equivalent proof before use
- legacy boundary rule that legacy code is oracle/donor evidence only and never
  a production dependency

## Tests and guardrails that prove this phase

- `test.functional_ledger.legacy_capability_inventory` -> `test/functional_ledger/legacy_capability_inventory_test.dart`
- `oracle.legacy_capability_inventory_complete`

## Exit gate

- legacy capability inventory rows are complete
- each row names the legacy oracle and evidence focus
- each reusable donor has a decision, target phase and required ported tests
- copy/adapt donors are linked from the relevant implementation phase
- no implementation proceeds without green inventory guardrail.

## Risks and trade-offs

- Copying legacy structure would violate the target architecture. P1 records
  behavior and donor decisions, not new package structure.
- Skipping donor proof would make later phase closure depend on memory of legacy
  behavior instead of executable coverage.

## Why this phase belongs here

All implementation phases after P1 rely on knowing which legacy behavior must be
preserved, which donor code is reusable, and which legacy shells are forbidden.
That evidence must be closed before public API freeze and runtime work.
