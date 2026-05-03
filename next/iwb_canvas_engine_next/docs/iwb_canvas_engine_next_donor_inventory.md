# `iwb_canvas_engine_next`: current-code donor inventory

This document lists reusable donors from the current `iwb_canvas_engine`
codebase for the greenfield `iwb_canvas_engine_next` implementation.

The current engine is a **functional oracle and implementation donor**, not a
legacy dependency. Donor use means copying or adapting proven algorithms,
contracts, tests, and guardrails into the new package shape. It does not allow
the new package to import the old runtime or preserve the old public API.

## Reuse rules

- No production import from the old package or old `lib/src/**` runtime paths is
  allowed in `iwb_canvas_engine_next`.
- Public names and API shapes in the new package remain governed by the v1 API
  plan, even when the implementation donor came from an old public type.
- `copy` is allowed only for small cohesive utilities with low legacy coupling
  and ported tests.
- `copy/adapt` means the core logic is portable, but names, owners, error
  types, or public boundaries must change.
- `adapt` means the behavior or algorithm is valuable, but the old shell is too
  coupled to legacy scene/controller/snapshot types.
- `rewrite-reference` means use the old code and tests as behavioral evidence
  only; do not port the structure.
- Every reused donor must carry at least one ported or equivalent test before
  the implementation slice closes.
- If donor code conflicts with the new v1 API, package layout, or no-legacy
  rules, the new plan wins.

## Summary by decision

### Strong direct-copy candidates

These are small enough or cohesive enough to copy first, then rename/relocate
inside the new package as needed.

| Area | Donor | Reuse | Proof to port |
|---|---|---:|---|
| Numeric policy | `lib/src/core/numeric_clamp.dart`, `lib/src/core/numeric_tolerance.dart`, `lib/src/contract/transform_tolerance.dart` | `copy` | geometry and hit-test tests |
| Local bounds | `lib/src/core/local_bounds_policy.dart` | `copy` | `test/render/render_geometry_cache_test.dart`, `test/render/render_hit_bounds_parity_test.dart` |
| Paint admission | `lib/src/core/paint_candidate_admission.dart` | `copy` | `test/render/scene_painter_bounds_contract_test.dart`, `plan/step_37_paint_admission_edge_touch_parity.md` |
| Generic cache policy | `lib/src/render/cache/scan_resistant_cache.dart` | `copy` | `test/render/scan_resistant_cache_test.dart`, `test/render/render_cache_policy_contract_test.dart` |
| Pointer tap tracking | `lib/src/core/pointer_input_tracker.dart` | `copy` | `test/core/pointer_input_test.dart` |
| Flutter pointer routing | `lib/src/view/scene_view_pointer_router.dart` | `copy` | `test/view/scene_view_pointer_router_test.dart` |
| Gesture ownership | `lib/src/interactive/internal/interactive_gesture_machine.dart` | `copy` | `test/interactive/core/interactive_move_session_test.dart`, single-pointer policy tests |
| Structure validation | `lib/src/contract/scene_structure_validation.dart` | `copy/adapt` | `test/contract/scene_structure_validation_test.dart` |

### Foundation donors to adapt early

These should be ported before deeper runtime work, because later store, edit,
codec, geometry, and interaction slices depend on them.

| Area | Donor | What to preserve | Reuse | Target phase |
|---|---|---|---:|---|
| Affine transform | `lib/src/contract/transform2d.dart` | robust 2D affine math, inverse handling, `applyToPoint`, `applyToRect`, canvas matrix layout | `copy/adapt` | P2/P3 foundation |
| Core geometry | `lib/src/core/geometry.dart` | AABB, line/stroke bounds, singular value helpers, SVG path centering, point/segment distances | `copy/adapt` | P7 geometry |
| Contract limits | `lib/src/contract/scene_contract_limits.dart` | id/text/svg/stroke/layer/node/json/coordinate limits | `copy/adapt` | P1/P2 scope gate |
| Error contract | `lib/src/contract/scene_data_exception.dart`, `lib/src/contract/scene_validation_diagnostics.dart` | structured code/path/details/source errors and sanitized diagnostics | `copy/adapt` | P2/P3 |
| Value validators | `lib/src/contract/validated/*.dart`, `lib/src/contract/validated/validated_value_support.dart` | finite/range/string/json/svg validation policies | `adapt` | P2/P3 |
| Tri-state patch semantics | `lib/src/contract/patch_field.dart`, `lib/src/contract/node_patch.dart` | absent/value/explicit-null behavior and non-nullable-null rejection | `copy/adapt` | P2 API freeze |
| Immutable collection policy | `lib/src/contract/owned_collections.dart`, `lib/src/core/immutable_collections.dart` | defensive copy and immutable list/map behavior | `adapt` | P2 DTOs |
| Pointer input contract | `lib/src/contract/pointer_input.dart`, `lib/src/contract/canvas_pointer_input.dart`, `lib/src/contract/pointer_phase_codec.dart` | pointer phases, policy validation, pointer-device kind handling | `copy/adapt` | P2/P9 |
| Action event immutability | `lib/src/core/action_events.dart` | immutable events, timestamp normalization behavior, text-edit request shape evidence | `adapt` | P2/P9 |

## Geometry, hit-test, and eraser donors

Port these as algorithms over new shape structs, not as old `SceneNode` or
`NodeSnapshot` APIs.

| Donor | What to preserve | Reuse | Risks | Proof to port |
|---|---|---:|---|---|
| `lib/src/core/node_geometry.dart` | hit eligibility, candidate bounds, inverse-transform box hit, line/stroke world radius, path fill/stroke metric sampling with `2048` cap | `adapt` | tightly coupled to old node classes | `test/core/node_geometry_test.dart`, `test/core/hit_test_test.dart`, `test/core/hit_test_candidate_bounds_test.dart` |
| `lib/src/core/hit_test.dart` | thin primitive hit facade and `kHitSlop` policy | `adapt` | `hitTestTopNode` traversal is legacy scene-order logic | `test/core/hit_test_test.dart` |
| `lib/src/render/render_geometry_builder.dart` | unified local/world bounds construction and validity-key idea | `adapt` | old snapshot, text layout, and cache keys | `test/render/render_geometry_cache_test.dart`, `test/render/render_hit_bounds_parity_test.dart` |
| `lib/src/interactive/internal/interactive_geometry.dart` | segment batching, segment range bounds, rect-distance prefilter | `copy/adapt` | gesture soft-limit helpers depend on input sampling | `test/interactive/core/interactive_draw_path_buffer_test.dart`, eraser guardrail tests |
| `lib/src/interactive/internal/interactive_draw_eraser_exact_hit.dart` and line/stroke eraser hit files | projected eraser-to-local algorithm, singular transform fallback, batched exact line/stroke checks | `adapt` | tied to old snapshots, delete eligibility, debug counters | `test/interactive/core/interactive_draw_eraser_engine_test.dart`, eraser lifecycle tests |

## Spatial, frame, render, and cache donors

These are valuable after the committed store and revision model exist. Do not
copy old controller shells.

| Donor | What to preserve | Reuse | Risks | Target phase |
|---|---|---:|---|---|
| `lib/src/core/scene_spatial_index.dart` | uniform-grid index, separate hit/paint entries, outlier fallback, `structuralRevision` candidate payload | `adapt` | old `Scene`, `SceneNode`, locator maps, background sentinel | P7 |
| `lib/src/controller/internal/spatial_index_cache.dart` | lazy build, epoch invalidation, incremental commit, fallback rebuild, debug counters | `adapt` | old `ChangeSet` and controller revisions | P7/P8 |
| `lib/src/controller/scene_store_controller.dart` spatial query/resolve paths | opaque committed candidates and stale `structuralRevision` rejection | `adapt` | current file is mixed controller facade | P5/P7 |
| `lib/src/core/snapshot_paint_admission_bounds.dart` | bounded snapshot-local paint-bounds cache keyed by node revision/validity | `adapt` | validity keys must be rebuilt for next shapes | P8 |
| `lib/src/core/scene_snapshot_paint_candidates.dart` | snapshot fallback enumeration and selected preview widened visibility rect | `adapt` | only valid for non-committed fallback paths | P8 |
| `lib/src/contract/scene_view_render_state.dart` | atomic frame-read and immutable preview snapshot model | `adapt` | old contract path/name must not leak | P8 |
| `lib/src/interactive/internal/scene_controller_scene_view_runtime.dart` | committed fast path only when frame snapshot matches committed snapshot | `adapt` | do not port controller shell | P8 |
| `lib/src/interactive/internal/scene_controller_paint_candidate_stage.dart` | ordered paint plan, selected supplements, preview-shifted bounds, merge without global full-scene sort | `adapt` | requires new order-token and selection model | P8 |
| `lib/src/render/scene_painter_frame.dart` | viewport calculation, halo visibility budget, single paint-plan call | `adapt` | Flutter/render-specific and node-snapshot coupled | P8/P10 |
| `lib/src/render/scene_render_caches.dart` | single render-cache owner lifecycle and epoch/controller swap clearing | `adapt` | lifecycle belongs to new frame/surface owner | P8/P10 |
| `lib/src/render/cache/scene_static_layer_cache.dart` | recorded grid/background cache and explicit `Picture.dispose` lifecycle | `adapt` | only if next keeps static layer cache | P8/P10 |
| `lib/src/render/cache/scene_text_layout_cache.dart`, `scene_stroke_path_cache.dart`, `scene_path_metrics_cache.dart` | text layout, stroke path, path metrics cache shapes | `adapt` | old keys depend on snapshots/revisions | P8 |

## DTO, model, validation, and structure donors

These are useful as validation and immutability behavior. Do not copy the old
public class names into the new public API.

| Donor | What to preserve | Reuse | Risks | Target phase |
|---|---|---:|---|---|
| `lib/src/contract/snapshot.dart` | immutable DTO construction, defensive copies, canonical background/palette/grid behavior | `adapt` | file is too broad and legacy-family named | P2 |
| `lib/src/contract/node_spec.dart` | creation DTO validation split from snapshots | `adapt` | old family names and old API shape | P2 |
| `lib/src/contract/internal/node_boundary_schema*.dart` | shared schema-field groups and parity across typed/JSON validation | `adapt` | internal fast-path/backing coupling | P2/P3 |
| `lib/src/model/scene_value_validation*.dart` | runtime/model validation adapters and diagnostic normalization | `adapt/rewrite` | bridges old mutable runtime and public DTOs | P2/P3 |
| `lib/src/model/scene_node_boundary_mapping*.dart` | mapping families between boundary DTOs and runtime rows | `adapt` | old node names and runtime shapes | P3/P5 |
| `lib/src/model/document_*.dart` | pure document edit/clone/selection helpers | `adapt` | verify ownership against new store/edit split | P5/P6 |

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

## Interaction, edit, event, and staged-load donors

These donors carry critical behavior. The public controller/facade shells are
not donors for the new public API.

| Donor | What to preserve | Reuse | Risks | Target phase |
|---|---|---:|---|---|
| `lib/src/view/scene_view_interactive_pointer_host.dart` | finite admission, terminal release in `finally`, session replacement reset | `adapt` | Flutter host-specific | P10 |
| `lib/src/interactive/internal/scene_controller_pointer_session.dart` | session detach/dispose, pending tap timer, settings adoption only when raw pointers idle | `adapt` | timer lifecycle and current `Listenable` wiring | P9/P10 |
| `lib/src/interactive/internal/interactive_pointer_normalizer.dart` | non-finite sample filtering and terminal recovery from last finite point | `copy/adapt` | preserve session-token keying | P9 |
| `lib/src/interactive/internal/interactive_event_dispatcher.dart` | monotonic timestamp resolution, stream ownership, deferred notify scheduling | `adapt` | decide sync/async notification contract first | P9 |
| `lib/src/interactive/internal/interactive_double_tap_router.dart` | text double-tap edit-request routing | `adapt` | depends on new text hit-test and read model | P9 |
| `lib/src/interactive/internal/interactive_gesture_router.dart`, `interactive_runtime.dart` | dispatch order, reentrancy guard, terminal cleanup, external mutation interruption | `adapt` | old callback graph is not a donor | P9 |
| `lib/src/interactive/internal/interactive_move_session.dart` and move coordinators | move preview, marquee selection, commit-on-up, cancel restore | `adapt` | depends on selection, hit-test, and mutation callbacks | P9 |
| `lib/src/interactive/internal/interactive_draw_coordinator.dart`, draw engines, terminal router, action emitter | stroke/line/eraser lifecycle, pending line state, exception-safe terminal cleanup | `adapt/rewrite` | eraser internals depend on new geometry/spatial model | P9 |
| `lib/src/interactive/internal/scene_controller_mutation_boundary.dart` | single interaction-owned bridge into committed writes | `adapt` | current bridge names and access types are legacy | P6/P9 |
| `lib/src/controller/scene_writer_runtime.dart`, `lib/src/controller/scene_snapshot_materializer.dart`, `lib/src/controller/scene_controller_committed_mutation_access.dart` | staged load: validate/materialize first, interrupt active interaction only before successful apply, consume prepared replacement once | `adapt` | do not leak prepared replacement through public API | P6/P9 |
| `lib/src/model/scene_import_draft.dart`, `scene_policy.dart`, `scene_from_import_draft.dart`, `scene_import_draft_from_snapshot.dart` | validated import draft seam before runtime materialization | `adapt` | rename around new `loadDocument` model | P3/P6 |
| `lib/src/interactive/scene_controller_interaction.dart`, `scene_controller_scene.dart` | behavioral contracts and validation calls only | `rewrite-reference` | old public API shape is banned | P1/P2 checklist |

## Donors to avoid as structure

These files are useful as behavioral evidence or test sources, but they should
not shape the new package structure.

- `lib/src/interactive/scene_controller.dart` and public controller facade
  files: old public API shape is explicitly not preserved.
- `lib/src/interactive/internal/interactive_runtime.dart` as a whole: useful
  dispatch semantics, but too coupled to old callback graph.
- `lib/src/model/scene_builder.dart` and `scene_builder_api.dart` as public
  architecture: useful schema behavior, but old builder API is not a target.
- `lib/src/serialization/scene_codec.dart` as a whole: useful canonical codec
  flow, but coupled to old `SceneSnapshot`.
- `lib/src/controller/scene_store_controller.dart` as a whole: useful committed
  read and spatial resolution semantics, but mixed with old controller facade.

## P1 closure requirements

P1 donor inventory is closed only when:

- every donor intended for P2-P12 is represented in this file or a later
  machine-readable donor registry;
- every `copy` or `copy/adapt` donor has at least one named test to port;
- every `adapt` donor names the old behavior to preserve and the old shell to
  reject;
- every `rewrite-reference` donor is listed only as behavior/test evidence;
- the functional ledger links capabilities to donor files where reuse is
  expected;
- implementation phases do not import donor files from the old package at
  runtime.
