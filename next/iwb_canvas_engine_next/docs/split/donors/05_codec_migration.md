<!-- CONTEXT:BEGIN -->
Registry id: `donors_05_codec_migration`
Source: `docs/iwb_canvas_engine_next_donor_inventory.md / Codec and migration donors`
Canonical original: `docs/iwb_canvas_engine_next_donor_inventory.md`
Feeds registry: `docs/split/_registry/donors.yaml`
Feeds indexes:
- `docs/split/indexes/donor_to_phase.md`
- `docs/split/indexes/phase_to_donor.md`
Use rule: donor entries are phase-bound implementation inputs, not old architecture to copy.
<!-- CONTEXT:END -->

<!-- ORIGINAL-SECTION:BEGIN -->
## Codec and migration donors

Use these to build the schema v1 codec and later the schema v7 migration tool.
The old `SceneBuilder` shape is not the new architecture.

| Donor | What to preserve | Reuse | Risks | Target phase |
|---|---|---:|---|---|
| `lib/src/serialization/codec_guards.dart` | raw JSON length guard, parse guard, non-object root guard | `copy/adapt` | currently `part of scene_codec.dart` | P3 |
| `lib/src/model/scene_builder_json_require.dart` | path builder and strict field access helpers | `copy/adapt` | rename away from `SceneBuilder` | P3 |
| `lib/src/model/scene_builder_json_parse.dart` | color/size/offset/transform/enum parsers | `adapt` | old enum and transform names | P3 |
| `lib/src/model/scene_builder_decode_scene_metadata.dart` | schema gate, camera/background/grid/palette validation sequence | `adapt` | old schema shape | P3/P11 |
| `lib/src/model/scene_builder_decode_layers.dart` | layer/background layer decode loops and node budget pathing | `adapt` | layer model may change | P3 |
| `lib/src/model/scene_builder_decode_node_common.dart` | common id/revision/transform/flag/opacity/hitPadding decode | `adapt` | `instanceRevision` behavior is migration-relevant | P3/P11 |
| `lib/src/model/scene_builder_decode_image.dart`, `*_path.dart`, `*_text.dart`, `*_stroke.dart`, `*_line.dart`, `*_rect.dart` | family decode validation and diagnostic paths | `adapt` | old JSON aliases belong mostly to migration | P3/P11 |
| `lib/src/serialization/scene_codec.dart` | canonical encode/decode flow and encode helpers | `adapt/rewrite` | too coupled to `SceneSnapshot` and `SceneBuilder` | P3 |
| `lib/src/model/scene_validation_path_surface.dart` | typed-vs-JSON diagnostic path aliasing | `copy/adapt` | only needed where aliases remain | P3/P11 |
| `tool/audit_schema_family_parity.dart` | static schema-family parity audit | `adapt` | valuable only if next keeps field-record schema families | P12/tooling |

Migration-relevant old behavior to preserve as reference:

- current mainline writes schema v7 and reads only v7;
- unsupported schema versions are rejected;
- legacy text `size` is rejected in schema v7;
- text payloads require explicit `textDirection`;
- missing `instanceRevision` is accepted on old decode and re-encoded with an
  allocated revision;
- old JSON diagnostic aliases include line `localA`/`localB` and stroke
  `localPoints`.

<!-- ORIGINAL-SECTION:END -->
