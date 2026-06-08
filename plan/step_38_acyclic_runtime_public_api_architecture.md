# Change Contract

## Goal

Re-home the shared public declarations and internal cross-owner seams below the
public facade so runtime, edit, store, selection, codec, diagnostics, and future
resource/frame owners no longer depend on `lib/src/api/**` as their type
library. The supported package public surface remains the root barrel and
`CanvasRuntime` remains the public facade over `RuntimeRoot`, while repository
guardrails, architecture graph data, diagrams, docs, and the public incremental
smoke test prove the resulting owner graph is acyclic before P7 resource work
adds new edges.

## Evidence

- `.design/2026-05-27-acyclic-runtime-public-api-architecture.md` / disposition: the design is `READY_FOR_CONTRACT` and selects a contract layer under the public facade -> this step must preserve that architecture form rather than redesigning the owner graph.
- `.design/2026-05-27-acyclic-runtime-public-api-architecture.md` / target contract classification: the required profile is `ANALYZER_RULE` and the required obligations are `SEAM_MIGRATION` and `PUBLIC_API_CHANGE` -> this step must treat mechanical DAG enforcement, seam migration, and public compatibility proof as first-class completion criteria.
- `.design/2026-05-27-acyclic-runtime-public-api-architecture.md` / selected form: `lib/src/contracts/public/**` owns public DTOs, values, public errors, diagnostic policies, runtime state/config types, and public port interfaces; `lib/src/contracts/internal/**` owns non-exported owner ports, facts, effect/result seams, and guard contracts -> implementation must create those owners before moving consumers.
- `.design/2026-05-27-acyclic-runtime-public-api-architecture.md` / target DAG: implementation owners may depend on contracts, runtime may compose implementation owners, and contracts must not depend on implementation owners -> the boundary rule and graph proof must be directional, not another allowlist.
- `.design/2026-05-27-acyclic-runtime-public-api-architecture.md` / source-of-truth impact: architecture docs, public API contract docs, codec/edit/load/resource docs, architecture graph YAML, semantic diagrams, generated graph views, guardrail docs, and public smoke coverage are named dependent surfaces -> the step must update diagrams and docs in the same change, not leave topology drift for P7.
- `.design/2026-05-27-acyclic-runtime-public-api-architecture.md` / verification impact: the required proof includes module-DAG guardrails, import/export boundary fixtures, architecture graph forbidden edges, public API compile/export/signature/equality checks, the public incremental smoke test, behavior characterization tests, docs checks, and architecture graph checks -> completion checks must name each executable signal.
- `.research/2026-05-27-cyclic-dependency-anchors.md` / current cycles: `api`, `runtime`, `edit`, `store`, `selection`, `codec`, and `diagnostics` form source cycles through public API imports -> a local call-site patch is incomplete unless the shared declaration owner changes.
- `lib/iwb_canvas_engine.dart` / root public barrel: the supported public package surface exports `src/api/**` files only -> public consumers must keep importing `package:iwb_canvas_engine/iwb_canvas_engine.dart` after declarations move.
- `lib/src/api/canvas_runtime.dart` / public facade bridge: `CanvasRuntime` imports and constructs `RuntimeRoot` -> this remains the single approved runtime implementation bridge from the public facade.
- `lib/src/api/canvas_codec.dart` / public codec facade: the public codec facade imports schema v1 encoder/decoder implementation -> this remains the approved public codec bridge while public DTO declarations move below API.
- `lib/src/runtime/runtime_root.dart` / runtime imports: `RuntimeRoot` currently imports public diagnostics, document, ids, runtime, and action declarations from `lib/src/api/**` while composing edit, selection, and store owners -> runtime must move to contract imports before the API boundary can be tightened.
- `lib/src/edit/**`, `lib/src/store/**`, `lib/src/selection/**`, `lib/src/codec/**`, and `lib/src/diagnostics/**` / current imports: implementation modules still import public API declaration files for document, element, ids, runtime ports, codec limits, errors, and diagnostic policies -> each owner must consume `contracts/public/**` or `contracts/internal/**` instead.
- `tool/guardrails/src/public_api_import_cycle_checks.dart` / current guardrail: the cycle check filters to `lib/src/api/**` files and only adds edges between public API sources -> it cannot prove the target owner DAG or wrapper export reachability by itself.
- `tool/guardrails/src/core_boundary_checks.dart` / boundary rules: current source-boundary rules forbid selected direct targets and keep a one-off `CanvasRuntime -> RuntimeRoot` exception -> this proof must be replaced or extended with named bridge policy plus implementation-to-api and contracts-to-implementation prohibitions.
- `test/guardrails/import_boundaries_test.dart` and `test/guardrails/public_api_import_cycles_test.dart` / existing fixtures: guardrail tests already exercise boundary and public API cycle behavior -> new positive and negative owner-DAG fixtures belong in the guardrail test suite instead of production source files.
- `docs/architecture/architecture_graph.yaml` / graph edges: the graph currently records `api.public_surface.exports_runtime`, `api.canvas_runtime.composes_runtime_root`, `codec.schema_v1.uses_public_dto`, edit/store/load edges, and future P7/P9 resource/session/frame edges -> graph nodes and forbidden edges must change with the new contract owners.
- `docs/_registry/diagrams.yaml` / generated graph views: generated architecture graph views are registered from `docs/architecture/architecture_graph.yaml` -> graph changes require regenerated checked-in views and registry/index consistency checks.
- `docs/tool/sync_generated_docs.dart` / generated docs workflow: the selected generated graph-view phase is `P6` -> docs and generated outputs must be updated through the existing generator and checked with the repo-selected `P6` command, not edited as stale copies.
- `docs/README.md` / docs checks: the documentation entry point lists `dart run tool/architecture_graph/generate_views.dart --phase P6 --check` with the docs checks -> this step must use `P6` for generated graph view verification unless it explicitly changes the docs workflow.
- `docs/architecture/01_runtime_ownership.md`, `docs/architecture/02_package_boundaries.md`, and `docs/architecture/03_data_model.md` / architecture source of truth: current docs assign stable DTOs to Public API and define package boundaries without a contract layer -> they must be updated to distinguish facade ownership, contract declaration ownership, and live state ownership.
- `docs/contracts/public_api_v1.md`, `docs/contracts/codec_boundary.md`, `docs/contracts/edit_kernel.md`, `docs/contracts/load_document.md`, and `docs/contracts/resources.md` / contract source of truth: public behavior, codec schema behavior, edit/load sequencing, and resource/session placement are durable behavior docs -> wording may change to contract declarations, but public behavior and sequencing must not change.
- `docs/implementation/p7_resources_and_images.md` / P7 implementation source of truth: P7 already owns `ResourceKernel`, `SurfaceResourceSession`, visual resource revision effects, resolver reentrancy rejection, and surface-session image resolution -> this implementation plan must be updated so P7 builds on contract-owned resource DTOs, outcomes, frame facts, and resolver guard seams instead of adding new runtime/resource/session cycles.
- `test/smoke/public_incremental_smoke_test.dart` / external consumer proof: the smoke uses only `package:iwb_canvas_engine/iwb_canvas_engine.dart` and already exercises decode, runtime state, selection, edit, and load through the public surface -> the smoke must remain a root-barrel public compatibility proof after API files become wrapper exports.

## Boundaries

Owner:

`lib/src/contracts/**` owns shared declaration placement and cross-owner seams.
`lib/src/api/**` owns public facade files and wrapper exports. `RuntimeRoot`
continues to own runtime composition and public state publication. Guardrail
tooling owns mechanical owner-DAG enforcement. Architecture docs, graph data,
diagram registries, and generated diagram views own durable topology truth.

In Scope:

- Introduce `lib/src/contracts/public/**` for public DTOs, value types, public
  errors, diagnostic policies, runtime state/config types, public action/event
  payloads, and public port interfaces that are part of the package contract.
- Introduce `lib/src/contracts/internal/**` for non-exported owner ports,
  immutable facts, and effect/result seams that cross implementation owners
  without becoming public API, including the minimal declaration-only P7
  resolver mutation guard and resource dirty outcome seams required by the
  design handoff. These P7 seams are contracts only; this step does not
  implement resource runtime behavior.
- Move current implementation consumers in runtime, edit, store, selection,
  codec, and diagnostics from `lib/src/api/**` imports to contract imports while
  preserving public names, constructors, equality, validation behavior, schema
  behavior, and edit/load publication ordering.
- Convert moved declaration-only `lib/src/api/**` files into wrapper exports of
  `contracts/public/**`, and keep `api/canvas_runtime.dart` and
  `api/canvas_codec.dart` as named implementation bridge facades.
- Update root-barrel and public surface checks so supported consumers still use
  `package:iwb_canvas_engine/iwb_canvas_engine.dart` with unchanged signatures.
- Add or extend repository-local guardrails so implementation owners cannot
  import `lib/src/api/**`, `contracts/public/**` and `contracts/internal/**`
  cannot import or export `lib/src/api/**` or implementation owners, API files
  cannot import or export `contracts/internal/**`, wrapper exports to
  `contracts/public/**` are allowed, and only named facade bridges may point
  from API to implementation.
- Update architecture graph nodes, edges, forbidden edges, generated graph
  views, semantic diagrams, diagram registries, generated indexes, architecture
  docs, contract docs, verification docs, and the public incremental smoke test
  to reflect the contract layer and acyclic owner DAG.
- Preserve the existing external-consumer public incremental smoke journey and
  update it as needed so it proves root-barrel reachability after wrapper-export
  migration without private `src/**` probes.
- After implementation and verification pass, mark Step 38 complete in
  `PLAN.md` and mark this step document's execution-unit checkboxes complete in
  the same change.

Out of Scope:

- Do not implement P7 resource kernel, surface resource session runtime behavior,
  resolver budget/cache behavior, frame renderer behavior, or public resource
  commands beyond declaration placement and documented seams needed to keep the
  future owner graph acyclic.
- Do not change public payload shapes, command names, codec schema v1 formats,
  public error codes, public runtime state semantics, edit/load ordering, or
  public `CanvasRuntime` behavior.
- Do not move `CanvasRuntime` itself into runtime, make runtime the public API
  declaration owner, duplicate public DTOs through adapter DTOs, or preserve
  cycles through allowlists.
- Do not add fixture-only imports, exports, registry entries, schemas, or public
  declarations to production source-of-truth files solely to prove guardrails.
- Do not broaden DCM or analyzer suppressions to hide migration fallout; any
  unavoidable local metric exception must follow the repository DCM exception
  policy with exact metric names and a nearby reason.

Source of Truth:

The design input for this step is
`.design/2026-05-27-acyclic-runtime-public-api-architecture.md`. Durable
architecture truth lives in `docs/architecture/**`,
`docs/architecture/architecture_graph.yaml`, `docs/diagrams/**`,
`docs/_registry/**`, and generated graph views. Durable behavior truth remains
in `docs/contracts/**` and must not be rewritten to change public behavior.
Implementation sequencing truth lives in `docs/implementation/**`. This step
must update every implementation phase document whose current wording describes
the old API-as-type-library owner, moved public declarations, moved internal
seams, or resource/session/frame placement affected by the new contract layer.
P7 is explicitly affected because it is the next resource/session phase, but it
is not the only implementation document in scope.
Executable enforcement lives in `tool/guardrails/**`,
`tool/architecture_graph/**`, and their tests. Public compatibility proof lives
in public API tests and `test/smoke/public_incremental_smoke_test.dart`.

Compatibility:

Root-barrel consumers importing `package:iwb_canvas_engine/iwb_canvas_engine.dart`
must see unchanged public names, constructors, fields, methods, enum/union
behavior, equality/hash behavior, validation errors, codec schema behavior, and
runtime observation semantics. Unsupported direct imports of
`package:iwb_canvas_engine/src/api/...` may observe wrapper-export files, but
must not be required for supported usage. Existing behavior tests for codec,
edit, load, diagnostics, runtime publication, and public smoke must continue to
pass after the migration.

Order Constraints:

Create contract declaration owners before moving implementation imports. Migrate
runtime/edit/store/selection/codec/diagnostics consumers away from `api` before
tightening guardrails. Convert API declaration files into wrapper exports only
after their declarations exist in `contracts/public/**`. Add public
compatibility tests and the public incremental smoke before enforcing the final
boundary so failures identify behavior drift. Tighten guardrails only after
that behavior-preservation proof passes, then update architecture graph
forbidden edges before P7 resource/session implementation adds future edges.
Update docs, diagrams, graph views, registries, and generated indexes after the
code and guardrail DAG are stable so source-of-truth text matches the enforced
graph.

## Execution Units

### [x] Unit 1: Public contract declarations and API wrappers

Owner:

Public contract declaration layer plus API facade wrapper files.

Boundary:

`lib/src/contracts/public/**`,
declaration-only files under `lib/src/api/**` that move to
`contracts/public/**`, `test/contracts/contract_declaration_shape_test.dart`,
the narrow `core.import_boundaries` wrapper-export allowance in
`tool/guardrails/**`, and the focused guardrail test coverage for that allowance
under `test/guardrails/**`. This unit creates the public contract owner,
replaces moved API declaration files with final wrapper exports, and teaches the
existing boundary guardrail that this final facade form is allowed in the same
change. It does not move internal runtime seams and does not add the full
owner-DAG guardrail yet.

Change:

Move public shared declarations out of their current API owners into cohesive
files named by stable responsibility under `contracts/public/**`: public DTOs,
values, errors, diagnostic policies, runtime state/config, public action/event
payloads, and public port interfaces. In the same unit, replace every moved API
declaration file with the final wrapper export to its `contracts/public/**`
owner. These API wrapper exports are the selected final facade shape, not a
temporary compatibility path. Keep `contracts/public/**` declaration-only: no
mutable runtime/store/selection/resource/frame/interaction state, no
composition roots, no imports from implementation owners, and no
`contracts/internal/**` exports. Internal runtime seams stay in their current
owners until Unit 2, where the seam declaration move and consumer migration
happen atomically without internal shim exports. Add or update the focused
`test/contracts/contract_declaration_shape_test.dart` proof file that verifies
public declaration shape. In the same unit, update only the existing
`core.import_boundaries` export rule so API wrapper exports to
`contracts/public/**` are allowed and API imports/exports to
`contracts/internal/**` remain forbidden. Do not add the broader owner-DAG
guardrail in this unit.

Completion Check:

`rg -n "lib/src/(api|runtime|edit|store|selection|codec|diagnostics|resources|frame|interaction|spatial|flutter_bridge)|package:iwb_canvas_engine/src/(api|runtime|edit|store|selection|codec|diagnostics|resources|frame|interaction|spatial|flutter_bridge)|\\.\\./(api|runtime|edit|store|selection|codec|diagnostics|resources|frame|interaction|spatial|flutter_bridge)" lib/src/contracts/public`
prints no implementation-owner imports or references except allowed sibling
`contracts/public/**` references. `dart analyze` reports no duplicate
declaration, missing import, or public type resolution errors for the new public
contract files and API wrapper exports.
`dart test test/contracts/contract_declaration_shape_test.dart` passes and
covers moved equality, const constructors, validation helpers, error
sanitization/value behavior, and public port interface reachability without
importing `lib/src/api/**` from the tested implementation owner fixtures.
`rg -n "export '../contracts/public|export 'package:iwb_canvas_engine/src/contracts/public" lib/src/api`
shows wrapper exports for moved public declarations, while
`rg -n "contracts/internal" lib/src/api lib/iwb_canvas_engine.dart` prints no
matches. `rg -n "contracts/internal" lib/src/runtime lib/src/edit lib/src/store lib/src/selection lib/src/codec lib/src/diagnostics`
prints no matches in Unit 1, proving internal seam migration has not been
partially started before Unit 2. `dart test test/guardrails/import_boundaries_test.dart`
passes for the narrow wrapper-export allowance: positive fixture for
`api/** -> contracts/public/**` export passes, and negative fixture for
`api/** -> contracts/internal/**` import or export still fails.

Depends On:

None.

### [x] Unit 2: Internal owner import migration

Owner:

Runtime, edit, store, selection, codec, and diagnostics implementation owners.

Boundary:

`lib/src/contracts/internal/**`, runtime seam files being moved from
`lib/src/runtime/**`, production sources under `lib/src/runtime/**`,
`lib/src/edit/**`, `lib/src/store/**`, `lib/src/selection/**`,
`lib/src/codec/**`, and `lib/src/diagnostics/**`, and
`test/contracts/internal_seam_shape_test.dart`. This unit moves internal
cross-owner seams and all affected consumers atomically; it must not leave
temporary runtime seam shim exports behind and must not change public behavior,
schema v1 payloads, runtime publication order, or edit/load commit semantics.

Change:

Move non-exported `DocumentFactsPort`, `FrameFactsPort`,
`SelectionFactsPort`, `SelectionMembershipPort`, and
`LoadInteractionBoundary` into `contracts/internal/**` when those declarations
cross runtime/edit/store/selection/frame/load owners, and migrate all affected
implementation imports in the same unit. For edit/runtime commit delivery,
create one explicit contract-owned delivery seam, for example
`lib/src/contracts/internal/commit_delivery.dart`, containing
`CommitDeliveryResult`, sealed `CommitDeliveryEffect`,
`CommitEffectObserver`, and `CommitApplyResultDelivery`. Move the immutable
`TouchedSet` value into `contracts/internal/**` as the single touched-fact
source used by edit plans and runtime delivery effects.
`CommitDeliveryResult` carries only
`shouldPublishState`, `replacedDocument`, and immutable
`List<CommitDeliveryEffect>`. `TouchedSet` carries only contract/public IDs and
booleans needed by spatial/resource delivery effects; it must not expose store
revision state or callbacks. Edit keeps its mutable `TouchedSetBuilder` and
`StoreRevisionDelta` private. Keep edit-local planning and store-install internals
owned by their current implementation owners: `CommitPlan`, `CommitInstaller`,
`CommitDocumentInstallers`, `CommitApplier`, `TouchedSetBuilder`, and
`StoreRevisionDelta` do not move to contracts and must not be referenced by
`contracts/internal/**`. Create the minimal contract-owned P7 handoff seams in
`contracts/internal/**` without implementing P7 behavior: a resource dirty
outcome value, for example `ResourceDirtyOutcome`, that carries only immutable
contract/public resource identity and dirty/all-dirty flags needed to describe
resource visual dirtiness; and a resolver mutation guard port, for example
`ResolverMutationGuard`, that owns resolver callback entry and runtime mutation
permission checks without importing resource, runtime, frame, cache, or session
owners. These declarations must not create `ResourceKernel`,
`SurfaceResourceSession`, resource caches, frame-budget behavior,
`CanvasRuntime.resources`, public resource commands, or callback execution
logic. P7 later wires these seams to the resource/session implementation; Step
38 only fixes the owner and shape so P7 cannot introduce a resource/runtime/API
cycle.
`RuntimeRoot` must consume contract types and compose store, selection, edit,
diagnostics, and future resource seams without importing API wrappers.
Selection must consume contract-owned facts/membership instead of runtime-owned
ports. Edit/runtime commit collaboration must use contract-owned
effect/apply-result/delivery/observer seams for values that cross from edit
into runtime delivery; edit-local planning and store-install details remain
owned by edit/store unless the implementation performs the split described
above.
Load ordering must use contract-owned `LoadInteractionBoundary` and outcome
seams. Codec must consume public contract DTOs and report diagnostics through
the existing diagnostics route without importing API. Diagnostics must consume
contract-owned diagnostic policy/error/sanitizer declarations without importing
codec, runtime, or API. Add or update
`test/contracts/internal_seam_shape_test.dart` to prove the moved internal seam
shape.

Completion Check:

`rg -n "\\.\\./api/|package:iwb_canvas_engine/src/api" lib/src/runtime lib/src/edit lib/src/store lib/src/selection lib/src/codec lib/src/diagnostics`
prints no matches. `rg -n "\\.\\./runtime/(document_facts_port|frame_facts_port|selection_facts_port|selection_membership_port|load_interaction_boundary|commit_effect_observer)|package:iwb_canvas_engine/src/runtime/(document_facts_port|frame_facts_port|selection_facts_port|selection_membership_port|load_interaction_boundary|commit_effect_observer)" lib/src/runtime lib/src/edit lib/src/store lib/src/selection lib/src/codec lib/src/diagnostics`
prints no matches after those seams move to contracts. `rg -n "\\.\\./edit/(commit_plan|commit_applier)|package:iwb_canvas_engine/src/edit/(commit_plan|commit_applier)" lib/src/store lib/src/selection lib/src/codec lib/src/diagnostics`
prints no matches; any remaining `runtime -> edit` imports must be limited to
the allowed runtime composition path and must not make `contracts/**` import
edit/store planning types.
`rg -n "CommitPlan|CommitInstaller|CommitDocumentInstallers|CommitApplier|TouchedSetBuilder|StoreRevisionDelta|store_revision_delta|lib/src/api|package:iwb_canvas_engine/src/api|\\.\\./api/" lib/src/contracts/internal`
prints no matches. `rg -n "class CommitDeliveryResult|sealed class CommitDeliveryEffect|final class TouchedSet|typedef CommitEffectObserver|typedef CommitApplyResultDelivery" lib/src/contracts/internal`
shows the explicit commit delivery seam declarations.
`rg -n "class ResourceDirtyOutcome|abstract interface class ResolverMutationGuard|runResolverCallback|ensureRuntimeMutationAllowed" lib/src/contracts/internal`
shows the explicit declaration-only P7 handoff seams.
`rg -n "ResourceKernel|SurfaceResourceSession|CanvasRuntime\\.resources|resource cache|frame budget|lib/src/api|package:iwb_canvas_engine/src/api|\\.\\./api/" lib/src/contracts/internal`
prints no matches, proving the P7 handoff declarations did not pull resource
runtime, surface session, frame/cache behavior, or API wrappers into contracts.
`rg -n "CommitApplyResult|CommitEffect" lib/src/runtime lib/src/edit`
shows no cross-owner use of the old edit-owned result/effect payloads; any
remaining uses are private edit implementation details and do not cross into
runtime. `rg -n "export '../contracts/internal|export 'package:iwb_canvas_engine/src/contracts/internal" lib/src/runtime lib/src/edit lib/src/store lib/src/selection lib/src/codec lib/src/diagnostics`
prints no matches, proving the migration did not leave internal shim exports.
`dart test test/contracts/internal_seam_shape_test.dart` passes and proves the
internal seam declarations named above are value-only or interface/typedef-only
contracts with no implementation-owner imports, callbacks only where the
existing seam is explicitly a callback seam, and no store/selection/runtime
state reads hidden behind getters. The same test proves `TouchedSet` is
immutable and contains no `StoreRevisionDelta`, lazy owner reads, or
callback/function fields, and that
`ResourceDirtyOutcome` and `ResolverMutationGuard` are declaration-only P7
handoff seams with no P7 resource runtime implementation. Run
`dart test test/codec/decode_encode_no_runtime_side_effects_test.dart`,
`dart test test/codec/schema_v1/canonical_encode_roundtrip_test.dart`,
`dart test test/edit/edit_matrix_effects_test.dart`,
`dart test test/runtime/load_document_ordering_test.dart`,
`dart test test/runtime/load_document_state_publication_test.dart`,
`dart test test/edit/sync_non_nested_async_stale_test.dart`,
`dart test test/edit/rollback_test.dart`,
`dart test test/selection/runtime_owner_separation_test.dart`,
`dart test test/store/read_document_projection_test.dart`, and
`dart test test/diagnostics/sanitizer_and_public_projection_test.dart`; each
passes with unchanged public expectations. The edit callback tests prove
non-nested synchronous edit callbacks and rollback/reentry surfaces still reject
stale or reentrant mutation attempts without publishing partial runtime state.

Depends On:

Unit 1.

### [x] Unit 3: Public facade compatibility proof

Owner:

Public API facade compatibility.

Boundary:

`lib/src/api/canvas_runtime.dart`, `lib/src/api/canvas_codec.dart`,
`lib/iwb_canvas_engine.dart`, and public API registries/tests. Unit 1 already
converted moved declaration files to wrapper exports; this unit proves the
facade and root barrel still expose the same public contract.

Change:

Keep the root package barrel as the supported consumer surface. Keep
`CanvasRuntime` in `lib/src/api/canvas_runtime.dart` as the public facade over
`RuntimeRoot`, and keep `canvas_codec.dart` as the public codec facade over
schema v1 encode/decode implementation. Ensure public registry/signature/
equality/immutability tests see the same public declarations through the root
barrel after Unit 1's wrapper-export migration.

Completion Check:

`dart test test/api_contract` passes with expected public names and behavior
unchanged, including compile, export completeness, public signature shape,
public type completeness, equality policy, DTO immutability, public registry,
and no-legacy-symbol checks.
`rg -n "contracts/internal" lib/src/api lib/iwb_canvas_engine.dart` prints no
matches. `rg -n "runtime_root.dart|schema_v1_(encoder|decoder).dart" lib/src/api`
prints only the named facade bridge files required by this unit. A public
compile test importing only `package:iwb_canvas_engine/iwb_canvas_engine.dart`
can instantiate/decode/read/edit/load/select using the same public names as
before the migration.

Depends On:

Units 1 and 2.

### [x] Unit 4: Mechanical owner-DAG guardrails

Owner:

Repository guardrail tooling.

Boundary:

`tool/guardrails/**`, guardrail registry/executor entries, guardrail docs
inventory, and guardrail fixture tests under `test/guardrails/**`.

Change:

Add or extend a structural owner-DAG guardrail that scans production import and
export directives by owner prefix and rejects cycles or directive edges outside
the selected DAG. Extend `core.import_boundaries` beyond the Unit 1
wrapper-export allowance so implementation owners cannot import
`lib/src/api/**`, contracts cannot import or export `lib/src/api/**`,
contracts cannot import implementation owners, resources cannot import runtime
or frame, selection cannot import runtime, codec cannot import runtime, store,
edit, or frame, API cannot import or export `contracts/internal/**`, and only
named facade bridges can point from API to runtime or codec implementation.
Update or companion
`api.no_public_api_import_cycles` so wrapper export files and re-exported
`contracts/public/**` declarations are included in the public reachability
proof. Add positive and negative fixtures for import and export directives
without writing fixture-only directives into production sources. The owner-DAG
fixture must be table-driven from the selected DAG owner matrix so adding,
removing, or changing an allowed owner edge changes the expected fixture set in
one place.

Completion Check:

`dart test test/guardrails/import_boundaries_test.dart`,
`dart test test/guardrails/public_api_import_cycles_test.dart`, and
`dart test test/guardrails/owner_dag_import_boundaries_test.dart` pass.
Negative fixture cases fail with the expected guardrail id for `runtime -> api`,
`edit -> api`, `store -> api`, `selection -> runtime`, `codec -> api`,
`diagnostics -> api`,
`diagnostics -> codec`, `diagnostics -> runtime`, `diagnostics -> store`,
`diagnostics -> edit`, `diagnostics -> frame`,
`resources -> runtime`, `resources -> frame`, `edit -> runtime`,
`store -> runtime`, `codec -> runtime`,
`codec -> store`, `codec -> edit`, `codec -> frame`, `contracts -> runtime`,
`contracts -> api`,
`contracts -> edit`, `contracts -> store`, `contracts -> selection`,
`contracts -> codec`, `contracts -> diagnostics`, `contracts -> resources`,
`contracts -> frame`, `contracts -> interaction`, `contracts -> spatial`,
`contracts -> flutter_bridge`, and `api -> contracts/internal` imports or
exports. The fixture set must cover every owner-edge rejected by the selected
DAG, not only the examples listed here; if the implementation represents this
with a table-driven DAG test, the expected signal is one negative case for each
disallowed owner pair and one positive case for each named allowed bridge or
wrapper-export edge.
Positive fixture cases pass for `api` wrapper exports to `contracts/public`,
`api/canvas_runtime.dart -> runtime/runtime_root.dart`, and
`api/canvas_codec.dart -> codec/schema_v1_encoder.dart` /
`schema_v1_decoder.dart`. Running `dart run tool/guardrails/run.dart` reports
no production owner-DAG or import-boundary violations.

Depends On:

Units 1, 2, 3, and 6.

### [x] Unit 5: Architecture graph, diagrams, and durable docs

Owner:

Architecture documentation and generated documentation pipeline.

Boundary:

`docs/architecture/**`, `docs/contracts/**`,
`docs/verification/guardrails.md`,
`docs/verification/guardrail_design_patterns.md`,
`docs/verification/tests.md`,
`docs/implementation/p2_public_api_v1_freeze.md`,
`docs/implementation/p3_schema_v1_dto_validation_and_codec_skeleton.md`,
`docs/implementation/p4_runtime_spine.md`,
`docs/implementation/p6_load_document.md`,
`docs/implementation/p7_resources_and_images.md`,
`docs/implementation/p9_frame_rendering_and_caches.md`,
`docs/implementation/p13_flutter_surface.md`,
`docs/architecture/architecture_graph.yaml`, semantic Mermaid diagrams under
`docs/diagrams/**`, generated graph views under `docs/diagrams/generated/**`,
`docs/_registry/**`, generated indexes/catalogs/context capsules,
`test/architecture_graph/phase_closure_checker_test.dart`, architecture graph
fixtures needed by that test, and any source docs required by the registry
entries.

Change:

Update architecture docs to describe the new contract declaration owner below
the public facade while preserving runtime/store/selection/resource live state
ownership. Update public API, codec, edit, load, and resource docs to say
implementation owners consume contract declarations rather than API wrappers,
without changing public behavior or edit/load sequencing. Update
`docs/verification/guardrails.md` to document owner-DAG enforcement,
implementation-to-API prohibitions, contracts-to-API prohibitions,
contracts-to-implementation prohibitions, wrapper export traversal, and named
facade bridge policy. Update
`docs/verification/guardrail_design_patterns.md` to describe the table-driven
owner-DAG fixture pattern and how positive bridge/export fixtures differ from
negative owner-edge fixtures. Update `docs/verification/tests.md` to inventory
the public root-barrel smoke, API compatibility tests, contract-shape tests,
owner-DAG guardrail tests, and architecture graph forbidden-edge tests.
Update the implementation phase documents that contain stale or affected
ownership language:
`docs/implementation/p2_public_api_v1_freeze.md` for `src/api` DTO placement
and "runtime phases consume public DTOs" wording,
`docs/implementation/p3_schema_v1_dto_validation_and_codec_skeleton.md` for
codec/public DTO ownership,
`docs/implementation/p4_runtime_spine.md` for runtime public state and
`FrameFactsPort` placement,
`docs/implementation/p6_load_document.md` for load validation consuming public
contract DTOs,
`docs/implementation/p7_resources_and_images.md` for resource DTOs,
`CanvasResourcePort`, dirty-resource outcomes, resolver mutation guards,
`FrameFactsPort` descriptor facts, and surface-session placement,
`docs/implementation/p9_frame_rendering_and_caches.md` for frame-facing
`FrameFactsPort` and `SurfaceResourceSession` ownership, and
`docs/implementation/p13_flutter_surface.md` for surface attachment and
`SurfaceResourceSession` ownership. These documents must describe the new
`contracts/public/**`, `contracts/internal/**`, and `resources/**` owners where
the phase remains current source-of-truth; any retained old wording must be
explicitly marked as historical completed-phase context and must point to the
current contract-layer owner. Update `architecture_graph.yaml` with
`contracts.public` and `contracts.internal_ports` nodes, replace
codec/public-DTO edges with codec/contracts edges, add explicit forbidden edges
for every implementation owner to `api.public_surface`, contract nodes to
`api.public_surface`, contract nodes to every implementation owner,
`resource.kernel` and `resource.surface_session` to runtime/frame, selection to
runtime, and codec to runtime/store/edit/frame.
Route P7/P9 resource/session/frame future edges through the
`ResourceDirtyOutcome`, `ResolverMutationGuard`, frame-facts, and resource DTO
contract seams named by this step and by the design.
Update `test/architecture_graph/phase_closure_checker_test.dart` and its
fixtures so architecture graph forbidden-edge proof covers the new contract DAG
without requiring P7 resource runtime implementation.
Update `docs/diagrams/c4_container.mmd`,
`docs/diagrams/c4_component_runtime.mmd`,
`docs/diagrams/c4_code_edit_kernel.mmd`,
`docs/diagrams/dfd_public_edit.mmd`,
`docs/diagrams/dfd_schema_v1_import_encode.mmd`,
`docs/diagrams/seq_schema_v1_import_encode_order.mmd`,
`docs/diagrams/dfd_resource_resolution.mmd`,
`docs/diagrams/seq_resource_resolution.mmd`,
`docs/diagrams/dfd_main_paint_frame.mmd`, and
`docs/diagrams/dfd_cache_invalidation.mmd`, then regenerate generated graph
views and generated documentation outputs.

Completion Check:

`dart run tool/architecture_graph/check.dart --phase P6` passes for the current
implemented phase after the contract-layer graph repair. `dart test test/architecture_graph/phase_closure_checker_test.dart`
passes with fixtures proving the new graph forbidden edges reject
implementation owners to API, contracts to implementation owners, resources to
runtime/frame, selection to runtime, and codec to runtime/store/edit/frame
without requiring P7 resource runtime implementation. `dart run tool/architecture_graph/generate_views.dart --phase P6 --check`
passes after generated graph views are updated according to the repository
selected generated-view phase. `dart run docs/tool/sync_generated_docs.dart --check`
and `dart run docs/tool/check_docs.dart` pass. `rg -n "API owns stable DTOs|codec uses public DTOs|implementation modules import.*api|public API as shared type library" docs`
prints no stale source-of-truth wording except historical plan/design records or
phrasing that explicitly identifies the old shape as retired.
`rg -n "src/api|public DTOs|API owns|Public API owns|FrameFactsPort|SurfaceResourceSession|CanvasResourcePort|ResourceKernel|api.*type|type library" docs/implementation/p2_public_api_v1_freeze.md docs/implementation/p3_schema_v1_dto_validation_and_codec_skeleton.md docs/implementation/p4_runtime_spine.md docs/implementation/p6_load_document.md docs/implementation/p7_resources_and_images.md docs/implementation/p9_frame_rendering_and_caches.md docs/implementation/p13_flutter_surface.md`
has no stale implementation-source wording left unhandled: every match either
uses the new `contracts/public/**`, `contracts/internal/**`, or `resources/**`
ownership, or explicitly marks the statement as historical completed-phase
context and points to the current contract-layer owner.
`rg -n "ResourceKernel|SurfaceResourceSession|CanvasResourcePort|resolver reentrancy|FrameFactsPort" docs/implementation/p7_resources_and_images.md`
shows the P7 source now routes public resource declarations through
`contracts/public/**`, resolver guards and frame facts through
`contracts/internal/**`, and session/cache ownership through `resources/**`.
`rg -n "resolver reentrancy|StateError|no runtime effects|resource visual|public state" docs/implementation/p7_resources_and_images.md`
shows the P7 handoff still requires resolver reentrancy to be rejected through
the contract-owned guard seam with no resource visual revision, no public state
publication, no action/effect emission, and no runtime mutation.
`rg -n "owner-DAG|wrapper export|facade bridge|contracts/internal|contracts/public|implementation-to-api|contracts-to-api" docs/verification/guardrails.md docs/verification/guardrail_design_patterns.md docs/verification/tests.md`
shows the verification docs now cover module-DAG enforcement, public wrapper
export traversal, named facade bridge policy, and the new guardrail/test
inventory.
The graph YAML contains explicit forbidden-edge entries for implementation
owners to API, contracts to API, contracts to implementation owners, resources
to runtime/frame, selection to runtime, and codec to runtime/store/edit/frame.
The graph proof must not substitute an unnamed closure rule for these explicit
forbidden edges. The diagram registry and generated diagram catalog include the
updated semantic diagrams and graph-backed views with no orphaned or missing
diagram entries.

Depends On:

Units 1, 2, 3, and 4.

### [x] Unit 6: Public incremental smoke and behavior preservation

Owner:

Public smoke and focused behavior tests.

Boundary:

`test/smoke/public_incremental_smoke_test.dart` and focused behavior tests for
codec, runtime state publication, edit/load ordering, selection, diagnostics,
and store projection. The smoke remains an external-consumer journey through
the root public barrel only.

Change:

Update the public incremental smoke test so it still proves decode,
`CanvasRuntime`, public state observation, selection, edit, and load through
`package:iwb_canvas_engine/iwb_canvas_engine.dart` after API declarations become
wrapper exports. Keep the existing P6 load step as the public user journey
anchor and adjust the test only by adding root-barrel public reachability checks
needed by the contract migration; do not add private `src/**`, `RuntimeRoot`,
store, projection-cache, frame, spatial, interaction-boundary, or guardrail
probes. Run focused behavior tests to prove the declaration migration did not
change codec schema behavior, edit/load publication ordering, selection results,
store projections, diagnostics sanitization, or public state snapshots.

Completion Check:

`dart test test/smoke/public_incremental_smoke_test.dart` passes, and the
generated consumer source contains only
`package:iwb_canvas_engine/iwb_canvas_engine.dart` for package imports while
covering decode, runtime state, selection, edit, and
`runtime.edits.loadDocument(...)`. `rg -n "src/|RuntimeRoot|DocumentStoreKernel|SelectionKernel|projection|frame|spatial|LoadInteractionBoundary" test/smoke/public_incremental_smoke_test.dart`
prints no matches for private probes in the smoke source. Focused behavior tests
named by Unit 2 plus `dart test test/runtime/runtime_state_publication_test.dart`
and `dart test test/api_contract` pass with unchanged public expectations. The
focused behavior set explicitly covers edit callback rollback/reentry,
post-publication commit effect observers, and load cleanup boundary callback
ordering so every current synchronous callback surface named by the design keeps
its rejection/no-partial-publication behavior.

Depends On:

Units 1, 2, and 3.

### [x] Unit 7: Repository verification and roadmap closure

Owner:

Implementation owner coordinating final verification and plan state.

Boundary:

Repository-level Dart analysis, DCM, guardrail runner, focused test commands,
architecture graph checks, documentation checks, `PLAN.md`, and this step file.

Change:

Run the full verification set required by this mixed code, tooling,
architecture, documentation, diagram, and smoke change. Repair only failures
inside the ownership boundaries established by earlier units. After all checks
pass, mark Step 38 complete in `PLAN.md` and mark Units 1-7 complete in this
step file in the same change.

Completion Check:

Run `dart analyze`, `dcm analyze .`, and `dcm calculate-metrics .` from the
repository root. Run `dart test test/api_contract`,
`dart test test/contracts/contract_declaration_shape_test.dart`,
`dart test test/contracts/internal_seam_shape_test.dart`,
`dart test test/codec/decode_encode_no_runtime_side_effects_test.dart`,
`dart test test/codec/schema_v1/canonical_encode_roundtrip_test.dart`,
`dart test test/edit/edit_matrix_effects_test.dart`,
`dart test test/edit/sync_non_nested_async_stale_test.dart`,
`dart test test/edit/rollback_test.dart`,
`dart test test/runtime/load_document_ordering_test.dart`,
`dart test test/runtime/load_document_state_publication_test.dart`,
`dart test test/runtime/runtime_state_publication_test.dart`,
`dart test test/selection/runtime_owner_separation_test.dart`,
`dart test test/store/read_document_projection_test.dart`,
`dart test test/diagnostics/sanitizer_and_public_projection_test.dart`,
`dart test test/guardrails/import_boundaries_test.dart`,
`dart test test/guardrails/public_api_import_cycles_test.dart`,
`dart test test/guardrails/owner_dag_import_boundaries_test.dart`,
`dart test test/architecture_graph/phase_closure_checker_test.dart`, and
`dart test test/smoke/public_incremental_smoke_test.dart`. Run
`dart run tool/guardrails/run.dart`.
Run `dart run tool/architecture_graph/check.dart --phase P6` and
`dart run tool/architecture_graph/generate_views.dart --phase P6 --check`.
Run `dart run docs/tool/sync_generated_docs.dart --check` and
`dart run docs/tool/check_docs.dart`. Before the implementation is considered
complete, `PLAN.md` shows Step 38 checked and this step document shows Units
1-7 checked.

Depends On:

Units 1, 2, 3, 4, 5, and 6.
