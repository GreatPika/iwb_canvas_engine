# Target Proof Architecture Overview

## Purpose

This document is Level 1 of the proof target map.

It records the stable proof-family registry only:

- `overview.md` answers who owns the proof area and the current verification
  status.
- [`proof_flows.md`](proof_flows.md) owns the short mechanically supported
  flow/inventory registry.
- [`families/*.md`](families) own the local target rules, forbidden shapes,
  and family-level verification steps.
- [`PLAN.md`](/Users/blackpika/iwb_canvas_engine/PLAN.md) owns execution order,
  not target-map structure.

## Verification Status Vocabulary

- `locked`: the accepted target and the family document are aligned with the
  checked-in local proof form.
- `provisional`: the target direction is known, but the local proof contract
  still needs a narrower source-of-truth cut before it can be treated as
  locked.
- `docs stale`: checked-in proof code already changed the local form, so the
  family document must be rewritten before it can guide more work.

## Proof Family Registry

| Family | Target boundary | Verification status | Detailed map |
| --- | --- | --- | --- |
| Public entrypoint and signature proof | Keep one effective public namespace model for golden surface, owner resolution, and signature hermeticity checks. | `provisional` | [public_entrypoint_and_signature_proof.md](families/public_entrypoint_and_signature_proof.md) |
| Guardrail runner and artifact model | Keep rule order, invariant ownership, and shared runner artifacts explicit so one artifact does not silently stand in for two proof universes. | `provisional` | [guardrail_runner_and_artifact_model.md](families/guardrail_runner_and_artifact_model.md) |
| Invariant registry and proof reachability | Keep invariant ids, required proof paths, regression surfaces, and required-code-change reachability explicit and mechanically checked. | `locked` | [invariant_registry_and_proof_reachability.md](families/invariant_registry_and_proof_reachability.md) |

## Mechanical Evidence

The Level 1 map stays short by delegating proof to the committed evidence
layer:

- [`proof_flows.md`](proof_flows.md) names the mechanically supported proof
  flows and inventories.
- Each family doc names repository-local probe commands and committed evidence
  artifacts under [`evidence/`](evidence).
- The structural owner of this shape is
  [`test/tool/target_proof_architecture_map_tool_test.dart`](/Users/blackpika/iwb_canvas_engine/test/tool/target_proof_architecture_map_tool_test.dart).

## Update Rules

- Keep this file limited to the proof-family registry and shared status
  vocabulary.
- Do not add slice order, long mismatch narratives, raw failure logs, or
  hand-written proof graphs here.
- When checked-in proof code lands a local target form before its family doc is
  rewritten, mark the family `docs stale` until the family doc catches up.
