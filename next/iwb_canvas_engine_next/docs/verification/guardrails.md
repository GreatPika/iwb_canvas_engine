<!-- CONTEXT:BEGIN -->
Registry id: `section_22_guardrails_machine_checks`
Registry source: `docs/_registry/sections.yaml`
Document path: `docs/verification/guardrails.md`
Owns:
- 22. Guardrails and machine checks
Must read before editing:
- `section_00_status_and_scope` -> `docs/architecture/00_architecture_overview.md`
- `section_03_package_layout` -> `docs/architecture/02_package_boundaries.md`
- `section_27_final_release_gates` -> `docs/verification/release_gates.md`
Feeds phases:
- `P0`
- `P12`
Related donors:
- `tooling_schema_family_parity`
Related diagrams:
- `none`
Required tests:
- `test.guardrails.blocking_suite`
Guardrails:
- `api.functional_ledger_complete`
- `api.integration_surface_complete`
- `api.v1_scope_gate_green_before_freeze`
- `api.no_legacy_public_types`
- `api.public_types_complete`
- `api.public_api_compiles_as_written`
- `api.no_undefined_public_type_references`
- `api.dto_immutability`
- `api.id_validation_no_extension_type_escape`
- `core.no_legacy_imports`
- `core.no_scene_controller_shape_dependency`
- `core.no_node_spec_patch_shape_dependency`
- `core.single_runtime_root`
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
- no non-blocking critical guardrail
<!-- CONTEXT:END -->

## 22. Guardrails and machine checks

Mandatory guardrails:

| Guardrail id | Rule |
|---|---|
| `api.functional_ledger_complete` | every functional ledger row has API + tests |
| `api.integration_surface_complete` | API has enough public surface for app-level `NextEngineAdapter`, but adapter is not in package |
| `api.v1_scope_gate_green_before_freeze` | P1.5 scope gate passed before public API freeze starts |
| `api.no_legacy_public_types` | legacy public golden symbols not exported by next package |
| `api.public_types_complete` | all public signatures reference defined public types |
| `api.public_api_compiles_as_written` | public API declarations compile in an empty consumer package |
| `api.no_undefined_public_type_references` | every exported signature type is exported or from Flutter/Dart SDK |
| `api.dto_immutability` | DTO collections defensively copied and unmodifiable |
| `api.id_validation_no_extension_type_escape` | ids cannot be publicly constructed without validation |
| `core.no_legacy_imports` | no import of legacy package/runtime |
| `core.no_scene_controller_shape_dependency` | no `SceneController` concept in core |
| `core.no_node_spec_patch_shape_dependency` | no legacy NodeSpec/NodePatch/PatchField in core |
| `core.single_runtime_root` | exactly one production RuntimeRoot |
| `edit.sync_non_nested` | nested/async edit rejected |
| `edit.rollback_no_effects` | rollback discards events/repaint/resources/spatial |
| `edit.stale_handle_rejected` | stale edit handle throws |
| `events.low_level_edit_no_user_actions` | CanvasEdit.removeElement/clearContent emit no user action events |
| `events.commands_emit_user_actions` | high-level commands and interaction commits own user action events |
| `load.prepares_before_interrupt` | failed load does not interrupt gesture |
| `load.success_interrupts_before_install` | success interrupt happens before atomic install |
| `preview.selected_move_main_repaint` | selected move preview increments main repaint, not overlay |
| `resources.mutation_inside_edit_only` | resource descriptor mutation only via CanvasEdit |
| `resources.dirty_no_document_revision` | markResourceDirty does not increment documentRevision |
| `resources.app_key_only` | resource descriptors use appKey only |
| `codec.schema_v1_exact` | only schema v1 read/write |
| `codec.known_fields_validated` | known schema v1 fields are validated and canonical encoder writes only v1 fields |
| `diagnostics.disabled_no_alloc_hot_path` | no record allocation on successful hot path |
| `diagrams.all_required_present` | required Mermaid files exist |

---

