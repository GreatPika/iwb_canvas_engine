# P1.5 - v1 scope gate before public API freeze

## Purpose

Stop public API freeze until mandatory v1 scope, accepted differences, and
validation limits are explicit and mechanically checked.

## Build scope

- scope checklist based on legacy functional behavior and approved v1 additions
- functional ledger mapping from P1 legacy capabilities to next API targets
- public API draft probe
- public API compiles as written.

## Dependencies on earlier phases

- P0 package boundaries are enforced.
- P1 legacy capability inventory and donor inventory are available.

## Read first

- `section_00_status_and_scope` -> `docs/architecture/00_architecture_overview.md`
- `section_04_public_api_v1` -> `docs/contracts/public_api_v1.md`
- `section_06_validation_limits` -> `docs/contracts/validation_limits.md`
- `section_08_functional_ledger` -> `docs/verification/functional_ledger.md`
- `section_09_accepted_differences` -> `docs/architecture/04_decisions_and_differences.md`

## Required donors

- `foundation_contract_limits` - decision: `copy/adapt`; target owner: Validation limits and public constructors

## Forbidden donor structure

- `avoid_scene_controller_facades` - decision: `avoid`
- `avoid_interactive_runtime_whole` - decision: `avoid`
- `avoid_scene_builder_public_architecture` - decision: `avoid`
- `avoid_scene_codec_whole` - decision: `avoid`
- `avoid_scene_store_controller_whole` - decision: `avoid`

## Diagrams to read or update

- `c4_container` -> `docs/diagrams/c4_container.mmd`
- `c4_context` -> `docs/diagrams/c4_context.mmd`
- `dfd_diagnostics_error_projection` -> `docs/diagrams/dfd_diagnostics_error_projection.mmd`
- `dfd_public_edit` -> `docs/diagrams/dfd_public_edit.mmd`

## Contracts satisfied by this phase

- v1 scope additions from `section_00_status_and_scope`
- accepted differences from legacy from `section_09_accepted_differences`
- functional ledger mapping from `section_08_functional_ledger`
- mandatory public API draft coverage from `section_04_public_api_v1`
- validation limit adoption from `section_06_validation_limits`

## Tests and guardrails that prove this phase

- `test.api_contract.v1_scope_gate` -> `test/api_contract/v1_scope_gate_test.dart`
- `test.functional_ledger.row_specific_tests` -> `test/functional_ledger/row_specific_tests_test.dart`
- `api.v1_scope_gate_green_before_freeze`
- `api.functional_ledger_complete`
- `api.public_types_complete`
- `api.public_api_compiles_as_written`
- `api.no_undefined_public_type_references`
- `api.dto_immutability`
- `api.equality_policy_explicit`
- `api.id_validation_no_extension_type_escape`
- `codec.known_fields_validated`
- `core.no_legacy_imports`
- `core.no_node_spec_patch_shape_dependency`
- `core.no_scene_controller_shape_dependency`

## Exit gate

- mandatory v1 scope is green
- functional ledger rows map every P1 legacy capability to a next API target and
  row-specific test id
- public equality policy is explicit before API freeze
- public API compiles as written
- no undefined public type references remain
- P2 public API freeze is blocked until this gate is green.

## Risks and trade-offs

- Freezing API before scope closure would make later compatibility changes
  expensive.
- Over-expanding scope here would turn v1 into a migration layer. The accepted
  target is functional compatibility, not legacy API compatibility.

## Why this phase belongs here

P2 cannot freeze stable public declarations until the v1 scope and accepted
differences have been proved. P1.5 is the explicit gate between oracle evidence
and API commitment.
