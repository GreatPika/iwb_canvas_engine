# Engine Architecture

## Purpose

This document is the engine-family registry for the architecture atlas.

It routes contributors to the family document that owns a change area. Family
documents own local target rules, forbidden shapes, mechanical evidence,
proof links, status, and update triggers.

## Verification Status Vocabulary

- `locked`: the accepted target and the family document are aligned with the
  checked-in local form.
- `known issue`: checked-in code or proof state violates the intended rule and
  the family links to an active issue or dedicated plan step.
- `docs stale`: checked-in code or evidence changed the local form, so the
  family document must be refreshed before it can guide implementation.

## Owner Family Registry

| Family id | Family | Status |
| --- | --- | --- |
| `public_package_boundary` | [Public package boundary](families/public_package_boundary.md) | `locked` |
| `contract_document_model_and_validated_fast_paths` | [Contract document model and validated fast paths](families/contract_document_model_and_validated_fast_paths.md) | `locked` |
| `import_build_materialization` | [Import build materialization](families/import_build_materialization.md) | `locked` |
| `serialization_and_schema` | [Serialization and schema](families/serialization_and_schema.md) | `known issue` |
| `core_scene_graph_geometry_and_spatial_indexes` | [Core scene graph geometry and spatial indexes](families/core_scene_graph_geometry_and_spatial_indexes.md) | `known issue` |
| `model_document_mutation_and_topology` | [Model document mutation and topology](families/model_document_mutation_and_topology.md) | `locked` |
| `store_and_commit_path` | [Store and commit path](families/store_and_commit_path.md) | `locked` |
| `composition_root_and_facade` | [Composition root and facade](families/composition_root_and_facade.md) | `locked` |
| `interaction_runtime` | [Interaction runtime](families/interaction_runtime.md) | `locked` |
| `mutation_gateway` | [Mutation gateway](families/mutation_gateway.md) | `locked` |
| `view_runtime_and_pointer_hosting` | [View runtime and pointer hosting](families/view_runtime_and_pointer_hosting.md) | `locked` |
| `render_frame_admission_and_caches` | [Render frame admission and caches](families/render_frame_admission_and_caches.md) | `locked` |
| `diagnostics_performance_and_debug_surfaces` | [Diagnostics performance and debug surfaces](families/diagnostics_performance_and_debug_surfaces.md) | `known issue` |

## Mechanical Evidence

- [execution_flows.md](execution_flows.md) names the mechanically supported
  runtime-view artifacts.
- `dart run tool/check_architecture_atlas.dart`

## Update Rules

- Keep this file limited to the owner-family registry and shared status
  vocabulary.
- Do not add slice order, long mismatch narratives, raw metric dumps, or
  hand-written flow/diagram blocks here.
