<!-- CONTEXT:BEGIN -->
Registry id: `donors_07_donors_to_avoid`
Source: `docs/iwb_canvas_engine_next_donor_inventory.md / Donors to avoid as structure`
Canonical original: `docs/iwb_canvas_engine_next_donor_inventory.md`
Feeds registry: `docs/split/_registry/donors.yaml`
Feeds indexes:
- `docs/split/indexes/donor_to_phase.md`
- `docs/split/indexes/phase_to_donor.md`
Use rule: donor entries are phase-bound implementation inputs, not old architecture to copy.
<!-- CONTEXT:END -->

<!-- ORIGINAL-SECTION:BEGIN -->
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

<!-- ORIGINAL-SECTION:END -->
