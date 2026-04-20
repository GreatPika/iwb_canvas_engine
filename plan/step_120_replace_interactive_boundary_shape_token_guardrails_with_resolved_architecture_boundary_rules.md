language: english

# Change Contract

## 1. Change Mandate
This change replaces interactive boundary-shape token guardrails with resolved architecture-boundary rules and converts the existing interactive architecture proof test to analyzer-backed structure assertions while preserving the repository’s current invariant-registry proof ownership and the file’s existing marker coverage.

### Program End State
The end state for steps 119 through 126 is one symmetric guardrail architecture: rule families prove semantics through resolved analysis instead of token/lexical heuristics, repeated proof mechanics live in explicit shared support seams, runner ordering and shared state are declared through one inventory, and tool-test scaffolds plus their verification enforcement use canonical owned support seams.

### This Step's Role in the Chain
This step moves the interactive architecture-boundary family onto the target resolved structural form and leaves cross-family shared-engine extraction, declarative runner inventory, and normalized tool-test scaffolds to steps 123 through 126.

## 2. Change Boundary

### Included in the Change
- Retirement of `tool/src/guardrails/rules/interactive/boundary_shape_token_rules.dart` and replacement with a semantic architecture-boundary part file under the existing interactive guardrail runner.
- Removal of the last `resolver_purity_rules.dart` dependency and deletion of `tool/src/guardrails/rules/interactive/resolver_purity_rules.dart` after the semantic architecture rule is wired.
- Analyzer-backed migration of `test/interactive/core/scene_controller_architecture_boundary_test.dart` away from file-string `contains(...)`, `indexOf(...)`, `readAsStringSync()`, and `_extractMethodBody(...)` checks.
- Tool-test updates for the interactive architecture boundary surface.
- `doc/guardrails_state_map.md` updates that reflect the renamed architecture rule and the removal of token/source-order ownership from this family.

### Not Included in the Change
- Root/capability resolver-purity migration from step 118.
- Mutation-owner sequence/routing proof from step 119, including `ensureExternalMutationAllowed(...)` / `interruptForExternalMutation()` ordering and direct `replaceScene(...)` callback-forwarding validation.
- Controller-layer lexical guardrail migration from step 121.
- Runtime feature changes in `lib/src/interactive/**`, `lib/src/view/**`, or `lib/src/contract/scene_view_runtime.dart`.

## 3. Surrounding Code Review

### Inspected Artifacts
- `tool/src/guardrails/rules/interactive/boundary_shape_token_rules.dart` — current monolithic interactive architecture proof surface; reads repository files with `readAsStringSync()` and enforces exact required tokens, banned tokens, and token order over `lib/src/interactive/**`, `lib/src/view/**`, and `lib/src/contract/scene_view_runtime.dart`.
- `tool/src/guardrails/rules/interactive/mutation_boundary_rules.dart` — current interactive guardrail entrypoint; wires `_checkInteractiveBoundaryShape(context)` into `runInteractiveApiGuardrails(...)`.
- `tool/src/guardrails/rules/interactive/resolver_purity_rules.dart` — token helper consumed by the boundary-shape part; becomes dead once the semantic architecture rule is in place.
- `tool/src/guardrails/core/guardrail_runner_support.dart` — repository-native helpers for parsed directive checks, normalized repo-relative paths, layer ownership checks, and residual-file detection.
- `tool/src/guardrails/rules/model/model_architecture_rules.dart` — closest repository precedent for parsed/resolved structure enforcement over a whole source subtree.
- `tool/src/guardrails/rules/contract/contract_architecture_rules.dart` — another repository precedent for architecture-boundary checks backed by AST directives instead of string matching.
- `lib/src/interactive/scene_controller.dart` — `SceneController` owns graph creation, remains the facade, and exposes `sceneControllerViewRuntimeOf(...)`; it must not become `SceneViewRenderState`.
- `lib/src/interactive/internal/scene_controller_graph.dart` — `createSceneControllerGraph(...)` is the assembly owner for interaction, selection, scene, and scene-view runtime owners.
- `lib/src/interactive/internal/scene_controller_interaction_runtime.dart` — owns runtime callbacks and committed-read wiring to `SceneStoreController` spatial helpers and `SceneControllerMutationBoundary` write callbacks.
- `lib/src/interactive/internal/scene_controller_scene_view_runtime.dart` — `SceneControllerSceneViewRuntime` currently implements `SceneViewRuntime` and owns pointer-session creation.
- `lib/src/interactive/internal/scene_controller_pointer_session.dart` — `SceneControllerPointerSession` currently implements `SceneViewPointerSession`.
- `lib/src/contract/scene_view_runtime.dart` — declares the abstract runtime boundary that separates interactive owners from view consumers.
- `lib/src/view/scene_view_runtime_host.dart` — current owner of active runtime swap, pointer-host replacement, and render-surface composition.
- `lib/src/view/scene_view_interactive.dart` — thin public shell that obtains `SceneViewRuntime` from `sceneControllerViewRuntimeOf(controller)` and passes it into `SceneViewRuntimeHost`.
- `lib/src/view/scene_view_render_surface.dart` — render-state-only surface that must remain free of concrete controller ownership.
- `lib/src/interactive/internal/interactive_event_dispatcher.dart`, `interactive_draw_coordinator.dart`, `interactive_draw_eraser_engine.dart`, `interactive_draw_eraser_exact_hit.dart`, `interactive_draw_eraser_line_hit.dart`, `interactive_draw_eraser_projection.dart`, `interactive_draw_eraser_stroke_hit.dart`, and `interactive_selection_actions.dart` — current split owner families that the token rule enforces by exact file text today.
- `test/interactive/core/scene_controller_architecture_boundary_test.dart` — current primary proof file for `INV-ENG-INTERACTIVE-ARCHITECTURE-BOUNDARY`; it is entirely string-backed today.
- `test/tool/guardrails/guardrails_interactive_api_tool_test.dart` plus `test/tool/guardrails/interactive_api/**` — current tool regression harness for deleted residual seams and interactive structure drift; the suite now executes from the existing top-level test file and is physically decomposed into semantic `part` files under `interactive_api/**`.
- `doc/guardrails_state_map.md` — records `boundary_shape_token_rules.dart` as the main AST-migration target and still lists `resolver_purity_rules.dart` as a low-medium reliability rule owner.

### Current Entry Path
- `tool/check_guardrails.dart` -> `tool/src/guardrails/guardrails_runner.dart` -> `runInteractiveApiGuardrails(...)` -> `_checkInteractiveBoundaryShape(context)`.
- `test/interactive/core/scene_controller_architecture_boundary_test.dart` is the separate primary-proof witness for `INV-ENG-INTERACTIVE-ARCHITECTURE-BOUNDARY` and `INV-ENG-VIEW-RENDER-READ-STATE-BOUNDARY`.

### Current Owner
- Interactive architecture-boundary proof is split between `boundary_shape_token_rules.dart` and `scene_controller_architecture_boundary_test.dart`.

### Adjacent Abstractions
- `SceneControllerMutationBoundary` — interactive write owner; architecture proof must not re-own its runtime mutation behavior.
- `SceneViewRuntimeHost` and `SceneViewRenderSurface` — view-layer consumers of the assembled runtime/render-state boundary.
- `sceneControllerViewRuntimeOf(...)` — the only supported facade-to-view bridge.

### Existing Tests
- `test/interactive/core/scene_controller_architecture_boundary_test.dart` — current analyzer-hostile structure witness for the interactive owner split; it is the primary proof file for `INV-ENG-INTERACTIVE-ARCHITECTURE-BOUNDARY` and `INV-ENG-VIEW-RENDER-READ-STATE-BOUNDARY`, and it also carries additional `// INV:` markers that this step must not silently reinterpret as primary-proof ownership.
- `test/tool/guardrails/guardrails_interactive_api_tool_test.dart` — current structural regression harness for interactive guardrails; supporting scenarios now live in `test/tool/guardrails/interactive_api/**` `part` files under the same executable proof surface.

### Analogous Implementation Path
- `tool/src/guardrails/rules/model/model_architecture_rules.dart` — structural subtree checks built from parsed/resolved files.
- `tool/src/guardrails/rules/contract/contract_architecture_rules.dart` — directive-boundary enforcement from AST, not source tokens.
- `tool/src/guardrails/rules/public/public_signature_rules.dart` — resolved element checks for structural boundary leaks.

### Governing Repository Rules
- `AGENTS.md` — code changes must end with `dart run tool/run_verification_preset.dart run --preset=required_code_change --changed-paths-file=<path-or->`.
- `AGENTS.md` — invariant metadata in `tool/invariant_registry.dart` is the source of truth for primary-proof ownership; this step must not silently reassign pointer-semantics or committed-selection-revision primary proofs just because `scene_controller_architecture_boundary_test.dart` currently contains extra `// INV:` markers.
- `doc/guardrails_state_map.md` — the repository already names this family as the main AST migration target and explicitly distinguishes it from the resolved high-reliability families.

### Rejected Misleading Local Patterns
- Exact source-token requirements in `boundary_shape_token_rules.dart` — wrong seam, because they overfit concrete file text, exact import spellings, and statement order instead of semantic owner relationships.
- The current `_extractMethodBody(...)` + `contains(...)` pattern in `scene_controller_architecture_boundary_test.dart` — wrong proof level, because it repeats the same string fragility in the primary proof file.
- Reusing `tool/check_guardrails.dart` as the only architecture witness — wrong proof shape, because the invariant registry already expects an independent primary proof file under `test/interactive/core`.
- Re-homing step-119 mutation-owner sequence/routing proof into this step’s architecture rule or primary proof test — wrong owner, because sequence/order/forwarding stays with `interactive_mutation_owner_guard_rules.dart` while this step owns only architecture-level boundary placement and bypass constraints.

## 4. Architecture

### 4A. Locked Architectural Form

#### Problem Ownership Level
- Structural architecture-boundary guardrail plus independent analyzer-backed structure witness.

#### Selected Architectural Form
- A semantic interactive architecture rule family inside the interactive guardrail runner, paired with analyzer-backed structure assertions in the existing primary-proof test file.

#### Owning Layer or Module
- Tool side: `tool/src/guardrails/rules/interactive/interactive_architecture_boundary_rules.dart` as a `part of 'mutation_boundary_rules.dart';`.
- Test side: `test/interactive/core/scene_controller_architecture_boundary_test.dart`.

#### Dependency Direction
- The tool rule reads parsed/resolved source units through `GuardrailContext`.
- The primary-proof test reads repository source with analyzer APIs directly in the test file.
- Neither side introduces any reverse dependency from runtime code into tool code.

#### State and Data Ownership
- No runtime state changes.
- Structural policy state for interactive architecture lives only in the new `interactive_architecture_boundary_rules.dart` part.
- Deleted residual seam paths remain owned by the tool rule as explicit repository-file facts.

#### Entry and Exit Boundaries
- Entry: parsed/resolved declarations under `lib/src/interactive/**`, `lib/src/view/**`, and `lib/src/contract/scene_view_runtime.dart`.
- Exit: `GuardrailViolation` diagnostics from `runInteractiveApiGuardrails(...)` and analyzer-backed failing assertions in `scene_controller_architecture_boundary_test.dart`.

#### Permitted Extension Seam
- `tool/src/guardrails/rules/interactive/interactive_architecture_boundary_rules.dart` remains the rule-family entrypoint and orchestration owner.
- Category-scoped private `part` files under `tool/src/guardrails/rules/interactive/` are allowed for the step-120 boundary groups when they preserve one clear reason to change per file.
- One private shared-support `part` file under `tool/src/guardrails/rules/interactive/` is allowed for resolved-AST matcher/helpers that would otherwise force every category back into one monolithic file.
- Private analyzer helper code remains local to `test/interactive/core/scene_controller_architecture_boundary_test.dart`.
- Private owner-family spec objects and boundary-category helpers may live inside `interactive_architecture_boundary_rules.dart` only when they are small orchestration data. Category-local checks and generic matcher libraries should not accumulate there once the file stops being cohesive.

#### Rejected Alternatives
- Keep the old filename `boundary_shape_token_rules.dart` after removing token logic — rejected because the file name would become misleading about the proof owner.
- Move all architecture proof into tool tests only — rejected because the invariant registry already depends on an independent primary proof test file.

#### Why This Level Is Correct
- Interactive architecture boundary is already a first-class invariant with both a tool gate and a primary proof test. The correct repair is to migrate both existing proof surfaces to semantic analysis while keeping ownership exactly where the repository already expects it.

## 5. File Map

### Implementation Files
- `tool/src/guardrails/rules/interactive/mutation_boundary_rules.dart`
- `tool/src/guardrails/rules/interactive/interactive_architecture_boundary_rules.dart`
- `tool/src/guardrails/rules/interactive/boundary_shape_token_rules.dart` (delete)
- `tool/src/guardrails/rules/interactive/resolver_purity_rules.dart` (delete)
- `doc/guardrails_state_map.md`

### Test Files
- `test/interactive/core/scene_controller_architecture_boundary_test.dart`
- `test/tool/guardrails/guardrails_interactive_api_tool_test.dart`

### Fixtures and Supporting Data
- `test/tool/support/guardrails_tool_test_support.dart`

### Analysis Area
- `lib/src/interactive/**`
- `lib/src/view/**`
- `lib/src/contract/scene_view_runtime.dart`
- `tool/src/guardrails/rules/interactive/**`

### File Rules
- Every modified implementation file must be tied to a specific slice.
- Every new or modified test must be tied to a specific verification.
- Every new or modified fixture must be tied to a specific verification.
- Every proposed path must follow the global `File naming`.
- Untied changes are out of scope.

## 6. Locked Decisions

1. `boundary_shape_token_rules.dart` is retired. The semantic replacement lives in `interactive_architecture_boundary_rules.dart` as a `part of 'mutation_boundary_rules.dart';`.
2. `resolver_purity_rules.dart` is deleted at the end of this step. No interactive guardrail may keep a raw source-token helper dependency after the semantic architecture rule is wired.
3. Deleted residual seam checks remain explicit file-existence checks owned by the interactive architecture rule; they are not rewritten as token searches.
4. Architecture enforcement must validate semantic owner relationships, forbidden dependency edges, canonical interface/adapter boundaries, and deleted residual seam absence from parsed/resolved analysis. Exact source token order, exact import text, and method-body substring matching are forbidden.
5. `SceneController` remains the interactive facade and graph owner, must keep `sceneControllerViewRuntimeOf(...)` as the facade-to-view bridge, and must not implement `SceneViewRenderState`.
6. `createSceneControllerGraph(...)` remains the assembly owner for `SceneControllerInteractionOwner`, `SceneControllerSelectionOwner`, `SceneControllerSceneOwner`, and `SceneControllerSceneViewRuntime`; view-layer files do not reassemble those owners.
7. `SceneControllerSceneViewRuntime` remains the `SceneViewRuntime` adapter owner, `SceneControllerPointerSession` remains the `SceneViewPointerSession` owner, `SceneViewRuntimeHost` remains the active-runtime and pointer-host owner, and `SceneViewRenderSurface` remains render-state-only.
8. The semantic replacement must cover the complete currently enforced owner/category surface from `boundary_shape_token_rules.dart`: facade, graph assembly, runtime contract, interaction runtime/access/config, mutation-owner shells and boundary, internal-access registration, interaction eligibility policy, scene-view runtime/render-state adapter, pointer session/token, pointer-host/runtime-host/render-surface split, event/draw owner families, draw style, and deleted residual seams.
9. Event and draw-family owners remain structurally split: `InteractiveEventDispatcher`, `InteractiveDrawCoordinator`, `InteractiveDrawEraserEngine`, `InteractiveDrawEraserExactHit`, `InteractiveDrawEraserLineHit`, `InteractiveDrawProjectedEraser`, `InteractiveDrawEraserStrokeHit`, `InteractiveSelectionActions`, and `InteractiveDrawStyle` stay independent owners proved from declarations and allowed dependency boundaries, not from exact source text.
10. Within the mutation-owner/boundary area, this step owns only architecture-level placement and bypass categories inherited from `boundary_shape_token_rules.dart`: interaction-runtime callback routing through `SceneControllerMutationBoundary`, selection/scene mutation-owner and `InteractiveSelectionActions` delegation through `SceneControllerMutationBoundary`, and `SceneControllerMutationBoundary` remaining the canonical scene/selection write owner.
11. Mutation-owner local sequence/routing contracts stay exclusively owned by step 119 and `interactive_mutation_owner_guard_rules.dart`; this step and the primary proof test must not duplicate `ensureExternalMutationAllowed(...)` / `interruptForExternalMutation()` order checks or direct callback-forwarding checks.
12. `test/interactive/core/scene_controller_architecture_boundary_test.dart` remains the primary proof file for `INV-ENG-INTERACTIVE-ARCHITECTURE-BOUNDARY` and `INV-ENG-VIEW-RENDER-READ-STATE-BOUNDARY`; this step must not silently reassign primary-proof ownership for `INV-ENG-VIEW-POINTER-SEMANTICS-BOUNDARY` or `INV-ENG-COMMITTED-SELECTION-REVISION-ALIGNMENT`, even though the file currently carries additional `// INV:` markers.
13. The semantic replacement must be decomposed by boundary category inside `interactive_architecture_boundary_rules.dart` (owner presence, dependency boundary, graph assembly, pointer/runtime split, facade/view split, deleted seam absence). Replacing the token monolith with a single analyzer-backed mega-function is forbidden.
14. Where `guardrail_runner_support.dart` or existing element/path helpers already fit the needed proof shape, the step must reuse them instead of re-implementing equivalent local scans.
15. Step 120 must not end in one monolithic architecture-rule file that mixes rule orchestration, all boundary categories, and the full resolved-matcher helper library. `interactive_architecture_boundary_rules.dart` stays as the entrypoint, but the implementation must be split into category-scoped `part` files plus a shared support `part` once the family no longer fits a cohesive single file.
16. The required decomposition shape for this step is: entrypoint/orchestration, owner-and-residual-seam checks, facade/graph/runtime-view checks, pointer/session/host checks, dependency-and-mutation-boundary checks, draw-family checks, and shared resolved-boundary support. Adjacent categories may share a file only when the resulting file still has one clear reason to change.

## 7. Result Requirements

1. No interactive architecture-boundary enforcement path depends on `requireSourceTokens`, `requireTokenOrder`, raw file-source `readAsStringSync()`, `_extractMethodBody(...)`, or method-body substring matching.
2. Every owner/category currently enforced by `boundary_shape_token_rules.dart` is re-homed into semantic rule logic or the migrated analyzer-backed primary proof; no token-only category is left behind.
3. The interactive guardrail still fails when canonical facade/view/runtime/pointer-session owners disappear, when deleted seams reappear, when pointer/runtime ownership is collapsed, or when the controller/view/render split is reopened.
4. The interactive architecture proof test becomes analyzer-backed, remains independent from `tool/check_guardrails.dart`, and continues to discharge the interactive architecture/render-state proof ownership it already has today without silently rewriting invariant-registry ownership for other invariants.
5. `doc/guardrails_state_map.md` reflects the renamed architecture rule file, the removal of `resolver_purity_rules.dart`, and the fact that this family no longer owns token/source-order proof.
6. Mutation-owner local sequence/routing proof is not duplicated or re-homed here; step 120 owns only the architecture-level mutation-boundary placement/bypass categories listed in the locked decisions.
7. The semantic replacement is organized as small boundary-category checks over shared local specs/helpers rather than as a new monolithic analyzer pass.
8. The semantic replacement remains workable at the file level: category checks live in category files, and reusable resolved matcher/support code does not stay embedded in the same file as every boundary rule.

## 8. Implementation Rules

### Analysis Scope
- Limit structural proof to the interactive/view/runtime owner split and deleted seam absence already covered by the current boundary-shape family.
- Keep runtime feature behavior unchanged.
- Keep invariant proof-file paths unchanged; the proof technique changes, not the proof-file identity.

### Target Verification Units
- `test/tool/guardrails/guardrails_interactive_api_tool_test.dart`
- `test/interactive/core/scene_controller_architecture_boundary_test.dart`

### Protected States, Data, or Structures
- The interactive facade/graph/view-runtime/render-surface owner split.
- Deleted residual seam absence.
- The abstract `SceneViewRuntime` / `SceneViewPointerSession` boundary.
- The view-layer prohibition against concrete controller ownership.

### Allowed Semantic Change Zones
- Interactive architecture rule implementation.
- Interactive architecture proof test implementation.
- Interactive tool-test fixtures and diagnostics that reflect the migrated rule family.
- Documentation of guardrail state for this family.
- Local owner-family and orchestration specs inside `interactive_architecture_boundary_rules.dart`.
- Category-scoped boundary-rule `part` files and one shared resolved-boundary support `part`.

### Structural Enforcement
- Use `checkOwnedLayerFile(...)`, `checkDirectiveBoundaryViolation(...)`, and `checkExternalDirectiveBoundaryFile(...)` for file-level dependency and layer constraints where those helpers already fit the locked form.
- Resolve declaration presence, interface implementation, constructor targets, and top-level function targets from analyzer results rather than from file text.
- Resolve graph assembly by analyzer-backed constructor/top-level invocation targets, not by searching for names in raw source.
- Keep deleted seam absence as repository-file existence checks.
- Cover the complete owner/category surface currently encoded in `boundary_shape_token_rules.dart`; omitting runtime, pointer, eligibility-policy, mutation-shell, or draw-family categories is not allowed.
- For mutation-owner-related files, limit this step to architecture-level boundary placement and bypass proof; local guard/interrupt ordering and direct callback-forwarding remain step-119 concerns and must not be re-proved here.
- Organize the new rule as category-scoped checks over shared local spec data rather than one flat procedure that mixes every owner split inline.
- Keep the entrypoint file small enough to read as the family map: it should orchestrate categories, define small shared specs/constants, and delegate detailed checks plus generic matcher support into focused sibling `part` files.
- Reuse existing support/helpers before adding new local traversal code with the same proof shape.

### Required Test Strategy
- `dart run tool/run_tool_tests.dart test/tool/guardrails/guardrails_interactive_api_tool_test.dart`
- `flutter test test/interactive/core/scene_controller_architecture_boundary_test.dart`
- Negative structural scenarios for reintroduced deleted seams, missing canonical owners, a view file that depends on concrete `SceneController`, a render surface that consumes concrete controller state, pointer-host/runtime ownership drift, mutation-owner direct store/controller bypass, and interaction-eligibility policy leaking back to forbidden model/runtime seams.
- Positive structural scenarios for the current facade/graph/runtime/view arrangement, the current pointer-session ownership split, the current internal-access registration path, and the current event/draw-family owner split.

### Prohibited
- Keeping `boundary_shape_token_rules.dart` after this migration.
- Keeping `resolver_purity_rules.dart` after this migration.
- Importing tool rule implementations into the primary-proof test file.
- Raw source token or substring matching in the new architecture rule or in the migrated primary-proof test.
- Requiring exact statement order or exact import text as the architecture proof.
- A single analyzer-backed mega-function that encodes all interactive architecture categories inline after the token monolith is retired.

### Optional: Recognition Forms That Must Be Supported
- `SceneControllerSceneViewRuntime implements SceneViewRuntime`.
- `SceneControllerPointerSession implements SceneViewPointerSession`.
- `SceneViewInteractive` obtaining `SceneViewRuntime` from `sceneControllerViewRuntimeOf(controller)` and passing it into `SceneViewRuntimeHost`.
- `SceneViewRenderSurface` consuming `SceneViewRenderState` without concrete `SceneController` ownership.
- `createSceneControllerGraph(...)` assembling the canonical owner family.

### Optional: Allowed Forms That Are Not Violations
- Internal statement reordering that preserves the same semantic graph assembly and owner relationships.
- Import ordering changes that preserve the same dependency graph.
- Local helper extraction inside the same owner file when the semantic owner and dependency boundaries remain unchanged.

### Optional: Resolution Rules
- Declaration presence must be proved from AST/resolved declarations, not from file-system name alone.
- Constructor and top-level function connections must be proved from resolved invocation targets.
- A dependency violation is determined from parsed directives and normalized repo-relative paths, not from import-text substring matching.

## 9. Vertical Slices

### Slice 1. [x] Semantic interactive architecture rule family replaces token-boundary checks

#### Slice Contract
Interactive architecture boundary violations are emitted from semantic rule logic in `interactive_architecture_boundary_rules.dart`, not from `boundary_shape_token_rules.dart` token checks.

#### Change
- Create `interactive_architecture_boundary_rules.dart` as the `part of 'mutation_boundary_rules.dart';` owner for the migrated architecture rule family.
- Port the complete currently enforced owner/category surface from `boundary_shape_token_rules.dart` into semantic checks over declarations, interfaces, resolved constructor targets, and dependency directives.
- Rewire `runInteractiveApiGuardrails(...)` to call the new semantic rule and stop referencing the retired token rule file.
- Introduce local owner-family and boundary-category specs so migrated categories share proof scaffolding instead of landing as unrelated inline checks.

#### Behavioral Verification
- `dart run tool/run_tool_tests.dart test/tool/guardrails/guardrails_interactive_api_tool_test.dart`
- Tool sandbox scenario that passes with the current canonical interactive/view/runtime owner split.

#### Structural Verification
- Tool sandbox scenarios that fail when a canonical owner disappears, when pointer/runtime ownership drifts, when mutation shells or selection actions bypass the boundary owner, or when a deleted residual seam file is reintroduced.

#### Fixtures Used
- `test/tool/support/guardrails_tool_test_support.dart`

#### Positive Scenarios
- The canonical owner family remains accepted without relying on source-text layout.
- Deleted residual seams remain absent and continue to fail fast when reintroduced.

#### Negative Scenarios
- Missing `SceneControllerSceneViewRuntime`, `SceneControllerPointerSession`, or `SceneViewRuntimeHost` ownership fails.
- Reintroduced deleted seam files fail.

#### Closure Evidence
- Green run of the listed behavioral verification.
- Green run of the listed structural verification.
- No call site in `mutation_boundary_rules.dart` references `boundary_shape_token_rules.dart` after the new rule is wired.

### Slice 2. [x] Semantic view/runtime/render-surface boundary proof

#### Slice Contract
The migrated tool rule proves the locked facade/graph/view-runtime/render-surface split from analyzer-backed owner relationships and dependency boundaries.

#### Change
- Add semantic checks that `SceneController` stays a facade and graph owner, `createSceneControllerGraph(...)` stays the canonical assembly path, `SceneControllerSceneViewRuntime` remains the `SceneViewRuntime` adapter owner, `SceneViewRuntimeHost` remains the runtime swap owner, and `SceneViewRenderSurface` remains render-state-only.
- Replace any token-based draw/event owner checks with declaration-presence and dependency-boundary checks against the locked owner set.

#### Behavioral Verification
- `dart run tool/run_tool_tests.dart test/tool/guardrails/guardrails_interactive_api_tool_test.dart`
- Tool sandbox scenario that passes with the current `sceneControllerViewRuntimeOf(controller)` bridge and render-state-only surface.

#### Structural Verification
- Tool sandbox scenarios that fail when a view file depends on concrete `SceneController`, when `SceneController` implements `SceneViewRenderState`, or when `SceneViewRenderSurface` takes a concrete controller owner.

#### Fixtures Used
- `test/tool/support/guardrails_tool_test_support.dart`

#### Positive Scenarios
- Current facade-to-view runtime bridge passes.
- Current view-runtime host and render-surface boundary passes.

#### Negative Scenarios
- Concrete controller leakage into `view/**` fails.
- `SceneController` becoming `SceneViewRenderState` fails.
- Missing canonical assembly through `createSceneControllerGraph(...)` fails.

#### Closure Evidence
- Green run of the listed behavioral verification.
- Green run of the listed structural verification.
- Diagnostics identify the violated owner or dependency boundary instead of a missing source token.

### Slice 3. [ ] Analyzer-backed primary architecture proof test

#### Slice Contract
`test/interactive/core/scene_controller_architecture_boundary_test.dart` proves the interactive architecture boundary from analyzer-backed structure assertions and no longer depends on raw file text.

#### Change
- Replace the current `File.readAsStringSync()`, `_extractMethodBody(...)`, `contains(...)`, and `indexOf(...)` assertions in `scene_controller_architecture_boundary_test.dart` with analyzer-backed structure assertions that inspect the same locked owner relationships.
- Keep the test file as the primary proof path named in the invariant registry.
- Keep test-local analyzer helpers private to the test file.

#### Behavioral Verification
- `flutter test test/interactive/core/scene_controller_architecture_boundary_test.dart`

#### Structural Verification
- The test must fail when the canonical owner split or concrete-controller view leak is reintroduced.

#### Fixtures Used
- None.

#### Positive Scenarios
- Current interactive/view/runtime structure passes from analyzer-backed assertions.
- The test remains independent from `tool/check_guardrails.dart`.

#### Negative Scenarios
- Reintroduced concrete-controller dependency in `view/**` fails.
- Missing `SceneViewRuntime` or `SceneViewPointerSession` owner implementation fails.
- Reintroduced deleted seam file fails.

#### Closure Evidence
- Green run of the listed behavioral verification.
- Green run of the listed structural verification.
- The test file contains no raw source-text architecture assertions after migration.

### Slice 4. [ ] Token helpers are retired and repository state map is updated

#### Slice Contract
The old token-helper files are removed, and repository documentation names the semantic architecture rule as the active owner.

#### Change
- Delete `tool/src/guardrails/rules/interactive/boundary_shape_token_rules.dart`.
- Delete `tool/src/guardrails/rules/interactive/resolver_purity_rules.dart` after its final call site is gone.
- Update `doc/guardrails_state_map.md` so the file map, reliability notes, and next-step notes reflect the semantic architecture rule family and the removal of the token helpers.

#### Behavioral Verification
- `dart run tool/run_tool_tests.dart test/tool/guardrails/guardrails_interactive_api_tool_test.dart`
- `flutter test test/interactive/core/scene_controller_architecture_boundary_test.dart`

#### Structural Verification
- `dart run tool/run_verification_preset.dart run --preset=required_code_change --changed-paths-file=<path-or->`

#### Fixtures Used
- `test/tool/support/guardrails_tool_test_support.dart`

#### Positive Scenarios
- The tool and primary-proof test both pass with the semantic architecture rule in place.
- Documentation names the new rule file and no longer lists the deleted token helpers as active owners.

#### Negative Scenarios
- Any remaining reference to the deleted token-helper files fails repository verification.
- Documentation does not claim that clone/metrics meta-control is solved by this step; it records only the completed architecture-rule migration.

#### Closure Evidence
- Green run of the listed behavioral verifications.
- Green run of the listed structural verification.
- Deleted token-helper files are absent from the tree.

## 10. Final Verification

- `dart run tool/run_tool_tests.dart test/tool/guardrails/guardrails_interactive_api_tool_test.dart`
- `flutter test test/interactive/core/scene_controller_architecture_boundary_test.dart`
- `dart run tool/run_verification_preset.dart run --preset=required_code_change --changed-paths-file=<path-or->`

## 11. Acceptance Criteria

- The change mandate is satisfied.
- The surrounding code review records actual repository evidence.
- The architectural form is explicit, justified, and locked at the correct level.
- No material architectural choice remains to the implementing agent.
- Result requirements are satisfied.
- Implementation rules are satisfied.
- Mandatory slices are closed.
- Final verification has passed.
