# P4 - resources

## Build

- ResourceKernel
- CanvasResourceId
- CanvasResourceSource.appKey only
- resource mutation inside CanvasEdit only
- markResourceDirty
- markAllResourcesDirty
- synchronous app-owned image resolver bridge
- no engine IO
- no asset-bundle loading
- no file loading
- no remote/network loading

## Read first

- `section_04_public_api_v1` -> `docs/contracts/public_api_v1.md`
- `section_07_resource_lifecycle` -> `docs/contracts/resources.md`
- `section_23_tests` -> `docs/verification/tests.md`

## Required donors

- none

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

## Guardrails

- `api.dto_immutability` - DTO collections defensively copied and unmodifiable
- `api.functional_ledger_complete` - every functional ledger row has API + tests
- `api.id_validation_no_extension_type_escape` - ids cannot be publicly constructed without validation
- `api.no_undefined_public_type_references` - every exported signature type is exported or from Flutter/Dart SDK
- `api.public_api_compiles_as_written` - public API declarations compile in an empty consumer package
- `api.public_types_complete` - all public signatures reference defined public types
- `resources.app_key_only` - resource descriptors use appKey only
- `resources.dirty_no_document_revision` - markResourceDirty does not increment documentRevision
- `resources.mutation_inside_edit_only` - resource descriptor mutation only via CanvasEdit
- `resources.resolver_boundary_owned_by_resource_kernel` - painters never call CanvasResourceResolver directly
- `resources.no_same_frame_missing_retry` - missing/null resolve results are cached for the frame by resourceId and resourceRevision
- `resources.resolver_reentrancy_rejected` - public runtime mutation from inside the resolver throws StateError

## Tests

- `test.codec.schema_v1.resources_appkey_only` -> `test/codec/schema_v1/resources_appkey_only_test.dart`
- `test.codec.schema_v1.reject_unknown_resource_source_kind` -> `test/codec/schema_v1/reject_unknown_resource_source_kind_test.dart`
- `test.resources.sync_image_resolver` -> `test/resources/sync_image_resolver_test.dart`
- `test.resources.app_owned_image_not_disposed` -> `test/resources/app_owned_image_not_disposed_test.dart`
- `test.resources.resource_dirty` -> `test/resources/resource_dirty_test.dart`
- `test.resources.mark_all_resources_dirty` -> `test/resources/mark_all_resources_dirty_test.dart`
- `test.resources.painter_never_calls_resolver_directly` -> `test/resources/painter_never_calls_resolver_directly_test.dart`
- `test.resources.missing_result_cached_per_revision` -> `test/resources/missing_result_cached_per_revision_test.dart`
- `test.resources.resolver_reentrancy_rejected` -> `test/resources/resolver_reentrancy_rejected_test.dart`

## Exit gate

- resource descriptor mutation is rollback-safe
- resource dirty schedules main repaint without document revision
- resolver image results are app-owned and not disposed by engine
- painters resolve images only through ResourceKernel
- missing/null resolver results do not retry in the same frame
- resolver reentrancy is rejected without runtime effects
- resource surface matches the v1 appKey/synchronous image contract.
