<!-- CONTEXT:BEGIN -->
Registry id: `section_03_package_layout`
Registry source: `docs/_registry/sections.yaml`
Document path: `docs/architecture/02_package_boundaries.md`
Owns:
- 3. Package layout
Must read before editing:
- `section_00_status_and_scope` -> `docs/architecture/00_architecture_overview.md`
- `section_02_architecture_model` -> `docs/architecture/01_runtime_ownership.md`
Feeds phases:
- `P0`
Related donors:
- `none`
Related diagrams:
- `c4_container`
Required tests:
- `test.api_contract.no_old_public_symbols`
- `test.guardrails.import_boundaries`
Guardrails:
- `core.no_legacy_imports`
- `api.no_legacy_public_types`
- `core.import_boundaries`
Do not assume:
- no legacy package import
- no app adapters in package
<!-- CONTEXT:END -->

## 3. Package layout

The new package is rooted at the repository top level:

```text
./
  lib/
    iwb_canvas_engine.dart
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
    api/
    runtime/
    store/
    edit/
    interaction/
    frame/
    spatial/
    geometry/
    resources/
    codec/
    diagnostics/
    flutter_bridge/
    guardrails/
    benchmarks/
    support/
  tool/
    guardrails/
    bench/
    diagrams/
```

`lib/iwb_canvas_engine.dart` exports only `src/api/**`.

Production-owned тесты зеркалят top-level ownership folders под
`lib/src/**`: `test/edit/**` покрывает `lib/src/edit/**`, `test/frame/**`
покрывает `lib/src/frame/**`, и так далее. Cross-cutting proof areas, которые
не принадлежат одному production owner, остаются вне зеркала:
`test/api_contract/**`, `test/functional_ledger/**`, `test/guardrails/**`,
`test/benchmarks/**`, а shared test fixtures живут под `test/support/**`.

Зеркало является правилом ownership и навигации, а не правилом "каждому source
file нужен matching test file". Individual tests называются по behavior,
contract, invariant или regression, которые они доказывают, даже если несколько
source files совместно обеспечивают это поведение.

Forbidden imports:

```text
lib/src/api/**               -> may not import src/store, src/edit, src/frame concrete internals
lib/src/store/**             -> may not import src/interaction, src/frame, src/flutter_bridge
lib/src/edit/**              -> may not import src/flutter_bridge
lib/src/interaction/**       -> may not import, read, or mutate src/store directly
lib/src/frame/**             -> may not import public document projection as paint input
lib/src/spatial/**           -> may use only typed spatial delta/read ports, not concrete store tables or interaction/frame state
lib/src/resources/**         -> may not import interaction state
lib/src/codec/**             -> may not import Flutter widgets or interaction state
lib/src/diagnostics/**       -> may not expose runtime objects, images, closures, or full scene dumps as public diagnostic data
lib/src/flutter_bridge/**    -> may not import old iwb_canvas_engine
all lib/**                   -> may not import legacy package or legacy runtime paths
```

Committed facts used by interaction are supplied through narrow read-only query
ports owned by the runtime/store boundary. Interaction code may depend on those
intent-specific ports, not on `src/store` tables or concrete store internals.

---
