# Proof Architecture

## Purpose

This document is the proof-family registry for the architecture atlas.

It routes contributors to the family document that owns proof tools,
verification contracts, generated evidence, and invariant reachability.

## Verification Status Vocabulary

- `locked`: the accepted target and the family document are aligned with the
  checked-in local proof form.
- `known issue`: checked-in code or proof state violates the intended rule and
  the family links to an active issue or dedicated plan step.
- `docs stale`: checked-in proof code or evidence changed the local form, so
  the family document must be refreshed before it can guide implementation.

## Proof Family Registry

| Family id | Family | Status |
| --- | --- | --- |
| `public_entrypoint_and_signature_proof` | [Public entrypoint and signature proof](families/public_entrypoint_and_signature_proof.md) | `locked` |
| `guardrail_runner_and_artifact_model` | [Guardrail runner and artifact model](families/guardrail_runner_and_artifact_model.md) | `locked` |
| `invariant_registry_and_proof_reachability` | [Invariant registry and proof reachability](families/invariant_registry_and_proof_reachability.md) | `locked` |
| `verification_contract_and_workflow_drift` | [Verification contract and workflow drift](families/verification_contract_and_workflow_drift.md) | `known issue` |

## Mechanical Evidence

- [proof_flows.md](proof_flows.md) names the mechanically supported proof
  flows and inventories.
- `dart run tool/check_architecture_atlas.dart`

## Update Rules

- Keep this file limited to the proof-family registry and shared status
  vocabulary.
- Do not add slice order, long mismatch narratives, raw failure logs, or
  hand-written proof graphs here.
