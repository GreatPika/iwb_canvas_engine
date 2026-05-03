<!-- CONTEXT:BEGIN -->
Registry id: `section_05_schema_v1_contract`
Source: `docs/split/_registry/sections.yaml / section 5`
Canonical source: `docs/split/_registry/sections.yaml`
Owns:
- 5. Schema v1 full field contract
Must read before editing:
- `section_04_public_api_v1`
- `section_06_validation_limits`
- `section_19_codec_boundary`
- `section_25_migration_tool`
Depends on:
- `section_04_public_api_v1`
- `section_06_validation_limits`
- `section_19_codec_boundary`
- `section_25_migration_tool`
Feeds phases:
- `P3`
Related donors:
- `codec_guards`
- `codec_json_require`
- `codec_json_parse`
- `codec_metadata_decode`
- `codec_layer_decode`
- `codec_node_common_decode`
- `codec_family_decode`
- `codec_scene_codec_flow`
- `codec_validation_path_surface`
- `dto_boundary_schema`
Related diagrams:
- docs/split/diagrams/README.md#dfd_schema_v1_decode_encode -> docs/split/diagrams/generated/dfd_schema_v1_decode_encode.mmd
Required tests:
- `test.schema_v1.known_fields_validation`
- `test.schema_v1.resources_appkey_only`
- `test.schema_v1.reject_unknown_element_kind`
- `test.schema_v1.reject_unknown_resource_source_kind`
Guardrails:
- `codec.schema_v1_exact`
- `codec.known_fields_validated`
Do not infer:
- no schema v7 public entrypoints as next API
- no old SceneBuilder API shape
<!-- CONTEXT:END -->

<!-- ORIGINAL-SECTION:BEGIN -->
## 5. Schema v1 full field contract

### 5.1 Top-level JSON

`canvasSchemaVersionWrite == 1` and `canvasSchemaVersionsRead == {1}`.

Canonical JSON shape:

```json
{
  "schemaVersion": 1,
  "camera": { "offset": { "x": 0.0, "y": 0.0 } },
  "background": {
    "color": "#FFFFFFFF",
    "grid": { "enabled": false, "cellSize": 10.0, "color": "#1F000000" }
  },
  "palette": {
    "penColors": ["#FF000000", "#FFE53935", "#FF1E88E5", "#FF43A047", "#FFFB8C00", "#FF8E24AA"],
    "backgroundColors": ["#FFFFFFFF", "#FFFFF9C4", "#FFBBDEFB", "#FFC8E6C9"],
    "gridSizes": [10.0, 20.0, 40.0, 80.0]
  },
  "resources": [],
  "backgroundLayer": { "elements": [] },
  "layers": [],
  "metadata": {}
}
```

Unknown fields policy:

```text
- known schema v1 fields are validated;
- unknown non-metadata fields are ignored on decode;
- unknown non-metadata fields are not preserved by canonical encode;
- metadata is the only roundtripped extension area;
- unsupported schemaVersion is rejected.
- unknown element kind is rejected;
- unknown resource source kind is rejected;
- unknown enum value is rejected.
```

### 5.2 Primitive encodings

| Type | JSON | Validation |
|---|---|---|
| Color | `"#AARRGGBB"` uppercase canonical encode | exactly 9 chars, `#` + 8 hex digits |
| Offset | `{ "x": number, "y": number }` | finite, each in `[-1e7, 1e7]` |
| Size | `{ "w": number, "h": number }` | finite, `>0`, `<=1e7` |
| Rect | `{ "l": number, "t": number, "r": number, "b": number }` | finite, normalized on encode |
| CanvasTransform | `{ "a": number, "b": number, "c": number, "d": number, "tx": number, "ty": number }` | finite, scale singular values in `[1e-4, 1e4]` when invertibility needed |
| enum | lower camel string | unknown value rejected |
| metadata | JSON object | JSON-only values, limits below |

### 5.3 Resource JSON

Image resource:

```json
{
  "id": "sample-cat",
  "kind": "image",
  "source": { "kind": "appKey", "key": "sample-cat" },
  "mimeType": "image/png",
  "contentHash": null,
  "byteLength": null,
  "metadata": {}
}
```

Rules:

```text
source.kind=appKey    -> requires key;
appKey                -> non-empty string, length <= 1024, no control characters;
contentHash           -> null or non-empty string <= 256;
byteLength            -> null or int >= 0 and <= 32MB;
mimeType              -> null or non-empty string <= 128;
resource id uniqueness -> global across document.
```

### 5.4 Element common JSON

Every element contains:

```json
{
  "id": "e1",
  "kind": "text",
  "revision": 0,
  "transform": { "a": 1, "b": 0, "c": 0, "d": 1, "tx": 0, "ty": 0 },
  "opacity": 1.0,
  "hitPadding": 0.0,
  "isVisible": true,
  "isSelectable": true,
  "isLocked": false,
  "isDeletable": true,
  "isTransformable": true,
  "metadata": {}
}
```

Defaults are applied by constructors and canonical encoder always writes all common fields.

### 5.5 Element family JSON

Image element:

```json
{
  "kind": "image",
  "resourceId": "sample-cat",
  "size": { "w": 120.0, "h": 180.0 },
  "naturalSize": { "w": 600.0, "h": 900.0 }
}
```

`naturalSize` may be omitted or null.

Path element:

```json
{
  "kind": "path",
  "svgPathData": "M 0 0 L 10 0 L 10 10 Z",
  "fillColor": "#FF000000",
  "strokeColor": null,
  "strokeWidth": 0.0,
  "fillRule": "nonZero"
}
```

Text element:

```json
{
  "kind": "text",
  "text": "New Note",
  "fontSize": 24.0,
  "color": "#FF000000",
  "align": "left",
  "textDirection": "ltr",
  "isBold": false,
  "isItalic": false,
  "isUnderline": false,
  "fontFamily": null,
  "maxWidth": null,
  "lineHeight": null
}
```

Stroke element:

```json
{
  "kind": "stroke",
  "points": [{ "x": 0.0, "y": 0.0 }, { "x": 10.0, "y": 10.0 }],
  "thickness": 3.0,
  "color": "#FF000000"
}
```

Line element:

```json
{
  "kind": "line",
  "start": { "x": -5.0, "y": 0.0 },
  "end": { "x": 5.0, "y": 0.0 },
  "thickness": 3.0,
  "color": "#FF000000"
}
```

Rect element:

```json
{
  "kind": "rect",
  "size": { "w": 140.0, "h": 90.0 },
  "fillColor": "#330000FF",
  "strokeColor": "#FF0000FF",
  "strokeWidth": 2.0
}
```

### 5.6 Layer JSON

```json
{
  "id": "layer-auto-0",
  "elements": [],
  "metadata": {}
}
```

Layer flags are not part of v1. Element-level flags handle visibility/lock/delete/transform/selectability.

### 5.7 Metadata policy

Metadata is the only extension area.

```text
allowed values     -> null, bool, finite num, string, List, Map<String, Object?>;
forbidden values   -> DateTime, Offset, Color, Uri object, enum object, closures, runtime objects;
max depth          -> 8;
max object keys    -> 1024 per object;
max key length     -> 256;
max string length  -> 65536;
max total encoded metadata bytes per document -> 1MB;
unknown metadata keys -> preserved roundtrip;
metadata may not override schema fields.
```

---

<!-- ORIGINAL-SECTION:END -->
