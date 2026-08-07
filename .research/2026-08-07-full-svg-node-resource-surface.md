---
date: 2026-08-07
researcher: Codex
commit: 985208d8
branch: main
research_question: "How does the current engine represent elements, resources, schema v1 data, rendering, hit testing, and resource-cache lifecycle relative to supporting one full SVG document node backed by an appKey resource?"
---

# Research: Full SVG Node and Resource Surface

## Summary

The current public and committed element model has six closed families: image,
path, text, stroke, line, and rect (`lib/src/contracts/public/canvas_element.dart:12`,
`lib/src/store/family_tables.dart:69`). There is no full SVG document element or
SVG resource variant in the inspected repository. The existing SVG-named field
is `CanvasPathElement.svgPathData`; it represents one path-data string with one
fill/stroke style, and geometry parses it through `path_drawing`
(`lib/src/contracts/public/canvas_element.dart:89`,
`lib/src/contracts/public/canvas_element.dart:129`,
`lib/src/geometry/geometry_policy.dart:497`).

The closest existing resource-backed sized node is `CanvasImageElement`. It has
`resourceId`, `size`, and optional `naturalSize`, while the resource and resolver
contracts are explicitly image-typed: `CanvasImageResource` and synchronous
`CanvasResourceResolver.resolveImage`, returning `ui.Image?`
(`lib/src/contracts/public/canvas_element.dart:57`,
`lib/src/contracts/public/canvas_resource.dart:47`,
`lib/src/contracts/public/canvas_resource.dart:99`). Resource descriptors are
stored in the committed document, but resolved images and their cache belong to
the active surface session (`lib/src/store/resource_table.dart:309`,
`lib/src/resources/surface_resource_session.dart:20`).

Schema v1, store admission, public projection, sparse updates, frame records,
geometry, interaction snapshots, painting, public API registries, and tests all
contain explicit closed-family dispatch sites. Schema v1 currently accepts only
image resources with an `appKey` source and rejects unknown element and resource
kinds (`lib/src/codec/schema_v1_reader.dart:561`,
`lib/src/codec/schema_v1_reader.dart:580`,
`lib/src/codec/schema_v1_reader.dart:1515`). The runtime dependency set contains
`path_drawing`, but no `flutter_svg` or `vector_graphics`
(`pubspec.yaml:10`, `pubspec.yaml:14`).

## Detailed Findings

### 1. Public Element Model and Common Node Properties

- **Location**: `lib/src/contracts/public/canvas_element.dart:18`
- **Description**: `CanvasElement` owns the common document-node fields `id`,
  `revision`, `transform`, `opacity`, `hitPadding`, `isVisible`, `isSelectable`,
  `isLocked`, `isDeletable`, `isTransformable`, and `metadata`
  (`lib/src/contracts/public/canvas_element.dart:19`,
  `lib/src/contracts/public/canvas_element.dart:42`).
- **Dependencies**: Element constructors use the public id, metadata, transform,
  geometry, limit, error, and value-validation contracts
  (`lib/src/contracts/public/canvas_element.dart:3`).
- **Data flow**: A public `CanvasElement` is admitted into a family row, its
  common fields are copied into `ElementCommonRow`, and public document reads
  reconstruct the concrete DTO through the row's `toElement()` method
  (`lib/src/store/family_tables.dart:510`,
  `lib/src/store/family_tables.dart:616`,
  `lib/src/store/family_tables.dart:674`).
- **Current sized/resource-backed shapes**: `CanvasImageElement` owns
  `resourceId`, `size`, and `naturalSize`; `CanvasRectElement` owns `size`
  (`lib/src/contracts/public/canvas_element.dart:57`,
  `lib/src/contracts/public/canvas_element.dart:81`,
  `lib/src/contracts/public/canvas_element.dart:305`,
  `lib/src/contracts/public/canvas_element.dart:331`).
- **Current SVG-named shape**: `CanvasPathElement` owns a single
  `svgPathData` string plus fill/stroke fields and a fill rule
  (`lib/src/contracts/public/canvas_element.dart:89`,
  `lib/src/contracts/public/canvas_element.dart:129`).

### 2. Sparse Updates, Transforms, and Document Projection

- **Location**: `lib/src/contracts/public/canvas_element_update.dart:14`
- **Description**: `CanvasElementUpdate` defines sparse updates for all common
  node fields, and each of the six element families has a separate update DTO
  (`lib/src/contracts/public/canvas_element_update.dart:15`,
  `lib/src/contracts/public/canvas_element_update.dart:42`,
  `lib/src/contracts/public/canvas_element_update.dart:55`,
  `lib/src/contracts/public/canvas_element_update.dart:242`).
- **Dependencies**: Update application uses `CanvasFieldUpdate` absent/set/clear
  variants (`lib/src/contracts/public/canvas_field_update.dart:5`,
  `lib/src/contracts/public/canvas_field_update.dart:26`,
  `lib/src/contracts/public/canvas_field_update.dart:41`).
- **Data flow**: `CanvasEdit.updateElement` resolves the current element, checks
  the update family, produces an updated DTO, records a sparse store mutation,
  and commits replacement rows through `ElementRegistry.updateElements` and
  `FamilyTables.replaceElements` (`lib/src/edit/edit_session.dart:543`,
  `lib/src/edit/edit_session.dart:551`,
  `lib/src/edit/edit_session.dart:567`,
  `lib/src/store/element_registry.dart:216`,
  `lib/src/store/family_tables.dart:119`).
- **Selection transform flow**: Committed selection movement and transforms
  multiply a new transform into each selected element and dispatch to six
  family-specific update DTOs (`lib/src/runtime/runtime_root.dart:907`,
  `lib/src/runtime/runtime_root.dart:945`,
  `lib/src/runtime/runtime_root.dart:2878`).
- **Projection**: Explicit public reads build `CanvasDocument` from committed
  resource, background-order, layer, and family-table owners
  (`lib/src/store/document_projection_cache.dart:28`,
  `lib/src/store/document_projection_cache.dart:33`,
  `lib/src/store/document_projection_cache.dart:37`).

### 3. Committed Family Storage and Resource References

- **Location**: `lib/src/store/family_tables.dart:19`
- **Description**: `FamilyTables` owns six immutable row maps and the common
  family admission/projection order (`lib/src/store/family_tables.dart:60`,
  `lib/src/store/family_tables.dart:69`,
  `lib/src/store/family_tables.dart:85`).
- **Dependencies**: It consumes public element DTOs and dependency-neutral
  schema v1 import events (`lib/src/store/family_tables.dart:7`).
- **Data flow**: `ElementRegistry` combines family rows with background and
  layer ordering; it preserves order/location facts while family rows are
  replaced (`lib/src/store/element_registry.dart:27`,
  `lib/src/store/element_registry.dart:110`,
  `lib/src/store/element_registry.dart:216`).
- **Resource references**: `referencesResource` and resource admission currently
  inspect only image rows / `CanvasImageElement.resourceId`
  (`lib/src/store/family_tables.dart:78`,
  `lib/src/store/family_tables.dart:932`). Resource removal is refused when a
  current element reference exists and otherwise produces a resource revision
  delta (`lib/src/store/document_store_kernel.dart:114`,
  `lib/src/store/document_store_kernel.dart:680`).

### 4. Schema v1 Decode, Runtime Load, and Encode

- **Location**: `lib/src/codec/schema_v1_reader.dart:694`
- **Description**: The canonical reader maps wire strings to the six
  `CanvasElementKind` values and dispatches family-specific import events
  (`lib/src/codec/schema_v1_reader.dart:703`,
  `lib/src/codec/schema_v1_reader.dart:1515`). Unknown element kinds are
  rejected (`lib/src/codec/schema_v1_reader.dart:1526`).
- **Resource wire shape**: Schema v1 admits only resource `kind == image` and
  source `kind == appKey`; other values are rejected
  (`lib/src/codec/schema_v1_reader.dart:561`,
  `lib/src/codec/schema_v1_reader.dart:580`). The import event carries flattened
  `appKey`, MIME type, content hash, byte length, and metadata
  (`lib/src/contracts/internal/schema_v1_import_events.dart:39`,
  `lib/src/contracts/internal/schema_v1_import_events.dart:49`).
- **Compatibility policy**: Writer version and readable versions are both v1;
  non-v1 values are rejected as unsupported
  (`lib/src/api/canvas_codec.dart:6`,
  `lib/src/api/canvas_codec.dart:10`,
  `lib/src/codec/schema_v1_validation.dart:9`). Unknown non-metadata fields are
  ignored and are not preserved (`docs/contracts/schema_v1.md:67`).
- **Runtime load data flow**: Runtime load invokes the schema reader into
  `StoreSchemaV1ImportBuilder`, which consumes resource/family/layer/order facts
  into committed tables without retaining a public `CanvasDocument`
  (`lib/src/edit/staged_document_load.dart:123`,
  `lib/src/store/schema_v1_store_import.dart:15`,
  `lib/src/store/schema_v1_store_import.dart:101`).
- **Encode data flow**: Public encode validates a DTO and writes canonical root,
  resource, layer, common-element, and family-specific fields through explicit
  variant switches (`lib/src/codec/schema_v1_encoder.dart:15`,
  `lib/src/codec/schema_v1_encoder.dart:21`,
  `lib/src/codec/schema_v1_encoder.dart:62`,
  `lib/src/codec/schema_v1_encoder.dart:90`).

### 5. Resource Descriptor, Resolver, and Session Lifecycle

- **Location**: `lib/src/contracts/public/canvas_resource.dart:12`
- **Description**: `CanvasResource` owns `id`, `source`, `contentHash`,
  `byteLength`, and `metadata`; `CanvasImageResource` adds MIME type
  (`lib/src/contracts/public/canvas_resource.dart:47`).
- **Dependencies**: The only public source variant is app-key-backed, and the
  public resolver synchronously accepts `CanvasImageResource` and returns
  `ui.Image?` (`lib/src/contracts/public/canvas_resource.dart:68`,
  `lib/src/contracts/public/canvas_resource.dart:99`).
- **Data flow**: Store descriptors preserve `appKey` and descriptor metadata;
  frame capture requests immutable descriptor facts; asset binding starts a
  resource pass and asks the active surface session to resolve each unique image
  resource (`lib/src/store/resource_table.dart:309`,
  `lib/src/frame/frame_capture_service.dart:112`,
  `lib/src/frame/paint_asset_binding_service.dart:23`).
- **Resolver-facing projection**: `ResourceImageResolveRequest.descriptor`
  reconstructs `CanvasImageResource` and `CanvasResourceSource.appKey` from
  frame descriptor facts (`lib/src/resources/resource_resolver_adapter.dart:9`,
  `lib/src/resources/resource_resolver_adapter.dart:25`).
- **Failure behavior**: Ordinary resolver exceptions become a resolver-exception
  placeholder; resolver reentrancy rejection is rethrown
  (`lib/src/resources/surface_resource_session.dart:149`).

### 6. Existing Resource Cache and Cleanup

- **Location**: `lib/src/resources/resource_cache.dart:14`
- **Description**: `ImageResolveCache` is keyed by resolver generation,
  resource id, and resource revision, with 1,024 entries and a 64 MiB decoded
  byte limit (`lib/src/resources/resource_cache.dart:5`,
  `lib/src/resources/resource_cache.dart:8`).
- **Ownership**: The cache belongs to `SurfaceResourceSession`, not the committed
  document or `FrameEngine` (`lib/src/resources/surface_resource_session.dart:20`,
  `lib/src/resources/surface_resource_session.dart:29`).
- **Invalidation**: Resolver replacement increments generation and clears cache
  state (`lib/src/resources/surface_resource_session.dart:183`); targeted/all
  dirty events are delivered by runtime before dirty-state publication
  (`lib/src/runtime/runtime_root.dart:1908`,
  `lib/src/runtime/runtime_root.dart:1921`). Document replacement resets the
  active session (`lib/src/runtime/runtime_root.dart:1982`). Surface detach and
  runtime dispose drop the session (`lib/src/runtime/runtime_root.dart:362`,
  `lib/src/runtime/runtime_root.dart:1417`).
- **Cleanup semantics**: Cache invalidation and drop remove references and do not
  dispose app-owned `ui.Image` objects
  (`lib/src/resources/resource_cache.dart:85`,
  `lib/src/resources/surface_resource_session.dart:216`).

### 7. Frame Records, Primitive Caches, and Painting

- **Location**: `lib/src/frame/render_element_record.dart:126`
- **Description**: Immutable render records carry common transform, opacity,
  local/world bounds, optional resource id, and one of six row variants
  (`lib/src/frame/render_element_record.dart:142`).
- **Dependencies**: `RenderElementRecord.fromFacts` computes geometry through
  `GeometryPolicy`, maps public element kind to render family, and builds a
  family row (`lib/src/frame/render_element_record.dart:157`,
  `lib/src/frame/render_element_record.dart:180`,
  `lib/src/frame/render_element_record.dart:191`).
- **Primitive cache data flow**: `RenderFamilyCaches.bindAll` binds text, path,
  and stroke primitives; its path cache is a bounded 1,024-entry LRU
  (`lib/src/frame/render_family_caches.dart:32`,
  `lib/src/frame/render_family_caches.dart:37`,
  `lib/src/frame/frame_cache.dart:180`).
- **Paint data flow**: The main record painter switches on six row types, applies
  each record transform with canvas save/transform/restore, and uses
  `primitiveAlpha` for element opacity
  (`lib/src/frame/main_frame_record_painter.dart:23`,
  `lib/src/frame/main_frame_record_painter.dart:220`,
  `lib/src/frame/render_element_record.dart:332`).
- **Path behavior**: Path rows require path data, normalize it while constructing
  the record, use the path cache for painter input, and paint fallback bounds on
  a missing primitive (`lib/src/frame/render_element_record.dart:216`,
  `lib/src/frame/render_element_record.dart:229`,
  `lib/src/frame/main_frame_record_painter.dart:96`).
- **Dependencies present/absent**: `path_drawing` is a direct dependency;
  `flutter_svg` and `vector_graphics` are not declared
  (`pubspec.yaml:10`, `pubspec.yaml:14`).

### 8. Bounds, Hit Testing, Selection, and Movement

- **Location**: `lib/src/geometry/geometry_policy.dart:25`
- **Description**: `GeometryPolicy.boundsFor` derives local paint/hit/selection/
  edit metrics and transformed world bounds from immutable frame facts
  (`lib/src/geometry/geometry_policy.dart:112`,
  `lib/src/geometry/geometry_policy.dart:124`).
- **Sized box families**: Image and rect local bounds derive from `size`; image,
  rect, and text point hits use the box branch
  (`lib/src/geometry/geometry_policy.dart:154`,
  `lib/src/geometry/hit_test_policy.dart:103`).
- **Path family**: Path bounds and exact hit behavior parse `svgPathData`; exact
  point hit tests fill/stroke geometry instead of using the sized-box branch
  (`lib/src/geometry/geometry_policy.dart:480`,
  `lib/src/geometry/hit_test_policy.dart:555`).
- **Marquee and eraser**: Image, rect, and text use transformed-box intersection
  branches, while path uses path geometry branches
  (`lib/src/geometry/hit_test_policy.dart:148`,
  `lib/src/geometry/hit_test_policy.dart:170`).
- **Selection decoration**: Selected elements are reconstructed as render records;
  single-selection chrome uses one record's paint bounds, while multi-select
  chrome uses the union of selected record bounds
  (`lib/src/frame/selection_decoration_planner.dart:189`,
  `lib/src/frame/selection_decoration_planner.dart:160`,
  `lib/src/frame/selection_decoration_planner.dart:176`).
- **Selected move preview**: A nonzero move preview resolves current selected
  facts, creates shifted records, shifts world paint/hit bounds, and merges the
  supplement by order token (`lib/src/frame/selected_move_supplement_planner.dart:181`,
  `lib/src/frame/selected_move_supplement_planner.dart:206`,
  `lib/src/frame/selected_move_supplement_planner.dart:228`).

### 9. Public Surface and Existing Proof

- **Location**: `docs/_registry/public_api_v1.yaml:18`
- **Description**: The public registry explicitly lists the element enum, six
  element DTOs, six update DTOs, and the image resource/source/resolver surface
  (`docs/_registry/public_api_v1.yaml:21`,
  `docs/_registry/public_api_v1.yaml:29`,
  `docs/_registry/public_api_v1.yaml:47`).
- **Codec proof**: Tests cover canonical v1 roundtrip, exact schema-version
  acceptance, unknown element-kind rejection, and unknown resource-source-kind
  rejection (`test/codec/schema_v1/canonical_encode_roundtrip_test.dart:191`,
  `test/codec/schema_v1/known_fields_validation_test.dart:24`,
  `test/codec/schema_v1/reject_unknown_element_kind_test.dart:24`,
  `test/codec/schema_v1/reject_unknown_resource_source_kind_test.dart:24`).
- **Geometry proof**: Existing fixtures cover path fill/stroke/invalid data,
  anisotropic transform scale, and near-singular path/rect hit behavior
  (`test/geometry/fixtures/hit_policy_fixture.dart:111`,
  `test/geometry/fixtures/hit_policy_fixture.dart:525`,
  `test/geometry/fixtures/hit_policy_fixture.dart:618`).
- **Resource proof**: Existing fixtures cover target/all invalidation, document
  replacement reset, resolver swap, LRU pressure, oversized-image
  non-retention, dropped sessions, resolver errors, and app-owned image
  non-disposal (`test/resources/fixtures/surface_session_cache_lifecycle_fixture.dart:17`,
  `test/resources/fixtures/surface_session_cache_lifecycle_fixture.dart:116`,
  `test/resources/fixtures/app_owned_image_not_disposed_fixture.dart:22`,
  `test/resources/fixtures/resolver_exception_placeholder_fixture.dart:22`).
- **SVG-specific proof not found**: Searches found no `CanvasSvgElement`,
  `CanvasSvgResource`, `flutter_svg`, `vector_graphics`, `SvgPicture`,
  `VectorGraphic`, or `.svg.vec` symbol/dependency/use in `lib`, `test`, `docs`,
  `tool`, `pubspec.yaml`, or `pubspec.lock`.

## Code References

- `lib/src/contracts/public/canvas_element.dart:12` - Closed public element-kind enum.
- `lib/src/contracts/public/canvas_element.dart:18` - Common document-node contract.
- `lib/src/contracts/public/canvas_element.dart:57` - Sized resource-backed image element.
- `lib/src/contracts/public/canvas_element.dart:89` - Single-path element contract.
- `lib/src/contracts/public/canvas_resource.dart:47` - Only public resource subtype.
- `lib/src/contracts/public/canvas_resource.dart:99` - Image-typed synchronous resolver.
- `lib/src/store/family_tables.dart:69` - Six committed family row maps.
- `lib/src/store/family_tables.dart:78` - Image-only resource reference lookup.
- `lib/src/codec/schema_v1_reader.dart:561` - Image-only resource-kind admission.
- `lib/src/codec/schema_v1_reader.dart:1515` - Element-kind wire mapping.
- `lib/src/frame/render_element_record.dart:12` - Six render families.
- `lib/src/frame/render_family_caches.dart:32` - Current primitive-cache binding owner.
- `lib/src/resources/resource_cache.dart:14` - Surface-session image cache.
- `lib/src/geometry/hit_test_policy.dart:103` - Box versus exact-geometry point-hit dispatch.
- `pubspec.yaml:14` - Current runtime dependency set ending with `path_drawing`.

## Search Coverage

- **Inspected**: `docs/contracts/public_api_v1.md`,
  `docs/contracts/schema_v1.md`, `docs/contracts/codec_boundary.md`,
  `docs/contracts/resources.md`, `docs/contracts/cache_policy.md`,
  `docs/contracts/frame_rendering.md`, `docs/contracts/geometry.md`,
  `docs/contracts/spatial_kernel.md`, `docs/_registry/public_api_v1.yaml`,
  `pubspec.yaml`, `.dart_tool/package_config.json`, the public element/resource/
  update contracts, schema v1 codec/import files, committed family/resource
  tables, edit update application, frame record/cache/painter/planner files,
  geometry/hit policies, runtime resource and selection-transform paths, surface
  resource session files, and the focused tests cited above.
- **Searched**: `CanvasElementKind`, `RenderElementFamily`, concrete element and
  update classes, schema v1 import events, `CanvasResource`, `appKey`, resource
  removal and dirty delivery, resolver/session/cache symbols, hit/marquee/eraser
  dispatch, `SvgElement`, `SvgResource`, `CanvasSvg`, `flutter_svg`,
  `vector_graphics`, `SvgPicture`, `VectorGraphic`, and `svg.vec` across `lib`,
  `test`, `docs`, `tool`, dependency manifests, and generated package config.
- **Not found**: A full SVG document element/resource/resolver/cache; a `svg`
  value in public or render family enums; SVG document parsing/rendering APIs;
  `.svg.vec` handling; `flutter_svg` or `vector_graphics` dependencies.
- **Not inspected**: External package APIs and current upstream package behavior;
  no internet or package-documentation research was part of this repository-local
  investigation.

## Observed Architecture Facts

- **Pattern observed**: Element families are closed variants repeated across
  public DTOs, sparse update DTOs, committed row tables, schema import events,
  codec dispatch, frame records, geometry/hit dispatch, interaction projection,
  selection-transform updates, public API registries, and proof fixtures
  (`lib/src/contracts/public/canvas_element.dart:12`,
  `lib/src/store/family_tables.dart:283`,
  `lib/src/codec/schema_v1_encoder.dart:90`,
  `lib/src/frame/render_element_record.dart:180`,
  `lib/src/geometry/hit_test_policy.dart:103`,
  `lib/src/runtime/runtime_root.dart:2878`).
- **Pattern observed**: Common node behavior is centralized in the public base
  element, common committed row, frame facts, render record, geometry policy,
  and selection/move planners (`lib/src/contracts/public/canvas_element.dart:18`,
  `lib/src/store/family_tables.dart:616`,
  `lib/src/contracts/internal/frame_facts_port.dart:46`,
  `lib/src/frame/render_element_record.dart:126`).
- **Data flow**: Public/schema input -> store-owned descriptors and family rows
  -> immutable frame facts -> render records -> bounded primitive/asset binding
  -> painter output (`lib/src/store/schema_v1_store_import.dart:101`,
  `lib/src/runtime/runtime_root.dart:560`,
  `lib/src/frame/render_element_record.dart:157`,
  `lib/src/frame/frame_engine.dart:97`).
- **Key dependency**: Full path-data parsing currently uses `path_drawing` in
  geometry and render-record construction; the active resource resolver/cache
  path is typed to `ui.Image` (`lib/src/geometry/geometry_policy.dart:4`,
  `lib/src/contracts/public/canvas_resource.dart:99`).

## Open Questions

- The repository does not define a wire discriminator, public DTO, resource
  descriptor, resolver return type, parsed-cache value, cache weight, or
  unsupported-construction policy for a full SVG document.
- The repository does not define whether SVG source resolution would be
  synchronous or asynchronous, nor whether raw SVG and precompiled vector data
  would be separate resource variants or formats of one descriptor.
- The repository does not define SVG byte, node/command, recursion, or external
  reference limits beyond the existing general JSON/resource length limits and
  single-path-data length limit.
- External `flutter_svg` and `vector_graphics` API/runtime behavior was outside
  this repository-local research and remains uninspected.
