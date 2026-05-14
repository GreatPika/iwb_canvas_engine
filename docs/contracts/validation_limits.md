<!-- CONTEXT:BEGIN -->
Registry id: `section_06_validation_limits`
Registry source: `docs/_registry/sections.yaml`
Document path: `docs/contracts/validation_limits.md`
Owns:
- 6. Validation limits
Must read before editing:
- `section_04_public_api_v1` -> `docs/contracts/public_api_v1.md`
Feeds phases:
- `P1.5`
- `P2`
- `P3`
- `P4`
Related donors:
- `foundation_contract_limits`
- `foundation_validators`
- `foundation_error_contract`
Related diagrams:
- `dfd_diagnostics_error_projection`
Required tests:
- `test.codec.constructor_and_schema_limits`
Guardrails:
- `codec.known_fields_validated`
- `api.id_validation_no_extension_type_escape`
Do not assume:
- no unvalidated public ids
- no legacy diagnostics surface leakage
<!-- CONTEXT:END -->

## 6. Validation limits

These limits are mandatory for v1. They intentionally preserve legacy safety limits where a legacy equivalent exists.

| Limit | Value |
|---|---:|
| max raw JSON length | `32 * 1024 * 1024` chars |
| max content layers | `4096` |
| max total elements | `200000` |
| max resources | `4096` |
| max element id length | `256` |
| max layer id length | `256` |
| max resource id/appKey length | `1024` |
| max action id length | `256` |
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
- edit preflight;
- schema decode;
- loadDocument materialization;
- resource upsert;
- runtime config construction and materialization;
- interaction config mutation;
- pointer sample routing.
```

---
