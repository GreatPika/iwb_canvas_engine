<!-- CONTEXT:BEGIN -->
Registry id: `section_09_accepted_differences`
Registry source: `docs/split/_registry/sections.yaml`
Document path: `docs/split/architecture/04_decisions_and_differences.md`
Owns:
- 9. Accepted differences from old engine
Must read before editing:
- `section_00_status_and_scope` -> `docs/split/architecture/00_architecture_overview.md`
- `section_08_functional_ledger` -> `docs/split/verification/functional_ledger.md`
- `section_25_migration_tool` -> `docs/split/contracts/migration_tool.md`
Feeds phases:
- `P1.5`
- `P2`
- `P11`
Related donors:
- `none`
Related diagrams:
- `dfd_migration_tool`
Required tests:
- `none`
Guardrails:
- `new_api.v1_scope_gate_green_before_freeze`
Do not assume:
- accepted differences are explicit only
- no silent legacy compatibility layer
<!-- CONTEXT:END -->

## 9. Accepted differences from old engine

| Difference | Decision |
|---|---|
| Old public API not preserved | accepted target decision |
| `SceneController` absent | accepted target decision |
| `SceneSnapshot` absent | accepted target decision |
| `NodeSpec`/`NodePatch` absent | accepted target decision |
| old `CanvasPointerInput` name absent | new type is `CanvasPointerSample` |
| schema v7 not production decode target | migration tool outside core |
| palette preserved | `CanvasDocument.palette` |
| grid color preserved | `CanvasGrid.color` |
| old imageId replaced | `CanvasResourceId` + `CanvasResourceSource.appKey` |
| action payload no longer Map | typed payload classes |
| move resolver async not supported | synchronous resolver only |
| app migration adapters outside engine | explicit boundary |

---

