# P1 - legacy oracle and donor closure

## Purpose

Close the existing legacy capability inventory and donor registry before public
API freeze and runtime implementation start, without allowing the legacy public
API or legacy runtime shape to become the new package architecture.

## Build scope

- audit and complete `docs/verification/legacy_capability_inventory.md`
- audit and complete `docs/_registry/donors.yaml`
- keep `docs/donors/` aligned with the donor registry
- close the legacy oracle evidence file list used by the inventory
- close donor decisions with `copy`, `copy/adapt`, `adapt`, `adapt/rewrite`,
  `rewrite-reference`, or `avoid`
- verify each reusable donor names its target phase, target owner, behavior to
  preserve, structure not to copy, and required ported or equivalent proof
- verify each forbidden legacy structure is represented as an `avoid` donor.

## Dependencies on earlier phases

- P0 package skeleton and no-legacy guardrails are present.

## Read first

- `section_08_legacy_capability_inventory` -> `docs/verification/legacy_capability_inventory.md`
- `docs/donors/00_reuse_rules.md`
- `docs/_registry/donors.yaml`

## Legacy evidence inputs

Use these workspace paths when auditing and completing the P1 inventory:

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

## Closure focus

P1 must not create separate topic inventories for scenarios, actions, pointer
behavior, geometry, codec, or benchmarks. Those concerns already have durable
owners: `docs/verification/legacy_capability_inventory.md`,
`docs/_registry/donors.yaml`, `docs/donors/`, subsystem contracts, and P14
benchmark gates.

Close the existing inventory and donor registry for these important behavior and
donor families:

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

Benchmark baselines are not closed in P1. P1 may identify legacy paths that
later benchmark work should treat as equivalent feature paths, but benchmark
cases and gates remain owned by `section_24_benchmarks` and P14.

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
  required ported or equivalent proof before use
- legacy boundary rule that legacy code is oracle/donor evidence only and never
  a production dependency

## Tests and guardrails that prove this phase

- `test.oracle.legacy_capability_inventory` -> `test/oracle/legacy_capability_inventory_test.dart`
- `oracle.legacy_capability_inventory_complete`

## Exit gate

- legacy capability inventory rows are complete
- each row names the legacy oracle and evidence focus
- every checklist item in `section_08_legacy_capability_inventory` is covered by
  an inventory row, later owning test, or explicit accepted difference
- each reusable donor has a decision, target phase, target owner, structure not
  to copy, and required ported or equivalent proof
- each `copy` and `copy/adapt` donor names concrete proof to port before its
  implementation slice closes
- each `adapt`, `adapt/rewrite`, and `rewrite-reference` donor names the legacy
  behavior to preserve without copying the legacy shell
- each forbidden legacy shell is represented as an `avoid` donor and linked to
  the phase or guardrail it blocks
- no new standalone topic inventory is introduced for information already owned
  by the legacy inventory, donor registry, contracts, or P14 benchmark gates
- no implementation proceeds without green inventory guardrail.

## Risks and trade-offs

- Copying legacy structure would violate the target architecture. P1 records
  behavior and donor decisions, not new package structure.
- Treating P1 as a place to create parallel topic inventories would duplicate
  source-of-truth docs and create manual synchronization work.
- Skipping donor proof obligations would make later phase closure depend on
  memory of legacy behavior instead of executable coverage.

## Why this phase belongs here

All implementation phases after P1 rely on knowing which legacy behavior must be
preserved, which donor code is reusable, and which legacy shells are forbidden.
That evidence must be closed in the existing inventory and donor registry before
public API freeze and runtime work.
