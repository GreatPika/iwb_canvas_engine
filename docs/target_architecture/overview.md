# Target Architecture Overview

## Purpose

This document is Level 1 of the target map for
[`ADR 0001`](../adr/0001_target_engine_architecture.md).

It records the stable owner-family registry only:

- `overview.md` answers who owns the area and the current verification status.
- [`execution_flows.md`](execution_flows.md) owns the short runtime-view
  registry.
- [`families/*.md`](families) own the local target rules, forbidden shapes, and
  family-level verification steps.
- [`PLAN.md`](/Users/blackpika/iwb_canvas_engine/PLAN.md) owns execution order,
  not target-map structure.

## Verification Status Vocabulary

- `locked`: the accepted target and the family document are aligned with the
  checked-in local form.
- `locked, needs slimming`: the accepted target is fixed, but the checked-in
  owner is still broader or more shimmed than the intended local form.
- `provisional`: the target direction is known, but the local family contract
  still needs a narrower owner cut before it can be treated as locked.
- `docs stale`: checked-in code already changed the local form, so the family
  document must be rewritten before it can guide more work.

## Owner Family Registry

| Family | Target boundary | Verification status | Detailed map |
| --- | --- | --- | --- |
| Composition root and facade | Keep `SceneController` thin and center runtime assembly in one internal composition root. | `locked, needs slimming` | [composition_root_and_facade.md](families/composition_root_and_facade.md) |
| View runtime and render seam | Keep one assembled `SceneViewRuntime` boundary while exposing separate `mainSceneRenderRead` and `overlayPreviewRead` surfaces. | `locked` | [view_runtime_and_render_seam.md](families/view_runtime_and_render_seam.md) |
| Interaction runtime | Keep one interaction family that owns pointer-session orchestration, gesture state, and ephemeral preview state only. | `locked, needs slimming` | [interaction_runtime.md](families/interaction_runtime.md) |
| Mutation gateway | Keep `SceneControllerMutationBoundary` as the only interaction-owned bridge into committed writes. | `locked, needs slimming` | [mutation_gateway.md](families/mutation_gateway.md) |
| Store and commit path | Keep committed state in the store/write-kernel path and slim the broad store facade over time. | `locked, needs slimming` | [store_and_commit_path.md](families/store_and_commit_path.md) |

## Mechanical Evidence

The Level 1 map stays short by delegating proof to the target-map evidence
layers:

- [`execution_flows.md`](execution_flows.md) names the mechanically supported
  runtime-view artifacts.
- Each family doc must name repository-local probe commands and committed
  evidence artifacts under [`evidence/`](evidence).
- The structural owner of this shape is
  [`test/tool/target_architecture_map_tool_test.dart`](/Users/blackpika/iwb_canvas_engine/test/tool/target_architecture_map_tool_test.dart).

## Update Rules

- Keep this file limited to the owner-family registry and shared status
  vocabulary.
- Do not add slice order, long mismatch narratives, raw metric dumps, or
  hand-written flow/diagram blocks here.
- When checked-in code lands a local target form before its family doc is
  rewritten, mark the family `docs stale` until the family doc catches up.
