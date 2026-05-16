<!-- CONTEXT:BEGIN -->
Registry id: `donors_05_codec`
Source: `docs/_registry/donors.yaml / Codec donors`
Canonical source: `docs/_registry/donors.yaml`
Feeds registry: `docs/_registry/donors.yaml`
Feeds indexes:
- `docs/indexes/donor_to_phase.md`
Use rule: donor entries are phase-bound implementation inputs, not legacy architecture to copy.
<!-- CONTEXT:END -->

## Codec donors

Use these to build the schema v1 codec. The legacy `SceneBuilder` shape and raw
map metadata DTO exposure are not the next architecture; accepted metadata
materializes as `CanvasMetadata`.

| Donor | What to preserve | Reuse | Risks | Target phase |
|---|---|---:|---|---|
| `lib/src/serialization/codec_guards.dart` | raw JSON length guard, parse guard, non-object root guard | `copy/adapt` | currently `part of scene_codec.dart` | P3 |
| `lib/src/model/scene_builder_json_require.dart` | path builder and strict field access helpers | `copy/adapt` | rename away from `SceneBuilder` | P3 |
| `lib/src/model/scene_builder_json_parse.dart` | color/size/offset/transform/enum parsers | `adapt` | legacy enum and transform names | P3 |
| `lib/src/model/scene_builder_decode_scene_metadata.dart` | schema gate, camera/background/grid/palette validation sequence, and `CanvasMetadata` materialization behavior | `adapt` | legacy schema shape | P3 |
| `lib/src/model/scene_builder_decode_layers.dart` | layer/background layer decode loops and node budget pathing | `adapt` | layer model may change | P3 |
| `lib/src/model/scene_builder_decode_node_common.dart` | common id/revision/transform/flag/opacity/hitPadding decode | `adapt` | legacy common-field behavior may not be schema v1 behavior | P3 |
| `lib/src/model/scene_builder_decode_image.dart`, `*_path.dart`, `*_text.dart`, `*_stroke.dart`, `*_line.dart`, `*_rect.dart` | family decode validation and diagnostic paths | `adapt` | legacy JSON aliases are not preserved unless approved for schema v1 | P3 |
| `lib/src/serialization/scene_codec.dart` | canonical encode/decode flow and encode helpers | `adapt/rewrite` | too coupled to `SceneSnapshot` and `SceneBuilder` | P3 |
| `lib/src/model/scene_validation_path_surface.dart` | typed-vs-JSON diagnostic path aliasing | `copy/adapt` | only needed where aliases remain | P3 |
| `tool/audit_schema_family_parity.dart` | static schema-family parity audit | `adapt` | valuable only if next keeps field-record schema families | P12/tooling |

Legacy codec behavior to preserve as reference where it matches schema v1:

- current mainline writes schema v7 and reads only v7;
- unsupported schema versions are rejected;
- legacy text `size` is rejected in schema v7;
- text payloads require explicit `textDirection`;
- missing `instanceRevision` is accepted on legacy decode and re-encoded with an
  allocated revision;
- legacy JSON diagnostic aliases include line `localA`/`localB` and stroke
  `localPoints`.
