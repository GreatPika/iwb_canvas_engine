<!-- CONTEXT:BEGIN -->
Registry id: `section_03_package_layout`
Registry source: `docs/split/_registry/sections.yaml`
Document path: `docs/split/architecture/02_package_boundaries.md`
Owns:
- 3. Package layout
Must read before editing:
- `section_00_status_and_scope` -> `docs/split/architecture/00_architecture_overview.md`
- `section_02_architecture_model` -> `docs/split/architecture/01_runtime_ownership.md`
- `section_22_guardrails_machine_checks` -> `docs/split/verification/guardrails.md`
Depends on:
- `section_00_status_and_scope` -> `docs/split/architecture/00_architecture_overview.md`
- `section_02_architecture_model` -> `docs/split/architecture/01_runtime_ownership.md`
- `section_22_guardrails_machine_checks` -> `docs/split/verification/guardrails.md`
Feeds phases:
- `P0`
Related donors:
- `none`
Related diagrams:
- `docs/split/diagrams/README.md#c4_container` -> `docs/split/diagrams/generated/c4_container.mmd`
Required tests:
- `test.api_contract.no_old_public_symbols`
Guardrails:
- `new_core.no_legacy_imports`
- `new_api.no_old_public_types`
Do not assume:
- no old package import
- no app adapters in package
<!-- CONTEXT:END -->

<!-- ORIGINAL-SECTION:BEGIN -->
## 3. Package layout

Новый package создаётся отдельно:

```text
packages/iwb_canvas_engine_next/
  lib/
    iwb_canvas_engine_next.dart
    src/
      api/
        canvas_runtime.dart
        canvas_surface.dart
        canvas_document.dart
        canvas_element.dart
        canvas_element_update.dart
        canvas_resource.dart
        canvas_ids.dart
        canvas_geometry.dart
        canvas_tools.dart
        canvas_pointer.dart
        canvas_preview.dart
        canvas_events.dart
        canvas_errors.dart
        canvas_diagnostics.dart
      runtime/
        runtime_root.dart
        runtime_config.dart
      store/
        document_store_kernel.dart
        committed_document.dart
        element_registry.dart
        family_tables.dart
        selection_store.dart
        revision_state.dart
        document_projection_cache.dart
      edit/
        edit_kernel.dart
        edit_session.dart
        draft_document.dart
        touched_set.dart
        commit_plan.dart
        commit_compiler.dart
        commit_applier.dart
        staged_document_load.dart
      interaction/
        interaction_engine.dart
        pointer_session.dart
        move_machine.dart
        select_machine.dart
        draw_machine.dart
        line_machine.dart
        eraser_machine.dart
        text_tap_router.dart
      frame/
        frame_engine.dart
        captured_main_frame.dart
        captured_overlay_frame.dart
        paint_plan.dart
        render_element_record.dart
        repaint_bus.dart
      spatial/
        spatial_kernel.dart
        tile_index.dart
        outlier_index.dart
        spatial_membership.dart
      geometry/
        geometry_policy.dart
        hit_test_policy.dart
        bounds_policy.dart
        path_geometry.dart
      resources/
        resource_kernel.dart
        resource_cache.dart
        resource_resolver_adapter.dart
      codec/
        schema_v1_encoder.dart
        schema_v1_decoder.dart
        schema_v1_validation.dart
        schema_v1_paths.dart
      diagnostics/
        diagnostics_hub.dart
        diagnostics_sanitizer.dart
      flutter_bridge/
        canvas_surface_widget.dart
        pointer_adapter.dart
        main_painter.dart
        overlay_painter.dart
        image_bridge.dart
  test/
    api_contract/
    functional_ledger/
    schema_v1/
    edit_kernel/
    interaction/
    frame/
    spatial/
    resources/
    diagnostics/
    benchmarks/
  tool/
    guardrails/
    bench/
    diagrams/
```

`lib/iwb_canvas_engine_next.dart` exports only `src/api/**`.

Forbidden imports:

```text
lib/src/api/**               -> may not import src/store, src/edit, src/frame concrete internals
lib/src/store/**             -> may not import src/interaction, src/frame, src/flutter_bridge
lib/src/edit/**              -> may not import src/flutter_bridge
lib/src/interaction/**       -> may not mutate store directly
lib/src/frame/**             -> may not import public document projection as paint input
lib/src/resources/**         -> may not import interaction state
lib/src/codec/**             -> may not import Flutter widgets or interaction state
lib/src/flutter_bridge/**    -> may not import old iwb_canvas_engine
all lib/**                   -> may not import old package or old runtime paths
```

---

<!-- ORIGINAL-SECTION:END -->
