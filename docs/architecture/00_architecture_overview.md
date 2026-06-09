<!-- CONTEXT:BEGIN -->
Registry id: `section_00_status_and_scope`
Registry source: `docs/_registry/sections.yaml`
Document path: `docs/architecture/00_architecture_overview.md`
Owns:
- 0. Current package status and architecture decision
Must read before editing:
- `none`
Current owners:
- `architecture`
Benchmarks:
- `none`
Related diagrams:
- `c4_context`
- `c4_container`
Required tests:
- `test.api_contract.public_exports_complete`
- `test.api_contract.public_integration_compile_fixture`
Guardrails:
- `core.no_unapproved_external_package_imports`
- `core.no_unapproved_controller_shape_dependency`
- `core.no_unapproved_patch_shape_dependency`
Do not assume:
- no public facade bypass
- no controller shape
- no unregistered public API shape
- no runtime fallback path
<!-- CONTEXT:END -->

# `iwb_canvas_engine`: scope and architecture decision

## 0. Current package status and architecture decision

This document fixes the package boundary for Public API v1. The maintained
package is a single Flutter-based canvas runtime with its own public API,
runtime owners, verification gates, and release policy.

Fixed decision:

```text
iwb_canvas_engine
  -> maintained package root;
  -> Public API v1;
  -> one runtime root;
  -> owned core/store/edit/frame/interaction/resource/codec boundaries;
  -> no fallback runtime in the shipped artifact.
```

The package is complete only when current behavior is proved through package
tests, guardrails, generated documentation checks, architecture graph checks,
and release gates.

### 0.1 Scope lock for v1

v1 includes these package-owned capabilities:

```text
- CanvasResourceId;
- CanvasResourceSource.appKey;
- markResourceDirty / markAllResourcesDirty;
- typed action payloads;
- CanvasPreviewState;
- CanvasPalette;
- CanvasGrid.color;
- CanvasSurface(interactive=false).
```

The package boundary excludes:

```text
Public API:
  - parallel public facades;
  - unregistered public symbols;
  - public schema entrypoints outside the v1 contract.

Application integration:
  - application-owned integration code ports inside the package;
  - application-specific adapter implementations inside the package.

Runtime and proof:
  - fallback runtime paths;
  - proof that bypasses current package tests, registries, or guardrails.
```

Applications may own adapters around `iwb_canvas_engine`, but those adapters
are outside this package. Public API completeness for app-facing integration is
proved by an external compile fixture that imports only
`package:iwb_canvas_engine/iwb_canvas_engine.dart` and does not use `src/**` or
internal runtime classes.

---
