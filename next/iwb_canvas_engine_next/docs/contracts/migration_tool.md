<!-- CONTEXT:BEGIN -->
Registry id: `section_25_migration_tool`
Registry source: `docs/_registry/sections.yaml`
Document path: `docs/contracts/migration_tool.md`
Owns:
- 25. Migration tool outside production core
Must read before editing:
- `section_05_schema_v1_contract` -> `docs/contracts/schema_v1.md`
- `section_09_accepted_differences` -> `docs/architecture/04_decisions_and_differences.md`
- `section_19_codec_boundary` -> `docs/contracts/codec_boundary.md`
Feeds phases:
- `P11`
Related donors:
- `codec_metadata_decode`
- `codec_node_common_decode`
- `codec_family_decode`
- `codec_scene_codec_flow`
- `codec_validation_path_surface`
Related diagrams:
- `dfd_migration_tool`
Required tests:
- `test.migration.old_fixture_migration`
- `test.migration.no_silent_data_loss`
Guardrails:
- `codec.schema_v1_exact`
Do not assume:
- no migration code inside production core
- no silent data loss
<!-- CONTEXT:END -->

## 25. Migration tool outside production core

Production core reads/writes only schema v1.

A separate tool package is required:

```text
packages/canvas_migration_tools/
  lib/
    old_schema_v7_to_next_v1.dart
    migration_report.dart
    data_loss_report.dart
  test/
    old_fixtures_v7/
    migration_roundtrip_test.dart
    data_loss_report_test.dart
```

Mapping:

| Old | New |
|---|---|
| `SceneSnapshot.camera.offset` | `CanvasDocument.camera.offset` |
| `BackgroundSnapshot.color` | `CanvasBackground.color` |
| `GridSnapshot.enabled/cellSize/color` | `CanvasGrid.enabled/cellSize/color` |
| `ScenePaletteSnapshot` | `CanvasPalette` |
| `ContentLayerSnapshot.id` | `CanvasLayer.id` |
| `BackgroundLayerSnapshot.nodes` | `CanvasDocument.backgroundElements` |
| `ImageNodeSnapshot.imageId` | `CanvasImageResource(id=imageId, source=appKey(imageId))` + `CanvasImageElement.resourceId` |
| `TextNodeSnapshot` | `CanvasTextElement` |
| `StrokeNodeSnapshot` | `CanvasStrokeElement` |
| `LineNodeSnapshot` | `CanvasLineElement` |
| `RectNodeSnapshot` | `CanvasRectElement` |
| `PathNodeSnapshot.svgPathData` | `CanvasPathElement.svgPathData` |
| `instanceRevision` | `CanvasElement.revision` |
| common flags | common flags |
| `Transform2D` | `CanvasTransform` |

Migration report must list:

```text
input schema version;
output schema version;
element count;
resource count;
created resources from imageId;
unsupported fields;
losses;
warnings;
errors.
```

No silent data loss is allowed. Any intentional loss must appear in `DataLossReport`.

---

