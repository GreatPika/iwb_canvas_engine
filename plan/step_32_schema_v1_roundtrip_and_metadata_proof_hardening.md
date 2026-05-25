# Change Contract

## Goal

Harden the schema v1 codec proof so canonical encode/decode tests demonstrate full public DTO field equivalence after roundtrip and metadata projection coverage spans every schema-owned metadata owner: document, resource, layer, background element, and layer element. This step changes only the two schema v1 test proof surfaces plus repository-required closure checkboxes; it does not change production codec behavior, public DTO equality policy, schema format, or documentation source-of-truth content.

## Evidence

- `docs/implementation/p3_schema_v1_dto_validation_and_codec_skeleton.md` / exit gate: P3 requires all schema roundtrip tests to be green and metadata roundtrip tests to prove `CanvasMetadata` projects to canonical JSON object values without exposing raw maps as public DTO metadata -> the proof gap belongs in P3 codec tests.
- `docs/contracts/schema_v1.md` / required tests: `test.codec.schema_v1.canonical_encode_roundtrip` and `test.codec.schema_v1.metadata_projection` are required proof surfaces for schema v1 -> strengthen these tests instead of adding a parallel proof owner.
- `docs/contracts/schema_v1.md` / schema v1 full field contract: schema v1 owns document top-level fields, resource fields, layer fields, element common fields, all element family fields, and metadata as the only roundtripped extension area -> roundtrip proof must compare every schema-owned DTO field, not only ids and JSON keys.
- `docs/contracts/codec_boundary.md` / encode algorithm: encode must preserve layer/resource/element order, include all common element fields, project `CanvasMetadata`, and preserve metadata -> canonical encode proof must keep JSON shape/order checks and add decoded DTO equivalence.
- `lib/src/api/canvas_document.dart` / public DTO owners: `CanvasDocument` exposes `camera`, `background`, `palette`, `resources`, `backgroundElements`, `layers`, and `metadata`; `CanvasLayer` exposes `id`, `elements`, and `metadata` -> document and layer equivalence must compare these public fields explicitly.
- `lib/src/api/canvas_resource.dart` / public resource owners: `CanvasResource` exposes `id`, `source`, `contentHash`, `byteLength`, and `metadata`; `CanvasImageResource` exposes `mimeType`; `CanvasAppKeyResourceSource` exposes `key` -> resource equivalence must include common, image, and source fields.
- `lib/src/api/canvas_element.dart` / public element owners: every `CanvasElement` exposes common fields including `revision`, `transform`, visibility/selectability/lock/delete/transform flags, and `metadata`; each element family exposes its own variant fields -> element equivalence must include common fields and variant-specific fields for image, path, text, stroke, line, and rect.
- `test/api_contract/public_equality_policy_test.dart` / public equality policy: `CanvasDocument` and resources intentionally keep identity equality while `CanvasMetadata` is value-equatable -> the proof must use test-side field comparison helpers and must not add production `operator ==` or change public equality semantics.
- `test/codec/schema_v1/canonical_encode_roundtrip_test.dart` / embedded consumer test: the current test keeps canonical JSON key checks but, after decode, only checks element ids/order and that JSON decode returns a map -> the existing proof is partial and should be strengthened in this file.
- `test/codec/schema_v1/metadata_projection_test.dart` / embedded consumer test: the current projection proof checks only root document metadata decode, encode, and encoded-map immutability -> the test must cover resource, layer, background element, and layer element metadata owners too.
- `lib/src/codec/schema_v1_decoder.dart` / metadata readers: schema v1 reads metadata for root document, resources, layers, and common elements; background and layer elements share the common element metadata reader -> metadata projection proof must exercise both element containers even though the element metadata path is shared.
- `lib/src/codec/schema_v1_encoder.dart` / metadata writers: schema v1 writes metadata at root, resource, layer, and common element positions -> encode proof must inspect encoded metadata at each corresponding JSON owner path.

## Boundaries

Owner:

Schema v1 codec tests own the executable proof. Public API DTO owners and codec production code remain evidence surfaces, not edit targets for this step.

In Scope:

- Strengthen `test/codec/schema_v1/canonical_encode_roundtrip_test.dart` by making the embedded fixture cover non-default schema-owned document, resource, layer, element common, element family, and metadata fields.
- Add embedded consumer-source helper functions in `test/codec/schema_v1/canonical_encode_roundtrip_test.dart` that compare decoded `CanvasDocument` values against the source document by public DTO fields, preserving order-sensitive list comparisons.
- Compare both `decodeCanvasDocument(encodeCanvasDocument(document))` and `decodeCanvasDocumentFromJson(encodeCanvasDocumentToJson(document))` against the source document through the same field-equivalence helper.
- Keep the existing canonical JSON key and shape checks in `test/codec/schema_v1/canonical_encode_roundtrip_test.dart`, including schema version, background layer shape, encoded resource shape, element family keys, element ordering, color canonicalization, and omission of legacy root `backgroundElements`.
- Strengthen `test/codec/schema_v1/metadata_projection_test.dart` so the embedded source decodes and re-encodes metadata for document, resource, layer, background element, and layer element owners.
- Add metadata projection checks that each owner materializes public `CanvasMetadata`, preserves nested JSON-compatible values, encodes metadata back to the correct JSON owner path, drops unknown non-metadata fields, and exposes unmodifiable encoded metadata maps/lists.
- Stop implementation and report a Contract Blocker or create a new follow-up contract if the strengthened tests expose a production schema v1 codec defect; do not fix production code in this step.

Out of Scope:

- Production codec behavior changes, including fixes for defects exposed by the strengthened tests.
- Public DTO equality policy changes, including adding `operator ==` to `CanvasDocument`, resources, layers, or elements.
- Schema v1 JSON format changes, new public API names, runtime/store behavior changes, metadata limit changes, diagnostics changes, generated architecture graph changes, and durable documentation edits except the repository-required closure-only checkbox updates in `PLAN.md` and this linked step document when the step is completed.
- Creating a shared test-support helper that requires publishing test-only DTO equivalence APIs to the embedded consumer package.

Source of Truth:

`docs/contracts/schema_v1.md` and `docs/contracts/codec_boundary.md` remain the normative source of truth for schema v1 field ownership, canonical encode behavior, unknown-field policy, and metadata projection. `test/codec/schema_v1/canonical_encode_roundtrip_test.dart` and `test/codec/schema_v1/metadata_projection_test.dart` are the executable proof surfaces for this step.

Compatibility:

The public package API, public DTO equality semantics, schema v1 JSON shape, unknown-field policy, metadata wire shape, and codec entrypoint signatures must remain compatible. The embedded consumer tests must continue to use only public `package:iwb_canvas_engine/iwb_canvas_engine.dart` APIs.

Order Constraints:

First strengthen the canonical roundtrip fixture and add field-equivalence helpers so the complete decoded DTO comparison is available. Then expand metadata projection coverage for every metadata owner path. Run focused schema v1 tests before repository-wide Dart and DCM checks, and only mark the `PLAN.md` entry plus this linked step document complete after all checks named by the contract have passed.

## Execution Units

### [ ] Unit 1: Full DTO roundtrip equivalence proof

Owner:

`test/codec/schema_v1/canonical_encode_roundtrip_test.dart`.

Boundary:

Embedded Flutter consumer source for schema v1 canonical encode/decode proof.

Change:

Update the embedded source document fixture to set non-default schema-owned fields across document, camera, background, grid, palette, image resource, background rect element, content layer, and image/path/text/stroke/line elements. Add local embedded helper functions that compare decoded documents to the source document by public DTO fields: document sections, palette lists, resources and resource source, layers, element common fields, and every element family field. Use the helper for both map-based and JSON-string-based decode after encode. Preserve existing canonical JSON key/order, shape, color, legacy-field omission, and element ordering assertions.

Completion Check:

`dart test test/codec/schema_v1/canonical_encode_roundtrip_test.dart` passes, and the embedded source contains a decoded-document assertion that would fail if any schema-owned public DTO field is dropped or changed during encode/decode for document, resource, layer, common element, or image/path/text/stroke/line/rect element fields.

Depends On:

None.

### [ ] Unit 2: All-owner metadata projection proof

Owner:

`test/codec/schema_v1/metadata_projection_test.dart`.

Boundary:

Embedded Flutter consumer source for schema v1 metadata decode, encode, unknown-field discard, and encoded-object immutability proof.

Change:

Expand the embedded raw schema v1 JSON fixture so metadata appears at root document, `resources[].metadata`, `backgroundLayer.elements[].metadata`, `layers[].metadata`, and `layers[].elements[].metadata`. Assert that each owner decodes to public `CanvasMetadata` with the expected nested values, re-encodes metadata at the same schema owner path as a JSON object, drops unknown non-metadata fields, and exposes unmodifiable encoded maps/lists at each owner path.

Completion Check:

`dart test test/codec/schema_v1/metadata_projection_test.dart` passes, and the embedded source contains decode, encode, and immutability assertions for document, resource, layer, background element, and layer element metadata owners. The immutability proof explicitly attempts to mutate encoded metadata objects, nested metadata objects, and nested metadata lists through the owner-path assertions or a shared embedded helper.

Depends On:

Unit 1.

### [ ] Unit 3: Schema v1 proof closure verification

Owner:

Schema v1 codec test verification and repository-level Dart/DCM checks.

Boundary:

Commands that prove the strengthened test contract integrates with the existing repository checks.

Change:

Run the focused schema v1 tests and repository-level static checks required for Dart test changes. If failures reveal omissions within this contract's scope, repair only the two schema v1 test proof surfaces. If a failure reveals a production schema v1 codec defect, stop this step and report a Contract Blocker or create a new follow-up contract for the production fix. After all completion checks pass, update only the closure checkboxes for Step 32 in `PLAN.md` and this linked step document in the same change.

Completion Check:

The following commands pass from the repository root: `dart test test/codec/schema_v1/canonical_encode_roundtrip_test.dart test/codec/schema_v1/metadata_projection_test.dart`; `dart analyze`; `dcm analyze .`; and `dcm calculate-metrics .`. After those commands pass, the Step 32 entry in `PLAN.md` and all Unit checkboxes in this linked step document are marked complete in the same change.

Depends On:

Units 1 and 2.
