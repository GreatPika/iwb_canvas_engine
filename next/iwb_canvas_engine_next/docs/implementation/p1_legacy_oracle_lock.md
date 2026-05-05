# P1 - old capability inventory and oracle lock

## Build

- old_to_next_functional_matrix.md
- docs/donors/ and docs/_registry/donors.yaml
- old oracle file list
- donor file list with copy/adapt/rewrite-reference decisions
- example scenario inventory
- action/event inventory
- pointer/preview inventory
- geometry/spatial inventory
- codec/limits inventory
- benchmark baseline inventory.

## Read first

- `section_01_legacy_oracle` -> `docs/planning/legacy_oracle.md`
- `section_08_functional_ledger` -> `docs/verification/functional_ledger.md`

## Required donors

- `interaction_public_controller_behavior` - decision: `rewrite_reference`; target owner: Behavioral checklist only

## Forbidden donor structure

- `avoid_scene_controller_facades` - decision: `avoid`
- `avoid_interactive_runtime_whole` - decision: `avoid`
- `avoid_scene_builder_public_architecture` - decision: `avoid`
- `avoid_scene_codec_whole` - decision: `avoid`
- `avoid_scene_store_controller_whole` - decision: `avoid`

## Diagrams to read or update

- none

## Guardrails

- `new_api.functional_ledger_complete` - every functional ledger row has API + tests

## Tests

- `test.functional_ledger.row_specific_tests` -> `functional-ledger row-specific tests`

## Exit gate

- functional ledger rows are complete
- each row has oracle file(s), new API target and test id
- each reusable donor has a decision, target phase and required ported tests
- copy/adapt donors are linked from the relevant implementation phase
- no implementation proceeds without green inventory guardrail.
