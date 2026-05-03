<!-- CONTEXT:BEGIN -->
Registry id: `section_28_changes_from_previous_draft`
Source: `iwb_canvas_engine_next_full_implementation_plan_v2.md / section 28`
Canonical original: `docs/iwb_canvas_engine_next_full_implementation_plan_v2.md`
Owns:
- 28. Immediate changes compared with the previous draft
Must read before editing:
- `section_00_status_and_scope`
- `section_26_implementation_phases`
Depends on:
- `section_00_status_and_scope`
- `section_26_implementation_phases`
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
Do not infer:
- do not resurrect previous draft decisions
<!-- CONTEXT:END -->

<!-- ORIGINAL-SECTION:BEGIN -->
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
<!-- ORIGINAL-SECTION:END -->
