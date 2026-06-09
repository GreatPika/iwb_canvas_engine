<!-- CONTEXT:BEGIN -->
Registry id: `section_03_package_layout`
Registry source: `docs/_registry/sections.yaml`
Document path: `docs/architecture/02_package_boundaries.md`
Owns:
- 3. Package layout
Must read before editing:
- `section_00_status_and_scope` -> `docs/architecture/00_architecture_overview.md`
- `section_02_architecture_model` -> `docs/architecture/01_runtime_ownership.md`
Current owners:
- `architecture`
Benchmarks:
- `none`
Related diagrams:
- `c4_container`
Required tests:
- `test.api_contract.public_exports_complete`
- `test.guardrails.import_boundaries`
- `test.guardrails.frame_committed_facts_via_frame_facts_port`
- `test.guardrails.selection_boundary_checks`
- `test.guardrails.text_surface_guardrail_checks`
Guardrails:
- `core.no_unapproved_external_package_imports`
- `core.import_boundaries`
- `core.no_unapproved_part_files`
- `frame.committed_facts_via_frame_facts_port`
- `interaction.no_concrete_selection_imports`
- `surface.editable_text_surface_only`
Do not assume:
- no external package import bypass
- no public integrations in package
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
      contracts/
        public/
          canvas_document.dart
          canvas_element.dart
          canvas_resource.dart
          canvas_runtime.dart
          canvas_ids.dart
          canvas_errors.dart
          canvas_diagnostics.dart
          canvas_surface_styles.dart
        internal/
          commit_delivery.dart
          document_facts_port.dart
          frame_facts_port.dart
          load_interaction_boundary.dart
          resource_dirty_outcome.dart
          resolver_mutation_guard.dart
          selection_facts_port.dart
          selection_membership_port.dart
      runtime/
        runtime_root.dart
        runtime_config.dart
      store/
        document_store_kernel.dart
        committed_document.dart
        element_registry.dart
        family_tables.dart
        layer_table.dart
        revision_state.dart
        store_revision_delta.dart
        document_projection_cache.dart
        resource_table.dart
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
        interaction_read_port.dart
        interaction_request_registry.dart
        pointer_tool_cleanup_coordinator.dart
        pointer_session.dart
        move_machine.dart
        select_machine.dart
        draw_machine.dart
        line_machine.dart
        eraser_machine.dart
        context_action_router.dart
      frame/
        frame_engine.dart
        frame_capture_service.dart
        captured_frame.dart
        ordinary_paint_planner.dart
        selected_move_supplement_planner.dart
        selection_decoration_planner.dart
        paint_asset_binding_service.dart
        frame_spatial_paint_admission.dart
        frame_drawable_policy.dart
        static_background_planner.dart
        overlay_preview_planner.dart
        paint_plan.dart
        render_element_record.dart
        frame_paint_output.dart
        frame_repaint_signal.dart
      geometry/
        geometry_policy.dart
        hit_test_policy.dart
        bounds_policy.dart
        path_geometry.dart
        spatial_kernel.dart
        tile_index.dart
        outlier_index.dart
        spatial_membership.dart
      tools/
        draw_tool_kernel.dart
        tool_preview_coordinator.dart
      resources/
        resource_kernel.dart
        resource_cache.dart
        resource_resolver_adapter.dart
        surface_resource_session.dart
      codec/
        schema_v1_encoder.dart
        schema_v1_decoder.dart
        schema_v1_validation.dart
        schema_v1_paths.dart
      diagnostics/
        diagnostics_hub.dart
        diagnostics_sanitizer.dart
      surface/
        canvas_surface_widget.dart
        pointer_adapter.dart
        main_painter.dart
        overlay_painter.dart
        image_bridge.dart
  test/
    api_contract/
    oracle/
    api/
    runtime/
    store/
    edit/
    interaction/
    frame/
    spatial/
    geometry/
    tools/
    resources/
    codec/
    diagnostics/
    surface/
    guardrails/
    benchmarks/
    support/
  tool/
    guardrails/
    bench/
    diagrams/
```

`lib/iwb_canvas_engine.dart` exports only `src/api/**`. The files under
`lib/src/api/**` are facade or wrapper-export files: stable declarations live
under `lib/src/contracts/public/**`, non-exported cross-owner seams live under
`lib/src/contracts/internal/**`, and implementation owners consume those
contract files instead of using the API facade as a type library. The
`lib/src/api/canvas_surface.dart` facade is the narrow public widget exception:
it re-exports only the surface-owned public widgets `CanvasSurface` and
`CanvasTextEditingOverlay` plus public surface style contracts.

The target frame collaborator files listed under `lib/src/frame/**` are
implementation layout names for the `FrameEngine` internal split, not files
created by this documentation step. They remain frame-private implementation
details and are omitted from the public package barrel.

`lib/src/interaction/pointer_tool_cleanup_coordinator.dart` is the target
internal cleanup policy collaborator for `InteractionEngine`. It is not exported
from `lib/iwb_canvas_engine.dart`. Cleanup-capable tool-machine files under
`lib/src/interaction/**` may construct typed cleanup requests for
`InteractionEngine`, but the coordinator itself remains interaction-internal and
callable only by `InteractionEngine`.

`lib/src/interaction/interaction_read_port.dart` is the target read-only
interaction facts boundary. It may expose only immutable, intent-specific facts
needed by interaction routing and must not expose mutation APIs, draft access,
`CanvasDocument` projection, concrete store internals, concrete selection
internals, or resource/session internals.

`lib/src/interaction/pointer_sample_normalizer.dart` is the target pointer
admission boundary. It owns conversion from constructible public pointer
samples to finite normalized world-space samples, plus invalid-terminal cleanup
decisions for internal raw terminal facts. It does not read document,
selection, spatial, resolver, edit, resource, frame, runtime stream, or Flutter
state.

`lib/src/contracts/internal/command_facts_port.dart` is the target
runtime-owned high-level command facts boundary. It supplies immutable facts
for selection transform/delete, remove element, and clear content commands to
runtime-owned adapters. It is not an interaction read seam and must not be
imported by `lib/src/interaction/**`.

Source boundary rules:

```text
lib/iwb_canvas_engine.dart      -> only public barrel for package consumers
production lib/**               -> no `part` or `part of` files unless generated-code adoption is explicitly approved
all lib/**                      -> may not import another package's `src/**`
lib/src/frame/**                -> obtains committed document facts through `contracts/internal/frame_facts_port.dart`, not concrete store files
lib/src/frame/**                -> keeps frame collaborators package-internal; no root barrel export for collaborator files
lib/src/frame/frame_text_layout_measurer.dart -> owns TextPainter measurement for engine text layout; geometry, surface overlays, and example code consume measured geometry instead of remeasuring
lib/src/surface/**              -> may host Flutter widgets, including CanvasSurface and CanvasTextEditingOverlay
lib/src/contracts/public/**     -> declaration-only public DTOs, values, errors, policies, runtime state/config types, and public port interfaces; no API or implementation imports
lib/src/contracts/internal/**   -> declaration-only owner ports, immutable facts, delivery effects, resource dirty outcomes, and resolver mutation guards; may depend on contracts/public but not API or implementation owners
```

`FrameFactsPort` is the frame-intent committed facts boundary under
`lib/src/contracts/internal/`. It may be backed by `DocumentStoreKernel` through
`RuntimeRoot` composition, but frame-owned code must not import
`lib/src/store/document_store_kernel.dart`, `committed_document.dart`,
`family_tables.dart`, resource tables, `document_projection_cache.dart`, drafts,
or public projection internals to capture frames, resolve render-row snapshots,
or read descriptor snapshots.

Consumer compile fixtures under `test/api_contract/fixtures/**` model external
application code. They may import only
`package:iwb_canvas_engine/iwb_canvas_engine.dart`, must not import `src/**`,
and must not use package-internal or unregistered public symbols or internal runtime classes. The
public integration fixture is the proof surface for `api.integration_surface_complete`,
not an adapter implementation shipped by this package.

Production-owned tests mirror the top-level ownership folders under
`lib/src/**`: `test/edit/**` covers `lib/src/edit/**`, `test/frame/**` covers
`lib/src/frame/**`, and so on. Cross-cutting proof areas that do not belong to
one production owner stay outside the mirror: `test/api_contract/**`,
`test/oracle/**`, `test/guardrails/**`, `test/benchmarks/**`, and
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
lib/src/api/**               -> may not import/export contracts/internal except
                                 lib/src/api/canvas_runtime_surface_bridge.dart,
                                 which is the narrow package-boundary bridge
                                 allowed to import exactly
                                 ../contracts/internal/resolver_mutation_guard.dart
                                 and
                                 ../contracts/internal/surface_resource_session_lifecycle.dart;
                                 only named facade bridges may import runtime/codec implementation
lib/src/contracts/public/**  -> may not import/export src/api or implementation owners
lib/src/contracts/internal/** -> may not import/export src/api or implementation owners
lib/src/runtime/**           -> may not import src/api or the root public barrel as a type library
lib/src/api/**               -> may not import src/store, src/edit, src/frame concrete internals outside named facade bridges
lib/src/store/**             -> may not import src/interaction, src/frame, src/surface
lib/src/selection/**         -> may read document facts only through contracts/internal immutable query ports and must not import runtime
lib/src/edit/**              -> may not import src/surface
lib/src/interaction/**       -> may not import, read, or mutate src/store or src/selection concrete internals directly
lib/src/interaction/interaction_read_port.dart -> may not expose mutation APIs, drafts, CanvasDocument projection, concrete store internals, concrete selection internals, or resource/session internals
lib/src/interaction/**       -> may not import src/contracts/internal/command_facts_port.dart
lib/src/interaction/pointer_sample_normalizer.dart -> may not import document, selection, spatial, resolver, edit, resource, frame, runtime stream, or Flutter owners
lib/src/interaction/pointer_tool_cleanup_coordinator.dart -> may not import resolver callbacks, EditKernel, repaint buses, Flutter bridge, resource sessions, concrete store internals, or concrete selection internals
lib/src/frame/**             -> may not import public document projection as paint input or ResourceCatalogPort as an asset-binding seam
lib/src/geometry/**          -> may use only typed geometry/spatial delta/read ports, not concrete store tables or interaction/frame state
lib/src/geometry/**          -> may consume measured text layout facts but must not calculate text bounds with formula estimates or TextPainter
lib/src/resources/**         -> may not import runtime, store, frame, surface, interaction, Flutter, or cache/session owners outside resource-owned seams
lib/src/codec/**             -> may not import runtime, store, edit, frame, Flutter widgets, or interaction state
lib/src/diagnostics/**       -> may not expose runtime objects, images, closures, or full scene dumps as public diagnostic data
lib/src/tools/**             -> may not import runtime, frame, or surface internals
lib/src/surface/**           -> may not import package-internal iwb_canvas_engine route
lib/src/surface/**           -> may use CanvasRuntime public facade type for public widget constructor signatures, but runtime internals still go through named surface bridges
lib/src/surface/**           -> may use EditableText only for public surface widgets; non-surface production owners must not import or construct EditableText
example/lib/**               -> may consume the public package barrel and example-local files only; inline text editing must use CanvasTextEditingOverlay or CanvasTextEditingPort without src/** imports, visibility hiding, or duplicate TextPainter measurement
all lib/**                   -> may not import package-internal or runtime-private paths
```

Committed document facts and runtime selection facts used by interaction are
supplied through `InteractionReadPort` and narrow selection facts ports owned by
the runtime/document and runtime/selection boundaries. Interaction code may
depend on those intent-specific ports, not on `src/store`, `src/selection`, or
concrete owner internals.

`lib/src/interaction/context_action_router.dart` is the future interaction
route owner for direct `CanvasToolPort.handleDoubleTap` and pointer-sample
double-tap context-action target resolution and request emission. Direct
`handleDoubleTap` enters as a host-recognized input that clears pending context
tap history through the interaction cleanup coordinator before current-target
resolution. The router may read only the narrow interaction query facts needed
to distinguish content-element and empty-canvas targets; it must not own app
menu state, editor overlay lifetime, or mutations.

`lib/src/interaction/interaction_request_registry.dart` stores only
engine-issued `CanvasInteractionRequestId` guard facts, context request target
kind, controller epoch, live request status, and content-target guard facts for
app-owned interaction requests. Guarded command operations consume and remove
live facts instead of retaining durable extra registry facts. The registry must not
expose store tables, selection internals, Flutter editor overlay state,
IME/focus/selection state, context menu state, or mutation methods; guarded
mutations still enter through public command ports and commit through
`EditKernel`.

---
