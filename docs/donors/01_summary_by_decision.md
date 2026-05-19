<!-- CONTEXT:BEGIN -->
Registry id: `donors_01_summary_by_decision`
Source: `docs/_registry/donors.yaml / Summary by decision`
Canonical source: `docs/_registry/donors.yaml`
Feeds registry: `docs/_registry/donors.yaml`
Feeds indexes:
- `docs/indexes/donor_to_phase.md`
Use rule: donor entries are phase-bound implementation inputs, not legacy architecture to copy.
<!-- CONTEXT:END -->

## Summary by decision

### Strong direct-copy candidates

These are small enough or cohesive enough to copy first, then rename/relocate
inside the root package as needed.

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
| Error contract | `lib/src/contract/scene_data_exception.dart`, `lib/src/contract/scene_validation_diagnostics.dart` | structured code/path/bounded details and sanitized diagnostics | `copy/adapt` | P2/P3 |
| Value validators | `lib/src/contract/validated/*.dart`, `lib/src/contract/validated/validated_value_support.dart` | finite/range/string/json/metadata/svg validation policies for `CanvasMetadata` and DTO boundaries | `adapt` | P2/P3 |
| Tri-state patch semantics | `lib/src/contract/patch_field.dart`, `lib/src/contract/node_patch.dart` | absent/value/explicit-null behavior and non-nullable-null rejection | `copy/adapt` | P2 API freeze |
| Immutable collection policy | `lib/src/contract/owned_collections.dart`, `lib/src/core/immutable_collections.dart` | defensive copy, `CanvasMetadata` deep-freeze, and immutable list/map behavior | `adapt` | P2 DTOs |
| Pointer input contract | `lib/src/contract/pointer_input.dart`, `lib/src/contract/canvas_pointer_input.dart`, `lib/src/contract/pointer_phase_codec.dart` | pointer phases, policy validation, pointer-device kind handling | `copy/adapt` | P2/P9 |
| Action event immutability | `lib/src/core/action_events.dart` | immutable events, timestamp normalization behavior, context-action request shape evidence | `adapt` | P2/P9 |
