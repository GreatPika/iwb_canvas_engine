# Change Contract

## Goal

Long eraser gestures use one interaction-owned bounded retained corridor, publish immutable visual-only move previews without repeated geometry reads, perform exactly one bounded terminal evaluation with existing all-or-nothing and delivery semantics, preserve public declarations and exports while documenting the intentional approximation, and prove every performance claim through deterministic owner-level counters without introducing a second trajectory, public seam, profile-route acceptance, benchmark system, timing proxy, or displaced unbounded work.

## Source Inputs

| Category | Source ID | Location or authority |
| --- | --- | --- |
| Design | `eraser-corridor-hot-path-design` | docs/planning/designs/2026-08-27-eraser-corridor-hot-path.md |
| Research | `eraser-context-action-research` | docs/history/research/2026-06-02-p12-eraser-context-action-request.md |
| PLAN | none | none |
| Other | `prior-eraser-design` | docs/history/designs/2026-08-24-deletion-eraser-and-selection-policies.md |
| Other | `user-request` | user request |
| Other | `repository-instructions` | AGENTS.md |
| Other | `package-boundaries` | docs/architecture/02_package_boundaries.md |
| Other | `eraser-capture-owner` | lib/src/interaction/eraser_machine.dart |
| Other | `eraser-route-owner` | lib/src/interaction/interaction_engine.dart |
| Other | `interaction-read-boundary` | lib/src/interaction/interaction_read_port.dart |
| Other | `runtime-eraser-read-owner` | lib/src/runtime/runtime_interaction_read_adapter.dart |
| Other | `geometry-policy-owner` | lib/src/geometry/geometry_policy.dart |
| Other | `exact-hit-owner` | lib/src/geometry/hit_test_policy.dart |
| Other | `public-preview-declaration` | lib/src/contracts/public/canvas_preview.dart |
| Other | `frame-drawable-owner` | lib/src/frame/frame_drawable_policy.dart |
| Other | `validation-limits-contract` | docs/contracts/validation_limits.md |
| Other | `geometry-contract` | docs/contracts/geometry.md |
| Other | `interaction-contract` | docs/contracts/interaction_engine.md |
| Other | `eraser-commit-sequence` | docs/diagrams/seq_eraser_commit.mmd |
| Other | `eraser-budget-sequence` | docs/diagrams/seq_eraser_exact_budget.mmd |
| Other | `eraser-state-diagram` | docs/diagrams/state_eraser.mmd |
| Other | `test-proof-owner` | docs/verification/tests.md |
| Other | `performance-route-exclusion-source` | docs/verification/performance.md |
| Other | `interaction-guardrail-owner` | tool/guardrails/src/interaction_guardrail_checks.dart |
| Other | `geometry-guardrail-owner` | tool/guardrails/src/geometry_spatial_guardrail_checks.dart |
| Other | `interaction-guardrail-proof` | test/guardrails/interaction_guardrail_enforcement_test.dart |
| Other | `interaction-cleanup-adr` | architecture/decisions/ADR-0009-interaction-tool-machines-and-cleanup.md |
| Other | `public-api-contract` | docs/contracts/public_api_v1.md |
| Other | `public-action-declaration` | lib/src/contracts/public/canvas_actions.dart |
| Other | `overlay-preview-planner` | lib/src/frame/overlay_preview_planner.dart |
| Other | `overlay-painter` | lib/src/surface/overlay_painter.dart |
| Other | `diagnostics-read-port-consumer` | test/diagnostics/fixtures/interaction_diagnostics_fixture.dart |
| Other | `eraser-overflow-read-port-consumer` | test/geometry/fixtures/eraser_exact_budget_no_partial_commit_fixture.dart |
| Other | `eraser-routing-read-port-consumer` | test/interaction/fixtures/eraser_context_action_routing_fixture.dart |
| Other | `stale-text-read-port-consumer` | test/interaction/fixtures/text_edit_stale_commit_guard_fixture.dart |
| Other | `pointer-session-read-port-consumer` | test/interaction/pointer_session_test.dart |
| Other | `pointer-session-owner` | lib/src/interaction/pointer_session.dart |
| Other | `eraser-commit-intent-owner` | lib/src/interaction/interaction_runtime_intents.dart |
| Other | `runtime-delivery-owner` | lib/src/runtime/runtime_root.dart |
| Other | `runtime-action-finalizer` | lib/src/runtime/runtime_action_finalizer.dart |
| Other | `internal-action-intent-owner` | lib/src/contracts/internal/commit_action_intent.dart |
| Other | `terminal-resolver-proof-owner` | test/interaction/fixtures/terminal_eraser_deletion_resolver_fixture.dart |
| Other | `public-export-registry` | docs/_registry/public_api_v1.yaml |
| Other | `root-public-barrel` | lib/iwb_canvas_engine.dart |
| Other | `public-api-guardrail-owner` | tool/guardrails/src/public_api_checks.dart |
| Other | `executable-validation-limit-owner` | lib/src/contracts/public/canvas_contract_limits.dart |

## Classification

Profile: `BEHAVIOR_CHANGE`
Obligations: `PUBLIC_API_CHANGE`, `SEAM_MIGRATION`, `SEQUENCED_MIGRATION_AND_RETIREMENT`, `TEMPORAL_SURFACE_CLOSURE`, `ALL_OR_NOTHING_FAILURE_BOUNDARY`, `SOURCE_OF_TRUTH_SINGULARITY`, `WORK_BUDGET_CLOSURE`

## Decision Trace

| Decision ID | Independent failure family | Source decision | Contract location | Acceptance or evidence target |
| --- | --- | --- | --- | --- |
| `bounded-capture-work` | Move capture or storage can still grow with the unbounded admitted prefix or copy the retained prefix on every append. | R-001, R-002, D-001, and A-001 require one bounded mutable retained corridor and direct deterministic work evidence. | Unit 2; Work Budget And Cost Displacement; Matrix | `bounded-capture-work-evidence` |
| `retained-approximation` | Resampling can violate the 8000-to-4000 uniform-index endpoint policy or terminal/action consumers can use a different corridor. | R-002, D-001, and A-002 make the retained approximation the preview, terminal geometry, and point-count truth with explicit miss/false-positive cost. | Unit 2; Source of Truth; Matrix | `retained-approximation-evidence` |
| `visual-only-moves` | Move handling can retain preview reads or hidden geometry work while final preview output remains correct. | R-004, D-002, and A-003 retain only the initial one-point read and make admitted moves visual-only after append/resample. | Unit 3; Temporal Surface Closure; Matrix | `visual-only-move-evidence` |
| `public-surface-compatibility` | Public declarations or exports can drift even when existing consumers still compile. | R-003, D-003, and A-004 keep both public declaration shapes and the canonical export closure unchanged while changing semantic meaning only in the public contract. | Unit 2; Compatibility; Matrix | `public-surface-compatibility-evidence` |
| `preview-seam-consumer-closure` | A current read-port implementation, direct consumer, or negative guardrail can retain stale move-call expectations or be omitted by a copied inventory. | R-007, D-003, and A-005 derive closure from the owning interface and repository call sites while retaining the immutable initial/direct seams and existing guardrails. | Unit 3; Order Constraints; Matrix | `preview-seam-consumer-evidence` |
| `dependency-scope-containment` | Mutable capture, upward dependencies, restored benchmarks, or another excluded abstraction can hide outside behavioral fixtures. | R-005, R-008, D-001, D-004, and A-006 preserve current owner direction and prohibit the excluded surfaces. | Unit 3; Out of Scope; Matrix | `dependency-scope-evidence` |
| `semantic-document-parity` | Maintained contracts or diagrams can continue to promise full original coverage, move-time exact reads, or incorrect terminal finality. | I-002 and A-007 require every named semantic owner to describe the same retained-corridor lifecycle and distinct failure phases. | Units 2-3; Matrix | `semantic-document-parity-evidence` |
| `proof-admission-closure` | Independent new or extended proof families can be merged, proxy-owned, or added without durable admission. | R-007, I-003, and A-008 require separate admissions in `docs/verification/tests.md` before proof artifacts change. | Unit 1; Matrix | `proof-admission-closure-evidence` |
| `single-terminal-pass` | Pointer-up can repeat terminal reads, envelope/query/exact work, or prepare before evaluation completes. | R-001, R-004, D-002, and A-009 require one snapshot, one read/evaluation, and evaluation-before-preparation. | Unit 2; Order Constraints; Matrix | `single-terminal-pass-evidence` |
| `retained-overlay-rendering` | A post-resample corridor can disappear or bypass the existing public preview/planner/painter route. | R-003, D-003, and A-010 retain one-point, ordinary, and post-resample rendering through the existing route. | Unit 2; Compatibility; Matrix | `retained-overlay-rendering-evidence` |
| `preview-effect-isolation` | Down or move preview publication can mutate committed or derived owners without emitting an action. | D-003 and A-011 constrain preview publication to the existing preview state/revision surface. | Unit 2; All-Or-Nothing Failure Boundary; Matrix | `preview-effect-isolation-evidence` |
| `counter-only-performance-acceptance` | Final geometry can be correct while repeated work remains, or acceptance can depend on profile completion, timings, baselines, or generated summaries that do not directly prove the claimed bounds. | R-009, D-004, and A-012 require deterministic counters at the real capture, move, and terminal owners and exclude the Flutter profile route and timing proxies from acceptance. | Unit 3; Work Budget And Cost Displacement; Matrix | `counter-only-acceptance-evidence` |
| `accepted-delivery-finality` | Resolver rejection, accepted cleanup, point-count propagation, or post-consume listener failure can acquire the wrong order or rollback semantics. | R-005, D-002, and A-013 preserve prepare-before-resolver, discard-or-consume, cleanup-before-delivery, unchanged retained point count, and irreversible post-consume delivery. | Unit 2; Temporal Surface Closure; Matrix | `accepted-delivery-finality-evidence` |
| `sample-admission-order` | A distinct sample can be appended twice, skipped, resampled before admission, or lose the newest terminal endpoint. | R-006, D-001, and A-014 preserve the committed single-append meaning and append-before-resample order. | Unit 2; Matrix | `sample-admission-evidence` |
| `single-mutable-source` | A second raw/exact corridor, copied session snapshot, or obsolete reachable session can coexist with the retained capture. | R-002, R-005, D-001, and A-015 make the capture the only mutable trajectory and `PointerSession` a same-identity passive carrier. | Unit 2; Source of Truth; Matrix | `single-mutable-source-evidence` |
| `capture-cleanup-lifecycle` | Cancel, lifecycle shutdown, mode changes, or any pre-/post-commit failure phase can retain active capture reachability or clear it through a second owner at the wrong observable time. | R-005, D-001, D-002, A-016, the interaction contract, and the prior deletion design retain centralized cleanup across every source-owned exit. | Unit 2; Temporal Surface Closure; Matrix | `capture-cleanup-lifecycle-evidence` |
| `cleanup-work-displacement` | Cleanup can release capture correctly while first repeating corridor traversal, resampling, read, envelope, query, or exact work hidden from lifecycle evidence. | R-007, R-009, I-003, A-008, and A-012 require a separate real-owner cleanup-phase absence counter and admission. | Unit 2; Work Budget And Cost Displacement; Matrix | `cleanup-work-displacement-evidence` |
| `preacceptance-no-partial` | A stale, invalid, spatial, candidate, exact-budget, or empty result can reach preparation or mutate a committed/derived owner. | R-001, R-004, D-002, and A-017 preserve the existing pre-acceptance no-partial boundary without merging resolver rejection or post-consume failures into it. | Unit 2; All-Or-Nothing Failure Boundary; Matrix | `preacceptance-no-partial-evidence` |
| `accuracy-reentry-stop` | Implementation can restore original-segment exactness through a hidden trajectory after the accepted approximation becomes unacceptable. | H-001 requires architecture re-entry rather than a hidden exact buffer. | Out of Scope; Source of Truth | `dependency-scope-evidence` |
| `preview-pressure-reentry-stop` | Implementation can silently change the public preview, cadence, renderer, or limits if the fixed retained-bound move cost is still unacceptable. | H-002 requires architecture re-entry for those public or ownership changes. | Out of Scope; Compatibility | `dependency-scope-evidence` |

## Repository Evidence

- `docs/planning/designs/2026-08-27-eraser-corridor-hot-path.md:133` / accepted outcome: the design requires bounded active memory and per-move work plus one terminal all-or-nothing pass -> implement the owner-level hot-path change rather than a call-site-only optimization.
- `docs/planning/designs/2026-08-27-eraser-corridor-hot-path.md:134` / selected retained policy: the accepted values are one mutable corridor, overflow above 8000, uniform endpoint-preserving resample to 4000, and retained-approximation terminal/action meaning -> treat these as fixed behavior, not implementation choices.
- `docs/planning/designs/2026-08-27-eraser-corridor-hot-path.md:184` / ownership lock: interaction capture is the single mutable truth, `PointerSession` is a passive same-reference carrier, and mutable storage never crosses the port or public API -> no parallel raw trajectory, snapshot owner, or synchronization glue is permitted.
- `docs/planning/designs/2026-08-27-eraser-corridor-hot-path.md:195` / temporal lock: initial down keeps one preview read, moves perform no read/geometry work, terminal takes one snapshot/read/evaluation, and accepted delivery preserves existing phase semantics -> split visual, pre-acceptance, and post-consume evidence rather than inferring one from another.
- `docs/planning/designs/2026-08-27-eraser-corridor-hot-path.md:206` / compatibility and consumer closure: public and port signatures stay fixed; implementers and direct consumers are discovered from code while named fixtures are baseline witnesses -> do not add an implementation allowlist or API snapshot registry.
- `docs/planning/designs/2026-08-27-eraser-corridor-hot-path.md:217` / scope lock: the accepted change excludes public additions, unbounded or incremental exact paths, diagnostics, numeric thresholds, retired benchmark restoration, predecessor imports, and reusable cross-tool buffers -> keep every such surface absent.
- `lib/src/interaction/eraser_machine.dart:78` / current capture owner: `PointerEraserCapture` stores an immutable list and every distinct append spreads the prior list -> replace copy-on-append inside this owner while retaining duplicate suppression.
- `lib/src/interaction/interaction_engine.dart:556` / initial read route: eraser down obtains the immutable one-point preview through `eraserPreviewFacts` -> preserve this call and its public preview.
- `lib/src/interaction/interaction_engine.dart:806` / move read route: every admitted move currently calls `eraserPreviewFacts` with the whole proposed corridor -> retire only this caller after visual preview behavior is directly covered.
- `lib/src/interaction/interaction_engine.dart:1340` / terminal route: pointer-up currently passes the full proposed corridor through `eraserTerminalFacts` -> make this the sole immutable retained-corridor terminal read.
- `lib/src/interaction/interaction_read_port.dart:253` / immutable read boundary: eraser requests and facts defensively freeze corridor and result collections -> preserve terminal and initial preview immutability and keep mutable capture behind interaction.
- `lib/src/runtime/runtime_interaction_read_adapter.dart:327` / current geometry consumer: preview and terminal enter the same complete-corridor envelope, query, candidate, and exact route with different budgets -> remove only move-time entry while retaining the terminal owner and initial seam.
- `lib/src/runtime/runtime_interaction_read_adapter.dart:420` / existing terminal work seam: assertion-gated events already expose terminal read and entry materialization phases -> extend this owner-aligned seam as needed instead of timing or public diagnostics.
- `docs/contracts/validation_limits.md:44` / current validation truth: the mandatory eraser soft limit is 8000 and trim-to is 4000 -> reuse these values and make maintained behavior match them without a duplicate policy constant owner.
- `lib/src/contracts/public/canvas_contract_limits.dart:1` / executable validation owner: production validation constants are centralized in one declaration-only file already consumed directly by interaction -> add the eraser soft-limit and resample-target constants here and make capture consume them directly, while documentation records the same values.
- `docs/_registry/public_api_v1.yaml:92` / exported-name owner: `CanvasEraserPreview` is already registered and `CanvasEraseActionPayload` is registered at line 104 -> keep registry membership unchanged because no public name changes.
- `tool/guardrails/src/public_api_checks.dart:14` / registry consumer: the public API guardrail derives the analyzer namespace and compares it bidirectionally with the canonical registry -> use this direct parity route rather than adding an export mirror.
- `tool/guardrails/src/interaction_guardrail_checks.dart:168` / port immutability consumer: copied collection fields are derived from the parsed read-port declarations and checked for defensive freezing -> this guardrail has no manual field inventory and remains the direct negative owner.
- `tool/guardrails/src/geometry_spatial_guardrail_checks.dart:836` / geometry boundary consumer: the existing guardrail owns the preview/terminal budget-input and exact-hit structural boundary -> preserve its current scope and negative proof while changing call frequency only.
- `docs/architecture/02_package_boundaries.md:267` / test structure owner: production-owned tests mirror top-level production owners and cross-cutting guardrails remain separately owned -> extend the existing interaction, geometry, surface, runtime, API-contract, and guardrail suites named by the design.
- `docs/verification/tests.md:837` / current eraser proof owner: immutable read facts, routing, cleanup/delivery, and no-partial behavior already have named owner suites -> extend those owners and add the design-required admissions instead of creating parallel fixtures for existing families.
- `docs/contracts/interaction_engine.md:253` / cleanup ownership boundary: interaction owns session cleanup while hit testing, spatial selection, and exact eraser checks remain outside cleanup -> separately prove that every cleanup branch releases capture without displacing corridor or geometry work into that phase.
- `docs/verification/performance.md:30` / excluded profile authority: the maintained Flutter route is a completion and artifact-production gate without numeric thresholds -> do not use its completion, generated summaries, or timings as acceptance evidence for this change.

## Boundaries

Owner: `PointerEraserCapture` and `InteractionEngine` own active eraser capture, admission, immutable preview publication, and centralized cleanup; `RuntimeInteractionReadAdapter` retains immutable terminal read orchestration and geometry/spatial delegation; existing RuntimeRoot/edit owners retain preparation, resolver, consume, cleanup, and delivery.
In Scope: Replace copy-on-append capture with one mutable retained corridor; append distinct down/move/terminal samples once; immediately resample an over-limit input of length `n` to 4000 points by selecting input index `(i * (n - 1)) ~/ 3999` for every output position `i`, thereby preserving first and newest endpoints; publish immutable retained previews; remove move-time preview reads and geometry work while preserving the initial one-point read; perform one terminal retained snapshot/read/evaluation; preserve named failure and delivery semantics; update behavior-sensitive consumers, direct proofs, verification admissions, semantic contracts, public point-count meaning, and eraser diagrams; close every work claim with deterministic retained-count, copied-point, sample-admission, resample, move-phase, terminal-phase, and cleanup-phase counters at the real owners.
Out of Scope: Original-segment accuracy after resampling; any raw or unbounded trajectory; a bounded-memory exact claim; incremental exact state; minimum-distance decimation; async terminal work; public declaration, constructor, field, type, export, stream, revision, port-signature, or registry-membership changes; new diagnostics; official Flutter profile-route acceptance; generated comparison summaries; elapsed timings, baselines, or numeric performance thresholds; restored `tool/bench/**`, `test/benchmarks/**`, benchmark ids, registries, schemas, or checked-in artifacts; predecessor imports; cross-tool gesture buffers; unrelated resolver, deletion, edit, or delivery policy; any response to H-001 or H-002 without architecture re-entry.
Source of Truth: The interaction-owned retained corridor is the sole mutable trajectory and the sole source for immutable public previews, the terminal request, exact terminal geometry, and `corridorPointCount`; `lib/src/contracts/public/canvas_contract_limits.dart` is the sole machine-consumable owner of the eraser soft-limit and resample-target values, interaction consumes those constants directly, and `docs/contracts/validation_limits.md` documents them without defining a second executable policy. Public Dart declarations own concrete API shape, `docs/contracts/public_api_v1.md` owns public semantics, and `docs/_registry/public_api_v1.yaml` owns exported names only. No intent marker, copied corridor inventory, second count, or test-owned policy is introduced.
Compatibility: `CanvasEraserPreview`, `CanvasEraseActionPayload`, their facade/root exports, `InteractionReadPort.eraserPreviewFacts`, and `InteractionReadPort.eraserTerminalFacts` retain current declaration shapes and immutability; one-point and multi-point rendering, preview revision/state publication, erase action delivery, persisted data, codecs, configuration, and external consumers remain source-compatible. The documented semantic change is that long-gesture preview geometry, terminal exact work, and public point count use the retained approximation and may miss a narrow discarded detour or add a shortcut-chord hit.
Order Constraints: Admit every new or extended proof family before changing its permanent artifact; implement capture ownership and append/resample before consumers rely on retained snapshots; append the triggering move or endpoint before resampling; preserve initial preview read before retiring the move caller; establish one terminal retained request and its direct evidence before claiming old move-path retirement complete; evaluate fully before entry projection or preparation; prepare before resolver, discard or consume according to resolver, cleanup before delivery, and close semantic docs plus the complete deterministic-counter evidence set before lifecycle closure.
Temporal Surface Closure: Down performs the existing immutable one-point preview read; duplicate adjacent samples do nothing; each admitted distinct move synchronously appends/resamples then publishes one immutable preview with no read, envelope, query, candidate ordering, exact hit, or deletion projection; pointer-up appends/resamples, freezes one retained snapshot, performs exactly one terminal read and one complete evaluation, and only a nonempty successful result can enter preparation. Resolver rejection is pre-consume discard plus cleanup; accepted consume is final, cleanup precedes common delivery, and later listener failure does not roll back or reclassify the commit.
All-Or-Nothing Failure Boundary: Stale terminal input, invalid terminal input, spatial-query overflow, candidate-budget overflow, exact-budget overflow, and empty exact result expose no deletion entries to preparation and change no document, selection, spatial, projection, main repaint, or action state; resolver rejection remains a distinct prepared-but-not-consumed discard route; failures after consume retain the accepted deletion. Preview publication changes only the existing preview state/revision and overlay repaint surfaces.
Negative Proof And Fixture Quarantine: Mutable request/facts collection negatives remain owned by the existing interaction guardrail fixtures; geometry budget-input negatives remain owned by the existing geometry guardrail fixtures; narrow-detour and shortcut-chord cases demonstrate the accepted coherent approximation and must not become a guardrail that rejects another coherent policy. Test-only work observers remain assertion-gated, non-public, and attached to real owners; no fixture inventory or natural-language scanner becomes production authority.
Bounded Recognition Scope: No new analyzer, source scanner, generated-output recognizer, token heuristic, or fixture-recognition architecture is introduced. Existing analyzer-backed public namespace parity, AST-derived collection immutability, geometry budget-shape guardrail, repository call-site discovery, documentation tooling, and performance artifact checker retain their current bounded owners and target artifacts.
Work Budget And Cost Displacement: Construction/import/reset initializes the capture solely from the admitted down point and imports no preexisting trajectory; this is a source-of-truth constraint, not an additional construction-performance claim. Mutation/update/replay admits each distinct sample once; an ordinary non-overflow append performs zero traversal and zero copy of the existing retained prefix, while the only allowed whole-retained mutable pass is the immediate uniform resample after the triggering append exceeds the executable soft limit and before another sample. No work is displaced into `PointerSession`, another trajectory, or later cleanup. Freeze/publication/install may traverse or copy only the currently retained bounded corridor per admitted visual update, independent of the discarded admitted-history length, and performs no spatial/exact work or committed install; snapshot count, allocation strategy, and construction remain open. Query/read preserves the one-point initial read and permits exactly one terminal whole-retained-corridor snapshot plus envelope/query/candidate/exact pass under existing fixed terminal budgets; no move-time read or hidden pre-terminal geometry pass is allowed. Cleanup/rollback releases the active capture/session through the existing centralized owner with zero corridor traversal, snapshot, resample, read, envelope, query, candidate, or exact work on every cleanup branch; no raw-history walk, geometry recomputation, or disposal synchronization is allowed. Each performance claim is accepted only through its direct deterministic owner counter; profile completion, generated summaries, elapsed time, or correct final output cannot substitute for those counters, and correct results in any phase do not authorize unbounded or displaced work in another phase.

## Execution Units

### [ ] Unit 1: Admit the eraser proof families

Owner: `docs/verification/tests.md` as the permanent verification-admission authority.
Boundary: Record each design-required independent new or extended eraser failure family with its real production owner, failing witness, direct oracle, proxy limits, durable value, and existing artifact target before those artifacts change; do not create a test inventory, implementation detail lock, or duplicate no-partial/delivery owner.
Verification Profile: `SOURCE_OF_TRUTH_DOCS`
Change: The verification authority separately admits bounded move work, retained approximation, visual-only moves, sample admission, single mutable capture, cleanup lifecycle, cleanup work displacement, one terminal pass, overlay rendering, preview isolation, pre-acceptance no-partial extension, and accepted-delivery extension at their established proof owners.

Acceptance Outcomes:

| Outcome key | Starting state | System action | Observable result | Required side conditions |
| --- | --- | --- | --- | --- |
| `eraser-proof-families-admitted` | Existing verification documentation names eraser suites but lacks the twelve independent design-required admissions. | Maintainers update the verification authority for the accepted eraser design. | Each independent family has one complete admission routed to its production seam and real proof owner, and the existing no-partial and accepted-delivery families are explicitly extended rather than duplicated. | Admissions precede artifact changes; no prose parser, copied test inventory, private helper contract, new benchmark owner, or fixture-owned product truth is added. |

Depends On: None

### [ ] Unit 2: Establish the bounded corridor and close its terminal lifecycle

Owner: Executable validation limits, interaction-owned eraser capture and terminal routing, passive `PointerSession` carriage, `RuntimeInteractionReadAdapter`, public preview/planner/painter publication, retained-corridor semantic owners, and the existing RuntimeRoot resolver/consume/cleanup/delivery route.
Boundary: Atomically add the executable eraser limits, replace copy-on-append capture, establish the retained approximation, close one retained terminal evaluation and every cleanup/atomicity/delivery branch, update retained-corridor semantics, and land every admitted direct proof before the mutable capture or retained terminal/action meaning becomes authoritative; preserve the existing bounded move-time preview read until Unit 3.
Verification Profile: `BEHAVIOR_CHANGE`
Change: The repository reaches a dependency-closed bounded-corridor state with unchanged public rendering/publication, one retained terminal pass, complete centralized cleanup lifecycle, and direct capture/terminal evidence while move-time preview reads remain temporarily active against bounded snapshots.

Acceptance Outcomes:

| Outcome key | Starting state | System action | Observable result | Required side conditions |
| --- | --- | --- | --- | --- |
| `bounded-capture-move-work` | Gestures with different admitted-history lengths reach the same retained count after one or more overflow cycles. | The real interaction route admits distinct eraser moves and publishes their retained previews. | Ordinary distinct append reports zero traversal and zero copy of the existing retained prefix; active storage stays bounded; only the triggering overflow performs the allowed whole-retained resample to 4000 before another sample; publication traverses or copies only current retained points and its work is independent of discarded history length. | Equal adjacent samples do nothing; publication work is counted separately from mutation without fixing snapshot count or allocation strategy; no second trajectory or copy-on-append remains; evidence uses deterministic owner work events rather than elapsed time. |
| `retained-approximation-is-truth` | Deterministic corridors exceed 8000, include non-even index spacing, and contain both a narrow discarded detour and a shortcut-chord case. | Interaction resamples, publishes preview, and later supplies the retained terminal/action corridor. | Exactly 4000 output positions select source index `(i * (n - 1)) ~/ 3999`, preserve first/newest endpoints, and supply the same retained list to preview, terminal geometry, intent chain, and public point count, with the documented possible miss and possible added hit. | No alternative rounding/tie rule, minimum-distance decimation, raw count, hidden exact corridor, or predecessor implementation is used. |
| `sample-admission-semantics` | Duplicate moves, ordinary distinct moves, an overflow-triggering move, and a distinct terminal endpoint are supplied. | The interaction owner admits samples and applies its retained policy. | Every distinct sample is admitted once before any resample, equal adjacent samples are suppressed, and the newest terminal endpoint survives resampling. | Final length alone is insufficient; evidence distinguishes append events from later resample events and does not lock private storage shape. |
| `single-capture-passive-session` | An active eraser session is rebuilt across down, move, preview publication, and terminal preparation. | Interaction mutates the capture and updates `PointerSession` shells. | One capture identity and retained store remain reachable; session shells forward the same capture without mutation or snapshotting, and obsolete shells or a raw trajectory are not retained. | Mutable storage never crosses public or read-port boundaries, and evidence combines lifecycle identity with repository-derived consumer closure. |
| `public-eraser-surface-stays-compatible` | Existing external consumers construct/read eraser preview and action payload types through the root barrel and the canonical registry contains both names. | The retained-corridor capture and public semantic documentation land. | Declaration shapes, constructors, fields, immutability, facades, barrel exports, and registry membership remain unchanged and external consumers compile. | No executable limit constant or mutable capture becomes public; registry parity plus declaration inspection closes additive drift that compilation alone can miss. |
| `retained-corridors-render-through-existing-overlay` | One-point, ordinary multi-point, and post-resample public eraser previews are published while the existing preview read remains active. | The existing preview planner and painter capture their frames. | All three forms produce visible overlay output through the same public preview, planner, primitive, painter, and frame-drawable route. | No second renderer or mutable capture access is added; helper-only pixels cannot substitute for the public route. |
| `preview-publication-remains-isolated` | Initial, ordinary-move, and post-resample previews begin from observed runtime state and revision owners. | Interaction publishes each retained preview. | Only preview state/revision and overlay repaint effects change; no action, document, selection, spatial, projection, main repaint, or mutable capture exposure occurs. | Final terminal state is not used as a proxy; all committed and derived owners are observed at the preview boundary. |
| `single-terminal-evaluation` | Successful, empty, spatial-overflow, candidate-overflow, and exact-overflow terminal scenarios use a retained corridor. | Pointer-up enters the real interaction/read/runtime/geometry route. | Each attempt uses one immutable retained snapshot, one terminal read, one envelope/query/candidate/exact evaluation, and no preparation begins before evaluation completes. | A read count alone is insufficient; phase-specific work kills repeated geometry behind one read and detects a mismatched snapshot. |
| `preacceptance-failures-are-no-partial` | Stale, invalid, spatial-budget, candidate-budget, exact-budget, and empty terminal inputs are independently exercised. | The terminal route evaluates and rejects each input before acceptance. | No deletion entry reaches preparation and document, selection, spatial, projection, main repaint, and action state remain unchanged; cleanup occurs. | Resolver rejection and post-consume failure remain outside this family; action absence alone is rejected as a proxy. |
| `accepted-eraser-delivery-is-final` | Nonempty retained results reach resolver rejection, resolver acceptance, state-listener failure, and action-listener failure. | Runtime prepares deletion/action state, resolves, and either discards or consumes the prepared commit. | Preparation precedes resolver; rejection discards and cleans without delivery; acceptance consumes, cleans before common delivery, propagates retained `corridorPointCount` unchanged, and remains committed after listener failure. | No post-consume rollback/no-op classification or parallel transaction model is introduced; full phase order and final document are observed together. |
| `capture-cleanup-covers-every-exit` | Cancel, dispose, prepared load success, mode/tool change, active-session `interactive=false`, stale terminal, invalid terminal, empty/budget no-op, resolver cancel, resolver error, edit/preparation failure after an eraser intent, successful commit, and post-consume delivery failure each begin with an active retained capture. | The existing owning interaction, runtime, API, and surface routes reach each exit. | Active session and capture reachability are released through the existing centralized cleanup owner at the phase-appropriate time for every source-owned branch. | Resolver error retains its bounded diagnostic behavior; preparation failure remains pre-callback/fail-fast; cleanup precedes externally observable accepted delivery; no second cleanup owner or disposal protocol appears; garbage collection timing is not the oracle. |
| `cleanup-performs-no-displaced-work` | Every source-owned cleanup branch begins with an active retained capture whose release can hide redundant corridor or geometry work. | The real owning interaction, runtime, API, and surface routes perform cleanup. | Cleanup-phase owner events report zero corridor traversal, snapshot, resample, read, envelope, query, candidate, and exact work while active session/capture reachability is released. | This is separate from lifecycle-release evidence; correct release, final output, aggregate work counts, and timing cannot substitute for phase-specific zero-work counters. |

Depends On:

- Unit 1 — produces: every admitted retained-corridor, terminal, cleanup, no-partial, rendering, isolation, and delivery verification family; consumed as: authority for all permanent evidence changed in this unit.

### [ ] Unit 3: Retire move-time reads with consumers and final semantics

Owner: Interaction move routing, repository-derived read-port consumers, existing guardrails, visual-only move proof, final eraser semantic owners, and cross-owner scope closure.
Boundary: Starting from Unit 2's bounded and fully proven retained corridor, atomically migrate every behavior-sensitive consumer to initial-only preview reads, remove the move caller, prove zero move-phase read/geometry work, update the remaining move semantics and diagrams, and close the counter-only acceptance set without changing terminal, cleanup, public, or port declaration behavior.
Verification Profile: `BEHAVIOR_CHANGE`
Change: Admitted eraser moves become visual-only against the already bounded retained corridor, every live consumer and semantic owner adopts the initial-only read contract in the same unit, and final acceptance contains only direct owner counters.

Acceptance Outcomes:

| Outcome key | Starting state | System action | Observable result | Required side conditions |
| --- | --- | --- | --- | --- |
| `visual-only-move-route` | Unit 2 provides a bounded retained corridor while down and admitted moves still use the immutable preview read and behavior-sensitive consumers expect those calls. | The atomic move-path cutover migrates those expectations and processes duplicate, ordinary, and overflow-triggering moves through the real route. | Down performs one preview read; duplicates publish nothing; each distinct move publishes its post-admission immutable corridor without any preview read, envelope, query, ordering, exact-hit, or deletion-projection event. | Consumer expectations and direct visual-route proof land with caller removal; existing preview state/revision behavior and the initial immutable seam remain. |
| `preview-seam-consumers-migrate-completely` | The owning interface has all repository-derived implementations and `eraserPreviewFacts` has initial, move, and direct test consumers. | Call-site closure is re-derived during the atomic caller retirement and behavior-sensitive expectations are updated. | Every implementation compiles; initial/direct preview and terminal seams remain exercised; no move-time expectation survives; existing immutable-collection and geometry-budget positive/negative guardrails retain scope. | Named design paths are baseline witnesses, not a copied exhaustive list; unrelated port signatures and guardrails do not change. |
| `performance-acceptance-is-counter-only` | Unit 2 directly closes capture, terminal, and cleanup work while move-time reads and geometry remain observable. | Unit 3 removes those phases and maintainers assemble the complete performance acceptance set. | Retained-count, copied-point, admission, resample, move-phase, terminal-phase, and cleanup-phase claims all map to direct real-owner counters, and no acceptance depends on Flutter profile completion, summaries, elapsed time, baselines, or thresholds. | Final output, helper calls, profile success, and timing observations are rejected as substitutes for direct counters. |
| `eraser-semantics-stay-aligned` | Unit 2 documents executable limits, retained approximation, public point-count meaning, and terminal lifecycle while move-specific contracts and diagrams still show bounded preview reads. | The move cutover updates the remaining semantic owners. | Every owner agrees on append-before-resample, exact index mapping, endpoints, approximation cost, initial-only read, visual moves, one terminal pass, named pre-acceptance failures, prepare/resolver/consume/cleanup/delivery order, and retained point count. | Public declaration snippets and exported names stay unchanged; docs tooling or wording tokens alone cannot prove semantic parity. |
| `eraser-scope-and-dependencies-stay-contained` | The final implementation diff can add imports, public surfaces, diagnostics, benchmark files, or hidden retained state outside the main route. | Maintainers inspect changed owner edges, exported closure, capture reachability, and durable artifacts after move retirement. | Existing interaction-to-port-to-runtime-to-geometry/edit direction remains and every D-004 exclusion stays absent. | Architecture checks supplement but do not replace real owner/import/state inspection; no general feature-local scanner is introduced. |

Depends On:

- Unit 1 — produces: admitted visual-only move verification; consumed as: authority for the move-route permanent evidence changed in this unit.
- Unit 2 — produces: a bounded retained corridor with complete terminal, cleanup, rendering, isolation, and compatibility closure; consumed as: the valid source state whose bounded move-read caller is retired.

## Verification Matrix

| Evidence key | Covers | Evidence class | Evidence surface | Pre-implementation witness | Pass signal | Evidence constraints and rejected proxy | Adversarial false-positive case and kill signal | Durable impact | Artifact target | Admission |
| --- | --- | --- | --- | --- | --- | --- | --- | --- | --- | --- |
| `proof-admission-closure-evidence` | `eraser-proof-families-admitted` | `MANUAL_INSPECTION` | Direct comparison of `docs/verification/tests.md` admissions with A-001, A-002, A-003, A-008, A-009, A-010, A-011, A-012, A-013, A-014, A-015, A-016, and A-017 | The twelve independent admissions are absent. | Every family has one complete owner-routed admission and each changed permanent artifact maps to exactly its matching family. | Direct admission content and production-owner routing are admissible; test count, filename presence, another test, or natural-language parsing is rejected. | One broad “eraser behavior” admission names all files but omits independent failure modes; one-to-one family comparison kills it. | `UPDATE_EXISTING` | `docs/verification/tests.md` | None |
| `bounded-capture-work-evidence` | `bounded-capture-move-work` | `TEST` | Existing interaction routing owner through `dart test test/interaction/eraser_context_action_routing_test.dart` | Current distinct append copies the entire prior list and capture has no limit enforcement. | Owner work events show zero existing-prefix traversal/copy for every ordinary append, bounded active counts, immediate 8001-to-4000 resamples across multiple cycles, and separately counted publication point work that is identical for equal retained counts reached through different admitted-history lengths. | Deterministic mutation, resample, publication point work, and retained counts on the real route are admissible; final length, elapsed time, snapshot count, allocation strategy, or private field shape is rejected. | An implementation copies the current bounded 8000-point prefix on every append or publication consults discarded-history length; a nonzero ordinary-append copied/traversed-point event or unequal publication point work at equal retained counts kills it. | `EXTEND_COVERAGE` | `test/interaction/eraser_context_action_routing_test.dart` and its existing fixture | `bounded-capture-work-admission` |
| `retained-approximation-evidence` | `retained-approximation-is-truth` | `TEST` | Existing interaction routing plus terminal resolver/action owners through `dart test test/interaction/eraser_context_action_routing_test.dart test/interaction/terminal_eraser_deletion_resolver_test.dart` | No maintained resample exists and terminal/action behavior uses the complete original list. | Every retained source index, including non-even spacing cases, equals `(i * (n - 1)) ~/ 3999`; count/endpoints, preview, terminal input, intent chain, public count, narrow-detour miss, and shortcut-chord hit all match that approximation. | Real capture-to-public/terminal boundaries are admissible; helper-only resampling, endpoint-only checks, alternative rounding, or historic predecessor behavior is rejected. | Endpoint and count checks pass under nearest-index rounding but an interior non-even index differs; the full expected-index comparison kills it. | `EXTEND_COVERAGE` | Existing eraser routing and terminal resolver fixtures | `retained-approximation-admission` |
| `visual-only-move-evidence` | `visual-only-move-route` | `TEST` | Existing interaction routing owner through `dart test test/interaction/eraser_context_action_routing_test.dart` | Every distinct move calls `eraserPreviewFacts` and enters envelope/query/exact work. | Phase events show one initial read, zero move reads/geometry/deletion projection, and preview publication after each admitted append/resample only. | Real attached route and phase-specific events are admissible; machine-only output, aggregate read count, timing, or helper names are rejected. | Initial read is removed together with move reads; phase-specific down assertion kills it. | `EXTEND_COVERAGE` | `test/interaction/eraser_context_action_routing_test.dart` and its existing fixture | `visual-only-move-admission` |
| `sample-admission-evidence` | `sample-admission-semantics` | `TEST` | Existing interaction routing owner through `dart test test/interaction/eraser_context_action_routing_test.dart` | Current duplicate suppression exists, but no overflow transition or admitted-event proof distinguishes append-before-resample. | Duplicate, distinct, overflow-triggering, and terminal endpoint events prove exactly-once admission and newest endpoint retention. | Admission and retained-result observation on the real route is admissible; final length or helper-call assertions are rejected. | The triggering point is resampled before append and the length still becomes 4000; admitted-event/end-point ordering kills it. | `EXTEND_COVERAGE` | `test/interaction/eraser_context_action_routing_test.dart` and its existing fixture | `sample-admission-admission` |
| `single-mutable-source-evidence` | `single-capture-passive-session` | `TEST` | Existing pointer-session owner through `dart test test/interaction/pointer_session_test.dart` plus bounded production consumer inspection | Current session forwards immutable capture identity, but no mutable retained lifecycle or hidden-trajectory absence can yet be exercised. | Same capture identity is forwarded across shell updates, later mutation is observed through the active shell, obsolete shells are unreachable, and immutable snapshots alone cross boundaries. | Lifecycle identity plus repository-derived capture/session consumer closure is admissible; list equality or source-field scanning alone is rejected. | A second raw list stays hidden and equal outputs pass; reachability/consumer closure detects it and kills it. | `EXTEND_COVERAGE` | `test/interaction/pointer_session_test.dart` | `single-mutable-source-admission` |
| `single-terminal-pass-evidence` | `single-terminal-evaluation` | `TEST` | Existing terminal route-work owner through `dart test test/interaction/terminal_eraser_entry_route_work_test.dart` | Existing evidence begins at terminal entry materialization but does not close one retained snapshot plus envelope/query/exact/preparation order for all outcomes. | Successful, empty, and overflow traces contain one retained snapshot/read/envelope/query/order/exact sequence and preparation only after success. | Real interaction/read/runtime/geometry phase events are admissible; final state, timing, or read count alone is rejected. | One read internally repeats exact evaluation; duplicate exact phase events kill it. | `EXTEND_COVERAGE` | `test/interaction/terminal_eraser_entry_route_work_test.dart` and its existing fixture | `single-terminal-pass-admission` |
| `preacceptance-no-partial-evidence` | `preacceptance-failures-are-no-partial` | `TEST` | Existing no-partial owner through `dart test test/geometry/eraser_exact_budget_no_partial_commit_test.dart` | Current coverage owns terminal exact-budget overflow but not every named retained-corridor invalid/empty/budget family together with preparation exclusion and derived-owner stability. | Every named failure performs no preparation and leaves all committed/derived owners unchanged while cleaning active capture. | Direct preparation, state, derived-owner, action, repaint, and cleanup observation is admissible; action absence or terminal-work counts alone are rejected. | Partial preparation is discarded before action emission so final state looks unchanged; preparation-call assertion kills it. | `EXTEND_COVERAGE` | `test/geometry/eraser_exact_budget_no_partial_commit_test.dart` and its existing fixture | `preacceptance-no-partial-admission` |
| `accepted-delivery-finality-evidence` | `accepted-eraser-delivery-is-final` | `TEST` | Existing terminal resolver owner through `dart test test/interaction/terminal_eraser_deletion_resolver_test.dart` | Existing owner proves resolver and post-consume finality for short corridors but not retained post-resample point-count and phase closure. | Rejection and acceptance traces prove preparation, discard/consume, cleanup, delivery order, unchanged retained count, and final document under listener failures. | Real RuntimeRoot route and public observations are admissible; action count, final snapshot alone, or design prose is rejected. | Listener failure rolls back then recreates the same final document; consume/cleanup/delivery trace kills it. | `EXTEND_COVERAGE` | `test/interaction/terminal_eraser_deletion_resolver_test.dart` and its existing fixture | `accepted-delivery-finality-admission` |
| `capture-cleanup-lifecycle-evidence` | `capture-cleanup-covers-every-exit` | `TEST` | Existing owners through `dart test test/interaction/eraser_context_action_routing_test.dart test/interaction/terminal_eraser_deletion_resolver_test.dart test/geometry/eraser_exact_budget_no_partial_commit_test.dart test/runtime/load_interaction_cleanup_test.dart test/api/tool_port_settings_test.dart test/surface/interactive_false_active_session_cancel_test.dart test/runtime/dispose_lifecycle_test.dart` | Existing tests cover selected cleanup paths but cannot observe mutable capture reachability across every source-owned lifecycle and failure branch. | Cancel, dispose, prepared load success, mode/tool change, active-session `interactive=false`, stale/invalid/no-op, resolver cancel/error, edit/preparation failure, success, and post-consume failure all release active session/capture through the centralized owner, with accepted cleanup before delivery. | Direct active-owner reachability, diagnostic/fail-fast side conditions, and phase order are admissible; preview disappearance, garbage collection, or a second cleanup hook is rejected. | Preview clears on every public branch but an obsolete session retains capture after load or resolver error; per-branch reachability observation kills it. | `EXTEND_COVERAGE` | Existing eraser routing, no-partial, terminal resolver, load cleanup, tool settings, interactive-false, and dispose suites | `capture-cleanup-lifecycle-admission` |
| `cleanup-work-displacement-evidence` | `cleanup-performs-no-displaced-work` | `TEST` | Existing owners through `dart test test/interaction/eraser_context_action_routing_test.dart test/interaction/terminal_eraser_deletion_resolver_test.dart test/geometry/eraser_exact_budget_no_partial_commit_test.dart test/runtime/load_interaction_cleanup_test.dart test/api/tool_port_settings_test.dart test/surface/interactive_false_active_session_cancel_test.dart test/runtime/dispose_lifecycle_test.dart` | Current cleanup evidence can prove release and order but has no cleanup-phase counter capable of detecting hidden corridor or geometry recomputation. | Every source-owned cleanup branch reports zero corridor traversal, snapshot, resample, read, envelope, query, candidate, and exact work while releasing active capture/session reachability. | Phase-specific events at the real cleanup and downstream work owners are admissible; lifecycle release, aggregate counts, final output, helper calls, and timing are rejected. | Cleanup releases correctly but recomputes an envelope before clearing capture; any nonzero cleanup-phase work event kills it. | `EXTEND_COVERAGE` | Existing eraser routing, no-partial, terminal resolver, load cleanup, tool settings, interactive-false, and dispose suites | `cleanup-work-displacement-admission` |
| `public-surface-compatibility-evidence` | `public-eraser-surface-stays-compatible` | `BUILD_OR_COMPILE` | `dart test test/api_contract/public_api_v1_compiles_as_written_test.dart test/guardrails/public_api_declaration_checks_test.dart` plus direct registry/declaration comparison | Current public surface compiles and is registered before the semantic change. | Existing consumers compile, analyzer/registry parity passes, and both declarations and export paths retain exact current shapes with no mutable capture exposure. | External compile, canonical registry, analyzer namespace, and declaration inspection together are admissible; any one alone or a new snapshot is rejected. | An additive public field compiles and registry names stay equal; direct declaration-shape guardrail kills it. | `UPDATE_EXISTING` | Existing public API compile and declaration guardrail owners | None |
| `preview-seam-consumer-evidence` | `preview-seam-consumers-migrate-completely` | `TEST` | Repository-derived implementer/call closure plus `dart test test/interaction/interaction_read_port_test.dart test/guardrails/interaction_guardrail_enforcement_test.dart test/guardrails/geometry_eraser_exact_budget_inputs_guardrail_test.dart` and affected direct consumer suites | Current closure includes the move caller and behavior-sensitive fixtures expect preview reads on moves. | Every derived implementation and direct consumer compiles/exercises its remaining seam; initial/direct calls remain; move expectations are gone; positive/negative guardrails retain scope. | The owning interface and live call sites are authority; a copied list, compilation alone, or weakened negative fixture is rejected. | Named baseline fixtures pass but a newly added implementer is omitted; interface-derived compile closure kills it. | `UPDATE_EXISTING` | Existing interaction, geometry, runtime, diagnostics, and guardrail consumer owners | None |
| `retained-overlay-rendering-evidence` | `retained-corridors-render-through-existing-overlay` | `TEST` | Existing surface overlay owner through `dart test test/surface/overlay_drawable_policy_test.dart` | Existing owner covers one- and multi-point corridors but not a real post-resample public preview route. | Captured frames for one-point, ordinary, and post-resample previews all contain visible eraser overlay output through the existing planner/painter path. | Real public preview-to-frame route is admissible; helper-only drawing, DTO construction alone, or a second painter is rejected. | Direct helper pixels pass while planner drops post-resample preview; full route frame capture kills it. | `EXTEND_COVERAGE` | `test/surface/overlay_drawable_policy_test.dart` and its existing fixture | `retained-overlay-rendering-admission` |
| `preview-effect-isolation-evidence` | `preview-publication-remains-isolated` | `TEST` | Existing public preview-state owner through `dart test test/interaction/preview_public_state_test.dart` | Existing preview proof does not directly observe post-resample publication against every committed/derived owner. | Initial, move, and post-resample publication change only preview revision/state and overlay repaint, with no committed or action effect. | Real runtime states, revisions, action stream, derived owners, and repaint classification are admissible; DTO tests, action absence, or final terminal state is rejected. | Action stream is silent but spatial/projection revision changes; owner-by-owner observation kills it. | `EXTEND_COVERAGE` | `test/interaction/preview_public_state_test.dart` and its existing fixture | `preview-effect-isolation-admission` |
| `semantic-document-parity-evidence` | `eraser-semantics-stay-aligned` | `MANUAL_INSPECTION` | Direct semantic comparison of the four contract owners and three eraser diagrams against D-001 through D-003 and the corresponding behavioral evidence | Current diagrams still show move-time reads and maintained capture does not realize documented trimming. | Every named owner describes one coherent retained-corridor route and every transition has a matching direct behavior outcome. | Structured semantic review plus behavior routes is admissible; docs lint, wording-token scans, or behavior alone is rejected. | Docs checks pass while one diagram retains a second terminal pass; direct branch comparison kills it. | `UPDATE_EXISTING` | `docs/contracts/validation_limits.md`, `docs/contracts/geometry.md`, `docs/contracts/interaction_engine.md`, `docs/contracts/public_api_v1.md`, and the three eraser diagrams | None |
| `dependency-scope-evidence` | `eraser-scope-and-dependencies-stay-contained` | `MANUAL_INSPECTION` | Bounded changed-production imports, public namespace, capture/session consumer closure, and durable artifact diff | Excluded surfaces are absent before implementation. | The final change retains current owner direction and adds none of the public, async, diagnostics, benchmark, unbounded, predecessor, incremental-exact, or cross-tool surfaces. | Real changed edges/declarations/reachability/durable artifacts are admissible; path-name scans or architecture checks alone are rejected. | Hidden raw trajectory uses a neutral field name and all architecture checks pass; runtime reachability plus owner diff kills it. | `NONE` | None | None |
| `counter-only-acceptance-evidence` | `performance-acceptance-is-counter-only` | `MANUAL_INSPECTION` | Complete mapping from the work-bound outcomes to their Matrix counter evidence and final acceptance evidence set | Current code has no retained policy and the prior draft required profile completion despite that route having no direct performance verdict. | Every performance claim, including cleanup-phase absence, maps to a real-owner deterministic counter and the acceptance set contains no profile command, generated summary, elapsed timing, baseline, or threshold dependency. | Direct counter-to-claim mapping is admissible; correct output, helper calls, profile completion, timeline values, or local comparisons are rejected. | All behavior tests and a profile run pass while move geometry or cleanup recomputation still repeats; the phase-specific zero-work counter requirements kill it. | `NONE` | None | None |

## Permanent Artifact Admissions

### `bounded-capture-work-admission`: Bounded and copy-free eraser move work

Covers: `bounded-capture-move-work`
Impact: `EXTEND_COVERAGE`
Failure family: eraser move capture can retain or copy work proportional to an unbounded prior prefix
Failure mode or stable invariant: ordinary append traverses and copies zero existing retained points; active storage stays bounded; the only mutable whole-retained pass is immediate overflow resampling before another sample; publication point work depends only on current retained state, not discarded admitted-history length
Verification owner: interaction eraser routing suite
Current verification gap: current routing proves preview and intent behavior but has no retained-bound or copied-point work observation
Failing witness: the current capture spreads the complete prior list on every distinct append and never enforces 8000-to-4000 resampling
Durable and refactor-stable value: zero-copy ordinary append plus retained-state-bounded resample/publication work survive private storage, snapshot-count, allocation, and helper refactors without imposing wall-clock thresholds
Artifact target: `test/interaction/eraser_context_action_routing_test.dart` and its existing fixture

### `retained-approximation-admission`: Retained approximation and accuracy boundary

Covers: `retained-approximation-is-truth`
Impact: `EXTEND_COVERAGE`
Failure family: preview, terminal geometry, or public point count can diverge from the selected retained approximation
Failure mode or stable invariant: every output position selects `(i * (n - 1)) ~/ 3999`, and that exact endpoint-preserving retained corridor supplies every downstream consumer and exhibits the documented possible miss and shortcut hit
Verification owner: interaction eraser routing and terminal resolver suites
Current verification gap: no maintained resampling or cross-boundary retained-corridor proof exists
Failing witness: current preview, terminal geometry, and point count consume the full original corridor and cannot exercise the accepted approximation
Durable and refactor-stable value: one semantic corridor truth and its explicit accuracy cost survive private capture, runtime, and geometry refactors
Artifact target: Existing eraser routing and terminal resolver fixtures

### `visual-only-move-admission`: Visual-only eraser move routing

Covers: `visual-only-move-route`
Impact: `EXTEND_COVERAGE`
Failure family: move handling can retain read-port or geometry work despite correct preview output
Failure mode or stable invariant: down performs the preserved initial read while every admitted move publishes after append/resample with no read or geometry phase
Verification owner: interaction eraser routing suite
Current verification gap: current behavior expects and performs a preview read on every distinct move
Failing witness: the existing real route enters `eraserPreviewFacts` for each distinct move
Durable and refactor-stable value: phase-level routing guarantees survive private method and observer naming changes
Artifact target: `test/interaction/eraser_context_action_routing_test.dart` and its existing fixture

### `sample-admission-admission`: Exactly-once eraser sample admission

Covers: `sample-admission-semantics`
Impact: `EXTEND_COVERAGE`
Failure family: distinct move or terminal samples can be duplicated, skipped, or resampled in the wrong order
Failure mode or stable invariant: each distinct sample is admitted once before resampling, adjacent duplicates are ignored, and the newest terminal endpoint is retained
Verification owner: interaction eraser routing suite
Current verification gap: duplicate suppression exists but no admitted-event/resample-order proof covers overflow and terminal endpoint retention
Failing witness: the current route has no resampling transition against which append-before-resample can be falsified
Durable and refactor-stable value: semantic admission order survives helper extraction and storage representation changes
Artifact target: `test/interaction/eraser_context_action_routing_test.dart` and its existing fixture

### `single-mutable-source-admission`: Single mutable capture and passive session carriage

Covers: `single-capture-passive-session`
Impact: `EXTEND_COVERAGE`
Failure family: a second mutable or raw trajectory can coexist with copied or obsolete session state
Failure mode or stable invariant: one capture identity owns mutation, session shells forward it without copying, and only immutable snapshots cross boundaries
Verification owner: pointer-session owning suite plus bounded production consumer closure
Current verification gap: current tests cover immutable capture carriage but cannot observe the selected mutable retained lifecycle or hidden second trajectory
Failing witness: the new mutable behavior is absent and the current capture replacement model cannot demonstrate same-identity mutation across shell updates
Durable and refactor-stable value: identity, reachability, and boundary ownership survive private container changes
Artifact target: `test/interaction/pointer_session_test.dart`

### `single-terminal-pass-admission`: One retained-corridor terminal evaluation

Covers: `single-terminal-evaluation`
Impact: `EXTEND_COVERAGE`
Failure family: pointer-up can repeat terminal read or bounded geometry phases before preparation
Failure mode or stable invariant: one retained snapshot feeds one read/envelope/query/candidate/exact sequence and successful evaluation precedes preparation
Verification owner: terminal eraser entry-route work suite
Current verification gap: current work trace does not close the complete retained snapshot-to-preparation phase sequence across success, empty, and overflow outcomes
Failing witness: final state and existing terminal entry events can remain correct under duplicate hidden geometry evaluation
Durable and refactor-stable value: phase counts and order survive private algorithm decomposition without relying on timing
Artifact target: `test/interaction/terminal_eraser_entry_route_work_test.dart` and its existing fixture

### `preacceptance-no-partial-admission`: Retained terminal pre-acceptance no-partial behavior

Covers: `preacceptance-failures-are-no-partial`
Impact: `EXTEND_COVERAGE`
Failure family: retained-corridor stale, invalid, budget, or empty terminal results can reach preparation or mutate derived owners
Failure mode or stable invariant: every named pre-acceptance failure prepares nothing, changes no committed or derived owner, and cleans active eraser state
Verification owner: existing geometry eraser no-partial suite
Current verification gap: current owner focuses exact-budget overflow and does not cover the complete retained-corridor failure taxonomy and preparation exclusion
Failing witness: a partial preparation can be discarded before action emission and evade the current observable subset
Durable and refactor-stable value: pre-acceptance atomicity survives changes to candidate, projection, and cleanup internals
Artifact target: `test/geometry/eraser_exact_budget_no_partial_commit_test.dart` and its existing fixture

### `accepted-delivery-finality-admission`: Retained eraser resolver and delivery finality

Covers: `accepted-eraser-delivery-is-final`
Impact: `EXTEND_COVERAGE`
Failure family: retained-corridor resolver, cleanup, point-count, or post-consume delivery order can drift
Failure mode or stable invariant: prepare precedes resolver, rejection discards, acceptance consumes then cleans before delivery, retained count propagates unchanged, and listener failure cannot roll back
Verification owner: existing terminal eraser deletion resolver suite
Current verification gap: current owner does not exercise post-resample retained point-count and complete phase behavior together
Failing witness: a retained result can be recomputed or rolled back while short-corridor resolver cases remain green
Durable and refactor-stable value: public finality and temporal order survive private RuntimeRoot and intent refactors
Artifact target: `test/interaction/terminal_eraser_deletion_resolver_test.dart` and its existing fixture

### `capture-cleanup-lifecycle-admission`: Mutable eraser capture cleanup lifecycle

Covers: `capture-cleanup-covers-every-exit`
Impact: `EXTEND_COVERAGE`
Failure family: mutable capture reachability can survive a cancel or terminal phase or clear after externally observable delivery
Failure mode or stable invariant: the centralized cleanup owner releases capture/session reachability on cancel, dispose, prepared load success, mode/tool change, active-session `interactive=false`, stale/invalid/no-op terminal, resolver cancel/error, edit/preparation failure, success, and post-consume failure at the correct phase boundary
Verification owner: existing interaction routing, geometry no-partial, and terminal resolver suites
Current verification gap: current preview/session cleanup checks do not observe mutable capture reachability across all source-owned lifecycle, pre-callback, pre-consume, and post-consume exits
Failing witness: preview can disappear while an obsolete session shell retains the capture after load, resolver error, preparation failure, or another lifecycle exit
Durable and refactor-stable value: owner reachability and cleanup order survive private session and cleanup implementation changes
Artifact target: Existing eraser routing, no-partial, terminal resolver, load cleanup, tool settings, interactive-false, and dispose suites

### `cleanup-work-displacement-admission`: Cleanup performs no displaced corridor or geometry work

Covers: `cleanup-performs-no-displaced-work`
Impact: `EXTEND_COVERAGE`
Failure family: cleanup can release active capture correctly while hiding repeated retained-corridor or geometry work in the cleanup phase
Failure mode or stable invariant: every source-owned cleanup branch performs zero corridor traversal, snapshot, resample, read, envelope, query, candidate, and exact work while releasing active capture/session reachability
Verification owner: existing interaction routing, geometry no-partial, terminal resolver, load cleanup, tool settings, interactive-false, and dispose suites
Current verification gap: lifecycle evidence observes release and temporal order but cannot detect redundant corridor or geometry recomputation performed immediately before release
Failing witness: cleanup recomputes an envelope or snapshots the retained corridor and then clears the session, so lifecycle and final-output assertions still pass
Durable and refactor-stable value: phase-specific absence of displaced work survives private cleanup, session, corridor-storage, and geometry helper refactors
Artifact target: Existing eraser routing, no-partial, terminal resolver, load cleanup, tool settings, interactive-false, and dispose suites

### `retained-overlay-rendering-admission`: Post-resample eraser overlay rendering

Covers: `retained-corridors-render-through-existing-overlay`
Impact: `EXTEND_COVERAGE`
Failure family: a valid post-resample public corridor can disappear or bypass the existing overlay route
Failure mode or stable invariant: one-point, ordinary, and post-resample public eraser previews render visibly through the current planner and painter
Verification owner: existing surface overlay drawable policy suite
Current verification gap: existing owner covers one- and multi-point lists but not a real retained post-resample public preview
Failing witness: a planner equality or publication regression can drop only the post-resample case while helper drawing remains green
Durable and refactor-stable value: public preview-to-pixel continuity survives capture and planner refactors
Artifact target: `test/surface/overlay_drawable_policy_test.dart` and its existing fixture

### `preview-effect-isolation-admission`: Post-resample preview state isolation

Covers: `preview-publication-remains-isolated`
Impact: `EXTEND_COVERAGE`
Failure family: retained preview publication can mutate committed or derived runtime owners without emitting an action
Failure mode or stable invariant: initial, move, and post-resample preview publication affects only preview state/revision and overlay repaint
Verification owner: existing interaction public preview-state suite
Current verification gap: current owner does not observe a post-resample preview against all committed and derived owners
Failing witness: a hidden spatial or projection mutation can leave the action stream and final terminal result unchanged
Durable and refactor-stable value: preview-only isolation survives runtime publication and derived-state refactors
Artifact target: `test/interaction/preview_public_state_test.dart` and its existing fixture

## Verification Gate

| Check | Scope | Future command or evidence | Pass signal |
| --- | --- | --- | --- |
| Static analysis | All changed Dart production, test, and tool owners | `dart analyze` from repository root | Exit 0 |
| DCM analysis | Maintained package | `dcm analyze .` from repository root | Exit 0 |
| Interaction metrics | Changed interaction production owner | `dcm calculate-metrics lib/src/interaction` from repository root | Exit 0 with no unreviewed changed-owner finding; any local suppression follows AGENTS.md exact-metric justification rules |
| Runtime metrics | Changed runtime production owner | `dcm calculate-metrics lib/src/runtime` from repository root | Exit 0 with no unreviewed changed-owner finding |
| Public-contract metrics | Changed executable validation-limit owner | `dcm calculate-metrics lib/src/contracts/public` from repository root | Exit 0 with no unreviewed changed-owner finding |
| Interaction test metrics | Changed interaction proof owner | `dcm calculate-metrics test/interaction` from repository root | Exit 0 with no unreviewed changed-owner finding |
| Geometry test metrics | Changed geometry proof owner | `dcm calculate-metrics test/geometry` from repository root | Exit 0 with no unreviewed changed-owner finding |
| Surface test metrics | Changed surface proof owner | `dcm calculate-metrics test/surface` from repository root | Exit 0 with no unreviewed changed-owner finding |
| Runtime test metrics | Changed runtime cleanup proof owner | `dcm calculate-metrics test/runtime` from repository root | Exit 0 with no unreviewed changed-owner finding |
| API test metrics | Changed tool/settings lifecycle proof owner | `dcm calculate-metrics test/api` from repository root | Exit 0 with no unreviewed changed-owner finding |
| API-contract test metrics | Changed public compatibility proof owner | `dcm calculate-metrics test/api_contract` from repository root | Exit 0 with no unreviewed changed-owner finding |
| Guardrail test metrics | Changed guardrail proof owner and behavior-sensitive fixtures | `dcm calculate-metrics test/guardrails` from repository root | Exit 0 with no unreviewed changed-owner finding |
| Documentation generation | Changed contracts, diagrams, verification authority, and plan lifecycle | `dart run docs/tool/sync_generated_docs.dart --check` from repository root | Generated documentation is current |
| Documentation structure | All changed documentation | `dart run docs/tool/check_docs.dart` from repository root | Documentation check passes |
| Architecture graph closure | Changed architecture-owned interaction/runtime seams | `dart run tool/architecture_graph/check.dart` from repository root | Current graph closes the changed owners without an unapproved node or edge |
| Architecture view parity | Generated architecture views | `dart run tool/architecture_graph/generate_views.dart --check` from repository root | Generated views match the graph source |
| Canonical route integrity | Public eraser declarations, export registry/barrel, read-port closure, planner/painter, and RuntimeRoot delivery route | Direct inspection of the final diff plus the Matrix-owned public, consumer, overlay, preview, terminal, and guardrail evidence | No bypass, duplicate owner, stale move caller, hidden trajectory, or weakened canonical route remains |
| Residual work-budget closure | Cross-unit capture, publication, terminal, cleanup, and profile phases | Correlate the Matrix owner-work evidence with the final changed-owner diff | No unbounded work is retained or displaced outside the phase that owns it |
| Finding disposition | Whole implementation diff | Review findings are resolved at their owning source or reported as blockers before lifecycle closure | No unresolved correctness, compatibility, source-of-truth, temporal, atomicity, evidence, or work-budget finding remains |
| Diff hygiene | Whole change | `git diff --check` | Exit 0 |
| Lifecycle closure | Active contract and source design | After every outcome and required evidence completes, move this plan to `docs/history/plans/2026-08-27-eraser-corridor-hot-path.md` and move the linked design to `docs/history/designs/2026-08-27-eraser-corridor-hot-path.md` only when no active plan references it | No completed plan remains active; historical artifacts retain the same filename and no active reference is broken |
