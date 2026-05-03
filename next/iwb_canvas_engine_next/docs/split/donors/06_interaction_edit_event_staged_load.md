<!-- CONTEXT:BEGIN -->
Registry id: `donors_06_interaction_edit_event_staged_load`
Source: `docs/iwb_canvas_engine_next_donor_inventory.md / Interaction, edit, event, and staged-load donors`
Canonical original: `docs/iwb_canvas_engine_next_donor_inventory.md`
Feeds registry: `docs/split/_registry/donors.yaml`
Feeds indexes:
- `docs/split/indexes/donor_to_phase.md`
- `docs/split/indexes/phase_to_donor.md`
Use rule: donor entries are phase-bound implementation inputs, not old architecture to copy.
<!-- CONTEXT:END -->

<!-- ORIGINAL-SECTION:BEGIN -->
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

<!-- ORIGINAL-SECTION:END -->
