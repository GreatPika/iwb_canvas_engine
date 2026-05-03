<!-- CONTEXT:BEGIN -->
Registry id: `section_09_accepted_differences`
Source: `docs/split/_registry/sections.yaml / section 9`
Canonical source: `docs/split/_registry/sections.yaml`
Owns:
- 9. Accepted differences from old engine
Must read before editing:
- `section_00_status_and_scope`
- `section_08_functional_ledger`
- `section_25_migration_tool`
Depends on:
- `section_00_status_and_scope`
- `section_08_functional_ledger`
- `section_25_migration_tool`
Feeds phases:
- `P1.5`
- `P2`
- `P11`
Related donors:
- `none`
Related diagrams:
- docs/split/diagrams/README.md#dfd_migration_tool -> docs/split/diagrams/generated/dfd_migration_tool.mmd
Required tests:
- `none`
Guardrails:
- `new_api.v1_scope_gate_green_before_freeze`
Do not infer:
- accepted differences are explicit only
- no silent legacy compatibility layer
<!-- CONTEXT:END -->

<!-- ORIGINAL-SECTION:BEGIN -->
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

<!-- ORIGINAL-SECTION:END -->
