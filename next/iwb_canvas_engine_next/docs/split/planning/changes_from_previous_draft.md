<!-- CONTEXT:BEGIN -->
Registry id: `section_28_changes_from_previous_draft`
Registry source: `docs/split/_registry/sections.yaml`
Document path: `docs/split/planning/changes_from_previous_draft.md`
Owns:
- 28. Immediate changes compared with the previous draft
Must read before editing:
- `section_00_status_and_scope` -> `docs/split/architecture/00_architecture_overview.md`
- `section_26_implementation_phases` -> `docs/split/planning/implementation_phases.md`
Depends on:
- `section_00_status_and_scope` -> `docs/split/architecture/00_architecture_overview.md`
- `section_26_implementation_phases` -> `docs/split/planning/implementation_phases.md`
Feeds phases:
- `P1`
Related donors:
- `none`
Related diagrams:
- `none`
Required tests:
- `none`
Guardrails:
- `none`
Do not assume:
- do not resurrect previous draft decisions
<!-- CONTEXT:END -->

## 28. Immediate changes compared with the previous draft

This corrected plan removes legacy API compatibility deliverables and old public symbol compatibility.

It adds required implementation details that were missing:

```text
- full public API v1 with all referenced public types;
- P1.5 v1 scope gate before public API freeze;
- complete DTO immutability policy;
- validated id classes instead of extension type ids;
- full schema v1 field contract;
- validation limits from old engine;
- resource lifecycle and transactionality;
- external resource repaint replacement for notifySceneChanged;
- preview state public contract;
- typed action payload schema;
- separation between low-level CanvasEdit mutations and user action events;
- interactive=false as CanvasSurface pointer-routing only;
- single active pointer session;
- text editing integration model;
- accepted differences table;
- geometry/hit-test policy;
- reordered phases with oracle/capability inventory at the beginning;
- no app adapters inside the engine package.
```
