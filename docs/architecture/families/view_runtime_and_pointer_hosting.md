# View Runtime And Render Seam

## Purpose

This family defines how the view shell crosses into the interactive runtime
without reconstructing engine ownership locally.

The checked-in local form already uses one assembled `SceneViewRuntime`
boundary with separate render-read facets for the main scene and overlay
preview.

## Target Rules

- `SceneViewRuntime` remains the only view-facing runtime boundary.
- `SceneViewRuntime.mainSceneRenderRead` remains the main-scene render-read
  surface consumed by `SceneViewRenderSurface`.
- `SceneViewRuntime.overlayPreviewRead` remains the overlay-preview read
  surface consumed by `SceneViewInteractiveOverlayPainter` and controller-side
  preview getters.
- `SceneViewRuntime.createPointerSession` keeps pointer-session creation on the
  runtime boundary instead of moving session orchestration into the view shell.

## Owners

- Runtime boundary contracts:
  `lib/src/contract/scene_view_runtime.dart` and
  `lib/src/contract/scene_view_render_state.dart`
- Boundary implementation:
  `lib/src/interactive/internal/scene_controller_scene_view_runtime.dart`
- View host and read consumers:
  `lib/src/view/scene_view_runtime_host.dart`,
  `lib/src/view/scene_view_render_surface.dart`, and
  `lib/src/view/scene_view_interactive_overlay_painter.dart`
- Overlay-preview relay for public interactive reads:
  `lib/src/interactive/scene_controller.dart`

## Forbidden Shapes

- Do not collapse `mainSceneRenderRead` and `overlayPreviewRead` back into one
  ambiguous view-facing read contract.
- Do not make `SceneViewRuntimeHost` or the view consumers reconstruct runtime
  ownership locally.
- Do not make `SceneViewRenderSurface` depend on overlay-preview state or make
  `SceneViewInteractiveOverlayPainter` depend on the main-scene paint path.

## Mechanical Evidence

- `dart run tool/lsp_find_symbols.dart mainSceneRenderRead --path-contains=lib/src/contract`
- `dart run tool/lsp_find_symbols.dart overlayPreviewRead --path-contains=lib/src/contract`
- `dart run tool/lsp_trace_symbol.dart lib/src/contract/scene_view_runtime.dart SceneViewRuntime.mainSceneRenderRead --direction=both --depth=2 --json-out=docs/architecture/evidence/render_main_scene_read_flow.json --mermaid-out=docs/architecture/evidence/render_main_scene_read_flow.md`
  Evidence:
  [render_main_scene_read_flow.json](../evidence/render_main_scene_read_flow.json),
  [render_main_scene_read_flow.md](../evidence/render_main_scene_read_flow.md)
- `dart run tool/lsp_trace_symbol.dart lib/src/contract/scene_view_runtime.dart SceneViewRuntime.overlayPreviewRead --direction=both --depth=2 --json-out=docs/architecture/evidence/render_overlay_preview_flow.json --mermaid-out=docs/architecture/evidence/render_overlay_preview_flow.md`
  Evidence:
  [render_overlay_preview_flow.json](../evidence/render_overlay_preview_flow.json),
  [render_overlay_preview_flow.md](../evidence/render_overlay_preview_flow.md)
- `dart run tool/lsp_trace_symbol.dart lib/src/view/scene_view_interactive_pointer_host.dart SceneViewInteractivePointerHost.handlePointerEvent --direction=outgoing --depth=3 --json-out=docs/architecture/evidence/pointer_input_flow.json --mermaid-out=docs/architecture/evidence/pointer_input_flow.md`
  Evidence:
  [pointer_input_flow.json](../evidence/pointer_input_flow.json),
  [pointer_input_flow.md](../evidence/pointer_input_flow.md)

## Proof Links

- Proof family: [public entrypoint and signature proof](../../proof_architecture/families/public_entrypoint_and_signature_proof.md)
- Proof family: [guardrail runner and artifact model](../../proof_architecture/families/guardrail_runner_and_artifact_model.md)
- Guardrail: `dart run tool/check_guardrails.dart`
- Import boundaries: `dart run tool/check_import_boundaries.dart`
- Invariant: `INV-G-LAYER-DAG`

## Status

- `locked`
- Checked-in code already exposes the split read surface through
  `SceneViewRuntime.mainSceneRenderRead` and
  `SceneViewRuntime.overlayPreviewRead`.

## Update Triggers

- Refresh this family when its listed owners, evidence commands, or linked proof surfaces change.
