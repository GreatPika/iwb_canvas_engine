<!-- CONTEXT:BEGIN -->
Registry id: `section_08_functional_ledger`
Registry source: `docs/split/_registry/sections.yaml`
Document path: `docs/split/verification/functional_ledger.md`
Owns:
- 8. Functional ledger: old capability -> new API -> required test
Must read before editing:
- `section_01_legacy_oracle` -> `docs/split/planning/legacy_oracle.md`
- `section_04_public_api_v1` -> `docs/split/contracts/public_api_v1.md`
- `docs/split/donors/00_reuse_rules.md`
Depends on:
- `section_01_legacy_oracle` -> `docs/split/planning/legacy_oracle.md`
- `section_04_public_api_v1` -> `docs/split/contracts/public_api_v1.md`
- `docs/split/donors/00_reuse_rules.md`
Feeds phases:
- `P1`
- `P12`
Related donors:
- `none`
Related diagrams:
- `none`
Required tests:
- `test.functional_ledger.row_specific_tests`
Guardrails:
- `new_api.functional_ledger_complete`
Do not assume:
- do not prove next API completeness by old public API ledger
<!-- CONTEXT:END -->

## 8. Functional ledger: old capability -> new API -> required test

| Capability | Old oracle | New API v1 | Required test id |
|---|---|---|---|
| create runtime/controller | `SceneController` | `CanvasRuntime` | `functional.create_runtime` |
| show canvas as widget | `SceneView`/`SceneViewInteractive` | `CanvasSurface` | `functional.surface_paints_empty` |
| load document | `scene.replaceScene` | `runtime.edits.loadDocument` | `functional.load_document_success` |
| failed load preserves gesture | staged replace code | `loadDocument` staged contract | `functional.load_document_failure_preserves_preview` |
| get document | `snapshot` | `runtime.readDocument()` | `functional.read_document` |
| add image node | `ImageNodeSpec` | `CanvasImageResource` + `CanvasImageElement` | `functional.add_image_element` |
| add SVG path node | `PathNodeSpec` | `CanvasPathElement` | `functional.add_path_element` |
| add text node | `TextNodeSpec` | `CanvasTextElement` | `functional.add_text_element` |
| add stroke node | `StrokeNodeSpec` | `CanvasStrokeElement` | `functional.add_stroke_element` |
| add line node | `LineNodeSpec` | `CanvasLineElement` | `functional.add_line_element` |
| add rect node | `RectNodeSpec` | `CanvasRectElement` | `functional.add_rect_element` |
| select elements | selection owner | `CanvasSelectionPort` | `functional.selection_set_toggle_clear` |
| marquee select | move selection coordinator | interaction move mode | `functional.marquee_select` |
| move selection | move coordinator | interaction + `CanvasMoveCommitResolver` | `functional.move_selection` |
| rotate selection | selection owner | `rotateSelectionClockwise/CounterClockwise` | `functional.rotate_selection` |
| flip selection | selection owner | `flipSelectionVertical/Horizontal` | `functional.flip_selection` |
| delete selection | selection owner | `deleteSelection` | `functional.delete_selection` |
| clear canvas | scene owner | `clearContent` | `functional.clear_content` |
| move mode | `CanvasMode.move` | `CanvasInteractionMode.move` | `functional.mode_move` |
| draw mode | `CanvasMode.draw` | `CanvasInteractionMode.draw` | `functional.mode_draw` |
| pencil | `DrawTool.pen` | `CanvasDrawTool.pencil` | `functional.draw_pencil` |
| marker/highlighter | `DrawTool.highlighter` | `CanvasDrawTool.marker` | `functional.draw_marker` |
| line tool | `DrawTool.line` | `CanvasDrawTool.line` | `functional.draw_line` |
| eraser | `DrawTool.eraser` | `CanvasDrawTool.eraser` | `functional.eraser` |
| draw style color | interaction config | `CanvasDrawStyle.color` | `functional.draw_color` |
| pencil thickness | interaction config | `CanvasDrawStyle.pencilThickness` | `functional.pencil_thickness` |
| marker thickness | interaction config | `CanvasDrawStyle.markerThickness` | `functional.marker_thickness` |
| marker opacity | interaction config | `CanvasDrawStyle.markerOpacity` | `functional.marker_opacity` |
| line thickness | interaction config | `CanvasDrawStyle.lineThickness` | `functional.line_thickness` |
| eraser thickness | interaction config | `CanvasDrawStyle.eraserThickness` | `functional.eraser_thickness` |
| pointer settings | `PointerInputSettings` | `CanvasPointerPolicy` | `functional.pointer_policy` |
| pending line state | interaction getters | `CanvasPreviewState` | `functional.pending_line_preview` |
| text edit request | `EditTextRequested` | `CanvasTextEditRequested` | `functional.text_edit_request` |
| action committed event | `ActionCommitted` | `CanvasActionCommitted` typed payloads | `functional.action_events` |
| camera offset | `CameraSnapshot.offset` | `CanvasCameraPort.offset` | `functional.camera_offset` |
| background color | scene owner | `setBackgroundColor` | `functional.background_color` |
| grid enabled/size/color | `GridSnapshot` | `CanvasGrid` | `functional.grid` |
| palette | `ScenePaletteSnapshot` | `CanvasPalette` | `functional.palette_roundtrip` |
| external image repaint | `notifySceneChanged` | `markResourceDirty` | `functional.resource_dirty_repaint` |
| save/restore | schema codec | schema v1 codec | `functional.schema_v1_roundtrip` |
| old saved docs migration | old schema v7 | migration tool outside core | `migration.schema_v7_to_v1` |

All rows must be green before release.

---

