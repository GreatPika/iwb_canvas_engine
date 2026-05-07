<!-- CONTEXT:BEGIN -->
Registry id: `donors_04_dto_model_validation_structure`
Source: `docs/_registry/donors.yaml / DTO, model, validation, and structure donors`
Canonical source: `docs/_registry/donors.yaml`
Feeds registry: `docs/_registry/donors.yaml`
Feeds indexes:
- `docs/indexes/donor_to_phase.md`
Use rule: donor entries are phase-bound implementation inputs, not legacy architecture to copy.
<!-- CONTEXT:END -->

## DTO, model, validation, and structure donors

These are useful as validation and immutability behavior. Do not copy the
legacy public class names into the next public API.

| Donor | What to preserve | Reuse | Risks | Target phase |
|---|---|---:|---|---|
| `lib/src/contract/snapshot.dart` | immutable DTO construction, defensive copies, canonical background/palette/grid behavior | `adapt` | file is too broad and legacy-family named | P2 |
| `lib/src/contract/node_spec.dart` | creation DTO validation split from snapshots | `adapt` | legacy family names and legacy API shape | P2 |
| `lib/src/contract/internal/node_boundary_schema*.dart` | shared schema-field groups and parity across typed/JSON validation | `adapt` | internal fast-path/backing coupling | P2/P3 |
| `lib/src/model/scene_value_validation*.dart` | runtime/model validation adapters and diagnostic normalization | `adapt/rewrite` | bridges legacy mutable runtime and public DTOs | P2/P3 |
| `lib/src/model/scene_node_boundary_mapping*.dart` | mapping families between boundary DTOs and runtime rows | `adapt` | legacy node names and runtime shapes | P3/P5 |
| `lib/src/model/document_*.dart` | pure document edit/clone/selection helpers | `adapt` | verify ownership against new store/edit split | P5/P6 |
