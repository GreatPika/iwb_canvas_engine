# Change Contract

## Goal

App-owned image resolver failures must degrade only the affected resource to a
bounded placeholder while the rest of the frame continues to bind and paint.
Runtime resolver-guard violations must remain fail-fast `StateError` failures so
contract-breaking reentrant mutations are not hidden as asset misses.

## Source Inputs

- Design: none
- Research: none
- Phase: none
- PLAN: `PLAN.md`
- Other: PM requirement from current conversation: "RESOURCE-001: a throwing
  app-owned image resolver must not abort binding for the whole frame; the
  affected image degrades to a bounded placeholder, other resources continue,
  resolver guard violations still fail fast, and no old design or research
  artifact is the review baseline."

## Classification

Profile: Boundary-owned defect containment

Obligations: Boundary-Owned Policy; Temporal Surface Closure; All-Or-Nothing
Failure Boundary; Negative Proof And Fixture Quarantine; Source-Of-Truth
Singularity; Compatibility Preservation.

## Decision Trace

| Source decision | Contract location | Execution unit / proof surface |
|---|---|---|
| `RESOURCE-001`: one throwing app image resolver must not abort binding for the full asset set. | `Boundaries.Owner`, `Boundaries.In Scope`, `Unit 4` | `PaintAssetBindingService.bind` fixture with one throwing resource and one resolvable resource returns both bounded placeholder and resolved image. |
| Current implementation has one production app-image resolver boundary in `SurfaceResourceSession`; caller-level catches would patch symptoms. | `Boundaries.Owner`, `Boundaries.Order Constraints`, `Unit 3` | `SurfaceResourceSession.resolveImage` catches ordinary app resolver exceptions at `_resolveThroughResolver` and returns a resource-owned placeholder outcome. |
| Runtime resolver guard violations are contract failures, not missing assets. | `Boundaries.Compatibility`, `Unit 1`, `Unit 4` | Reentrant resource resolver tests continue to observe `throwsStateError` and no document, selection, cache, repaint, or action mutation. |
| A plain `StateError` cannot identify guard violations because ordinary app resolvers may throw `StateError`. | `Boundaries.In Scope`, `Unit 1`, `Unit 3` | `resolver_mutation_guard.dart` owns a shared internal marker that remains a `StateError` subtype; `SurfaceResourceSession` rethrows it while ordinary `StateError` from app resolver becomes exception placeholder. |
| Resource/session protection is not currently a `DiagnosticsHub` writer. | `Boundaries.Out of Scope`, `Boundaries.Source of Truth`, `Unit 5` | Resource contract update preserves no `DiagnosticsHub` write for resolver exception placeholders; diagnostics routing table is not broadened. |
| Placeholder result states are explicit resource-owned types and shape-guarded. | `Boundaries.Source of Truth`, `Unit 2`, `Unit 6` | Resource resolver adapter shape test includes the new resolver-exception placeholder result type. |

## Evidence

- `lib/src/resources/surface_resource_session.dart:44` / resolver boundary: `resolveImage` owns dropped-session, missing descriptor, cache, absent resolver, null suppression, budget, and final resolver-call ordering -> exception containment belongs in this owner before frame callers receive a result.
- `lib/src/resources/surface_resource_session.dart:146` / app callback: `_resolveThroughResolver` invokes `resolver.resolveImage` through `runResolverCallback` without a catch -> ordinary app exceptions currently escape the resource boundary.
- `lib/src/frame/paint_asset_binding_service.dart:39` / frame binding caller: `bind` directly stores `session.resolveImage` results for each unique resource id -> a thrown resolver aborts the binding loop unless the session returns a result.
- `lib/src/frame/main_frame_asset_images.dart:11` / painter input projection: only `ResolvedResourceImage` entries become `ui.Image` bindings -> a new placeholder subtype will naturally paint through the existing bounded fallback path.
- `lib/src/runtime/runtime_root.dart:1424` / dispose guard: dispose during a resolver callback records reentrant rejection and throws `StateError` -> guard failures must remain observable failures rather than resource placeholders.
- `lib/src/runtime/runtime_root.dart:1454` / resolver callback guard: nested resolver callbacks currently throw `StateError` while the active callback flag is cleared in `finally` -> marker typing must preserve existing fail-fast and cleanup behavior.
- `lib/src/runtime/runtime_root.dart:1472` / mutation guard: public runtime mutation during resolver callback records reentrant rejection and throws `StateError` -> containment must not hide contract-breaking mutation attempts.
- `lib/src/contracts/internal/resolver_mutation_guard.dart:1` / internal seam: both resolver callback execution and mutation allowance already share this contract -> the guard marker type belongs in this seam so runtime can throw it and resources can rethrow it without importing runtime.
- `docs/architecture/02_package_boundaries.md:303` / package boundary: `lib/src/resources/**` may not import runtime or other non-resource owners -> `SurfaceResourceSession` cannot depend on a runtime-owned marker type.
- `test/guardrails/import_boundaries_test.dart:427` / import guardrail: resource session code cannot import runtime, store, frame, surface, interaction, diagnostics, or IO owners -> the marker type must stay in an allowed internal contract seam.
- `test/guardrails/owner_dag_import_boundaries_test.dart:1138` / owner DAG guardrail: resources to runtime is a required forbidden edge -> the implementation must not solve marker sharing by adding a resources-to-runtime dependency.
- `lib/src/resources/resource_resolver_adapter.dart:59` / result model: `ResourceImageResolveResult` has explicit resolved and placeholder subclasses -> adding an exception placeholder changes this source-owned result vocabulary.
- `test/resources/resource_resolver_adapter_shape_test.dart:65` / shape guard: current result subclasses are enumerated structurally -> the new placeholder type needs an explicit shape proof.
- `docs/contracts/resources.md:246` / resource contract: unresolved resources paint bounded placeholders and normal placeholder painting does not write `DiagnosticsHub` -> resolver exception placeholder semantics belong in this source of truth.
- `docs/contracts/diagnostics.md:88` / diagnostics routing: resource/session protection is classified as not a `DiagnosticsHub` write -> this step must not add a diagnostics route for resolver exceptions.

## Boundaries

Owner: `SurfaceResourceSession` owns image resolver exception containment and
resource placeholder outcome selection. `resolver_mutation_guard.dart` owns the
shared internal resolver-guard marker type. `RuntimeRoot` owns throwing that
marker from resolver guard rejection paths. `resource_resolver_adapter.dart`
owns the explicit result vocabulary.

In Scope:

- Add an internal resolver-guard rejection marker that remains a `StateError`
  subtype and is thrown by runtime resolver guard paths.
- Add an explicit resource-owned resolver-exception placeholder result.
- Catch ordinary app image resolver `Object` failures inside
  `SurfaceResourceSession._resolveThroughResolver`, rethrow guard marker
  failures, and return the new bounded placeholder for ordinary failures.
- Preserve resolver-call budget accounting for attempted resolver calls.
- Preserve cache policy: exception placeholders are not written as resolved,
  null, missing, or durable cross-frame cache entries.
- Preserve null-result same-frame suppression only for actual null resolver
  returns, not thrown exceptions.
- Update focused tests and the resource contract source of truth for the new
  resolver exception placeholder behavior.

Out of Scope:

- No `PaintAssetBindingService`, `FrameEngine`, `CanvasSurface`, or painter
  caller-level exception catch as the primary fix.
- No new `DiagnosticsHub` route, public diagnostics stream, logging surface, or
  public API exposure for resolver exceptions.
- No async resolver support, asset bundle loading, file IO, remote loading, or
  resolver retry scheduler.
- No reinterpretation of selected-move resolver exception behavior.
- No review baseline from historical `.design` or `.research` artifacts.

Source of Truth: `SurfaceResourceSession` is the behavioral source of truth for
resource resolver outcomes; `resolver_mutation_guard.dart` is the shared
internal source of truth for resolver callback guard typing;
`resource_resolver_adapter.dart` is the type vocabulary source of truth;
`docs/contracts/resources.md` is the stable documentation source for resolver
placeholder semantics. `docs/contracts/diagnostics.md` continues to own the
absence of a DiagnosticsHub route.

Compatibility: Public `CanvasResourceResolver.resolveImage` remains synchronous
and returns `ui.Image?`. Public reentrant resolver violations remain observable
as `StateError`. Existing placeholder painting remains bounded by image record
paint bounds. Existing resolved-image cache behavior and app-owned `ui.Image`
lifetime remain unchanged.

Order Constraints:

1. Establish guard-error typing before catching ordinary resolver exceptions so
   `SurfaceResourceSession` can distinguish contract violations from asset
   failures without message matching.
2. Extend the resource result vocabulary before returning the new placeholder
   from `SurfaceResourceSession`.
3. Implement session containment before frame-binding proof so the proof tests
   the owner boundary rather than a caller catch.
4. Update source-of-truth docs after behavior and proof surfaces are defined.

## Execution Units

### [x] Unit 1: Shared guard marker

Owner: `ResolverMutationGuard` internal contract and `RuntimeRoot`.

Boundary: Internal-only error classification shared by the runtime guard owner
and resource session owner without a resources-to-runtime dependency.

Change: Add an internal resolver-callback rejection `StateError` subtype for
runtime guard failures in `resolver_mutation_guard.dart`, then use it in the
`RuntimeRoot` resolver guard rejection paths that currently throw plain
`StateError`.

Completion Check: Internal seam shape proof shows the marker type is declared in
`resolver_mutation_guard.dart`, not in runtime. Focused behavior tests prove
that every protected runtime resolver guard path throws a `StateError`-compatible
marker failure: nested resolver callback through `runResolverCallback`, public
runtime mutation through `ensureRuntimeMutationAllowed`, and `dispose` during a
resolver callback. The proof must include resource resolver coverage for the
nested callback and public mutation paths, plus a dispose-during-resolver
callback coverage path, and must retain no-mutation assertions for document,
selection, cache, repaint, or action state where the existing reentrancy fixtures
own those assertions.

Depends On: none

### [x] Unit 2: Resource exception placeholder outcome

Owner: Resource resolver adapter.

Boundary: Resource-owned `ResourceImageResolveResult` vocabulary.

Change: Add a `ResolverExceptionResourceImagePlaceholder` result subtype under
`ResourceImagePlaceholderResult`.

Completion Check: The resource adapter shape test proves that
`ResolverExceptionResourceImagePlaceholder` is part of the explicit resource
result vocabulary and remains a placeholder subtype rather than a resolved image
or public resolver API change.

Depends On: none

### [x] Unit 3: Session-owned exception containment

Owner: `SurfaceResourceSession`.

Boundary: Synchronous app image resolver callback invoked by
`_resolveThroughResolver`.

Change: Catch ordinary `Object` failures thrown by app
`CanvasResourceResolver.resolveImage`, rethrow the internal guard marker, and
return `ResolverExceptionResourceImagePlaceholder` with the request's
`placeholderBounds`. Do not cache exception placeholders, do not add them to
same-frame null suppression, and keep resolver-call budget consumption for the
attempted callback.

Completion Check: Focused resource-session tests prove all direct outcomes:
ordinary app resolver throwing plain `StateError` returns
`ResolverExceptionResourceImagePlaceholder` with bounded request geometry;
ordinary app resolver throwing a non-`StateError` `Object` also returns
`ResolverExceptionResourceImagePlaceholder`; runtime guard marker failures from
nested resolver callback and public runtime mutation still bubble as
`throwsStateError` instead of becoming placeholders; a second resource in the
same frame can still resolve to `ResolvedResourceImage`; a later frame retries
the throwing resource instead of reading a cached placeholder; null-result
suppression behavior remains limited to actual null returns; resolver budget
behavior still counts attempted callbacks.

Depends On: Units 1 and 2

### [x] Unit 4: Frame binding continuation proof

Owner: `PaintAssetBindingService` test surface, with production behavior still
owned by `SurfaceResourceSession`.

Boundary: Frame asset binding loop over unique render-record resource ids.

Change: Add focused frame-binding coverage that exercises one ordinary throwing
image resolver entry and one normally resolved entry through
`PaintAssetBindingService.bind`. Do not add a frame-layer catch.

Completion Check: The frame-binding test observes a completed
`FrameAssetBindings` map when one app resolver branch throws plain `StateError`,
containing a `ResolverExceptionResourceImagePlaceholder` for the failing
resource and `ResolvedResourceImage` for the healthy resource. The same test or
an adjacent existing reentrancy test proves runtime guard marker failures from a
runtime mutation inside the resolver and from nested resolver callback still
bubble as `throwsStateError`, never become frame asset placeholders, and leave
runtime state unchanged. `FrameEngine.buildMainFrameWithAssetBindings` coverage
may be added as adjacent coverage, but it does not replace the required
`PaintAssetBindingService.bind` proof seam.

Depends On: Unit 3

### [x] Unit 5: Resource contract and diagram alignment

Owner: Resource contract documentation and any current resource-resolution
diagram that explicitly enumerates resolver outcomes.

Boundary: Stable repository source of truth for resolver placeholder semantics,
not task-progress notes.

Change: Update `docs/contracts/resources.md` to define resolver exception
placeholder behavior: bounded placeholder, no cache write, no null suppression,
ordinary resolver retry remains possible on later frames, and no
`DiagnosticsHub` write. Update current resource-resolution diagrams only where
they explicitly model sync resolver outcomes and would otherwise contradict the
new behavior.

Completion Check: Documentation checks pass after the source-of-truth update:
`dart run docs/tool/sync_generated_docs.dart --check` and
`dart run docs/tool/check_docs.dart`. Direct diagram proof also passes: bounded
search or file inspection over `docs/diagrams/seq_resource_resolution.mmd`,
`docs/diagrams/state_resource_resolution.mmd`, and
`docs/diagrams/seq_main_paint.mmd` shows resolver-exception placeholder behavior
is represented anywhere those diagrams enumerate synchronous resolver outcomes,
and no stale `ui.Image or null`-only outcome wording remains in those resolver
outcome branches. If generated-docs check reports stale output, implementation
must run the sync command, review the generated diff, and rerun both checks.

Depends On: Unit 3

### [x] Unit 6: Full verification for resource resolver containment

Owner: Verification surface for changed production, tests, and docs.

Boundary: Repository-required checks for Dart code, DCM, focused behavior tests,
and documentation.

Change: Run focused tests covering resource session containment, frame asset
binding continuation, resolver reentrancy preservation, and resource result
shape. Run repository-required code and docs checks for the changed owners.

Completion Check: The implementation report names the exact focused tests and
commands that passed: `dart analyze`, `dcm analyze .`, `dcm calculate-metrics`
for changed production/test scopes including `lib/src/resources`,
`lib/src/runtime`, `lib/src/contracts/internal`, `test/resources`, and
`test/frame`, plus the documentation checks from Unit 5. Any unavailable check
is reported with the exact command, failure reason, and impacted manual
verification gap.

Implementation Report:

- Passed: `dart test test/resources/resolver_exception_placeholder_test.dart`
- Passed: `dart test test/frame/paint_asset_binding_service_test.dart`
- Passed: `dart test test/resources/resolver_reentrancy_rejected_test.dart`
- Passed: `dart test test/resources/resource_resolver_adapter_shape_test.dart`
- Passed: `dart test test/contracts/internal_seam_shape_test.dart`
- Passed: `dart analyze`
- Passed: `dcm analyze .`
- Passed: `dcm calculate-metrics lib/src/resources lib/src/runtime lib/src/contracts/internal test/resources test/frame`
- Passed: `dart run docs/tool/sync_generated_docs.dart --check`
- Passed: `dart run docs/tool/check_docs.dart`
- Unavailable checks: none.

Depends On: Units 1, 2, 3, 4, and 5
