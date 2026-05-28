# P7 - resources and image lifecycle

## Purpose

Implement resource descriptors, image resources, synchronous app-owned image
resolution, dirty-resource repaint effects, and resolver safety after edit and
load have established rollback-safe mutation and replacement boundaries.

## Build scope

- `ResourceKernel`
- `SurfaceResourceSession`
- `CanvasResourceId` and resource DTO support from `contracts/public/**`
- `CanvasResourceSource.appKey` only, publicly readable as
  `CanvasAppKeyResourceSource.key`
- resource descriptor mutation only inside `CanvasEdit`
- image resource and image element lifecycle
- `markResourceDirty`
- `markAllResourcesDirty`
- resource visual public state revision effects through contract-owned
  `ResourceDirtyOutcome` without document revision changes
- synchronous app-owned image resolver bridge
- surface-scoped image resolve cache keyed by resolverGeneration, resource id,
  and resource revision
- missing/null resolve results suppressed per frame by resource id and resource
  revision and resolverGeneration, without durable null/missing cache writes
- resolver frame budget with bounded placeholders and no null/missing cache write
- resolver reentrancy guard through contract-owned `ResolverMutationGuard`,
  rejecting public runtime mutation from inside the resolver
- no engine IO
- no asset-bundle loading
- no file loading
- no remote/network loading.

## Dependencies on earlier phases

- P2 public resource API is frozen and its declarations are owned by
  `contracts/public/**`.
- P3 resource schema and validation are implemented.
- P4 runtime spine exposes descriptor facts through `contracts/internal/**`
  seams; P7 must not import runtime to read them.
- P5 edit core provides rollback-safe resource mutations.
- P6 load replacement invalidates resource state correctly.

## Read first

- `section_07_resource_lifecycle` -> `docs/contracts/resources.md`
- `section_10_runtime_data_model` -> `docs/architecture/03_data_model.md`
- `section_23_tests` -> `docs/verification/tests.md`

## Required donors

- none.

## Forbidden donor structure

- `avoid_scene_controller_facades` - decision: `avoid`
- `avoid_interactive_runtime_whole` - decision: `avoid`
- `avoid_scene_builder_public_architecture` - decision: `avoid`
- `avoid_scene_codec_whole` - decision: `avoid`
- `avoid_scene_store_controller_whole` - decision: `avoid`

## Diagrams to read or update

- `c4_context` -> `docs/diagrams/c4_context.mmd`
- `dfd_public_edit` -> `docs/diagrams/dfd_public_edit.mmd`
- `dfd_resource_resolution` -> `docs/diagrams/dfd_resource_resolution.mmd`
- `seq_resource_resolution` -> `docs/diagrams/seq_resource_resolution.mmd`
- `state_resource_resolution` -> `docs/diagrams/state_resource_resolution.mmd`
- `dfd_cache_invalidation` -> `docs/diagrams/dfd_cache_invalidation.mmd`

## Contracts satisfied by this phase

- resource lifecycle, mutation, dirtying, resolver, missing-placeholder, budget,
  and reentrancy contract from `section_07_resource_lifecycle`
- resource schema v1 appKey-only contract from `section_05_schema_v1_contract`
- resource revision and descriptor ownership from `section_10_runtime_data_model`
- image resolve cache policy from `section_07_resource_lifecycle`

## Tests and guardrails that prove this phase

- `test.codec.schema_v1.resources_appkey_only` -> `test/codec/schema_v1/resources_appkey_only_test.dart`
- `test.api_contract.public_readable_union_variants` -> `test/api_contract/public_readable_union_variants_test.dart`
- `test.codec.schema_v1.reject_unknown_resource_source_kind` -> `test/codec/schema_v1/reject_unknown_resource_source_kind_test.dart`
- `test.resources.sync_image_resolver` -> `test/resources/sync_image_resolver_test.dart`
- `test.resources.app_owned_image_not_disposed` -> `test/resources/app_owned_image_not_disposed_test.dart`
- `test.resources.resource_dirty` -> `test/resources/resource_dirty_test.dart`
- `test.resources.mark_all_resources_dirty` -> `test/resources/mark_all_resources_dirty_test.dart`
- `test.resources.missing_result_suppressed_per_frame` -> `test/resources/missing_result_suppressed_per_frame_test.dart`
- `test.resources.surface_session_cache_lifecycle` -> `test/resources/surface_session_cache_lifecycle_test.dart`
- `test.resources.resolver_swap_starts_fresh_cache` -> `test/resources/resolver_swap_starts_fresh_cache_test.dart`
- `test.resources.resolver_frame_budget` -> `test/resources/resolver_frame_budget_test.dart`
- `test.resources.resolver_reentrancy_rejected` -> `test/resources/resolver_reentrancy_rejected_test.dart`
- `resources.app_key_only`
- `resources.dirty_no_document_revision`
- `resources.mutation_inside_edit_only`
- `resources.resolver_boundary_owned_by_surface_session`
- `resources.resolver_frame_budget`
- `resources.no_same_frame_missing_retry`
- `resources.resolver_reentrancy_rejected`

## Exit gate

- implemented subset: `CanvasRuntime.resources` is backed by `ResourceKernel`
  for committed catalog reads and public dirty resource revision orchestration;
  `ResourceCatalogPort` is the internal catalog seam and frame code is blocked
  from using it for asset binding
- resource descriptor mutation is rollback-safe
- `ResourceKernel` owns the public resource read/dirty API under
  `lib/src/resources/**`; `SurfaceResourceSession` owns resolver/cache/session
  behavior under the same resource owner, while resource DTOs and
  `CanvasResourcePort` remain in `contracts/public/**`
- dirty-resource outcomes are carried by `ResourceDirtyOutcome` and resolver
  reentrancy is rejected through `ResolverMutationGuard`, both owned by
  `contracts/internal/**`
- descriptor facts that later frame code needs are exposed through the
  `contracts/internal/**` `FrameFactsPort`, not by importing runtime or frame
- resource dirty publishes `state.revisions.resourceVisual` and schedules main
  repaint intent without document revision
- target resource dirty evicts the target active-session image cache entry
  before dirty public-state/effect publication and resolves that image again on
  the next session resolve
- mark-all resource dirty clears the active-session image cache before dirty
  public-state/effect publication
- resolver image results are app-owned and not disposed by engine
- the P7 resource/session surface exposes image resolution only through
  `SurfaceResourceSession`; later frame and widget wiring must keep that
  `lib/src/resources/**` boundary
- resolver swap, detach, dispose, and runtime swap cannot reuse stale session cache entries
- missing/null resolver results do not retry in the same frame
- resolver frame budget produces bounded placeholders and no invalid cache write
- resolver reentrancy is rejected through the contract-owned guard seam with no
  resource visual revision, no public state publication, no action/effect
  emission, and no runtime mutation
- resource surface matches the v1 appKey/synchronous image contract.

## Risks and trade-offs

- Resource descriptors belong to committed state, while resolved images belong
  to a live surface session. This phase must not merge those owners.
- The frame paint path is implemented later, so this phase proves the resolver
  boundary and budget through SurfaceResourceSession tests and typed repaint
  intents.

## Why this phase belongs here

Resources need public/schema validation, committed storage, rollback-safe edit,
and load invalidation before they can be correct. They also must exist before
frame rendering can paint image elements.
