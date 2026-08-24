<!-- CONTEXT:BEGIN -->
Registry id: `section_22_guardrails_machine_checks`
Registry source: `docs/_registry/sections.yaml`
Document path: `docs/verification/guardrails.md`
Owns:
- 22. Guardrails and machine checks
Must read before editing:
- `section_00_status_and_scope` -> `docs/architecture/00_architecture_overview.md`
- `section_03_package_layout` -> `docs/architecture/02_package_boundaries.md`
Current owners:
- `guardrail`
Related diagrams:
- `none`
Required tests:
- `test.api_contract.public_integration_compile_fixture`
- `test.api_contract.prepared_vector_public_api`
- `test.guardrails.frame_committed_facts_via_frame_facts_port`
- `test.guardrails.text_surface_guardrail_checks`
- `test.guardrails.blocking_suite`
Guardrails:
- `api.integration_surface_complete`
- `api.public_exports_complete`
- `api.no_public_internal_load_types`
- `api.no_unapproved_document_load_inputs`
- `api.facades_do_not_export_internal`
- `api.public_types_complete`
- `api.public_api_compiles_as_written`
- `api.resource_source_app_key_publicly_readable`
- `api.preview_state_sealed_union_publicly_readable`
- `api.exported_dartdoc_complete`
- `api.public_class_modifiers_explicit`
- `api.no_public_api_import_cycles`
- `api.public_signature_shape`
- `api.no_undefined_public_type_references`
- `api.dto_immutability`
- `api.equality_policy_explicit`
- `api.id_validation_no_extension_type_escape`
- `core.no_unapproved_external_package_imports`
- `core.import_boundaries`
- `core.no_unapproved_part_files`
- `core.no_unapproved_controller_shape_dependency`
- `core.no_unapproved_patch_shape_dependency`
- `core.single_runtime_root`
- `store.no_public_document_live_state`
- `selection.owner_separate_from_document`
- `projection.only_explicit_read_paths`
- `edit.sync_non_nested`
- `edit.rollback_no_effects`
- `edit.stale_handle_rejected`
- `edit.operation_matrix_complete`
- `edit.no_global_invalidation_except_replacement`
- `edit.typed_effects_no_frame_dependency`
- `events.low_level_edit_no_user_actions`
- `events.commands_emit_user_actions`
- `events.action_after_state_order`
- `events.runtime_created_timestamps_monotonic`
- `load.prepares_before_interrupt`
- `load.success_interrupts_before_install`
- `preview.selected_move_main_only`
- `preview.marquee_overlay_only`
- `interaction.no_concrete_store_imports`
- `interaction.no_concrete_selection_imports`
- `interaction.read_port_immutable_facts`
- `interaction.no_command_facts_import`
- `interaction.cleanup_coordinator_dependency_bans`
- `interaction.no_resolver_on_cancel_paths`
- `interaction.no_stale_terminal_commit`
- `interaction.pointer_cleanup_coordinator_only`
- `geometry.committed_handle_order`
- `geometry.eraser_exact_budget_no_partial`
- `spatial.no_full_clone_ordinary_edit`
- `spatial.stale_candidate_rejected`
- `spatial.fallback_budget_enforced`
- `frame.committed_facts_via_frame_facts_port`
- `frame.no_global_scene_sort`
- `frame.paint_plan_excludes_preview_delta`
- `frame.paint_plan_excludes_selection_state`
- `text.single_measured_layout_source`
- `text.no_overlay_textpainter_measurement`
- `surface.editable_text_surface_only`
- `cache.keys_use_next_revisions_only`
- `cache.background_grid_not_element_visual`
- `cache.hot_caches_have_capacity_eviction`
- `resources.mutation_inside_edit_only`
- `resources.dirty_no_document_revision`
- `resources.app_key_only`
- `resources.resolver_boundary_owned_by_surface_session`
- `resources.resolver_frame_budget`
- `resources.no_same_frame_missing_retry`
- `resources.resolver_reentrancy_rejected`
- `codec.schema_v1_exact`
- `codec.known_fields_validated`
- `codec.no_runtime_side_effects`
- `diagnostics.disabled_no_alloc_hot_path`
- `diagnostics.sanitized_public_projection`
- `tools.public_port_behavior`
- `surface.pointer_samples_normalized_before_runtime`
- `surface.interactive_false_pending_line_preserved`
Do not assume:
- no non-blocking critical guardrail
<!-- CONTEXT:END -->

## 22. Guardrails and machine checks

### Guardrail runner contract

Guardrails are blocking architecture and release rules. They must be executable
through one project-owned entrypoint so developers and CI do not need to
remember individual proof commands.

The primary entrypoint is:

```bash
dart run tool/guardrails/run.dart
```

A run without arguments executes the full blocking guardrail suite. The runner
is a thin dispatcher over existing proof commands, such as Dart tests and
tool-owned structural checks. It must not become a second test framework or a
second source of truth for required guardrails.

The current architecture graph checker is a standalone strict closure
command:

```bash
dart run tool/architecture_graph/check.dart
```

For current closure work, this command is the blocking source of truth
for graph-checkable obligations. A non-zero result means the current closure has
an open architecture violation that must be repaired, rescheduled by an accepted
contract, or explicitly resolved before dependent architecture work continues.

The graph extractor is not a general Dart call-graph analyzer. It extracts only
named graph facts declared in `docs/architecture/architecture_graph.yaml`, such
as covered imports, declarations, implemented interfaces, graph-owned
composition fields, public placeholders, sensitive throws, and explicitly named
delegation members. If a future implementation chooses block-bodied internal
logic for a graph-critical route, keep a small named graph-checkable bridge for
the route instead of relying on broad call-body scanning. Sensitive-throw routes
must also name the bridge call target, so an unused bridge declaration cannot
close the architecture edge.

The runner must support these selection modes:

```bash
dart run tool/guardrails/run.dart --suite=api
dart run tool/guardrails/run.dart --guardrail=core.import_boundaries
```

`--suite=<name>` runs a named guardrail group. `--guardrail=<id>` runs one
guardrail id from the executable runner inventory.

Runner metadata lives under `tool/guardrails/**` and owns the executable
guardrail ids, suite membership, and dispatch routing for checks that can run
through this entrypoint. Future mandatory guardrails remain owned by
`docs/_registry/sections.yaml` and this section until their implementation
contract adds executable proof.

Design guidance for implementing or rewriting individual guardrails lives in
`docs/verification/guardrail_design_patterns.md`. Each mandatory guardrail must
choose a pattern from that document before executable proof is added, so new
checks reuse the repository-proven scanner, resolver, sequence, parity, behavior,
and budget patterns instead of inventing bespoke enforcement.

Mandatory guardrails:

| Guardrail id | Rule |
|---|---|
| `api.integration_surface_complete` | external app-adapter compile fixture imports only the public barrel and proves the public surface is enough for app-level `application adapter` responsibilities, including the image/vector resolver signatures, while the adapter itself is not in package; its prepared-vector companion permits only the admitted preparation use and rejects raw Picture, upstream vector types, codec-local decode helpers, internal helpers, construction/liveness, and diagnostic members |
| `api.public_exports_complete` | all public names listed in `docs/_registry/public_api_v1.yaml`, including the admitted vector DTO/update/resource names, are exported by the root package public barrel |
| `api.no_public_internal_load_types` | the public API registry and root barrel do not expose declarations resolved from internal load, import, store, row, or prepared-load implementation libraries |
| `api.no_unapproved_document_load_inputs` | production runtime/edit/store/codec load and admission signatures do not accept `CanvasDocument`; allowed `CanvasDocument` parameters are limited to read/output projection, encode/tooling, explicit draft materialization paths, and named test hooks |
| `api.facades_do_not_export_internal` | `lib/src/api/**` facade exports do not expose declarations marked `@internal` |
| `api.public_types_complete` | all public signatures reference defined public types |
| `api.public_api_compiles_as_written` | public API declarations compile in an empty consumer package, including `CanvasRuntime.state` and exported runtime state snapshot types while excluding extra document/preview listener getters |
| `api.resource_source_app_key_publicly_readable` | external resolver code can read `CanvasAppKeyResourceSource.key` from image/vector resource `.source` through the public barrel only |
| `api.preview_state_sealed_union_publicly_readable` | external preview consumers can type-test exported sealed CanvasPreviewState variants and read variant payloads through the public barrel only |
| `api.exported_dartdoc_complete` | exported public declarations have non-empty Dart documentation summaries before API freeze |
| `api.public_class_modifiers_explicit` | every exported public class chooses an explicit Dart 3 subtype/implementation policy |
| `api.no_public_api_import_cycles` | public API wrapper files and re-exported `contracts/public/**` declarations form an acyclic parsed import/export reachability graph |
| `api.public_signature_shape` | public signatures avoid `FutureOr`, nullable async/container returns, and `dynamic` outside approved JSON or diagnostic boundaries; metadata-bearing DTO signatures use exported `CanvasMetadata` |
| `api.no_undefined_public_type_references` | every exported signature type is exported or from Flutter/Dart SDK |
| `api.dto_immutability` | DTO collections are defensively copied and unmodifiable; `CanvasMetadata` is deep-frozen; public constructors with caller-provided validated or sanitized values are non-const factories while marker/empty/default/private storage forms keep only approved const forms |
| `api.equality_policy_explicit` | public value equality is explicit for concrete public classes, including runtime state snapshot types, and covered by API contract tests |
| `api.id_validation_no_extension_type_escape` | ids cannot be publicly constructed without validation |
| `core.no_unapproved_external_package_imports` | no import of package-internal package routes |
| `core.import_boundaries` | package-owned source paths obey source boundary rules and the forbidden import matrix from `section_03_package_layout`; exactly one API-owned vector-preparation root may import `vector_graphics`, while its owned dependency closure admits only finite capability-free whole libraries plus local/package-owned edges. Capability-bearing umbrella namespaces require `show`: `dart:ui` Offset/Picture/Size, Flutter widgets BuildContext, Flutter foundation internal, and vector_graphics BytesLoader/PictureInfo/vg. Unshown, hidden, or unapproved names and all other external routes, including asset/file/network loaders, platform channels, isolates, and global error handlers, are rejected consistently for parsed fixtures and resolved production source. |
| `core.owner_dag_import_boundaries` | production import/export directives obey the selected owner-DAG: implementation-to-API, contracts-to-API, contracts-to-implementation, `resources -> runtime/store/frame/surface`, `selection -> runtime`, and `codec -> runtime/store/edit/frame` edges are rejected; API wrapper exports to `contracts/public/**` and named facade bridges are the only API exceptions |
| `core.no_unapproved_part_files` | production code has no `part` or `part of` files unless generated-code use is explicitly approved |
| `core.no_unapproved_controller_shape_dependency` | blocks controller-shaped ownership bypasses in core |
| `core.no_unapproved_patch_shape_dependency` | blocks update-owner shape bypasses in core |
| `core.single_runtime_root` | exactly one production RuntimeRoot |
| `store.no_public_document_live_state` | DocumentStoreKernel stores compact committed tables, not a live mutable `CanvasDocument` |
| `selection.owner_separate_from_document` | selected ids and selectionRevision are owned by the internal selection owner, not DocumentStoreKernel, CommittedDocument, CanvasDocument projection, schema v1, or public DTO state |
| `projection.only_explicit_read_paths` | `CanvasDocument` projection is built only by read/encode/test/tool or explicit draft-read paths, never pointer/hit/paint hot paths, runtime JSON load before first explicit read, or ordinary sparse accepted-finalization/no-op routing |
| `edit.sync_non_nested` | nested/async edit rejected |
| `edit.rollback_no_effects` | rollback discards events/repaint/resources/spatial |
| `edit.stale_handle_rejected` | stale edit handle throws |
| `edit.operation_matrix_complete` | every operation matrix row has executable assertions for expanded operation matrix dimensions: touched state, public state revisions, internal revisions, spatial, projection, resource effects, repaint, user-action events, no-op behavior including compensating final fact no-ops, and rollback behavior |
| `edit.no_global_invalidation_except_replacement` | ordinary edits compile exact accepted touched invalidation from store-finalized facts; only document replacement may use global invalidation |
| `edit.typed_effects_no_frame_dependency` | CommitCompiler produces typed effects and does not depend on concrete FrameEngine |
| `events.low_level_edit_no_user_actions` | CanvasEdit.removeElement/clearContent emit no user action events |
| `events.commands_emit_user_actions` | high-level commands and interaction commits own user action events |
| `events.action_after_state_order` | accepted public state is published before user action events emitted by interaction and command commits |
| `events.runtime_created_timestamps_monotonic` | runtime-created `timestampMs` outputs resolve nullable and backwards hints through one runtime-local monotonic cursor, including stale host timestamps, action events, context-action requests, and pending line start previews; selected move resolver callback requests are not timestamped outputs |
| `load.prepares_before_interrupt` | failed schema-v1 JSON load does not interrupt gesture, clear selection, publish state, emit actions, build public projection, or install partial store rows |
| `load.success_interrupts_before_install` | successful schema-v1 JSON load parses JSON, emits codec-owned import events, prepares store-owned rows, prepares interaction cleanup before atomic install, performs no post-install interaction owner call to finish load cleanup, and publishes exactly one accepted runtime state without building first projection |
| `preview.selected_move_main_only` | selected move preview is routed only through the main repaint domain |
| `preview.marquee_overlay_only` | marquee preview is routed only through the overlay repaint domain |
| `interaction.no_concrete_store_imports` | InteractionEngine uses EditKernel and narrow read-only query ports, not concrete store imports or mutations |
| `interaction.no_concrete_selection_imports` | InteractionEngine uses intent-specific selection query ports and EditKernel commits, not concrete SelectionKernel imports or mutations |
| `interaction.read_port_immutable_facts` | InteractionReadPort request and fact objects derive caller-provided collection fields from constructor/field shape and defensively copy them before exposing them to interaction machines, including eraser corridor and erased-id lists |
| `interaction.no_command_facts_import` | interaction code must not import command facts; command read facts stay owned by runtime command adapters |
| `interaction.cleanup_coordinator_dependency_bans` | PointerToolCleanupCoordinator must not depend on runtime, edit, frame, resources, store, selection, Flutter bridge, Flutter package, resolver callback, or resolver guard owners |
| `interaction.no_resolver_on_cancel_paths` | selected-move resolver is not called on cancel, load, mode-change, `interactive=false`, stale terminal, or dispose paths |
| `interaction.no_stale_terminal_commit` | stale or controllerEpoch-mismatched terminal samples cannot create selected-move, draw, line, or eraser commit intents |
| `interaction.pointer_cleanup_coordinator_only` | cleanup-capable tool machines return typed cleanup requests to `InteractionEngine`, `InteractionEngine` is the only caller of `PointerToolCleanupCoordinator`, and no tool machine owns shared preview/session cleanup policy, cleanup-effect publication, or direct coordinator calls |
| `geometry.committed_handle_order` | geometry and hit-test policy use committed handle order tokens without bypassing committed frame facts |
| `geometry.eraser_exact_budget_no_partial` | eraser primitive and exact-check budget inputs cannot produce partial-erasure paths, and terminal overflow cleanup remains a no-op with no document mutation, action emission, or DiagnosticsHub allocation |
| `spatial.no_full_clone_ordinary_edit` | ordinary spatial updates touch only changed ids/pages; full rebuild is reserved for replacement/load paths |
| `spatial.stale_candidate_rejected` | stale candidate handles are rejected by generation and structuralRevision checks before frame/hit use |
| `spatial.fallback_budget_enforced` | query-tile and fallback-candidate budgets increment non-hub counters and return typed budget-exceeded results without partial candidates |
| `frame.committed_facts_via_frame_facts_port` | production frame code obtains committed frame facts, row snapshots, and descriptor snapshots through `FrameFactsPort`, and `lib/src/frame/**` does not import concrete store internals |
| `frame.no_global_scene_sort` | selected supplement staging merges by orderToken and does not globally sort all scene elements; the analyzer-backed proof rejects whole-scene sort bypasses through direct sort calls, cascades, multi-line statements, and named comparator/helper indirection |
| `frame.paint_plan_excludes_preview_delta` | OrdinaryPaintRecordCache stores ordinary committed records only and excludes selectedMoveDelta/previewDelta from keys and values across ordinary-cache storage surfaces such as `PaintPlanKey`, `OrdinaryPaintRecordKey`, `OrdinaryPaintRecordCacheEntry`, `PaintPlan`, and registered render-row payloads |
| `frame.paint_plan_excludes_selection_state` | OrdinaryPaintRecordCache stores ordinary committed records only and excludes selected ids, selectionRevision, and selection flags from keys and values across ordinary-cache storage surfaces such as `PaintPlanKey`, `OrdinaryPaintRecordKey`, `OrdinaryPaintRecordCacheEntry`, `PaintPlan`, and registered render-row payloads |
| `text.single_measured_layout_source` | `FrameTextLayoutMeasurer` remains the single TextPainter-backed text layout source, while geometry consumes measured text layout facts instead of formula bounds based on text length, font size, maxWidth, or lineHeight |
| `text.no_overlay_textpainter_measurement` | surface and example text editing overlays must not construct a duplicate TextPainter measurement path; editor size and placement come from session geometry |
| `surface.editable_text_surface_only` | production `EditableText` use is confined to surface-owned widgets, with example code allowed as an application consumer and tests allowed as proof code |
| `cache.keys_use_next_revisions_only` | cache keys use current package-owned revision facts and stable inputs, not non-owned snapshot facts |
| `cache.background_grid_not_element_visual` | backgroundRevision/gridRevision changes and runtime view camera changes must not invalidate ordinary element paint plans |
| `cache.hot_caches_have_capacity_eviction` | hot caches declare capacity, eviction policy, invalidation owner, and metric/probe |
| `resources.mutation_inside_edit_only` | resource descriptor mutation only via CanvasEdit |
| `resources.dirty_no_document_revision` | markResourceDirty/markAllResourcesDirty publish `state.revisions.resourceVisual` for accepted dirty calls, prove missing/empty no-ops, and do not increment `state.revisions.document` |
| `resources.app_key_only` | resource descriptors use appKey only |
| `resources.resolver_boundary_owned_by_surface_session` | frame, painter, and non-session resource code cannot hold typed `CanvasResourceResolver` references; `SurfaceResourceSession` owns typed resolver access for an active surface |
| `resources.resolver_frame_budget` | SurfaceResourceSession enforces per-frame sync resolver call budget and budget-exceeded placeholders are not cached as null/missing |
| `resources.no_same_frame_missing_retry` | null resource resolve results are suppressed by resolverGeneration, resourceId, and resourceRevision for the frame instead of retried immediately; missing descriptors and absent resolvers return bounded placeholders without resolver calls |
| `resources.resolver_reentrancy_rejected` | public runtime mutation from inside CanvasResourceResolver throws StateError without runtime effects |
| `codec.schema_v1_exact` | only schema v1 read/write |
| `codec.known_fields_validated` | known schema v1 fields are validated and canonical encoder writes only v1 fields |
| `codec.no_runtime_side_effects` | schema v1 import/encode validates codec-owned input without mutating runtime or store state; runtime load import emits dependency-neutral events instead of materializing public DTOs |
| `diagnostics.disabled_no_alloc_hot_path` | schema/codec success paths allocate no diagnostic records while diagnostics are disabled; pointer/paint hot-path proof remains deferred until those runtime owners exist |
| `diagnostics.sanitized_public_projection` | diagnostic details expose only sanitized bounded public data; the guard uses explicit `diagnostics_public_surface` registry membership plus analyzer-resolved public signature traversal to prevent currently classified runtime-like public types from leaking |
| `tools.public_port_behavior` | public tool and command ports expose interaction payload families without source-level internal imports |
| `surface.pointer_samples_normalized_before_runtime` | Flutter surface adapters pass finite pointer samples or terminal cleanup input into runtime routing without owning world normalization |
| `surface.interactive_false_pending_line_preserved` | interactive=false cancels active routed pointers, preserves pending line state not owned by an active routed pointer, and does not mutate runtime mode, committed document, selection, or resources |

Surface repaint routing is currently enforced by focused API and surface tests
rather than new guardrail runner ids. `test/api/runtime_surface_frame_bridge_test.dart`
proves runtime/surface pre-output invalidation uses
`CanvasSurfaceRepaintTarget` without importing or exposing `FrameRepaintSignal`.
`test/surface/surface_frame_output_cache_test.dart` proves
`SurfaceFrameOutputCache` owns targeted main/overlay output rebuilds, local
surface invalidation mapping, output identity stability, and all-or-nothing
notifier publication. `test/surface/no_live_runtime_read_in_painters_test.dart`
proves painters consume immutable layer outputs through repaint listenables and
do not read runtime, store, public document projection, resolver, or session
state during paint. `test/surface/widget_paint_test.dart` proves the stable
public surface wrapper contains independent main and overlay paint hosts, and
targeted layer output notifier dispatch marks only the affected paint layer.
These proof surfaces must not be invoked through `--guardrail=<id>` unless a
future implementation contract adds runner metadata under `tool/guardrails/**`.

`api.integration_surface_complete` is executable only when the guardrail runner
or its delegated proof compiles
`test/api_contract/fixtures/public_integration_compile_fixture.dart` and
checks that the fixture imports only
`package:iwb_canvas_engine/iwb_canvas_engine.dart`. The fixture must not import
`src/**`, package-internal symbols, or internal runtime classes, and it must exercise the
required external adapter operation families from the public API contract.

---
