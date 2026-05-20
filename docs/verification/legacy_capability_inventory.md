<!-- CONTEXT:BEGIN -->
Registry id: `section_08_legacy_capability_inventory`
Registry source: `docs/_registry/sections.yaml`
Document path: `docs/verification/legacy_capability_inventory.md`
Owns:
- 8A. Legacy capability inventory
Must read before editing:
- `docs/donors/00_reuse_rules.md`
Feeds phases:
- `P1`
Related donors:
- `none`
Related diagrams:
- `none`
Required tests:
- `test.oracle.legacy_capability_inventory`
Guardrails:
- `oracle.legacy_capability_inventory_complete`
Do not assume:
- no next API mapping table as release proof
<!-- CONTEXT:END -->

## 8A. Legacy capability inventory

This inventory is the P1 legacy-oracle closure point. It records which legacy
capabilities must be preserved or explicitly rejected before any new public API
shape is frozen. It does not choose next API names or signatures, and it is not
a release-proof mapping table.

## Evidence closure checklist

When completing or auditing inventory rows, ensure these legacy behavior areas
are covered by rows and tests, or by an explicit accepted difference:

- edits are synchronous and non-nested;
- async edit callbacks are rejected;
- edit handles become stale after the transaction ends;
- rollback does not emit events, repaint, resource changes, or spatial updates;
- document replacement is staged as validate/materialize, interrupt gesture,
  then atomic install;
- failed document replacement does not interrupt the active gesture;
- main paint captures the frame once;
- overlay repaint is separate from main repaint;
- selected move preview repaints the main scene, not the overlay;
- marquee, draw, line, and eraser previews repaint the overlay;
- pending line state retains start, timestamp, color, and thickness facts;
- text editing is requested through an event and the editing UI belongs to the
  application;
- pointer policy includes legacy `tapSlop`, `doubleTapSlop`,
  `doubleTapMaxDelayMs`, `deferSingleTap`, and `dragStartSlop` behavior;
- draw style keeps separate thickness values for pencil, marker, line, and
  eraser, plus marker opacity;
- external visual resource repaint was represented by legacy
  `notifySceneChanged()` and is represented in the next API by resource dirtying,
  not engine-owned IO;
- legacy scene limits for ids, text, paths, strokes, JSON, layers, and nodes
  remain covered by validation-limit tests;
- geometry keeps legacy hit slop `4.0`, separate hit bounds, and separate paint
  bounds;
- spatial indexing keeps legacy cell size `256`, max cells per node `1024`,
  max query cells `50000`, large-node/outlier registry, and fallback behavior;
- action streams close on dispose;
- runtime-created timestamps are monotonic;
- legacy `imageId` behavior is migrated to the next-owned resource model;
- palette and legacy `grid.color` survive document read/write and migration
  coverage.

| Capability | Legacy oracle | Evidence focus |
|---|---|---|
| create runtime/controller | `SceneController` | runtime construction and lifecycle |
| show canvas as widget | `SceneView`/`SceneViewInteractive` | surface creation and empty paint |
| load document | `scene.replaceScene` | staged replacement success |
| failed load preserves gesture | staged replace code | failed replacement preservation |
| get document | `snapshot` | immutable document read |
| add image node | `ImageNodeSpec` | image element creation behavior |
| add SVG path node | `PathNodeSpec` | path element creation behavior |
| add text node | `TextNodeSpec` | text element creation behavior |
| add stroke node | `StrokeNodeSpec` | stroke element creation behavior |
| add line node | `LineNodeSpec` | line element creation behavior |
| add rect node | `RectNodeSpec` | rectangle element creation behavior |
| select elements | selection owner | selection set/toggle/clear behavior |
| marquee select | move selection coordinator | marquee selection behavior |
| move selection | move coordinator | selected move behavior |
| rotate selection | selection owner | selected transform behavior |
| flip selection | selection owner | selected transform behavior |
| delete selection | selection owner | selection deletion behavior |
| clear canvas | scene owner | content clearing behavior |
| move mode | `CanvasMode.move` | mode selection behavior |
| draw mode | `CanvasMode.draw` | mode selection behavior |
| pencil | `DrawTool.pen` | pencil draw behavior |
| marker/highlighter | `DrawTool.highlighter` | marker draw behavior |
| line tool | `DrawTool.line` | line draw behavior |
| eraser | `DrawTool.eraser` | eraser behavior |
| draw style color | interaction config | draw style color behavior |
| pencil thickness | interaction config | pencil thickness behavior |
| marker thickness | interaction config | marker thickness behavior |
| marker opacity | interaction config | marker opacity behavior |
| line thickness | interaction config | line thickness behavior |
| eraser thickness | interaction config | eraser thickness behavior |
| pointer settings | `PointerInputSettings` | pointer policy behavior |
| pending line state | interaction getters | pending line preview state |
| text edit request | `EditTextRequested` | text edit request event |
| action committed event | `ActionCommitted` | user action event behavior |
| camera offset | `CameraSnapshot.offset` | camera state behavior |
| background color | scene owner | background state behavior |
| grid enabled/size/color | `GridSnapshot` | grid state behavior |
| palette | `ScenePaletteSnapshot` | palette state behavior |
| external image repaint | `notifySceneChanged` | external visual resource repaint |
| save/restore | schema codec | document persistence behavior |

Inventory rows feed later behavior tests and accepted-difference decisions. They
must not be treated as proof that the next public API is complete.

---
