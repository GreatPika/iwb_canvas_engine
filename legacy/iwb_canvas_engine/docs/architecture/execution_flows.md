# Target Execution Flows

## Purpose

This document is the runtime-view layer of the atlas.

It records only mechanically supported runtime-center flows and the target
boundary each artifact is used to check. It does not carry hand-written flow
diagrams or unsupported runtime views.

## Runtime-View Registry

| Flow | Entry point | Boundary it checks | Evidence |
| --- | --- | --- | --- |
| Add-node write path | `SceneControllerSceneOwner.addNode` | Interaction-owned writes still cross `SceneControllerMutationBoundary` before they reach committed mutation access. | [JSON](evidence/add_node_write_flow.json), [Mermaid](evidence/add_node_write_flow.md) |
| Pointer input orchestration | `SceneViewInteractivePointerHost.handlePointerEvent` | Pointer hosting stays in `view/**`, while routed pointer-session work stays behind the `SceneViewRuntime` boundary. | [JSON](evidence/pointer_input_flow.json), [Mermaid](evidence/pointer_input_flow.md) |
| Main-scene render read | `SceneViewRuntime.mainSceneRenderRead` | `SceneViewRuntime` keeps one main-scene render-read facet for `SceneViewRenderSurface`. | [JSON](evidence/render_main_scene_read_flow.json), [Mermaid](evidence/render_main_scene_read_flow.md) |
| Overlay preview read | `SceneViewRuntime.overlayPreviewRead` | `SceneViewRuntime` keeps a separate overlay-preview read facet for `SceneViewInteractiveOverlayPainter`. | [JSON](evidence/render_overlay_preview_flow.json), [Mermaid](evidence/render_overlay_preview_flow.md) |

## Update Rules

- Keep this file limited to mechanically supported runtime-center flows.
- Do not reintroduce the unsupported import/build view until a checked-in probe
  can derive and persist that path mechanically.
- Link to committed evidence artifacts only; family docs own the local target
  rule and probe-command detail.

## Evidence Commands

- `dart run tool/lsp_trace_symbol.dart lib/src/interactive/scene_controller_scene.dart SceneControllerSceneOwner.addNode --direction=outgoing --depth=5 --omit-reference-path-prefix=test/ --omit-reference-path-prefix=example/ --json-out=docs/architecture/evidence/add_node_write_flow.json --mermaid-out=docs/architecture/evidence/add_node_write_flow.md`
- `dart run tool/lsp_trace_symbol.dart lib/src/view/scene_view_interactive_pointer_host.dart SceneViewInteractivePointerHost.handlePointerEvent --direction=outgoing --depth=3 --omit-reference-path-prefix=test/ --omit-reference-path-prefix=example/ --json-out=docs/architecture/evidence/pointer_input_flow.json --mermaid-out=docs/architecture/evidence/pointer_input_flow.md`
- `dart run tool/lsp_trace_symbol.dart lib/src/contract/scene_view_runtime.dart SceneViewRuntime.mainSceneRenderRead --direction=both --depth=2 --omit-reference-path-prefix=test/ --omit-reference-path-prefix=example/ --json-out=docs/architecture/evidence/render_main_scene_read_flow.json --mermaid-out=docs/architecture/evidence/render_main_scene_read_flow.md`
- `dart run tool/lsp_trace_symbol.dart lib/src/contract/scene_view_runtime.dart SceneViewRuntime.overlayPreviewRead --direction=both --depth=2 --omit-reference-path-prefix=test/ --omit-reference-path-prefix=example/ --json-out=docs/architecture/evidence/render_overlay_preview_flow.json --mermaid-out=docs/architecture/evidence/render_overlay_preview_flow.md`
