<!-- CONTEXT:BEGIN -->
Registry id: `donors_01_summary_by_decision`
Source: `docs/_registry/donors.yaml / Summary by decision`
Canonical source: `docs/_registry/donors.yaml`
Use rule: donor entries are phase-bound implementation inputs, not legacy architecture to copy.
<!-- CONTEXT:END -->

## Summary by decision

### Strong direct-copy candidates

These are small enough or cohesive enough to copy first, then rename/relocate
inside the root package as needed.

| Area | Donor | Reuse | Proof to port |
|---|---|---:|---|
| Numeric policy | `lib/src/core/numeric_clamp.dart`, `lib/src/core/numeric_tolerance.dart`, `lib/src/contract/transform_tolerance.dart` | `copy` | `test.api_contract.public_api_v1_compiles_as_written`, `test.geometry.hit_policy` |
| Local bounds | `lib/src/core/local_bounds_policy.dart` | `copy` | `test.geometry.hit_policy`, `test.frame.frame_spatial_paint_admission` |
| Paint admission | `lib/src/core/paint_candidate_admission.dart` | `copy` | `test.frame.frame_spatial_paint_admission`, `test.geometry.no_legacy_scene_order` |
| Generic cache policy | `lib/src/render/cache/scan_resistant_cache.dart` | `copy` | `test.frame.cache_capacity_eviction_policy`, `test.benchmarks.benchmark_manifest` |
| Pointer tap tracking | `lib/src/core/pointer_input_tracker.dart` | `copy` | `test.interaction.pointer_session`, `test.interaction.pointer_sample_normalizer` |
| Flutter pointer routing | `lib/src/view/scene_view_pointer_router.dart` | `copy` | `test.interaction.pointer_session`, `test.interaction.context_action_request` |
| Gesture ownership | `lib/src/interactive/internal/interactive_gesture_machine.dart` | `copy` | `test.interaction.pointer_session`, `test.interaction.move_machine` |
| Structure validation | `lib/src/contract/scene_structure_validation.dart` | `copy/adapt` | `test.api_contract.public_api_v1_compiles_as_written`, `test.codec.schema_v1.known_fields_validation` |

### Foundation donors to adapt early

These should be ported before deeper runtime work, because later store, edit,
codec, geometry, and interaction slices depend on them.

| Area | Donor | What to preserve | Reuse | Target phase |
|---|---|---|---:|---|
| Affine transform | `lib/src/contract/transform2d.dart` | robust 2D affine math, inverse handling, `applyToPoint`, `applyToRect`, canvas matrix layout | `copy/adapt` | P2/P3 foundation |
| Core geometry | `lib/src/core/geometry.dart` | AABB, line/stroke bounds, singular value helpers, SVG path centering, point/segment distances | `copy/adapt` | P8 geometry |
| Contract limits | `lib/src/contract/scene_contract_limits.dart` | id/text/svg/stroke/layer/node/json/coordinate limits | `copy/adapt` | P1/P2 scope gate |
| Error contract | `lib/src/contract/scene_data_exception.dart`, `lib/src/contract/scene_validation_diagnostics.dart` | structured code/path/bounded details and sanitized diagnostics | `copy/adapt` | P2/P3 |
| Value validators | `lib/src/contract/validated/*.dart`, `lib/src/contract/validated/validated_value_support.dart` | finite/range/string/json/metadata/svg validation policies for `CanvasMetadata` and DTO boundaries | `adapt` | P2/P3 |
| Tri-state patch semantics | `lib/src/contract/patch_field.dart`, `lib/src/contract/node_patch.dart` | absent/value/explicit-null behavior and non-nullable-null rejection | `copy/adapt` | P2 API freeze |
| Immutable collection policy | `lib/src/contract/owned_collections.dart`, `lib/src/core/immutable_collections.dart` | defensive copy, `CanvasMetadata` deep-freeze, and immutable list/map behavior | `adapt` | P2 DTOs |
| Pointer input contract | `lib/src/contract/pointer_input.dart`, `lib/src/contract/canvas_pointer_input.dart`, `lib/src/contract/pointer_phase_codec.dart` | pointer phases, policy validation, pointer-device kind handling | `copy/adapt` | P2/P9 |
| Action event immutability | `lib/src/core/action_events.dart` | immutable events, timestamp normalization behavior, context-action request shape evidence | `adapt` | P2/P9 |
