<!-- CONTEXT:BEGIN -->
Registry id: `section_09_accepted_differences`
Registry source: `docs/_registry/sections.yaml`
Document path: `docs/architecture/04_decisions_and_differences.md`
Owns:
- 9. Accepted differences from legacy engine
Must read before editing:
- `section_00_status_and_scope` -> `docs/architecture/00_architecture_overview.md`
Current owners:
- `architecture`
Benchmarks:
- `none`
Related diagrams:
- `none`
Required tests:
- `test.api_contract.no_retired_public_exports`
- `test.api_contract.app_next_engine_adapter_compile_fixture`
Guardrails:
- `api.no_retired_public_exports`
- `core.no_scene_controller_shape_dependency`
- `core.no_node_spec_patch_shape_dependency`
Do not assume:
- accepted differences are explicit only
- no silent legacy compatibility layer
<!-- CONTEXT:END -->

## 9. Accepted differences from legacy engine

| Difference | Decision |
|---|---|
| Legacy public API not preserved | accepted target decision |
| `SceneController` absent | accepted target decision |
| `SceneSnapshot` absent | accepted target decision |
| `NodeSpec`/`NodePatch` absent | accepted target decision |
| legacy `CanvasPointerInput` name absent | next type is `CanvasPointerSample` |
| schema v7 not production decode target | accepted target decision |
| palette preserved | `CanvasDocument.palette` |
| grid color preserved | `CanvasGrid.color` |
| legacy imageId replaced | `CanvasResourceId` + `CanvasResourceSource.appKey` |
| action payload no longer Map | typed payload classes |
| move resolver async not supported | synchronous resolver only |

---
