# Split documentation for `iwb_canvas_engine_next`

The canonical source of truth remains the two original files in `docs/`:

- `iwb_canvas_engine_next_full_implementation_plan_v2.md`
- `iwb_canvas_engine_next_donor_inventory.md`

This directory is a working navigation layer. Start implementation planning from `indexes/by_phase.md`, then open the linked implementation sections, donor records, diagrams, tests and guardrails.

## Layout

- `implementation/`: one file per top-level implementation-plan section, with a context capsule and preserved original body.
- `donors/`: split donor inventory sections. Donor use is controlled by `_registry/donors.yaml`.
- `diagrams/`: catalog of required Mermaid deliverables from section 21.
- `indexes/`: human-readable working maps by phase, subsystem, guardrail, test area and donor relation.
- `_registry/`: machine-readable coverage records used to prevent orphan sections, donors and diagrams.

## Reconstruction rule

The text between `ORIGINAL-SECTION:BEGIN` and `ORIGINAL-SECTION:END` is the preserved canonical body. Reconstruct by concatenating those bodies in filename order for implementation and donor files separately.

## Donor rule

A donor is allowed for implementation only when `_registry/donors.yaml` gives it a target phase and owner. Records with `decision: avoid` or `target_phases: [reference_only]` are not implementation structure.
