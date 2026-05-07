<!-- CONTEXT:BEGIN -->
Registry id: `section_09_accepted_differences`
Registry source: `docs/_registry/sections.yaml`
Document path: `docs/architecture/04_decisions_and_differences.md`
Owns:
- 9. Accepted differences from old engine
Must read before editing:
- `section_00_status_and_scope` -> `docs/architecture/00_architecture_overview.md`
- `section_08_functional_ledger` -> `docs/verification/functional_ledger.md`
Feeds phases:
- `P1.5`
- `P2`
Related donors:
- `none`
Related diagrams:
- `none`
Required tests:
- `test.api_contract.v1_scope_gate`
Guardrails:
- `api.v1_scope_gate_green_before_freeze`
Do not assume:
- accepted differences are explicit only
- no silent legacy compatibility layer
<!-- CONTEXT:END -->

## 9. Accepted differences from old engine

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
