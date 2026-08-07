---
date: 2026-05-28
researcher: Codex
commit: 70fd86bc
branch: new-architecture
research_question: "Исследовать текущий статус P7 resource/session/resolver lifecycle перед архитектурным дизайном."
---

# Research: P7 Resource Session Resolver Lifecycle

## Summary

After Step 39, the implemented P7 scope is a narrow non-surface resource slice:
`CanvasRuntime.resources` is backed by `ResourceKernel`, committed resource
catalog reads go through `ResourceCatalogPort`, accepted dirty calls increment
`state.revisions.resourceVisual`, and dirty outcomes are delivered as typed
resource/repaint/public-state effects (`docs/implementation/p7_resources_and_images.md:104`,
`lib/src/runtime/runtime_root.dart:130`, `lib/src/runtime/runtime_root.dart:133`,
`lib/src/runtime/runtime_root.dart:146`, `lib/src/runtime/runtime_root.dart:524`).
Step 39 is marked complete in the plan, and all four execution units in the step
document are checked (`PLAN.md:61`,
`plan/step_39_p7_resource_kernel_read_seam_and_dirty_orchestration.md:157`,
`plan/step_39_p7_resource_kernel_read_seam_and_dirty_orchestration.md:200`,
`plan/step_39_p7_resource_kernel_read_seam_and_dirty_orchestration.md:245`,
`plan/step_39_p7_resource_kernel_read_seam_and_dirty_orchestration.md:310`).

Full P7 session/resolver/cache behavior remains documented as future or
unimplemented by the current narrow files: real `SurfaceResourceSession` cache
behavior, synchronous resolver execution, resolver generation, same-frame
missing/null suppression, resolver frame budget, app-owned image disposal
guarantees, frame asset binding, and Flutter surface lifecycle wiring are
explicitly outside Step 39 (`plan/step_39_p7_resource_kernel_read_seam_and_dirty_orchestration.md:83`,
`plan/step_39_p7_resource_kernel_read_seam_and_dirty_orchestration.md:85`,
`plan/step_39_p7_resource_kernel_read_seam_and_dirty_orchestration.md:89`,
`docs/verification/tests.md:573`, `docs/verification/tests.md:578`).
The architecture graph also records P7 as an overall future phase while the
ResourceKernel owner node records the implemented subset and the session/frame
edges remain future (`docs/architecture/architecture_graph.yaml:42`,
`docs/architecture/architecture_graph.yaml:44`,
`docs/architecture/architecture_graph.yaml:360`,
`docs/architecture/architecture_graph.yaml:741`,
`docs/architecture/architecture_graph.yaml:755`).

## Detailed Findings

### 1. Step 39 Implemented Resource Kernel Slice

- **Location**: primary `lib/src/resources/resource_kernel.dart:7`; related
  `lib/src/runtime/runtime_root.dart:130`,
  `lib/src/api/canvas_runtime.dart:38`.
- **Description**: `ResourceKernel` implements `CanvasResourcePort`, stores
  `ResourceCatalogPort`, `ResolverMutationGuard`, `ResourceDirtyOutcomeSink`,
  and a local `_resourceVisualRevision` (`lib/src/resources/resource_kernel.dart:7`,
  `lib/src/resources/resource_kernel.dart:9`,
  `lib/src/resources/resource_kernel.dart:10`,
  `lib/src/resources/resource_kernel.dart:11`,
  `lib/src/resources/resource_kernel.dart:19`). Read methods delegate to the
  catalog port (`lib/src/resources/resource_kernel.dart:23`,
  `lib/src/resources/resource_kernel.dart:27`). Runtime composes the store-backed
  catalog port and kernel, and the public facade returns that resource port
  (`lib/src/runtime/runtime_root.dart:130`,
  `lib/src/runtime/runtime_root.dart:133`,
  `lib/src/runtime/runtime_root.dart:146`,
  `lib/src/api/canvas_runtime.dart:38`).
- **Dependencies**: Resource code imports only internal/public contracts:
  `ResourceCatalogPort`, `ResourceDirtyOutcome`, `ResolverMutationGuard`,
  `CanvasResourceId`, and `CanvasResource` (`lib/src/resources/resource_kernel.dart:1`,
  `lib/src/resources/resource_kernel.dart:2`,
  `lib/src/resources/resource_kernel.dart:3`,
  `lib/src/resources/resource_kernel.dart:4`,
  `lib/src/resources/resource_kernel.dart:5`).
- **Data flow**: `markResourceDirty(id)` calls the mutation guard, reads the
  catalog by id, returns on missing target, increments the resource visual
  revision for accepted targets, and emits a target dirty outcome
  (`lib/src/resources/resource_kernel.dart:31`,
  `lib/src/resources/resource_kernel.dart:33`,
  `lib/src/resources/resource_kernel.dart:34`,
  `lib/src/resources/resource_kernel.dart:35`,
  `lib/src/resources/resource_kernel.dart:39`,
  `lib/src/resources/resource_kernel.dart:40`). `markAllResourcesDirty()` calls
  the guard, returns for empty catalog, increments the same revision for
  non-empty catalogs, and emits an all-resources outcome
  (`lib/src/resources/resource_kernel.dart:45`,
  `lib/src/resources/resource_kernel.dart:47`,
  `lib/src/resources/resource_kernel.dart:48`,
  `lib/src/resources/resource_kernel.dart:52`,
  `lib/src/resources/resource_kernel.dart:53`).

### 2. Dirty Publication and Reentrancy Guard

- **Location**: primary `lib/src/runtime/runtime_root.dart:379`; related
  `lib/src/contracts/internal/resolver_mutation_guard.dart:1`.
- **Description**: `RuntimeRoot` implements `ResourceDirtyOutcomeSink` and
  delivers non-empty dirty outcomes to resource, repaint, and public-state
  effects (`lib/src/runtime/runtime_root.dart:42`,
  `lib/src/runtime/runtime_root.dart:47`,
  `lib/src/runtime/runtime_root.dart:379`,
  `lib/src/runtime/runtime_root.dart:383`,
  `lib/src/runtime/runtime_root.dart:524`,
  `lib/src/runtime/runtime_root.dart:532`,
  `lib/src/runtime/runtime_root.dart:533`). Public state publication reads
  `resourceVisual` from `ResourceKernel` (`lib/src/runtime/runtime_root.dart:417`,
  `lib/src/runtime/runtime_root.dart:425`,
  `lib/src/runtime/runtime_root.dart:552`).
- **Dependencies**: `ResourceDirtyOutcome` is a contract-owned outcome with
  target ids, all-resources flag, and sink interface
  (`lib/src/contracts/internal/resource_dirty_outcome.dart:3`,
  `lib/src/contracts/internal/resource_dirty_outcome.dart:9`,
  `lib/src/contracts/internal/resource_dirty_outcome.dart:10`,
  `lib/src/contracts/internal/resource_dirty_outcome.dart:15`). The resolver
  guard seam exposes `runResolverCallback` and
  `ensureRuntimeMutationAllowed`
  (`lib/src/contracts/internal/resolver_mutation_guard.dart:1`,
  `lib/src/contracts/internal/resolver_mutation_guard.dart:2`,
  `lib/src/contracts/internal/resolver_mutation_guard.dart:3`).
- **Data flow**: Runtime sets `_isRunningResolverCallback` around resolver
  callbacks, rejects nested resolver callbacks, and rejects public mutations
  while the flag is active (`lib/src/runtime/runtime_root.dart:112`,
  `lib/src/runtime/runtime_root.dart:114`,
  `lib/src/runtime/runtime_root.dart:354`,
  `lib/src/runtime/runtime_root.dart:356`,
  `lib/src/runtime/runtime_root.dart:359`,
  `lib/src/runtime/runtime_root.dart:368`,
  `lib/src/runtime/runtime_root.dart:371`). Current tests drive this seam by
  calling dirty APIs inside `runResolverCallback` and asserting rejection before
  side effects (`test/runtime/fixtures/resource_dirty_runtime_delivery_fixture.dart:281`,
  `test/runtime/fixtures/resource_dirty_runtime_delivery_fixture.dart:284`,
  `test/runtime/fixtures/resource_dirty_runtime_delivery_fixture.dart:291`,
  `test/runtime/fixtures/resource_dirty_runtime_delivery_fixture.dart:294`).

### 3. Existing Resource and Frame Descriptor Seams

- **Location**: primary `lib/src/contracts/internal/frame_facts_port.dart:138`;
  related `lib/src/runtime/runtime_root.dart:275`.
- **Description**: `FrameFactsPort` exposes frame revisions, element handles,
  element facts, and resource descriptor facts; resource descriptor facts include
  `id`, `appKey`, `resourceRevision`, and `metadata`
  (`lib/src/contracts/internal/frame_facts_port.dart:8`,
  `lib/src/contracts/internal/frame_facts_port.dart:16`,
  `lib/src/contracts/internal/frame_facts_port.dart:25`,
  `lib/src/contracts/internal/frame_facts_port.dart:124`,
  `lib/src/contracts/internal/frame_facts_port.dart:126`,
  `lib/src/contracts/internal/frame_facts_port.dart:129`,
  `lib/src/contracts/internal/frame_facts_port.dart:138`,
  `lib/src/contracts/internal/frame_facts_port.dart:142`). `RuntimeRoot`
  implements `FrameFactsPort`, copies store frame revisions, and maps store
  descriptor facts into `FrameResourceDescriptorFacts`
  (`lib/src/runtime/runtime_root.dart:42`,
  `lib/src/runtime/runtime_root.dart:45`,
  `lib/src/runtime/runtime_root.dart:171`,
  `lib/src/runtime/runtime_root.dart:179`,
  `lib/src/runtime/runtime_root.dart:275`,
  `lib/src/runtime/runtime_root.dart:281`,
  `lib/src/runtime/runtime_root.dart:286`).
- **Dependencies**: Image elements carry `resourceId`, `size`, and `naturalSize`
  in public DTOs (`lib/src/contracts/public/canvas_element.dart:56`,
  `lib/src/contracts/public/canvas_element.dart:60`,
  `lib/src/contracts/public/canvas_element.dart:81`,
  `lib/src/contracts/public/canvas_element.dart:85`). Public resource contracts
  define `CanvasImageResource`, app-key sources, synchronous
  `CanvasResourceResolver.resolveImage`, and `CanvasResourcePort`
  (`lib/src/contracts/public/canvas_resource.dart:46`,
  `lib/src/contracts/public/canvas_resource.dart:66`,
  `lib/src/contracts/public/canvas_resource.dart:75`,
  `lib/src/contracts/public/canvas_resource.dart:98`,
  `lib/src/contracts/public/canvas_resource.dart:103`).
- **Data flow**: Current frame-facing image input is element facts plus
  descriptor facts: `FrameElementFacts` has nullable `resourceId`, `size`, and
  `naturalSize`; `FrameResourceDescriptorFacts` provides app-key descriptor
  identity and resource revision (`lib/src/contracts/internal/frame_facts_port.dart:58`,
  `lib/src/contracts/internal/frame_facts_port.dart:98`,
  `lib/src/contracts/internal/frame_facts_port.dart:100`,
  `lib/src/contracts/internal/frame_facts_port.dart:124`,
  `lib/src/contracts/internal/frame_facts_port.dart:127`,
  `lib/src/contracts/internal/frame_facts_port.dart:128`).

### 4. P7/P9 Boundary for Frame Image Binding

- **Location**: primary `docs/contracts/resources.md:87`; related
  `docs/implementation/p9_frame_rendering_and_caches.md:37`.
- **Description**: The resource contract says paint/resource resolution receives
  immutable descriptor snapshots and `resourceRevision` through `FrameFactsPort`,
  and the target frame split makes `PaintAssetBindingService` the only frame
  collaborator that receives `SurfaceResourceSession`
  (`docs/contracts/resources.md:87`, `docs/contracts/resources.md:88`,
  `docs/contracts/resources.md:95`,
  `docs/contracts/resources.md:96`,
  `docs/contracts/resources.md:98`). P9 documents resource image resolution only
  through `SurfaceResourceSession` and committed descriptor lookup only through
  `FrameFactsPort` (`docs/implementation/p9_frame_rendering_and_caches.md:37`,
  `docs/implementation/p9_frame_rendering_and_caches.md:39`,
  `docs/implementation/p9_frame_rendering_and_caches.md:40`).
- **Dependencies**: P9 depends on P7 resources for the session boundary and image
  resolve cache behavior (`docs/implementation/p9_frame_rendering_and_caches.md:96`,
  `docs/implementation/p9_frame_rendering_and_caches.md:97`). P9 names
  `PaintAssetBindingService` as descriptor-to-asset binding for records with
  image resource ids using descriptor facts and `SurfaceResourceSession`
  (`docs/implementation/p9_frame_rendering_and_caches.md:51`,
  `docs/implementation/p9_frame_rendering_and_caches.md:57`,
  `docs/implementation/p9_frame_rendering_and_caches.md:61`,
  `docs/implementation/p9_frame_rendering_and_caches.md:63`).
- **Data flow**: The architecture graph keeps `frame.renderer.uses_surface_resource_session`
  as a future P9 boundary and records that ordinary planners and painters do not
  call `CanvasResourceResolver` directly (`docs/architecture/architecture_graph.yaml:755`,
  `docs/architecture/architecture_graph.yaml:759`,
  `docs/architecture/architecture_graph.yaml:760`,
  `docs/architecture/architecture_graph.yaml:765`). Step 39 explicitly excludes
  frame rendering, paint asset binding, and painter routing through
  `ResourceCatalogPort` (`plan/step_39_p7_resource_kernel_read_seam_and_dirty_orchestration.md:92`,
  `plan/step_39_p7_resource_kernel_read_seam_and_dirty_orchestration.md:93`).

### 5. P7/P13 Boundary for Flutter Surface Lifecycle

- **Location**: primary `lib/src/api/canvas_surface.dart:10`; related
  `docs/implementation/p13_flutter_surface.md:17`.
- **Description**: `CanvasSurface` is currently a public `StatefulWidget` with
  `runtime`, optional `resourceResolver`, selection/grid styles, and
  `interactive` fields; its current state builds `SizedBox.shrink()`
  (`lib/src/api/canvas_surface.dart:10`,
  `lib/src/api/canvas_surface.dart:11`,
  `lib/src/api/canvas_surface.dart:13`,
  `lib/src/api/canvas_surface.dart:20`,
  `lib/src/api/canvas_surface.dart:21`,
  `lib/src/api/canvas_surface.dart:30`,
  `lib/src/api/canvas_surface.dart:32`). P13 build scope owns
  `CanvasSurface`, single active attachment, main/overlay painters,
  synchronous resolver bridge, and `SurfaceResourceSession` attach,
  resolver-swap, detach, dispose, and runtime swap lifecycle wiring
  (`docs/implementation/p13_flutter_surface.md:11`,
  `docs/implementation/p13_flutter_surface.md:12`,
  `docs/implementation/p13_flutter_surface.md:14`,
  `docs/implementation/p13_flutter_surface.md:15`,
  `docs/implementation/p13_flutter_surface.md:16`,
  `docs/implementation/p13_flutter_surface.md:17`,
  `docs/implementation/p13_flutter_surface.md:18`).
- **Dependencies**: P13 depends on the P7 resource resolver boundary, P9 frame
  rendering, and P10-P12 interaction behavior
  (`docs/implementation/p13_flutter_surface.md:30`,
  `docs/implementation/p13_flutter_surface.md:32`,
  `docs/implementation/p13_flutter_surface.md:33`,
  `docs/implementation/p13_flutter_surface.md:34`). The resource contract says
  `CanvasSurface` creates an empty `SurfaceResourceSession` only after successful
  single-active-surface attachment, rejected attachment creates no session, and
  detach/dispose/runtime swap drops the session without disposing app-owned
  images (`docs/contracts/resources.md:103`,
  `docs/contracts/resources.md:104`,
  `docs/contracts/resources.md:105`,
  `docs/contracts/resources.md:106`,
  `docs/contracts/resources.md:107`,
  `docs/contracts/resources.md:108`).
- **Data flow**: Current production code exposes the future resolver input as a
  `CanvasSurface.resourceResolver` field, while P13 documents the lifecycle that
  will connect that input to `SurfaceResourceSession`
  (`lib/src/api/canvas_surface.dart:13`,
  `lib/src/api/canvas_surface.dart:21`,
  `docs/implementation/p13_flutter_surface.md:140`,
  `docs/implementation/p13_flutter_surface.md:142`,
  `docs/implementation/p13_flutter_surface.md:144`,
  `docs/implementation/p13_flutter_surface.md:145`).

### 6. Documentation-Only P7 Session and Resolver Obligations

- **Location**: primary `docs/implementation/p7_resources_and_images.md:11`;
  related `docs/contracts/resources.md:110`.
- **Description**: P7 scope still lists `SurfaceResourceSession`, synchronous
  app-owned image resolver bridge, surface-scoped image cache keyed by
  resolver generation/resource id/resource revision, same-frame missing/null
  suppression, resolver frame budget, and resolver reentrancy guard
  (`docs/implementation/p7_resources_and_images.md:11`,
  `docs/implementation/p7_resources_and_images.md:22`,
  `docs/implementation/p7_resources_and_images.md:23`,
  `docs/implementation/p7_resources_and_images.md:25`,
  `docs/implementation/p7_resources_and_images.md:27`,
  `docs/implementation/p7_resources_and_images.md:28`). The resource contract
  defines `ImageResolveCache` as `SurfaceResourceSession` policy owned by the
  resources module, consumed by frame rendering, with lifecycle wiring deferred
  to P13 (`docs/contracts/resources.md:110`,
  `docs/contracts/resources.md:112`,
  `docs/contracts/resources.md:114`,
  `docs/contracts/resources.md:115`,
  `docs/contracts/resources.md:116`).
- **Dependencies**: The documented cache key is `resolverGeneration + resourceId
  + resourceRevision`, with invalidation by resolver replacement, descriptor
  change, resource dirty target/all, detach/dispose/runtime swap, LRU, probes,
  sync resolver budget, and same-frame suppression
  (`docs/contracts/resources.md:118`,
  `docs/contracts/resources.md:120`).
- **Data flow**: The current verification registry separates current dirty
  proof from future session/cache proof: current tests cover
  `state.revisions.resourceVisual` without document/resource/selection/preview/
  view-camera/interaction/epoch/action/projection changes, while future tests
  cover target cache eviction and mark-all cache clearing in active
  `SurfaceResourceSession`
  (`docs/verification/tests.md:561`, `docs/verification/tests.md:563`,
  `docs/verification/tests.md:565`, `docs/verification/tests.md:573`,
  `docs/verification/tests.md:578`, `docs/verification/tests.md:580`).

## Code References

- `PLAN.md:61` - Step 39 is marked complete.
- `docs/implementation/p7_resources_and_images.md:104` - P7 exit gate names the
  implemented subset as resource catalog reads and dirty revision orchestration.
- `docs/implementation/p7_resources_and_images.md:119` - target resource dirty
  cache eviction is labeled future session/cache subset.
- `docs/implementation/p7_resources_and_images.md:122` - mark-all cache clearing
  is labeled future session/cache subset.
- `docs/architecture/architecture_graph.yaml:360` - architecture graph records
  `ResourceKernel` implemented subset and future resolver/cache/session work.
- `docs/architecture/architecture_graph.yaml:741` - resource-kernel to
  surface-session invalidation edge is future P13 work.
- `docs/architecture/architecture_graph.yaml:755` - frame renderer to surface
  session edge is future P9 work.
- `lib/src/resources/resource_kernel.dart:7` - concrete resource kernel.
- `lib/src/contracts/internal/resource_catalog_port.dart:4` - committed public
  resource catalog seam.
- `lib/src/contracts/internal/resource_dirty_outcome.dart:3` - dirty outcome DTO.
- `lib/src/contracts/internal/resolver_mutation_guard.dart:1` - resolver
  mutation guard seam.
- `lib/src/contracts/internal/frame_facts_port.dart:124` - frame descriptor facts.
- `lib/src/api/canvas_surface.dart:21` - current surface stores the public
  resolver input.
- `lib/src/api/canvas_surface.dart:32` - current surface build is a placeholder.
- `docs/implementation/p9_frame_rendering_and_caches.md:57` - P9
  `PaintAssetBindingService` owns descriptor-to-asset binding through the session.
- `docs/implementation/p13_flutter_surface.md:17` - P13 owns session lifecycle
  wiring through the resource session owner.
- `docs/verification/tests.md:573` - target dirty cache eviction proof is future.
- `docs/verification/tests.md:578` - mark-all cache clearing proof is future.

## Observed Architecture Facts

- Pattern observed: committed resource descriptors are store-owned; public
  resource reads use the internal catalog seam; frame descriptor reads use
  `FrameFactsPort`; resolved image/cache/session state is documented under
  `SurfaceResourceSession` (`docs/contracts/resources.md:53`,
  `docs/contracts/resources.md:56`,
  `docs/contracts/resources.md:58`,
  `docs/contracts/resources.md:60`,
  `docs/contracts/resources.md:63`,
  `docs/contracts/resources.md:64`).
- Data flow: public dirty call -> `ResourceKernel` guard/catalog check/revision
  increment -> `ResourceDirtyOutcome` -> `RuntimeRoot` public state and main
  repaint effect (`lib/src/resources/resource_kernel.dart:31`,
  `lib/src/resources/resource_kernel.dart:33`,
  `lib/src/resources/resource_kernel.dart:39`,
  `lib/src/resources/resource_kernel.dart:40`,
  `lib/src/runtime/runtime_root.dart:379`,
  `lib/src/runtime/runtime_root.dart:383`,
  `lib/src/runtime/runtime_root.dart:524`,
  `lib/src/runtime/runtime_root.dart:532`).
- Data flow: frame image binding target is element resource id and descriptor
  facts through `FrameFactsPort` -> `PaintAssetBindingService` -> future
  `SurfaceResourceSession`, with painters and ordinary planners excluded from
  direct resolver calls (`docs/contracts/resources.md:93`,
  `docs/contracts/resources.md:95`,
  `docs/contracts/resources.md:96`,
  `docs/contracts/resources.md:98`,
  `docs/contracts/resources.md:100`,
  `docs/implementation/p9_frame_rendering_and_caches.md:61`,
  `docs/implementation/p9_frame_rendering_and_caches.md:63`).
- Data flow: Flutter lifecycle target is successful single-active surface attach
  -> create empty session -> resolver swap increments generation and clears stale
  entries -> detach/dispose/runtime swap drops the session without disposing
  app-owned images (`docs/contracts/resources.md:103`,
  `docs/contracts/resources.md:104`,
  `docs/contracts/resources.md:105`,
  `docs/contracts/resources.md:106`,
  `docs/contracts/resources.md:107`,
  `docs/contracts/resources.md:108`).
- Enforcement fact: owner DAG allows the narrow runtime-to-resources composition
  edge and forbids resources-to-runtime/resources-to-frame edges
  (`test/guardrails/owner_dag_import_boundaries_test.dart:274`,
  `test/guardrails/owner_dag_import_boundaries_test.dart:284`,
  `test/guardrails/owner_dag_import_boundaries_test.dart:435`,
  `test/guardrails/owner_dag_import_boundaries_test.dart:436`).
- Enforcement fact: resource handoff internal seams are declaration-only and do
  not name `SurfaceResourceSession` in dirty outcome or catalog seams
  (`test/contracts/internal_seam_shape_test.dart:49`,
  `test/contracts/internal_seam_shape_test.dart:61`,
  `test/contracts/internal_seam_shape_test.dart:64`,
  `test/contracts/internal_seam_shape_test.dart:65`).

## Open Questions

- The current architecture graph marks the overall P7 phase as future while
  Step 39 is complete and the `ResourceKernel` node is required with an
  implemented subset (`docs/architecture/architecture_graph.yaml:42`,
  `docs/architecture/architecture_graph.yaml:44`,
  `PLAN.md:61`,
  `docs/architecture/architecture_graph.yaml:360`).
- `resource.surface_session` is a required architecture owner node with
  `SurfaceResourceSession` listed as its actual declaration, while Step 39 and
  verification docs still classify real session/cache behavior as future
  (`docs/architecture/architecture_graph.yaml:364`,
  `docs/architecture/architecture_graph.yaml:370`,
  `docs/architecture/architecture_graph.yaml:376`,
  `docs/architecture/architecture_graph.yaml:379`,
  `plan/step_39_p7_resource_kernel_read_seam_and_dirty_orchestration.md:89`,
  `docs/verification/tests.md:573`).
- The P7 phase doc lists full resolver/cache/session tests as phase proof, while
  current verification text records only narrow dirty behavior as implemented and
  session/cache proof as future (`docs/implementation/p7_resources_and_images.md:85`,
  `docs/implementation/p7_resources_and_images.md:90`,
  `docs/implementation/p7_resources_and_images.md:92`,
  `docs/implementation/p7_resources_and_images.md:93`,
  `docs/verification/tests.md:561`,
  `docs/verification/tests.md:573`).
- Current code has the resolver callback guard seam and runtime rejection logic,
  but actual resolver execution through `SurfaceResourceSession` is not present
  in the current surface implementation, which only stores `resourceResolver`
  and builds an empty widget (`lib/src/contracts/internal/resolver_mutation_guard.dart:1`,
  `lib/src/runtime/runtime_root.dart:354`,
  `lib/src/runtime/runtime_root.dart:368`,
  `lib/src/api/canvas_surface.dart:21`,
  `lib/src/api/canvas_surface.dart:32`).
- Unclosed classification in the current sources: which owner closes each
  remaining documented behavior: P7 session/cache primitive and policy
  (`docs/contracts/resources.md:110`), P9 frame image binding
  (`docs/implementation/p9_frame_rendering_and_caches.md:57`), and P13
  lifecycle wiring (`docs/implementation/p13_flutter_surface.md:17`).
