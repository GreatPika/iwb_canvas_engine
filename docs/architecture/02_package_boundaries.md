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
- `test.api_contract.no_legacy_public_symbols`
- `test.guardrails.import_boundaries`
- `test.guardrails.selection_boundary_imports`
Guardrails:
- `core.no_legacy_imports`
- `api.no_legacy_public_types`
- `core.import_boundaries`
- `core.no_unapproved_part_files`
- `interaction.no_concrete_selection_imports`
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
        document_facts_port.dart
        selection_facts_port.dart
        selection_normalization_port.dart
      store/
        document_store_kernel.dart
        committed_document.dart
        element_registry.dart
        family_tables.dart
        revision_state.dart
        document_projection_cache.dart
      selection/
        selection_kernel.dart
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

Source boundary rules:

```text
lib/iwb_canvas_engine.dart      -> only public barrel for package consumers
production lib/**               -> no `part` or `part of` files unless generated-code adoption is explicitly approved
all lib/**                      -> may not import another package's `src/**`
```

Production-owned tests mirror the top-level ownership folders under
`lib/src/**`: `test/edit/**` covers `lib/src/edit/**`, `test/frame/**` covers
`lib/src/frame/**`, and so on. Cross-cutting proof areas that do not belong to
one production owner stay outside the mirror: `test/api_contract/**`,
`test/functional_ledger/**`, `test/guardrails/**`, `test/benchmarks/**`, and
shared test fixtures live under `test/support/**`.

The mirror is an ownership and navigation rule, not a rule that every source
file needs a matching test file. Individual tests are named for the behavior,
contract, invariant, or regression they prove, even when several source files
jointly provide that behavior.

Guardrail ownership is intentionally split:

```text
test/guardrails/** -> cross-cutting proof integration with dart test and CI
tool/guardrails/** -> CLI orchestration, runner metadata, and shared check logic
```

Production `lib/**` code must not import `tool/**`. Tests may call reusable
guardrail check logic from `tool/guardrails/**` or execute the guardrail runner
when a proof needs the same command path as CI.

Forbidden imports:

```text
lib/src/api/**               -> may not import src/store, src/edit, src/frame concrete internals
lib/src/store/**             -> may not import src/interaction, src/frame, src/flutter_bridge
lib/src/selection/**         -> may read document facts only through runtime-supplied immutable query ports
lib/src/edit/**              -> may not import src/flutter_bridge
lib/src/interaction/**       -> may not import, read, or mutate src/store or src/selection concrete internals directly
lib/src/frame/**             -> may not import public document projection as paint input
lib/src/spatial/**           -> may use only typed spatial delta/read ports, not concrete store tables or interaction/frame state
lib/src/resources/**         -> may not import interaction state
lib/src/codec/**             -> may not import Flutter widgets or interaction state
lib/src/diagnostics/**       -> may not expose runtime objects, images, closures, or full scene dumps as public diagnostic data
lib/src/flutter_bridge/**    -> may not import legacy iwb_canvas_engine package
all lib/**                   -> may not import legacy package or legacy runtime paths
```

Committed document facts and runtime selection facts used by interaction are
supplied through narrow read-only query ports owned by the runtime/document and
runtime/selection boundaries. Interaction code may depend on those
intent-specific ports, not on `src/store`, `src/selection`, or concrete owner
internals.

---
