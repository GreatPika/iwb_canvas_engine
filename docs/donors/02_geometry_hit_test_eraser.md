<!-- CONTEXT:BEGIN -->
Registry id: `donors_02_geometry_hit_test_eraser`
Source: `docs/_registry/donors.yaml / Geometry, hit-test, and eraser donors`
Canonical source: `docs/_registry/donors.yaml`
Use rule: donor entries are phase-bound implementation inputs, not legacy architecture to copy.
<!-- CONTEXT:END -->

## Geometry, hit-test, and eraser donors

Port these as algorithms over new shape structs, not as legacy `SceneNode` or
`NodeSnapshot` APIs.

| Donor | What to preserve | Reuse | Risks | Proof to port |
|---|---|---:|---|---|
| `lib/src/core/node_geometry.dart` | hit eligibility, candidate bounds, inverse-transform box hit, line/stroke world radius, path fill/stroke metric sampling with `2048` cap | `adapt` | tightly coupled to legacy node classes | `test.geometry.hit_policy`, `test.geometry.no_legacy_scene_order`, `test.geometry.eraser_exact_budget_inputs` |
| `lib/src/core/hit_test.dart` | thin primitive hit facade and `kHitSlop` policy | `adapt` | `hitTestTopNode` traversal is legacy scene-order logic | `test.geometry.hit_policy`, `test.geometry.no_legacy_scene_order` |
| `lib/src/render/render_geometry_builder.dart` | unified local/world bounds construction and validity-key idea | `adapt` | legacy snapshot, text layout, and cache keys | `test.frame.frame_spatial_paint_admission`, `test.frame.frame_record_painter_boundary`, `test.geometry.hit_policy` |
| `lib/src/interactive/internal/interactive_geometry.dart` | segment batching, segment range bounds, rect-distance prefilter | `copy/adapt` | gesture soft-limit helpers depend on input sampling | `test.interaction.pointer_session`, `test.interaction.context_action_request`, `test.geometry.eraser_exact_budget_inputs` |
| `lib/src/interactive/internal/interactive_draw_eraser_exact_hit.dart` and line/stroke eraser hit files | projected eraser-to-local algorithm, singular transform fallback, batched exact line/stroke checks | `adapt` | tied to legacy snapshots, delete eligibility, debug counters | `test.interaction.pointer_session`, `test.interaction.move_machine`, `test.geometry.eraser_exact_budget_inputs` |
