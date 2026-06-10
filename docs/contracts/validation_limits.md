<!-- CONTEXT:BEGIN -->
Registry id: `section_06_validation_limits`
Registry source: `docs/_registry/sections.yaml`
Document path: `docs/contracts/validation_limits.md`
Owns:
- 6. Validation limits
Must read before editing:
- `section_04_public_api_v1` -> `docs/contracts/public_api_v1.md`
Current owners:
- `contract`
Benchmarks:
- `none`
Related diagrams:
- `dfd_diagnostics_error_projection`
Required tests:
- `test.codec.constructor_and_schema_limits`
Guardrails:
- `codec.known_fields_validated`
- `api.id_validation_no_extension_type_escape`
Do not assume:
- no unvalidated public ids
- no diagnostics surface leakage
<!-- CONTEXT:END -->

## 6. Validation limits

These limits are mandatory for v1 and define the current package validation boundary.

| Limit | Value |
|---|---:|
| max raw JSON length | `32 * 1024 * 1024` chars |
| max content layers | `4096` |
| max total elements | `200000` |
| max resources | `4096` |
| max element id length | `256` |
| max layer id length | `256` |
| max resource id/appKey raw length | `1024` |
| max action id length | `256` |
| max interaction request id length | `256` |
| max text length | `100000` |
| max SVG path data length | `200000` |
| max stroke points per element | `20000` |
| interactive stroke soft limit | `22000` |
| interactive stroke trim-to | `18000` |
| interactive eraser points soft limit | `8000` |
| interactive eraser points trim-to | `4000` |
| max palette items | `1024` per palette list |
| max font family length | `256` |
| coordinate min/max | `[-1e7, 1e7]` |
| max positive size | `1e7` |
| min enabled grid cell size | `1.0` |
| max thickness | `1e5` |
| max hitPadding | `1e5` |
| opacity range | `[0, 1]` |
| marker opacity range | `[0, 1]` |
| transform scale singular value min/max | `[1e-4, 1e4]` |
| path hit samples per metric | `2048` |
| spatial cell size | `256` |
| max spatial cells per element | `1024` |
| max spatial query cells | `50000` |
| metadata max depth | `8` |
| metadata max total encoded bytes | `1MB` |
| diagnostic verbose preview length | default `256`, range `[1, 4096]` chars |
| diagnostic verbose list entries | default `32`, range `[1, 128]` |

Validation is applied at:

```text
- public DTO construction;
- edit/update construction;
- dynamic or generated `CanvasFieldUpdate` materialization;
- edit preflight;
- schema v1 JSON validation and import;
- store-owned schema load preparation;
- resource upsert;
- runtime config construction and materialization;
- interaction config mutation;
- interaction request id generation and guarded request commit;
- pointer input routing.
```

Element transform admission uses the same validation boundary list. Every
`CanvasElement.transform` and changed `CanvasElementUpdate.transform` value
must be finite, invertible, and within the transform singular-value limits
before public DTO exposure, generated or dynamic update materialization, edit
preflight, schema v1 JSON validation/import, or store-owned schema load
preparation.
Non-invertible element transforms are rejected with `fieldMustBeInvertible`
before any draft mutation, runtime mutation, repaint, event, or public state
publication.

`CanvasInteractionRequestId` follows the public id validator contract:
non-empty canonical string, no leading/trailing whitespace, length <= 256, and
no control characters. It is
validated at public construction and at the engine boundary that generates
request ids for emitted interaction requests.

`CanvasResourceSource.appKey` follows the public resource source validator
contract: non-empty raw string, no leading/trailing whitespace, raw length <=
1024, and no control characters. The appKey is an application-owned identity,
so public DTO construction and schema v1 decode/import preserve the accepted
value exactly and do not trim or canonicalize it.

The raw JSON limit applies to `CanvasEditPort.loadDocumentFromJson(String json)`
before parse. Under current 32 * 1024 * 1024 character limit, 100k raw JSON load
acceptance is outside v1 release readiness unless a later design changes the
limit with memory proof.

`CanvasMetadata.fromMap` applies the metadata depth, key, string, and total
encoded-byte limits at public construction and deep-freezes nested list/map
values before exposure. Metadata accepted through schema v1 JSON validation uses
the same limits before import or public projection. Public constructors that accept
caller-provided values with documented runtime validation or sanitization are
non-const factories because validation and defensive ownership transfer must
run before the value is exposed. Public `const` remains reserved for marker,
empty, default, or private storage forms where invalid public state cannot be
constructed.

`CanvasFieldUpdate` carries static nullability guarantees for ordinary public
API consumers, but boundary materialization still validates dynamic, generated,
schema, and test-created update values. Invalid clear requests for non-nullable
fields are rejected before draft mutation or any runtime effect.

---
