<!-- CONTEXT:BEGIN -->
Registry id: `section_26_implementation_phases`
Registry source: `docs/split/_registry/sections.yaml`
Document path: `docs/split/planning/implementation_phases.md`
Owns:
- 26. Implementation phases and tasks
Must read before editing:
- `docs/split/indexes/by_phase.md`
- `docs/split/indexes/phase_to_donor.md`
- `section_27_final_release_gates` -> `docs/split/verification/release_gates.md`
Feeds phases:
- `P0`
- `P1`
- `P1.5`
- `P2`
- `P3`
- `P4`
- `P5`
- `P6`
- `P7`
- `P8`
- `P9`
- `P10`
- `P11`
- `P12`
Related donors:
- `direct_numeric_policy`
- `direct_local_bounds_policy`
- `direct_paint_admission`
- `direct_scan_resistant_cache`
- `direct_pointer_tap_tracking`
- `direct_flutter_pointer_routing`
- `direct_gesture_ownership`
- `direct_structure_validation`
- `foundation_transform2d`
- `foundation_core_geometry`
- `foundation_contract_limits`
- `foundation_error_contract`
- `foundation_validators`
- `foundation_tri_state_patch_semantics`
- `foundation_immutable_collections`
- `foundation_pointer_input_contract`
- `foundation_action_event_immutability`
- `geometry_node_geometry`
- `geometry_hit_test`
- `render_geometry_builder`
- `geometry_interactive_geometry`
- `geometry_eraser_exact_hit`
- `spatial_scene_spatial_index`
- `spatial_index_cache`
- `store_scene_controller_read_paths`
- `snapshot_paint_admission_bounds`
- `snapshot_paint_candidates`
- `frame_render_state`
- `scene_view_runtime_fast_path`
- `paint_candidate_stage`
- `scene_painter_frame`
- `scene_render_caches`
- `static_layer_cache`
- `text_stroke_path_metrics_caches`
- `dto_snapshot_behavior`
- `dto_node_spec_behavior`
- `dto_boundary_schema`
- `dto_scene_value_validation`
- `dto_node_boundary_mapping`
- `dto_document_helpers`
- `codec_guards`
- `codec_json_require`
- `codec_json_parse`
- `codec_metadata_decode`
- `codec_layer_decode`
- `codec_node_common_decode`
- `codec_family_decode`
- `codec_scene_codec_flow`
- `codec_validation_path_surface`
- `tooling_schema_family_parity`
- `interaction_pointer_host`
- `interaction_pointer_session`
- `interaction_pointer_normalizer`
- `interaction_event_dispatcher`
- `interaction_double_tap_router`
- `interaction_gesture_runtime`
- `interaction_move_session`
- `interaction_draw_coordinator`
- `interaction_mutation_boundary`
- `staged_load_runtime_materialization`
- `validated_import_draft`
- `interaction_public_controller_behavior`
- `avoid_scene_controller_facades`
- `avoid_interactive_runtime_whole`
- `avoid_scene_builder_public_architecture`
- `avoid_scene_codec_whole`
- `avoid_scene_store_controller_whole`
Related diagrams:
- `none`
Required tests:
- `none`
Guardrails:
- `new_api.functional_ledger_complete`
- `new_api.integration_surface_complete`
- `new_api.v1_scope_gate_green_before_freeze`
- `new_api.no_old_public_types`
- `new_api.public_types_complete`
- `new_api.public_api_compiles_as_written`
- `new_api.no_undefined_public_type_references`
- `new_api.dto_immutability`
- `new_api.id_validation_no_extension_type_escape`
- `new_core.no_legacy_imports`
- `new_core.no_scene_controller_shape_dependency`
- `new_core.no_node_spec_patch_shape_dependency`
- `new_core.single_runtime_root`
- `edit.sync_non_nested`
- `edit.rollback_no_effects`
- `edit.stale_handle_rejected`
- `events.low_level_edit_no_user_actions`
- `events.commands_emit_user_actions`
- `load.prepares_before_interrupt`
- `load.success_interrupts_before_install`
- `preview.selected_move_main_repaint`
- `resources.mutation_inside_edit_only`
- `resources.dirty_no_document_revision`
- `resources.app_key_only`
- `codec.schema_v1_exact`
- `codec.known_fields_validated`
- `diagnostics.disabled_no_alloc_hot_path`
- `diagrams.all_required_present`
Do not assume:
- do not start phase without linked sections and donors
<!-- CONTEXT:END -->

## 26. Implementation phases and tasks

### P0 — package skeleton and hard boundaries

Deliverables:

```text
- create packages/iwb_canvas_engine_next;
- create public barrel exporting only src/api/**;
- add old-public-symbol ban guardrail;
- add no-old-import guardrail;
- add RuntimeRoot skeleton;
- add diagram file placeholders;
- add CI target for new package;
- add failing public_types_defined_test.
```

Exit criteria:

```text
new package builds empty public API skeleton;
old package not imported;
old public symbols not exported;
all required public type names have files.
```

### P1 — old capability inventory and oracle lock

Deliverables:

```text
- old_to_next_functional_matrix.md;
- docs/split/donors/ and docs/split/_registry/donors.yaml;
- old oracle file list;
- donor file list with copy/adapt/rewrite-reference decisions;
- example scenario inventory;
- action/event inventory;
- pointer/preview inventory;
- geometry/spatial inventory;
- codec/limits inventory;
- benchmark baseline inventory.
```

Exit criteria:

```text
functional ledger rows are complete;
each row has oracle file(s), new API target and test id;
each reusable donor has a decision, target phase and required ported tests;
copy/adapt donors are linked from the relevant implementation phase;
no implementation proceeds without green inventory guardrail.
```

### P1.5 — v1 scope gate before public API freeze

Deliverables:

```text
- scope checklist based on old functional behavior and approved v1 additions;
- public API draft probe;
- public API compiles as written.
```

Exit criteria:

```text
mandatory v1 scope is green;
public API compiles as written;
no undefined public type references remain;
P2 public API freeze is blocked until this gate is green.
```

### P2 — public API v1 freeze

Deliverables:

```text
- all src/api DTOs implemented;
- P1.5 v1 scope gate green;
- id validation implemented;
- CanvasOptional implemented;
- public API docs generated;
- DTO immutability tests;
- public signatures no undefined types.
```

Exit criteria:

```text
P1.5 scope gate remains green;
public API compiles;
all public constructor validations pass/fail as specified;
no old public symbols exported;
no public type references internal runtime classes.
```

### P3 — schema v1 DTO validation and codec skeleton

Deliverables:

```text
- schema_v1_full_contract tests;
- encode/decode skeleton;
- validation limits;
- metadata validator;
- color/offset/size/transform codecs;
- resource/element JSON codecs.
```

Exit criteria:

```text
all schema roundtrip tests green;
known field validation tests green;
unknown-field policy tests green;
limits tests green;
error payload tests green.
```

### P4 — resources

Deliverables:

```text
- ResourceKernel;
- CanvasResourceId;
- CanvasResourceSource.appKey only;
- resource mutation inside CanvasEdit only;
- markResourceDirty;
- markAllResourcesDirty;
- synchronous app-owned image resolver bridge;
- no engine IO;
- no asset-bundle loading;
- no file loading;
- no remote/network loading;
```

Exit criteria:

```text
resource descriptor mutation is rollback-safe;
resource dirty schedules main repaint without document revision;
resolver image results are app-owned and not disposed by engine;
resource surface matches the v1 appKey/synchronous image contract.
```

### P5 — store kernel and projection cache

Deliverables:

```text
- CommittedDocument;
- ElementRegistry;
- FamilyTables;
- LayerTable;
- SelectionStore;
- RevisionState;
- DocumentProjectionCache.
```

Exit criteria:

```text
readDocument projection matches DTO state;
projection lazy counters pass;
no projection in hot path tests pass.
```

### P6 — edit kernel

Deliverables:

```text
- EditSession;
- DraftDocument;
- TouchedSet;
- CommitCompiler;
- CommitPlan;
- CommitApplier;
- rollback and stale handle enforcement;
- staged loadDocument;
- replaceDraftDocument.
```

Exit criteria:

```text
sync/non-nested/async/stale tests green;
rollback tests green;
loadDocument staged tests green;
operation matrix tests green.
```

### P7 — spatial and geometry

Deliverables:

```text
- GeometryPolicy v1;
- HitTestPolicy v1;
- TileIndex;
- OutlierIndex;
- touched spatial update;
- exact family hit tests;
- paint admission.
```

Exit criteria:

```text
hit tests green;
spatial constants green;
outlier behavior green;
touched-only spatial update green.
```

### P8 — frame engine and render caches

Deliverables:

```text
- CapturedMainFrame;
- CapturedOverlayFrame;
- RenderElementRecord;
- PaintPlan;
- selected supplement staging;
- main/overlay repaint buses;
- text/path/stroke/background/resource caches.
```

Exit criteria:

```text
main capture once;
overlay capture once;
selected move preview main repaint;
overlay previews overlay repaint;
no live runtime read in painters;
no CanvasDocument projection in paint.
```

### P9 — interaction engine

Deliverables:

```text
- pointer session lifecycle;
- move/select/marquee machine;
- pencil/marker draw machine;
- two-tap line machine;
- eraser machine;
- text double-tap router;
- terminal cleanup;
- synchronous move resolver guard.
```

Exit criteria:

```text
all interaction state tests green;
pending line preview exposed;
text edit event emitted;
resolver cannot reenter mutation;
loadDocument failure preserves gesture;
loadDocument success clears gesture.
```

### P10 — Flutter surface

Deliverables:

```text
- CanvasSurface widget;
- pointer adapter;
- main painter;
- overlay painter;
- synchronous app-owned resource resolver bridge;
- selection/grid style application.
```

Exit criteria:

```text
surface paints empty and populated docs;
interactive=false disables pointer routing;
resource resolver repaint works;
widget tests green.
```

### P11 — migration tool package

Deliverables:

```text
- packages/canvas_migration_tools;
- old schema v7 fixtures;
- v7 to v1 mapping;
- MigrationReport;
- DataLossReport.
```

Exit criteria:

```text
old fixture migration tests green;
imageId maps to resources;
palette/grid color/revision preserved;
no silent data loss.
```

### P12 — benchmarks, diagrams, release readiness

Deliverables:

```text
- all required diagrams complete;
- benchmark baselines;
- benchmark diff tool;
- all guardrails blocking;
- release checklist.
```

Exit criteria:

```text
functional ledger complete;
schema tests green;
interaction/frame/spatial/resource tests green;
benchmarks pass;
no old imports;
no legacy facade;
no app adapters in package.
```

---

