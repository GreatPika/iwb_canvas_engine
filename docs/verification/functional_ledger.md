<!-- CONTEXT:BEGIN -->
Registry id: `section_08_functional_ledger`
Registry source: `docs/_registry/sections.yaml`
Document path: `docs/verification/functional_ledger.md`
Owns:
- 8B. Functional ledger: legacy capability -> next API -> required test
Must read before editing:
- `section_08_legacy_capability_inventory` -> `docs/verification/legacy_capability_inventory.md`
- `section_04_public_api_v1` -> `docs/contracts/public_api_v1.md`
Feeds phases:
- `P1.5`
- `P14`
Related donors:
- `none`
Related diagrams:
- `none`
Required tests:
- `test.functional_ledger.row_specific_tests`
Guardrails:
- `api.functional_ledger_complete`
Do not assume:
- do not prove next API completeness by legacy public API ledger
<!-- CONTEXT:END -->

## 8B. Functional ledger: legacy capability -> next API -> required test

This ledger maps each P1 legacy capability inventory row to the next public API
surface and the row-specific functional test that proves the mapping. It is a
P1.5/P14 closure artifact: P1 owns legacy evidence, while this file closes the
next API mapping after the scope gate.

| Capability | Next API v1 | Required test id |
|---|---|---|
| create runtime/controller | `CanvasRuntime` | `functional.create_runtime` |
| show canvas as widget | `CanvasSurface` | `functional.surface_paints_empty` |
| load document | `runtime.edits.loadDocument` | `functional.load_document_success` |
| failed load preserves gesture | `loadDocument` staged contract | `functional.load_document_failure_preserves_preview` |
| get document | `runtime.readDocument()` | `functional.read_document` |
| add image node | `CanvasImageResource` + `CanvasImageElement` | `functional.add_image_element` |
| add SVG path node | `CanvasPathElement` | `functional.add_path_element` |
| add text node | `CanvasTextElement` | `functional.add_text_element` |
| add stroke node | `CanvasStrokeElement` | `functional.add_stroke_element` |
| add line node | `CanvasLineElement` | `functional.add_line_element` |
| add rect node | `CanvasRectElement` | `functional.add_rect_element` |
| select elements | `CanvasSelectionPort` | `functional.selection_set_toggle_clear` |
| marquee select | interaction move mode | `functional.marquee_select` |
| move selection | interaction + `CanvasMoveCommitResolver` | `functional.move_selection` |
| rotate selection | `rotateSelectionClockwise/CounterClockwise` | `functional.rotate_selection` |
| flip selection | `flipSelectionVertical/Horizontal` | `functional.flip_selection` |
| delete selection | `deleteSelection` | `functional.delete_selection` |
| clear canvas | `clearContent` | `functional.clear_content` |
| move mode | `CanvasInteractionMode.move` | `functional.mode_move` |
| draw mode | `CanvasInteractionMode.draw` | `functional.mode_draw` |
| pencil | `CanvasDrawTool.pencil` | `functional.draw_pencil` |
| marker/highlighter | `CanvasDrawTool.marker` | `functional.draw_marker` |
| line tool | `CanvasDrawTool.line` | `functional.draw_line` |
| eraser | `CanvasDrawTool.eraser` | `functional.eraser` |
| draw style color | `CanvasDrawStyle.color` | `functional.draw_color` |
| pencil thickness | `CanvasDrawStyle.pencilThickness` | `functional.pencil_thickness` |
| marker thickness | `CanvasDrawStyle.markerThickness` | `functional.marker_thickness` |
| marker opacity | `CanvasDrawStyle.markerOpacity` | `functional.marker_opacity` |
| line thickness | `CanvasDrawStyle.lineThickness` | `functional.line_thickness` |
| eraser thickness | `CanvasDrawStyle.eraserThickness` | `functional.eraser_thickness` |
| pointer settings | `CanvasPointerPolicy` | `functional.pointer_policy` |
| pending line state | `CanvasPreviewState` | `functional.pending_line_preview` |
| text edit request | `CanvasTextEditRequested` + guarded `CanvasCommandPort.commitTextEdit` | `functional.text_edit_request` |
| action committed event | `CanvasActionCommitted` typed payloads | `functional.action_events` |
| camera offset | `CanvasCameraPort.offset` + `CanvasRuntime.state.revisions.viewCamera` | `functional.camera_offset` |
| background color | `setBackgroundColor` | `functional.background_color` |
| grid enabled/size/color | `CanvasGrid` | `functional.grid` |
| palette | `CanvasPalette` | `functional.palette_roundtrip` |
| external image repaint | `markResourceDirty` | `functional.resource_dirty_repaint` |
| save/restore | schema v1 codec | `functional.schema_v1_roundtrip` |

All legacy inventory capabilities must have one row here. All rows must be
green before release.

---
