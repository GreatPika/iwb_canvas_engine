<!-- CONTEXT:BEGIN -->
Registry id: `donors_02_geometry_hit_test_eraser`
Source: `docs/_registry/donors.yaml / Geometry, hit-test, and eraser donors`
Canonical source: `docs/_registry/donors.yaml`
Feeds registry: `docs/_registry/donors.yaml`
Feeds indexes:
- `docs/indexes/donor_to_phase.md`
Use rule: donor entries are phase-bound implementation inputs, not old architecture to copy.
<!-- CONTEXT:END -->

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

