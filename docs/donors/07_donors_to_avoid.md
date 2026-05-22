<!-- CONTEXT:BEGIN -->
Registry id: `donors_07_donors_to_avoid`
Source: `docs/_registry/donors.yaml / Donors to avoid as structure`
Canonical source: `docs/_registry/donors.yaml`
Feeds registry: `docs/_registry/donors.yaml`
Use rule: donor entries are phase-bound implementation inputs, not legacy architecture to copy.
<!-- CONTEXT:END -->

## Donors to avoid as structure

These files are useful as behavioral evidence or test sources, but they should
not shape the root package structure.

- `lib/src/interactive/scene_controller.dart` and public controller facade
  files: legacy public API shape is explicitly not preserved.
- `lib/src/interactive/internal/interactive_runtime.dart` as a whole: useful
  dispatch semantics, but too coupled to legacy callback graph.
- `lib/src/model/scene_builder.dart` and `scene_builder_api.dart` as public
  architecture: useful schema behavior, but legacy builder API is not a target.
- `lib/src/serialization/scene_codec.dart` as a whole: useful canonical codec
  flow, but coupled to legacy `SceneSnapshot`.
- `lib/src/controller/scene_store_controller.dart` as a whole: useful committed
  read and spatial resolution semantics, but mixed with legacy controller facade.

