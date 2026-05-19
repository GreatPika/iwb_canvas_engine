---
date: 2026-05-19
researcher: Codex
commit: 38eb18a
branch: new-architecture
research_question: "Research the current FrameEngine architecture facts needed before splitting FrameEngine internally into capture, ordinary paint planning, selection decoration, paint asset binding, and static background planning services without changing the public API."
---

# Research: FrameEngine Internal Split

## Summary

The current root documentation places `FrameEngine` inside the internal frame package and describes it as the owner of captured main/overlay frames, ordinary paint plans, selection decoration/staging, and repaint buses (`docs/architecture/01_runtime_ownership.md:59`; `docs/architecture/02_package_boundaries.md:92`). The public package barrel exports only `src/api/**`, so the documented frame implementation surface is internal rather than public API (`docs/architecture/02_package_boundaries.md:152`).

The requested internal split is recorded in the backlog note as `FrameCaptureService`, `OrdinaryPaintPlanner`, `SelectionDecorationPlanner`, `PaintAssetBindingService`, and `StaticBackgroundPlanner` (`todo.md:24`; `todo.md:31`). Current source-of-truth architecture docs do not list those service files in the target frame package layout; the documented frame files are `frame_engine.dart`, captured frame models, `paint_plan.dart`, `render_element_record.dart`, and `repaint_bus.dart` (`docs/architecture/02_package_boundaries.md:92`; `docs/architecture/02_package_boundaries.md:98`).

The current contracts already separate the facts those services would consume: committed frame facts enter through `FrameFactsPort`, selection facts through `SelectionFactsPort`, resource visual facts through `ResourceKernel`, resolver/cache work through `SurfaceResourceSession`, and view camera/style/viewport facts through paint capture inputs (`docs/contracts/frame_rendering.md:104`; `docs/contracts/frame_rendering.md:126`; `docs/architecture/01_runtime_ownership.md:98`; `docs/architecture/01_runtime_ownership.md:114`).

## Detailed Findings

### 1. FrameEngine Internal Surface

- **Location**: primary `docs/architecture/02_package_boundaries.md:92`; additional references `docs/architecture/01_runtime_ownership.md:59`, `docs/diagrams/c4_component_runtime.mmd:12`, `docs/implementation/p9_frame_rendering_and_caches.md:12`.
- **Description**: The target package layout places `FrameEngine` under `lib/src/frame/`, alongside `captured_main_frame.dart`, `captured_overlay_frame.dart`, `paint_plan.dart`, `render_element_record.dart`, and `repaint_bus.dart` (`docs/architecture/02_package_boundaries.md:92`; `docs/architecture/02_package_boundaries.md:98`). Runtime ownership docs say `FrameEngine` owns captured main/overlay frames, ordinary paint plans, selection decoration/staging, and repaint buses (`docs/architecture/01_runtime_ownership.md:59`).
- **Dependencies**: P9 frame rendering scope includes `FrameEngine`, captured frame models, `RenderElementRecord`, `PaintPlan`, selected supplement staging, selection decoration through captured selection facts, repaint buses, frame render caches, resource image resolution through `SurfaceResourceSession`, and committed facts through `FrameFactsPort` (`docs/implementation/p9_frame_rendering_and_caches.md:12`; `docs/implementation/p9_frame_rendering_and_caches.md:35`).
- **Data flow**: `CanvasSurface` requests main or overlay paint (`docs/diagrams/seq_main_paint.mmd:19`; `docs/diagrams/seq_overlay_paint.mmd:13`) -> `FrameEngine` captures frame facts once (`docs/contracts/frame_rendering.md:104`; `docs/contracts/frame_rendering.md:105`) -> painters receive immutable records, assets, caches, or primitives (`docs/diagrams/seq_main_paint.mmd:106`; `docs/diagrams/seq_overlay_paint.mmd:42`).

### 2. Capture Boundary And Captured Frames

- **Location**: primary `docs/contracts/frame_rendering.md:60`; additional references `docs/contracts/frame_rendering.md:82`, `docs/diagrams/seq_main_paint.mmd:19`, `docs/diagrams/seq_overlay_paint.mmd:13`.
- **Description**: `CapturedMainFrame` contains document, structural, bounds, element visual, background, grid, grid stroke width, selection, resource visual, view camera, viewport, device pixel ratio, selection ids/style, and selected-move delta facts (`docs/contracts/frame_rendering.md:60`; `docs/contracts/frame_rendering.md:79`). `CapturedOverlayFrame` contains preview revision, view camera revision/offset, preview state, and selection style (`docs/contracts/frame_rendering.md:82`; `docs/contracts/frame_rendering.md:90`).
- **Dependencies**: The main paint request provides `viewportRect`, `devicePixelRatio`, `gridStyle`, `selectionStyle`, and `SurfaceResourceSession` (`docs/diagrams/seq_main_paint.mmd:19`). Main capture reads committed facts through `FrameFactsPort`, resource visual facts through `ResourceKernel`, view camera facts from runtime view camera, selection facts through `SelectionFactsPort`, and selected-move preview from `CanvasPreviewState` (`docs/diagrams/seq_main_paint.mmd:20`; `docs/diagrams/seq_main_paint.mmd:31`).
- **Data flow**: Paint request inputs (`docs/diagrams/seq_main_paint.mmd:19`) -> committed/resource/camera/selection/preview capture (`docs/diagrams/seq_main_paint.mmd:20`; `docs/diagrams/seq_main_paint.mmd:32`) -> immutable `CapturedMainFrame` freezes the runtime facts for that paint frame (`docs/diagrams/seq_main_paint.mmd:33`).

### 3. Runtime And Store Fact Boundaries

- **Location**: primary `docs/architecture/01_runtime_ownership.md:98`; additional references `docs/architecture/02_package_boundaries.md:160`, `plan/step_16_frame_facts_port_committed_frame_facts_boundary.md:282`, `docs/diagrams/c4_component_runtime.mmd:37`.
- **Description**: `FrameFactsPort` is the accepted committed-state read seam between `FrameEngine` and `DocumentStoreKernel`, with the documented path `FrameEngine -> FrameFactsPort -> DocumentStoreKernel` (`docs/architecture/01_runtime_ownership.md:98`; `docs/architecture/01_runtime_ownership.md:104`). `lib/src/frame/**` obtains committed document facts through `runtime/frame_facts_port.dart`, not concrete store files (`docs/architecture/02_package_boundaries.md:160`).
- **Dependencies**: `FrameEngine` may depend on `FrameFactsPort`, `SelectionFactsPort`, `SpatialKernel`, `ResourceKernel` resource visual facts, and `SurfaceResourceSession` (`plan/step_16_frame_facts_port_committed_frame_facts_boundary.md:282`; `plan/step_16_frame_facts_port_committed_frame_facts_boundary.md:286`). It must not import or depend on concrete `DocumentStoreKernel`, `CommittedDocument`, family tables, resource tables, or `DocumentProjectionCache` (`plan/step_16_frame_facts_port_committed_frame_facts_boundary.md:286`; `plan/step_16_frame_facts_port_committed_frame_facts_boundary.md:288`).
- **Data flow**: `FrameFactsPort` supplies immutable frame-facing revisions, row facts, descriptor snapshots, and `resourceRevision` (`docs/architecture/01_runtime_ownership.md:106`; `docs/architecture/01_runtime_ownership.md:110`) -> frame code builds frame-owned render models (`docs/contracts/frame_rendering.md:112`; `docs/contracts/frame_rendering.md:114`) -> painters consume immutable data without live runtime reads (`docs/contracts/frame_rendering.md:115`; `docs/contracts/frame_rendering.md:116`).

### 4. Ordinary Paint Planning Facts

- **Location**: primary `docs/contracts/frame_rendering.md:179`; additional references `docs/contracts/cache_policy.md:47`, `docs/diagrams/seq_main_paint.mmd:35`, `docs/diagrams/dfd_main_paint_frame.mmd:91`.
- **Description**: Ordinary paint planning starts by looking up or building the committed ordinary paint plan from `PaintPlanCache`; the cache stores only ordinary committed `RenderElementRecord` data (`docs/contracts/frame_rendering.md:179`; `docs/contracts/frame_rendering.md:180`). The key uses `structuralRevision`, `boundsRevision`, `elementVisualRevision`, `viewportRect`, and `devicePixelRatio` (`docs/contracts/frame_rendering.md:181`; `docs/contracts/frame_rendering.md:182`; `docs/contracts/cache_policy.md:47`).
- **Dependencies**: The ordinary paint plan key must not include `backgroundRevision`, `gridRevision`, `gridStrokeWidth`, `viewCameraRevision`, `viewCameraOffset`, `selectedMoveDelta`, `previewDelta`, selected ids, selection flags, `selectionRevision`, or captured style-only inputs (`docs/contracts/frame_rendering.md:183`; `docs/contracts/frame_rendering.md:186`). Cached ordinary records do not include selection membership, selection flags, selected-move preview deltas, or other selection-only state (`docs/contracts/frame_rendering.md:157`; `docs/contracts/frame_rendering.md:161`).
- **Data flow**: `CapturedMainFrame` supplies ordinary cache-key facts (`docs/diagrams/dfd_main_paint_frame.mmd:91`) -> cache miss queries bounded paint candidates through `SpatialKernel` (`docs/diagrams/seq_main_paint.mmd:41`) -> `FrameFactsPort` resolves handles against captured structural revision and generation (`docs/diagrams/seq_main_paint.mmd:45`; `docs/diagrams/seq_main_paint.mmd:49`) -> ordinary records are stored in `PaintPlanCache` (`docs/diagrams/seq_main_paint.mmd:58`).

### 5. Selection Decoration Facts

- **Location**: primary `docs/contracts/cache_policy.md:49`; additional references `docs/contracts/frame_rendering.md:204`, `docs/diagrams/dfd_main_paint_frame.mmd:108`, `docs/verification/tests.md:428`.
- **Description**: `SelectionDecorationPlan` is frame-owned and keyed by `selectionRevision`, `structuralRevision`, `boundsRevision`, captured `selectionStyle`, and `devicePixelRatio` (`docs/contracts/cache_policy.md:49`). Selection UI is built as a separate decoration pass from ordinary cached records (`docs/contracts/frame_rendering.md:157`; `docs/contracts/frame_rendering.md:160`).
- **Dependencies**: Selection decoration reads selected ids and `selectionRevision` through the captured selection facts boundary and is invalidated separately from ordinary paint plans (`docs/contracts/frame_rendering.md:204`; `docs/contracts/frame_rendering.md:206`). Its key includes `boundsRevision` because selected element bounds can change without selection membership changing (`docs/contracts/frame_rendering.md:206`; `docs/contracts/frame_rendering.md:207`).
- **Data flow**: `CapturedMainFrame` supplies selection ids, `selectionRevision`, `boundsRevision`, `selectionStyle`, and DPR to selection decoration (`docs/diagrams/dfd_main_paint_frame.mmd:108`) -> decoration emits selection UI primitives into frame records (`docs/diagrams/dfd_main_paint_frame.mmd:116`) -> selection decoration changes schedule main repaint separately from ordinary paint-plan invalidation (`docs/diagrams/dfd_cache_invalidation.mmd:170`; `docs/diagrams/dfd_cache_invalidation.mmd:186`).

### 6. Paint Asset Binding And Resource Images

- **Location**: primary `docs/contracts/resources.md:78`; additional references `docs/contracts/resources.md:83`, `docs/contracts/cache_policy.md:48`, `docs/diagrams/seq_main_paint.mmd:84`, `docs/diagrams/seq_resource_resolution.mmd:35`.
- **Description**: Paint/resource resolution receives immutable descriptor snapshots and `resourceRevision` through `FrameFactsPort`, which is backed by the committed document owner for frame paint (`docs/contracts/resources.md:78`; `docs/contracts/resources.md:80`). Painters and frame paint code never call `CanvasResourceResolver` directly; they receive immutable descriptor facts and resolved assets or placeholders through `SurfaceResourceSession` (`docs/contracts/resources.md:83`; `docs/contracts/resources.md:85`).
- **Dependencies**: `SurfaceResourceSession` owns the resolver reference, `resolverGeneration`, `ImageResolveCache`, resolver budget, same-frame missing/null suppression, and budget-exceeded follow-up throttle (`docs/contracts/resources.md:69`; `docs/contracts/resources.md:75`). `ImageResolveCache` is keyed by `resolverGeneration`, `resourceId`, and `resourceRevision` (`docs/contracts/cache_policy.md:48`).
- **Data flow**: Records with image resource ids trigger descriptor lookup (`docs/diagrams/seq_main_paint.mmd:84`; `docs/diagrams/seq_main_paint.mmd:90`) -> `FrameFactsPort` returns immutable descriptor facts or missing descriptor (`docs/diagrams/seq_main_paint.mmd:86`; `docs/diagrams/seq_main_paint.mmd:89`) -> `SurfaceResourceSession` resolves a paint asset or placeholder (`docs/diagrams/seq_main_paint.mmd:90`; `docs/diagrams/seq_main_paint.mmd:101`) -> painter receives records plus resolved assets (`docs/diagrams/seq_main_paint.mmd:106`).

### 7. Static Background Planning Facts

- **Location**: primary `docs/contracts/cache_policy.md:46`; additional references `docs/contracts/frame_rendering.md:124`, `docs/diagrams/dfd_main_paint_frame.mmd:119`, `docs/diagrams/dfd_cache_invalidation.mmd:179`.
- **Description**: `StaticBackgroundCache` is frame-owned and keyed by `backgroundRevision`, `gridRevision`, `gridStrokeWidth`, `viewCameraBucket`, `viewportRect`, and `devicePixelRatio`; it keeps one latest picture for the full current key (`docs/contracts/cache_policy.md:46`). Background/grid document changes use internal background/grid revision facts and captured grid style values where they affect static background output (`docs/contracts/frame_rendering.md:124`; `docs/contracts/frame_rendering.md:126`).
- **Dependencies**: Runtime view camera changes use `state.revisions.viewCamera`, repaint affected frame surfaces, and must not invalidate ordinary committed element paint plans or public `CanvasDocument` projection (`docs/contracts/frame_rendering.md:121`; `docs/contracts/frame_rendering.md:123`). Step 7 states `StaticBackgroundCache` uses background/grid revisions and stable device/surface inputs, and does not use selection style (`plan/step_7_frame_cache_invalidation_facts_split.md:189`).
- **Data flow**: `CapturedMainFrame` supplies `backgroundRevision`, `gridRevision`, `gridStrokeWidth`, `viewCameraBucket`, `viewportRect`, and `devicePixelRatio` (`docs/diagrams/dfd_main_paint_frame.mmd:119`) -> `StaticBackgroundCache` produces a bounded static background primitive (`docs/diagrams/dfd_main_paint_frame.mmd:124`) -> view camera/background/grid invalidations route to main repaint (`docs/diagrams/dfd_cache_invalidation.mmd:179`; `docs/diagrams/dfd_cache_invalidation.mmd:187`).

### 8. Selected Move Supplement Staging

- **Location**: primary `docs/contracts/frame_rendering.md:174`; additional references `docs/contracts/frame_rendering.md:187`, `docs/diagrams/seq_main_paint.mmd:61`, `docs/diagrams/dfd_cache_invalidation.mmd:195`.
- **Description**: `CanvasSelectedMovePreview` is captured for the main-scene selected supplement path only (`docs/contracts/frame_rendering.md:93`; `docs/contracts/frame_rendering.md:94`). When selected move is active, frame staging filters movable selected ids from ordinary records for the current frame, queries selected supplement candidates using visibility shifted by `-selectedMoveDelta`, and resolves selected handles through `FrameFactsPort` (`docs/contracts/frame_rendering.md:187`; `docs/contracts/frame_rendering.md:193`).
- **Dependencies**: If selected row facts are current, staging creates shifted `RenderElementRecord` instances with preview delta for this frame only; stale selected candidates are skipped (`docs/contracts/frame_rendering.md:194`; `docs/contracts/frame_rendering.md:197`). Supplement records are merged with filtered ordinary records by `orderToken` and are not stored in `PaintPlanCache` (`docs/contracts/frame_rendering.md:198`; `docs/contracts/frame_rendering.md:199`).
- **Data flow**: Active selected-move delta (`docs/diagrams/seq_main_paint.mmd:61`) -> filter ordinary records and query shifted candidates (`docs/diagrams/seq_main_paint.mmd:62`; `docs/diagrams/seq_main_paint.mmd:64`) -> build per-frame supplement records (`docs/diagrams/seq_main_paint.mmd:71`) -> merge with ordinary stream without caching supplement records (`docs/diagrams/seq_main_paint.mmd:77`; `docs/diagrams/seq_main_paint.mmd:78`).

### 9. Overlay Planning And Preview Admission

- **Location**: primary `docs/contracts/frame_rendering.md:82`; additional references `docs/diagrams/seq_overlay_paint.mmd:13`, `docs/diagrams/seq_overlay_paint.mmd:21`, `docs/diagrams/dfd_overlay_frame.mmd:46`.
- **Description**: Overlay paint captures `previewRevision`, `viewCameraRevision`, `viewCameraOffset`, immutable `previewState`, and `selectionStyle` (`docs/contracts/frame_rendering.md:82`; `docs/contracts/frame_rendering.md:90`). It admits marquee, pencil, marker, pending line start, line preview, and eraser preview variants, while selected-move preview is main-scene only (`docs/contracts/frame_rendering.md:93`; `docs/contracts/frame_rendering.md:99`).
- **Dependencies**: Overlay primitive construction uses captured `viewCameraOffset`, `previewState`, and `selectionStyle` only (`docs/diagrams/seq_overlay_paint.mmd:40`; `docs/diagrams/seq_overlay_paint.mmd:41`). Overlay paint forbids resource resolver reads and selected move rendering in overlay paint (`docs/diagrams/seq_overlay_paint.mmd:48`).
- **Data flow**: Overlay paint request with selection style (`docs/diagrams/seq_overlay_paint.mmd:13`) -> capture view camera and preview state once (`docs/diagrams/seq_overlay_paint.mmd:14`; `docs/diagrams/seq_overlay_paint.mmd:19`) -> admit preview variants from captured state (`docs/diagrams/seq_overlay_paint.mmd:21`) -> build immutable overlay primitives and paint overlay UI (`docs/diagrams/seq_overlay_paint.mmd:40`; `docs/diagrams/seq_overlay_paint.mmd:43`).

### 10. Painter And Hot-Path Exclusions

- **Location**: primary `docs/diagrams/seq_main_paint.mmd:111`; additional references `docs/diagrams/seq_main_paint.mmd:112`, `docs/diagrams/seq_overlay_paint.mmd:45`, `docs/diagrams/seq_overlay_paint.mmd:47`.
- **Description**: Main painter consumes immutable `RenderElementRecord` data only and performs no live runtime reads (`docs/diagrams/seq_main_paint.mmd:111`). Main paint forbids direct `FrameEngine` store reads, store mutation, `CanvasDocument` projection, `DocumentProjectionCache` reads, public API reads, and `InteractionEngine` mutation (`docs/diagrams/seq_main_paint.mmd:112`).
- **Dependencies**: Overlay painter consumes captured frame facts and immutable primitives only, and it performs no live runtime reads (`docs/diagrams/seq_overlay_paint.mmd:45`). Overlay paint forbids `CanvasDocument` materialization, `DocumentProjectionCache` reads, store mutation, cache invalidation, repaint scheduling, and action events (`docs/diagrams/seq_overlay_paint.mmd:47`).
- **Data flow**: Frame capture freezes facts (`docs/diagrams/seq_main_paint.mmd:33`; `docs/diagrams/seq_overlay_paint.mmd:19`) -> immutable records/assets/primitives are passed to painters (`docs/diagrams/seq_main_paint.mmd:106`; `docs/diagrams/seq_overlay_paint.mmd:42`) -> painters draw without live runtime/store/resource resolver reads (`docs/diagrams/seq_main_paint.mmd:111`; `docs/diagrams/seq_overlay_paint.mmd:48`).

### 11. Verification And Guardrail Surface

- **Location**: primary `docs/verification/tests.md:428`; additional references `docs/verification/tests.md:450`, `docs/verification/guardrails.md:191`, `docs/verification/guardrails.md:201`.
- **Description**: Planned frame tests cover main/overlay capture, no live runtime reads in painters, cache key shape, cache capacity/eviction, preview delta exclusion, selection state exclusion, camera pan preserving ordinary paint plan, and selected supplement staging without global sort (`docs/verification/tests.md:288`; `docs/verification/tests.md:295`).
- **Dependencies**: Planned `paint_plan_excludes_selection_state` proves ordinary `PaintPlanCache` keys and cached records exclude selected ids, `selectionRevision`, selection flags, and selected-move preview state; it also proves bounds/style changes rebuild `SelectionDecorationPlan` without entering static background or ordinary paint-plan identity (`docs/verification/tests.md:428`; `docs/verification/tests.md:437`). Planned `camera_pan_preserves_ordinary_paint_plan` proves camera pan preserves ordinary paint-plan entries while scheduling repaint and proves `backgroundRevision`/`gridRevision` invalidate `StaticBackgroundCache` without invalidating ordinary paint plans (`docs/verification/tests.md:450`; `docs/verification/tests.md:458`).
- **Data flow**: Guardrails enforce frame committed facts via `FrameFactsPort`, no global scene sort, paint-plan exclusion of preview/selection facts, next-owned cache keys, background/grid not invalidating ordinary element paint plans, and resource resolver ownership by `SurfaceResourceSession` (`docs/verification/guardrails.md:191`; `docs/verification/guardrails.md:202`).

## Code References

- `todo.md:24` - requested internal split list begins.
- `todo.md:34` - requested `FrameCaptureService` section begins.
- `todo.md:60` - requested `OrdinaryPaintPlanner` section begins.
- `todo.md:83` - requested `SelectionDecorationPlanner` section begins.
- `todo.md:99` - requested `PaintAssetBindingService` section begins.
- `todo.md:118` - requested `StaticBackgroundPlanner` section begins.
- `docs/architecture/01_runtime_ownership.md:59` - `FrameEngine` owns captured frames, ordinary paint plans, selection decoration/staging, and repaint buses.
- `docs/architecture/01_runtime_ownership.md:98` - `FrameFactsPort` is the committed-state read seam between `FrameEngine` and `DocumentStoreKernel`.
- `docs/architecture/01_runtime_ownership.md:106` - `FrameFactsPort` supplied fact list begins.
- `docs/architecture/02_package_boundaries.md:92` - target `lib/src/frame/` layout begins.
- `docs/architecture/02_package_boundaries.md:152` - public barrel exports only `src/api/**`.
- `docs/architecture/02_package_boundaries.md:160` - frame code obtains committed facts through `runtime/frame_facts_port.dart`.
- `docs/architecture/03_data_model.md:154` - background/grid revisions and surface styles are separated.
- `docs/contracts/frame_rendering.md:60` - `CapturedMainFrame` field list begins.
- `docs/contracts/frame_rendering.md:82` - `CapturedOverlayFrame` field list begins.
- `docs/contracts/frame_rendering.md:104` - main and overlay capture-once rules begin.
- `docs/contracts/frame_rendering.md:157` - ordinary cached records exclude selection-only state.
- `docs/contracts/frame_rendering.md:179` - selected supplement staging algorithm begins with ordinary paint-plan lookup.
- `docs/contracts/frame_rendering.md:204` - selection decoration reads captured selection facts and includes `boundsRevision`.
- `docs/contracts/cache_policy.md:46` - `StaticBackgroundCache` key and policy row.
- `docs/contracts/cache_policy.md:47` - `PaintPlanCache` key and policy row.
- `docs/contracts/cache_policy.md:48` - `ImageResolveCache` key and policy row.
- `docs/contracts/cache_policy.md:49` - `SelectionDecorationPlan` key and policy row.
- `docs/contracts/resources.md:78` - descriptor snapshots and `resourceRevision` enter paint through `FrameFactsPort`.
- `docs/contracts/resources.md:83` - painters and frame paint code do not call `CanvasResourceResolver` directly.
- `docs/diagrams/seq_main_paint.mmd:19` - main paint request inputs.
- `docs/diagrams/seq_main_paint.mmd:35` - ordinary paint-plan lookup key.
- `docs/diagrams/seq_main_paint.mmd:84` - image resource-id resolution loop begins.
- `docs/diagrams/seq_main_paint.mmd:111` - main painter performs no live runtime reads.
- `docs/diagrams/seq_overlay_paint.mmd:13` - overlay paint request begins.
- `docs/diagrams/seq_overlay_paint.mmd:45` - overlay painter performs no live runtime reads.
- `docs/diagrams/dfd_main_paint_frame.mmd:91` - ordinary cache key data flow.
- `docs/diagrams/dfd_main_paint_frame.mmd:108` - selection decoration input data flow.
- `docs/diagrams/dfd_main_paint_frame.mmd:119` - static background cache input data flow.
- `docs/diagrams/dfd_cache_invalidation.mmd:168` - structural/bounds/element visual revisions invalidate `PaintPlanCache`.
- `docs/diagrams/dfd_cache_invalidation.mmd:170` - bounds revision invalidates selection decoration.
- `docs/diagrams/dfd_cache_invalidation.mmd:179` - view camera changes invalidate static frame output.
- `docs/verification/tests.md:428` - planned selection-state paint-plan exclusion test behavior.
- `docs/verification/tests.md:450` - planned camera-pan paint-plan preservation test behavior.
- `docs/verification/guardrails.md:191` - frame committed facts via `FrameFactsPort` guardrail.
- `docs/verification/guardrails.md:201` - resource resolver ownership by `SurfaceResourceSession` guardrail.

## Observed Architecture Facts

- Pattern observed: `FrameEngine` remains the internal frame owner under `lib/src/frame/`, while the public package barrel exports only API declarations (`docs/architecture/02_package_boundaries.md:92`; `docs/architecture/02_package_boundaries.md:152`).
- Pattern observed: committed document facts, selection facts, and resolver/session facts are already assigned to different boundaries: `FrameFactsPort`, `SelectionFactsPort`, `ResourceKernel`, and `SurfaceResourceSession` (`docs/architecture/01_runtime_ownership.md:98`; `docs/diagrams/c4_component_runtime.mmd:37`; `docs/diagrams/c4_component_runtime.mmd:42`).
- Data flow: main paint capture reads committed facts, resource visual facts, view camera facts, selection facts, and selected-move preview once before building `CapturedMainFrame` (`docs/diagrams/seq_main_paint.mmd:20`; `docs/diagrams/seq_main_paint.mmd:32`).
- Data flow: ordinary paint planning uses `structuralRevision`, `boundsRevision`, `elementVisualRevision`, `viewportRect`, and `devicePixelRatio`, while selection, preview, resolver, background/grid, view camera, and style-only facts are excluded from ordinary paint-plan identity (`docs/contracts/frame_rendering.md:181`; `docs/contracts/frame_rendering.md:186`).
- Data flow: selection decoration uses `selectionRevision`, `structuralRevision`, `boundsRevision`, captured `selectionStyle`, and DPR; `boundsRevision` is part of the key because selected bounds can change without selection membership changes (`docs/contracts/cache_policy.md:49`; `docs/contracts/frame_rendering.md:206`).
- Data flow: paint asset resolution receives descriptor snapshots and `resourceRevision` through `FrameFactsPort`, then resolves through `SurfaceResourceSession`; painter and frame paint code do not call `CanvasResourceResolver` directly (`docs/contracts/resources.md:78`; `docs/contracts/resources.md:83`).
- Data flow: static background planning uses background/grid revisions, grid stroke width, view camera bucket, viewport, and DPR; background/grid/runtime view camera changes repaint frame surfaces without invalidating ordinary committed element paint plans (`docs/contracts/cache_policy.md:46`; `docs/contracts/frame_rendering.md:121`; `docs/contracts/frame_rendering.md:126`).
- Key dependency: selected-move supplement records are per-frame values merged by `orderToken`; they are not stored in `PaintPlanCache` and do not trigger a full-scene sort (`docs/contracts/frame_rendering.md:198`; `docs/contracts/frame_rendering.md:200`).
- Key exclusion: `FrameFactsPort` must not return frame-owned render models, selection facts, or resolver state (`docs/contracts/frame_rendering.md:112`; `docs/contracts/frame_rendering.md:114`).
- Verification mapping: planned tests and guardrails explicitly cover capture boundaries, no live painter reads, ordinary paint-plan exclusions, selection-decoration bounds handling, camera/static-background separation, `FrameFactsPort` usage, and resolver ownership (`docs/verification/tests.md:288`; `docs/verification/tests.md:458`; `docs/verification/guardrails.md:191`; `docs/verification/guardrails.md:202`).

## Open Questions

- The requested internal service names are present in `todo.md`, while the current target frame package layout lists `frame_engine.dart`, captured frame models, `paint_plan.dart`, `render_element_record.dart`, and `repaint_bus.dart` (`todo.md:27`; `todo.md:31`; `docs/architecture/02_package_boundaries.md:92`; `docs/architecture/02_package_boundaries.md:98`).
- The requested `FrameCaptureService` input list includes `ResourceFactsPort` (`todo.md:39`; `todo.md:43`), while the current package layout documents resource-related files as `resource_kernel.dart`, `resource_cache.dart`, `resource_resolver_adapter.dart`, and `surface_resource_session.dart` (`docs/architecture/02_package_boundaries.md:109`; `docs/architecture/02_package_boundaries.md:113`).
- The current contracts document `SurfaceResourceSession` as the image resolver/cache/budget boundary, while `FrameFactsPort` supplies descriptor snapshots and `resourceRevision` (`docs/contracts/resources.md:78`; `docs/contracts/resources.md:85`).
- The current frame contract documents selected-move supplement staging inside frame rendering, but the requested internal service list does not name a separate selected-move supplement service (`docs/contracts/frame_rendering.md:174`; `docs/contracts/frame_rendering.md:199`; `todo.md:27`; `todo.md:31`).
- The current verification ledger names tests for frame behavior and guardrails, but it does not yet name tests for the requested internal service classes specifically (`docs/verification/tests.md:288`; `docs/verification/tests.md:295`).
