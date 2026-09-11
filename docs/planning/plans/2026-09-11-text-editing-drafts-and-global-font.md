# Change Contract

## Goal

The maintained package supports one runtime-owned text-editing gesture through the public port and stock overlay: existing text can be admitted by ID, text and whole-block B/I/U remain one recoverable draft with stable Flutter input state, and confirmation atomically updates, creates, or policy-deletes one block through the existing request/lease boundary. Typed completion and compatible adapters expose the actual outcome, hosts can replay exact accepted facts for Undo/Redo, and an immutable runtime font default consistently drives layout and display without changing stored family values or Schema v1.

## Source Inputs

| Category | Source ID | Location or authority |
| --- | --- | --- |
| Design | `text-design` | docs/planning/designs/2026-09-11-text-editing-drafts-and-global-font.md |
| PLAN | none | none |
| Other | `s-001` | user request |
| Research | `s-002` | docs/history/research/2026-09-11-text-editing-drafts-and-global-font.md |
| Other | `s-003` | /tmp/iwb-text-design-codebase-design-SKILL.md |
| Other | `s-004` | AGENTS.md |
| Other | `s-005` | docs/README.md |
| Other | `s-006` | docs/planning/README.md |
| Other | `s-007` | docs/contracts/public_api_v1.md |
| Other | `s-008` | docs/architecture/01_runtime_ownership.md |
| Other | `s-009` | docs/architecture/02_package_boundaries.md |
| Other | `s-010` | docs/_registry/public_api_v1.yaml |
| Other | `s-011` | lib/src/contracts/public/canvas_text_editing.dart |
| Other | `s-012` | lib/src/contracts/public/canvas_commit.dart |
| Other | `s-013` | lib/src/contracts/public/canvas_runtime.dart |
| Other | `s-014` | lib/src/runtime/runtime_root.dart |
| Other | `s-015` | lib/src/interaction/interaction_engine.dart |
| Other | `s-016` | lib/src/interaction/interaction_request_registry.dart |
| Other | `s-017` | lib/src/surface/text_editing_overlay.dart |
| Other | `s-018` | lib/src/edit/edit_kernel.dart |
| Other | `s-019` | lib/src/edit/edit_session.dart |
| Other | `s-020` | lib/src/frame/frame_text_layout_measurer.dart |
| Other | `s-021` | lib/src/frame/render_element_record.dart |
| Other | `s-022` | lib/src/codec/schema_v1_encoder.dart |
| Other | `s-023` | docs/verification/tests.md |
| Other | `s-024` | docs/contracts/operation_matrix.md |
| Other | `s-025` | docs/contracts/edit_kernel.md |
| Other | `s-026` | tool/guardrails/src/public_api_registry.dart |
| Other | `s-027` | tool/guardrails/src/public_api_checks.dart |
| Other | `s-028` | tool/guardrails/src/text_surface_guardrail_checks.dart |
| Other | `s-029` | architecture/decisions/README.md |
| Other | `s-030` | architecture/decisions/ADR-0010-runtime-text-edit-session.md |
| Other | `s-031` | architecture/decisions/ADR-0003-store-finalized-edit-transactions.md |
| Other | `s-032` | architecture/decisions/ADR-0007-immutable-frame-planning-and-caches.md |
| Other | `s-033` | .agents/skills/architecture-design/SKILL.md |
| Other | `s-034` | docs/architecture/architecture_graph.yaml |
| Other | `s-035` | lib/src/contracts/public/canvas_actions.dart |
| Other | `s-036` | lib/src/runtime/runtime_interaction_read_adapter.dart |
| Other | `contract-skill` | .agents/skills/change-contract/SKILL.md |
| Other | `unit-criteria` | .agents/skills/change-contract/references/engineering-change-unit-criteria.md |
| Other | `runtime-config` | lib/src/runtime/runtime_config.dart |
| Other | `family-values` | lib/src/contracts/public/canvas_element.dart |
| Other | `family-limits` | lib/src/contracts/public/canvas_contract_limits.dart |
| Other | `frame-contract` | docs/contracts/frame_rendering.md |
| Other | `cache-contract` | docs/contracts/cache_policy.md |
| Other | `relationships` | docs/_registry/sections.yaml |
| Other | `doc-generator` | docs/tool/sync_generated_docs.dart |
| Other | `capsule-generator` | docs/tool/generate_context_capsules.dart |
| Other | `doc-checker` | docs/tool/check_docs.dart |
| Other | `runtime-proof` | test/runtime/fixtures/text_editing_port_fixture.dart |
| Other | `surface-proof` | test/surface/fixtures/text_editing_overlay_fixture.dart |
| Other | `frame-proof` | test/frame/fixtures/measured_text_layout_fixture.dart |
| Other | `delivery-proof` | test/runtime/fixtures/common_commit_delivery_fixture.dart |
| Other | `history-proof` | test/api_contract/commit_confirmation_history_public_behavior_test.dart |
| Other | `compile-proof` | test/api_contract/public_api_v1_compiles_as_written_test.dart |
| Other | `integration-proof` | test/api_contract/fixtures/public_integration_compile_fixture.dart |
| Other | `consumer-harness` | test/support/flutter_consumer_test_harness.dart |
| Other | `guardrail-route` | docs/verification/guardrails.md |
| Other | `materialized-placement` | lib/src/edit/draft_document.dart |
| Other | `sparse-placement` | lib/src/edit/sparse_edit_structure.dart |
| Other | `structural-placement` | lib/src/store/element_registry.dart |
| Other | `store-insertion` | lib/src/store/document_store_kernel.dart |
| Other | `placement-proof` | test/edit/fixtures/sparse_edit_session/sparse_edit_session_structure_fixture.dart |
| Other | `structural-proof` | test/store/fixtures/structural_editor_fixture.dart |
| Other | `draw-proof` | test/runtime/fixtures/draw_commit_delivery_fixture.dart |

## Classification

Profile: `BEHAVIOR_CHANGE`
Obligations: `PUBLIC_API_CHANGE`, `SOURCE_OF_TRUTH_SINGULARITY`, `SEAM_MIGRATION`, `SEQUENCED_MIGRATION_AND_RETIREMENT`, `TEMPORAL_SURFACE_CLOSURE`, `ALL_OR_NOTHING_FAILURE_BOUNDARY`, `NEGATIVE_PROOF_AND_FIXTURE_QUARANTINE`, `WORK_BUDGET_CLOSURE`

## Decision Trace

| Decision ID | Independent failure family | Source decision | Contract location | Acceptance or evidence target |
| --- | --- | --- | --- | --- |
| `guard-authority` | Admission and completion disagree because guard comparison is manually duplicated | D-001, D-002, D-004, A-018; AGENTS.md single-source rule | Boundaries / Source of Truth; Unit 1 | `guard-authority-shared` |
| `admission-by-id` | ID admission loses refusal distinctions or replaces an active session | R-003, D-002, A-001 | Unit 5 | `id-admission` |
| `overlay-policy` | Double-tap omits or overwrites captured empty policy | R-011, D-002, A-002 | Unit 6 | `overlay-policy-capture` |
| `draft-input` | Formatting destroys input selection, focus, or composition | R-004, D-003, A-003 | Unit 3 | `formatting-input-stability` |
| `draft-geometry` | Draft and accepted geometry use different formatting or anchors | D-003, A-004 | Units 3, 10 | `formatted-geometry` |
| `conflict-retention` | A stale draft is lost, revived, or overwrites external state | R-006, D-004, A-005 | Unit 1; consumers in Units 2, 5, 10 | `stale-retention` |
| `finish-semantics` | Typed or legacy finish misreports document/session outcome | R-005, D-005, A-006 | Units 2, 4, 10 | `typed-finish` |
| `draft-atomicity` | Formatting is omitted, split into commits, or net equality still mutates | R-007, D-006, A-007 | Unit 3 | `atomic-draft-update` |
| `empty-deletion` | Whitespace confirmation installs an update before deleting or loses original facts | R-009, R-010, D-006, A-008 | Unit 4 | `empty-policy-deletion` |
| `transient-creation` | New editing leaks a placeholder, layer, selection, dirty state or history | R-008, D-007, D-008, A-009 | Unit 10 | `transient-new-draft` |
| `creation-guard` | Creation retargets a destination or overwrites an occupied ID | D-007, A-010 | Unit 10 | `creation-destination-guard` |
| `creation-proposal` | Creation request lacks exact insertion/layer facts or invents a before element | D-008, A-011 | Unit 10 | `atomic-text-creation` |
| `delivery-order` | A terminal bypasses guarded preparation, lease order or identity-safe closure | R-015, D-009, A-012 | Units 2, 4, 10 | `common-terminal-delivery` |
| `host-history` | Undo/Redo cannot reconstruct one gesture from accepted public facts | R-013, D-009, A-013 | Unit 11 | `host-gesture-history` |
| `effective-font` | Default family differs between layout, cache, paint and overlay or leaks across runtimes | R-012, D-010, A-014 | Unit 7; creation consumer in Unit 10 | `effective-font-consistency` |
| `stored-font` | Inherited family becomes persistent element or schema data | R-014, D-010, A-015 | Units 7, 10 | `stored-family-preserved` |
| `public-migration` | Declarations, exports, implementations or exhaustive consumers cannot migrate as documented | R-014, D-012, I-001, I-002, A-016 | Public seam closures in Units 2–7 and 10 | `public-migration-evidence` |
| `durable-handoff` | Current semantic owners or generated relationships contradict implemented behavior | R-017, D-012, I-003, I-004, I-005, A-017 | Owning documentation closures in Units 1–11 | `durable-handoff-evidence` |
| `owner-direction` | Draft, input, commit or font authority moves to a forbidden owner | D-001, D-011, A-018; package boundaries | Boundaries; Verification Gate / Ownership closure | `ownership-evidence` |
| `action-meaning` | Creation is emitted as an edit or existing modifications lose edit payload meaning | R-018, D-009, D-012, A-019 | Units 3, 10 | `text-action-meaning` |
| `scope-exclusions` | Implementation absorbs host UI/history, dynamic fonts or another engine owner | R-002, R-013, R-016, D-011; ADR Impact none | Boundaries / Out of Scope | `ownership-evidence` |
| `sparse-work` | Sparse text work is displaced into eager document projection or cleanup | R-015; edit_kernel.md sparse preparation; cache_policy.md projection rules | Boundaries / Work Budget And Cost Displacement | `text-work-evidence` |
| `unit-size` | Independent algorithms are merged or mandatory proof is deferred | user request; engineering-change-unit-criteria.md | Execution Units; Boundaries / Order Constraints | `ownership-evidence` |
| `architecture-reentry` | Implementation continues after an accepted stop condition invalidates the design | H-001, H-002, H-003, H-004 | Verification Gate / Finding disposition | `durable-handoff-evidence` |
| `artifact-lifecycle` | Planning becomes a second current behavior owner or closes prematurely | AGENTS.md; docs/planning/README.md; R-017 | Verification Gate / Lifecycle closure | `durable-handoff-evidence` |
| `insertion-destination-authority` | New admission or existing edit/replay selects a different default destination | D-007, D-011; AGENTS.md single-source rule; user small-unit constraint | Unit 8; consumed by Unit 10 | `destination-selection-evidence` |
| `prepared-insertion-lifetime` | Creation duplicates or diverges from the existing prepared insertion lifetime | D-008, D-009; D-001 private decomposition; user small-unit constraint | Unit 9; consumed by Unit 10 | `prepared-insertion-evidence` |
| `new-start-admission-policy` | startNew bypasses read-only or replaces an occupied session slot | D-002, D-007, R-008 | Unit 10 | `new-admission-evidence` |
| `preserve-action-ordinals` | Inserting createText shifts an existing CanvasActionType ordinal | D-012, R-014 | Unit 10 | `action-ordinal-evidence` |

## Repository Evidence

- `lib/src/contracts/public/canvas_text_editing.dart:108` / session and port: the final session exposes live text and bool/void completion; the port is an abstract interface -> additions must land with the runtime constructor, port implementation, facade exports and external implementation examples.
- `lib/src/interaction/interaction_engine.dart:199` / guard terminal: the existing public-command guard consumes known invalid requests and uses a local comparator -> retain consumption at the command terminal while exposing shared non-consuming validity to session consumers.
- `lib/src/runtime/runtime_root.dart:4809` / manual guard mirror: runtime repeats the interaction comparator; admission and isStale consume that copy -> remove the copied policy in the stale-lifecycle unit using existing interaction facts/owner direction, without making reads consume requests.
- `lib/src/runtime/runtime_interaction_read_adapter.dart:483` / eligible current facts: hidden and non-content targets produce missing commit facts; other kinds remain distinguishable in current frame facts -> ID admission must distinguish unavailable from notFound/unsupportedType using real facts, without hit testing.
- `lib/src/runtime/runtime_root.dart:4698` / consumed-request cleanup: a consumed stale active request currently dismisses its session -> replace this terminal behavior while keeping explicit reset dismissal.
- `lib/src/runtime/runtime_root.dart:1511` / text completion: current commit validates, guards, text-compares, prepares, resolves and delivers a text-only update -> typed finish and formatting must deepen this path rather than introduce another terminal algorithm.
- `lib/src/runtime/runtime_root.dart:1583` / prepared pair: the exact before/after pair is sealed from the accepted sparse candidate before resolver publication -> extend the same proposal with draft formatting and preserve full non-null text values.
- `lib/src/runtime/runtime_root.dart:1438` / direct deletion: removal already projects original entries and prepares through deferred EditKernel -> empty policy reuses removal eligibility and the one deletion request, including original placement.
- `lib/src/edit/edit_kernel.dart:170` / deferred preparation: the edit callback is closed in finally before the prepared package escapes -> new sessions retain seed/draft/placement only, never a live CanvasEdit.
- `lib/src/edit/edit_session.dart:630` / insertion: addElement admits the destination and sparse insertion together -> creation uses existing insertion normalization and atomic layer admission.
- `lib/src/edit/edit_session.dart:1074` / default destination: omitted placement uses the last content layer or default-layer -> capture that owner-selected destination at startNew, without copying its default constant into runtime.
- `lib/src/runtime/runtime_root.dart:3479` / prepared insertion facts: existing insertion projection obtains exact entry, layer index and createsLayer from a prepared candidate -> reuse that current capability for creation facts; do not add a second placement inventory or public projection.
- `lib/src/surface/text_editing_overlay.dart:239` / editing identity: the overlay replaces input objects only on a new session identity -> formatting notification retains the session and editor objects.
- `lib/src/surface/text_editing_overlay.dart:345` / controller synchronization: equal text leaves the editing value alone; a different string collapses selection and clears composition -> preserve that distinction for formatting-only versus programmatic text changes.
- `lib/src/surface/text_editing_overlay.dart:222` / double-tap consumer: stock context subscription currently forwards only the request -> overlay policy must be forwarded on actual auto-admission and captured once.
- `lib/src/runtime/runtime_root.dart:819` / font projection: frame facts and initial measurement currently forward the stored nullable family -> resolve one effective family before both handoffs.
- `lib/src/frame/frame_text_layout_measurer.dart:80` / layout/cache owner: cache key and TextPainter consume the same measured input family and formatting -> effective family travels in that input, not a surface-only resolver.
- `lib/src/frame/render_element_record.dart:265` / paint consumer: render rows build layout inputs and keys from frame facts -> keep derived effective values consistent with measurement and cached paint.
- `lib/src/contracts/public/canvas_element.dart:208` / font validation: per-element validation consumes the canonical family-length limit -> runtime default uses these constraints and their existing limit, not a copied numeric policy.
- `lib/src/codec/schema_v1_encoder.dart:160` / storage consumer: encoding writes the element family directly -> confirmation must retain the original nullable stored family separately from effective render input.
- `lib/src/contracts/public/canvas_actions.dart:10` / action compatibility: editText is the final existing enum value and its payload contains before/after lengths -> append createText and expose a creation-only payload without shifting existing enum indices.
- `tool/guardrails/src/public_api_registry.dart:7` / name authority consumer: export checking reads canonical YAML directly -> update only that registry and actual exports, never a test-owned expected-name copy.
- `tool/guardrails/src/public_api_checks.dart:15` / namespace parity: actual resolved exports are compared with canonical names -> retain this owner for migration coverage instead of weakening or replacing it.
- `test/api_contract/commit_confirmation_history_public_behavior_test.dart:1` / external history owner: public-only host replay already uses the shared Flutter consumer harness -> extend this owner for the one-gesture text lifecycle; no engine history or new runner.
- `docs/verification/tests.md:492` / proof shape: in-package behavior and external access have different harness rules -> keep runtime/surface/frame behavior in their owning areas and host access in the existing consumer proof.
- `docs/architecture/02_package_boundaries.md:185` / production structure: contracts and existing owner directories establish allowed implementation directions -> private collaborators stay within those nodes; no new graph node, public service, part file or implementation import into contracts.
- `docs/tool/sync_generated_docs.dart:5` / documentation consumer: navigation is generated from structured registries -> update relationships only when actual proof relationships change, then regenerate through the existing tool.
- `docs/tool/generate_context_capsules.dart:5` / context consumer: context capsules consume sections.yaml -> generated context remains derived, with no manually edited relationship mirror.
- `lib/src/edit/draft_document.dart:606` / materialized insertion destination: default choice and ensureLayer occur together -> isolate the non-mutating decision while preserving materialized insertion results and effects.
- `lib/src/edit/edit_session.dart:657` / sparse insertion destination: named/omitted selection repeats the same default and may create a layer -> the same decision must serve sparse insertion and later transient admission.
- `lib/src/store/element_registry.dart:929` / structural replay consumer: target-layer resolution repeats the default choice -> migrate this direct policy consumer mechanically rather than leaving a divergent manual default mirror.
- `lib/src/edit/sparse_edit_structure.dart:113` / current last-layer read: lastLayerId opens a transaction-local order -> the new admission query must read current structural facts without opening an edit or installing a layer; existing edit-local reads still observe their own current order.
- `lib/src/runtime/runtime_root.dart:3423` / stroke insertion preparation: the route constructs an element, then repeats deferred add/entry/action sealing -> separate the already-used insertion preparation from route-specific element/action construction.
- `lib/src/runtime/runtime_root.dart:3617` / line insertion preparation: the same deferred add/entry/action sealing sequence has a second active consumer -> both existing routes use the consolidated preparation immediately, before text creation is added.

## Boundaries

Owner: RuntimeRoot and its existing CanvasTextEditingPort own the active session and terminal orchestration; InteractionEngine/InteractionRequestRegistry own issued guard facts; EditKernel and Store own prepared finalization and atomic installation; frame owns measurement and immutable paint inputs; surface owns Flutter input objects. Public declarations stay in contracts/public with api facades; no new owner node is admitted.

In Scope: All R-003–R-014 and R-018 behavior, D-001–D-012 commitments, and I-001–I-005 durable transitions from text-design. Existing-session admission, stale retention, typed completion, draft formatting, policy deletion, transient creation and default family use existing owners. Every A-001–A-019 family has its own route below. Exact new result/policy/origin identifiers remain implementation-owned where the design leaves them open.

Out of Scope: R-016 and D-011 exclude engine keypad protocol, runtime caret/selection/composition mirrors, generic long-lived document transactions, merge/force overwrite, dynamic font setter/loader, font asset generation, persistent document defaults, engine Undo, external Numicod implementation, a new graph node, generic scanner or benchmark system. Host seed placement, keypad UI, focus choices, save and dirty/history storage remain host-owned. ADR Impact is none; retained ADR bodies are not rewritten.

Source of Truth: Store holds committed elements; one runtime draft retains immutable base/seed plus text/B/I/U and captured policy/placement, not a second document. Immutable base/seed and effective frame values have distinct purposes: the base/seed supplies stored fields and conflict/anchor basis until session close, while effective inputs feed measurement/display and are never serialized. Replace the existing runtime copy of guard comparison with consumption of the interaction-owned validity rule over the same issued/current facts; validity observation remains non-consuming, and existing command retirement remains explicit. This is deduplication within D-001/D-004, not new guard semantics. The stale latch or retained immutable facts may outlive request retirement only to preserve readable, permanently noncommittable input. Default-family fallback resolves once at runtime handoff; all frame/session/surface consumers use the effective value. Existing addElement destination admission/normalization owns defaults. Unit 8 separates its non-mutating decision from layer installation and replaces the currently repeated default-choice logic/literals in sparse edit, materialized edit and structural replay with one owning rule. Edit/runtime consumers use current owner facts and the same rule; they do not copy a default-layer value. Structural replay changes are limited to consuming the shared existing rule; Store candidate finalization, order normalization and install algorithms are unchanged. New-session admission later consumes the admitted read-only result without installing anything. Public semantic signatures belong to public_api_v1.md, exported names to public_api_v1.yaml, relationships to sections.yaml, and generated navigation/capsules to their generators. Compile examples exercise those owners; they do not own copied inventories.

Compatibility: Keep old bool commit, void dismiss/dismissActive, context candidate/start and direct commitTextEdit call shapes; optional empty policy defaults to keepElement. Typed success/refusal/result additions and session origin are additive for callers. Stale retention intentionally replaces automatic draft loss. External CanvasTextEditingPort implementations and exhaustive CanvasCommitRequest, CanvasActionType and CanvasActionPayload switches require the concrete D-012 migration. New public types, facade exports, canonical registry, in-repository implementations/doubles, compile-as-written examples and exhaustive consumers land atomically with each added member/variant. Append createText after existing enum values; existing editText and before/after payload fields retain meaning. Existing text request before/after remain non-null CanvasTextElement values. Per-element family and Schema v1 are unchanged; null default preserves Flutter fallback. Low-level addElement remains immediate. Validation, disposed and reentrancy errors keep existing categories; they are not all collapsed into rejected.

Order Constraints: Each unit is one reviewable result with its own falsifying owner proof and current documentation update before it lands. Producer/consumer API changes are compile-atomic inside the owning unit, never a terminal catch-up unit. Replaced local algorithms are removed with their replacement. The eleven units are necessary to keep destination selection, prepared insertion, new-origin activation and external replay separately reviewable while preserving one gesture's shared draft/finish/lease boundary. Units 8 and 9 immediately simplify current insertion consumers; neither leaves unused scaffolding or exposes an unfinished text API. Unit 10 consumes their completed facts and preparation path, plus the already-complete draft/geometry/finish capabilities: it must not implement destination policy, sparse insertion projection or another delivery algorithm. Its single result is activation of the new-origin text lifecycle. If that cutover still needs an independent algorithm, move that work to its existing owning unit before implementation rather than enlarging Unit 10. Units 9–11 share real produced/consumed boundaries; separate contracts would duplicate that migration context. No unit may absorb unrelated work to meet a count or metric. Unit fields own changes; the Matrix owns proof placement and future commands. A Matrix row spanning several units is extended and run in each producing unit for the outcomes introduced there, never deferred until the last referenced unit.
Temporal Surface Closure: D-002 admission checks read-only and the active slot first; only a valid same-target session is reused, with its original policy. D-004 stale is irreversible for mutation; draft reads survive, suppression stops, and retries cannot revive the session. Resolver refusal is retryable. Explicit successful load, runtime/overlay disposal/replacement and enabling read-only retain dismissal; failed load preserves the session. D-005 cancellation does not need a live guard. D-009 guards resolver and lease callbacks against mutation, ID generation, nested finish and disposal before effects while permitting reads/bookkeeping. After install, existing spatial/resource/frame delivery precedes public state, lease.committed, one action, observer and guard release; only then notify matching session closure. Cleanup must never clear a session started by that notification. Post-install contained callback failures do not change success or abort a committed lease.

All-Or-Nothing Failure Boundary: Guards and input validation precede operation selection; opted-in whitespace deletion precedes semantic no-op comparison. Changed update/create/delete builds one closed prepared package and exact immutable request before resolver entry, consumes once only after compatible acceptance, and never installs speculative draft data. Cancel, incompatibility, resolver failure or pre-install failure leave document/selection and history unchanged; a returned lease is aborted exactly once, no lease means no terminal callback. Existing stale drafts remain readable; valid rejected/preparation-failed drafts remain retryable. New empty confirmation closes unchanged before prepare/resolver. Accepted creation includes any operation-created layer in the same installation. Existing deletion installs no prior empty update and adds no automatic layer cleanup.

Negative Proof And Fixture Quarantine: Invalid/stale cases enter through actual public target edits, same-ID replacement, visibility/location changes, load/reset and destination/ID changes. Verify unchanged committed values/revisions, resolver/action silence and retained draft together. Test input cannot become a production guard constant, registry inventory or parallel policy. Existing failure seams may observe preparation/consume/callback behavior; no generic fault-injection framework or private-helper assertions are admitted. Different-string updateText retains existing selection behavior; formatting-only evidence includes live selection/composition and continued input.

Bounded Recognition Scope: This is behavioral work, not a new analyzer or recognition architecture. Existing export/import, graph, documentation and text-measurement checks retain their current bounded owners and accepted scope; no new parser, syntax heuristic or exact-name allowlist is added. Source queries establish ownership and absence only, never runtime behavior.

Work Budget And Cost Displacement: No new performance target or benchmark is introduced. Preserve the existing sparse-edit and cache-policy constraints consumed by R-015: construction/start/reset stores transient text-session/config facts without whole-document projection; ordinary import/load is not redesigned. Draft mutation and stale queries address the session/target and frame layout input, not a scene scan. Update/create/delete preparation uses addressed accepted facts and existing sparse insertion/removal normalization; it must not materialize CanvasDocument to manufacture request or destination facts. Freeze/install consumes the prepared package once with no repeated normalization/projection. Query/read may build a public document projection only when the host explicitly requests it; frame cache misses remain local to the existing current-record input and capacities. Cleanup/cancel/rollback discards transient/prepared state and cannot move projection, remeasurement of the scene, or a compensating document mutation into cleanup. Existing owner-authorized structural normalization and explicit load/import work remain permitted at their original phases; no new whole-owner pass is authorized. Observe these phase boundaries with existing owner probes and source inspection, not wall-clock thresholds.

## Execution Units

### [ ] Unit 1: Retain stale drafts through the shared guard boundary

Owner: Runtime text session lifecycle and interaction guard validity
Boundary: D-001/D-004 existing-target guard comparison and retention only
Verification Profile: `BEHAVIOR_CHANGE`
Change: Unify the duplicated guard comparison through the existing interaction facts boundary without making session reads consume requests. Preserve captured/current-fact comparison as one policy, leaving exact private query/helper shape open. Latch stale mutation refusal and preserve live text/style/last geometry across consumed-request cleanup and session bool/direct-command completion. Stop stale suppression, block draft mutation/revival, retain explicit cancellation and the existing explicit reset behavior. Update public stale semantics, runtime ownership, operation matrix, frame suppression contract and associated proof relationships in this same change.

Acceptance Outcomes:

| Outcome key | Starting state | System action | Observable result | Required side conditions |
| --- | --- | --- | --- | --- |
| `guard-authority-shared` | Issued text guard facts used by both session observation/admission and direct command completion | Read validity and attempt completion after matching or conflicting public edits | All consumers apply one guard rule; observation retains request lifetime while command retirement remains explicit | No duplicate comparator, generation authority or document-revision-only guard; current visible content eligibility remains required |
| `stale-retention` | An existing draft followed by target text/style change, removal, same-ID replacement, kind/visibility/location or epoch invalidation | Read the draft, update it, commit through session/direct entrypoints, retry start/commit, then explicitly cancel | The same draft text/style/geometry remains readable, immutable after staleness and noncommittable; explicit cancel clears it | No resolver/action/document overwrite; stale scene content is unsuppressed; unrelated element edits still allow completion; successful load/read-only/disposal resets dismiss, failed load preserves |
| `stale-durable-closure` | The behavior or seam description changed by this unit | Publish its current owner documentation and actual proof relationships | Applicable I-001–I-005 owner passages agree with the implemented behavior; changed generated relationships resolve to real owners | No pending semantic documentation debt; design/history/tests stay non-authoritative; only changed relationships are regenerated |
| `stale-ownership-closure` | The owners changed by this unit | Install this unit's behavior and direct consumer changes | Actual dependency and state ownership remain within D-001/D-011 and the declared unit boundary | No competing guard/default/placement/committed/input authority, new graph node, forbidden import or independent extra algorithm; necessary proof and documentation land with this unit |
| `stale-work-closure` | The text lifecycle phases changed by this unit | Admit/read/update a draft or prepare/install/clean up a terminal as applicable to this unit | No implicit document projection, displaced scene work or compensating mutation; changed terminals consume one prepared package | Explicit host document reads are outside measured regions; existing owner-authorized normalization stays in its original phase |

Depends On: None

### [ ] Unit 2: Expose typed finish through compatible adapters

Owner: CanvasTextEditingPort terminal API and runtime implementation
Boundary: D-005 existing-target result distinctions; no creation/deletion branch yet
Verification Profile: `BEHAVIOR_CHANGE`
Change: Add finishActive with explicit commit/cancel and the six required result distinctions. Route session bool commit, dismiss/dismissActive, direct commitTextEdit with a matching session, and stock overlay finish through the common terminal. Preserve direct text-only behavior without a matching session and existing error categories. Land declarations, exports, registry admission, port implementer changes, compile examples and public terminal documentation together.

Acceptance Outcomes:

| Outcome key | Starting state | System action | Observable result | Required side conditions |
| --- | --- | --- | --- | --- |
| `typed-finish` | Existing active, absent, unchanged, rejected or stale sessions | Finish by explicit choice and exercise matching legacy/overlay adapters | committed, unchanged, cancelled, rejected, stale and noActiveSession describe actual document and session outcomes; bool maps only committed/unchanged to true | Cancelled/unchanged close without document work; rejected remains retryable; stale remains readable; direct text argument remains effective; errors retain categories |
| `common-terminal-delivery` | An existing request-originated changed text edit, with and without a matching active session | Accept, refuse, or fail completion through the common typed/legacy terminal | Exact before/after proposal is observed before one install; accepted delivery preserves state/lease/action/observer/close order | Returned leases terminate once; pre-install failure installs nothing; post-install errors cannot abort; a close listener can start a surviving replacement session |
| `finish-public-closure` | The public seam changed by this unit | Compile retained and migrated external call patterns against the public barrel | New readable types/members are exported and registered; all implementations and exhaustive consumers agree with actual declarations | Old call shapes/defaults and documented exceptions remain valid; migration documentation is concrete and no manual export inventory is introduced |
| `finish-durable-closure` | The behavior or seam description changed by this unit | Publish its current owner documentation and actual proof relationships | Applicable I-001–I-005 owner passages agree with the implemented behavior; changed generated relationships resolve to real owners | No pending semantic documentation debt; design/history/tests stay non-authoritative; only changed relationships are regenerated |
| `finish-ownership-closure` | The owners changed by this unit | Install this unit's behavior and direct consumer changes | Actual dependency and state ownership remain within D-001/D-011 and the declared unit boundary | No competing guard/default/placement/committed/input authority, new graph node, forbidden import or independent extra algorithm; necessary proof and documentation land with this unit |
| `finish-work-closure` | The text lifecycle phases changed by this unit | Admit/read/update a draft or prepare/install/clean up a terminal as applicable to this unit | No implicit document projection, displaced scene work or compensating mutation; changed terminals consume one prepared package | Explicit host document reads are outside measured regions; existing owner-authorized normalization stays in its original phase |

Depends On:
- Unit 1 — produces: retained stale session lifecycle; consumed as: stale and cancellation result semantics

### [ ] Unit 3: Commit text and formatting as one draft

Owner: Runtime draft and frame geometry with stock surface input preservation
Boundary: D-003/D-006 one existing-target text/B/I/U candidate
Verification Profile: `BEHAVIOR_CHANGE`
Change: Add partial updateFormatting to the runtime session and project style and frame-measured geometry from the same draft. Keep session/controller/focus identities and notify the existing listenable. Extend the existing accepted update with text, supplied B/I/U and matching anchor transform; compare the complete draft against the base before resolver work. Matching direct commits consume draft formatting; unassociated requests remain text-only. Update the public session surface, exports when needed, compile consumers and draft/frame/cache/edit documentation with the behavior.

Acceptance Outcomes:

| Outcome key | Starting state | System action | Observable result | Required side conditions |
| --- | --- | --- | --- | --- |
| `formatting-input-stability` | A focused stock editor with typed text, a noncollapsed selection and composing range | Change individual and combined B/I/U flags, then continue typing | The session, editing value, focus, selection/caret and composing range survive formatting; omitted flags retain their values | Document text/style and document revision stay unchanged during the draft; formatting does not steal host focus; commitOnFocusLoss and different-string updateText keep their prior semantics |
| `formatting-stale-retention` | The existing session has become stale before a formatting call | Apply partial B/I/U updates and retry confirmation | The same last draft text/style/geometry remains unchanged and completion remains stale | No document mutation, resolver/action or session replacement; explicit cancellation remains available |
| `formatted-geometry` | An existing draft with metrics that distinguish normal/bold/italic text | Change formatting only or text plus formatting, then accept | Draft measured bounds and world anchor match the accepted frame geometry | Frame remains sole measurer; accepted transform uses draft style; base anchor is preserved; no overlay TextPainter |
| `atomic-draft-update` | An existing base text/B/I/U value | Confirm changed text/style, cancel, or toggle text/B/I/U back to base and confirm | A changed candidate installs one complete update; cancellation and net equality install nothing and issue no resolver request/action/history | Full before/after fields remain exact and non-null; style-only change is real; no intermediate commits or revision increments |
| `existing-edit-action` | An accepted text-only or style-only existing-block update | Observe the finalized action | Exactly one editText with CanvasTextEditActionPayload uses the requestId and actual before/after text lengths | No createText; action follows accepted state and lease; unsuccessful/no-op/cancelled attempts stay silent |
| `formatting-public-closure` | The public seam changed by this unit | Compile retained and migrated external call patterns against the public barrel | New readable types/members are exported and registered; all implementations and exhaustive consumers agree with actual declarations | Old call shapes/defaults and documented exceptions remain valid; migration documentation is concrete and no manual export inventory is introduced |
| `formatting-durable-closure` | The behavior or seam description changed by this unit | Publish its current owner documentation and actual proof relationships | Applicable I-001–I-005 owner passages agree with the implemented behavior; changed generated relationships resolve to real owners | No pending semantic documentation debt; design/history/tests stay non-authoritative; only changed relationships are regenerated |
| `formatting-ownership-closure` | The owners changed by this unit | Install this unit's behavior and direct consumer changes | Actual dependency and state ownership remain within D-001/D-011 and the declared unit boundary | No competing guard/default/placement/committed/input authority, new graph node, forbidden import or independent extra algorithm; necessary proof and documentation land with this unit |
| `formatting-work-closure` | The text lifecycle phases changed by this unit | Admit/read/update a draft or prepare/install/clean up a terminal as applicable to this unit | No implicit document projection, displaced scene work or compensating mutation; changed terminals consume one prepared package | Explicit host document reads are outside measured regions; existing owner-authorized normalization stays in its original phase |

Depends On:
- Unit 2 — produces: common typed existing completion; consumed as: atomic draft candidate and compatible adapters

### [ ] Unit 4: Select one deletion for opted-in empty existing text

Owner: Runtime existing-text operation selection and direct-removal preparation
Boundary: D-006 captured empty policy and deletion precedence
Verification Profile: `BEHAVIOR_CHANGE`
Change: Add the captured keepElement/deleteElement policy with keepElement default to existing candidate/context/start admission, and select deletion for trim().isEmpty before equal-draft handling. Reuse original-entry removal eligibility and deferred preparation; refusal/ineligibility reports rejected and retains original plus draft. Preserve compatible keepElement update/no-op behavior and add no empty-layer cleanup. Update policy declaration/facade/registry, every affected port implementation, compile examples and public/operation/edit contracts atomically.

Acceptance Outcomes:

| Outcome key | Starting state | System action | Observable result | Required side conditions |
| --- | --- | --- | --- | --- |
| `empty-policy-deletion` | An existing block admitted with deleteElement or default keepElement, including originally empty and non-deletable cases | Confirm empty, spaces or newlines after text/format changes | deleteElement submits one original CanvasDeleteCommitRequest and removes once when accepted; keepElement follows normal update/no-op | Original text/style/placement retained in request; no preceding update; original empty text still selects deletion; rejected/ineligible preserves both states; one deleteElements action and one lease only on accepted deletion |
| `deletion-terminal-delivery` | A policy-selected deletion with a matching text session | Accept, refuse, throw in resolver or fail before install; observe closure listeners | Deletion follows the established guarded delivery and typed/legacy outcomes with identity-safe session close | No pre-install state/selection leak; no aborted lease after install; callbacks reject mutation before effects; refusal stays retryable |
| `empty-policy-public-closure` | The public seam changed by this unit | Compile retained and migrated external call patterns against the public barrel | New readable types/members are exported and registered; all implementations and exhaustive consumers agree with actual declarations | Old call shapes/defaults and documented exceptions remain valid; migration documentation is concrete and no manual export inventory is introduced |
| `empty-policy-durable-closure` | The behavior or seam description changed by this unit | Publish its current owner documentation and actual proof relationships | Applicable I-001–I-005 owner passages agree with the implemented behavior; changed generated relationships resolve to real owners | No pending semantic documentation debt; design/history/tests stay non-authoritative; only changed relationships are regenerated |
| `empty-policy-ownership-closure` | The owners changed by this unit | Install this unit's behavior and direct consumer changes | Actual dependency and state ownership remain within D-001/D-011 and the declared unit boundary | No competing guard/default/placement/committed/input authority, new graph node, forbidden import or independent extra algorithm; necessary proof and documentation land with this unit |
| `empty-policy-work-closure` | The text lifecycle phases changed by this unit | Admit/read/update a draft or prepare/install/clean up a terminal as applicable to this unit | No implicit document projection, displaced scene work or compensating mutation; changed terminals consume one prepared package | Explicit host document reads are outside measured regions; existing owner-authorized normalization stays in its original phase |

Depends On:
- Unit 2 — produces: typed finish outcomes; consumed as: committed/rejected deletion terminal
- Unit 3 — produces: complete draft comparison; consumed as: deletion precedence over net no-op

### [ ] Unit 5: Admit existing text directly by ID

Owner: Runtime text admission and interaction request issuance/read facts
Boundary: D-002 typed ID route and parity with existing admission
Verification Profile: `BEHAVIOR_CHANGE`
Change: Add startForElement for visible empty/nonempty text without hit coordinates. Obtain current kind/location/visibility and issue real guarded identity without emitting a context event. Check read-only and active slot first, preserve captured policy for valid same-target reuse, reject stale same-target and any active different session. Make context/candidate/start routes consume the same admission policy and retain nullable compatibility. Land the full public/implementation/export/registry/compile and admission documentation seam together.

Acceptance Outcomes:

| Outcome key | Starting state | System action | Observable result | Required side conditions |
| --- | --- | --- | --- | --- |
| `id-admission` | Visible empty/nonempty, missing, wrong-type, hidden/non-content, read-only, same-target, stale-target and active-other states | Call startForElement and equivalent available context/candidate/start routes | Typed success carries the active session; refusals distinguish readOnly, anotherSessionActive, stale, notFound, unsupportedType and unavailable; only valid same-target identity is reused | No document mutation, hit-test dependency or fabricated context event; same-target policy is unchanged; different/stale active session is never replaced; legacy nullable route semantics remain compatible |
| `admission-public-closure` | The public seam changed by this unit | Compile retained and migrated external call patterns against the public barrel | New readable types/members are exported and registered; all implementations and exhaustive consumers agree with actual declarations | Old call shapes/defaults and documented exceptions remain valid; migration documentation is concrete and no manual export inventory is introduced |
| `admission-durable-closure` | The behavior or seam description changed by this unit | Publish its current owner documentation and actual proof relationships | Applicable I-001–I-005 owner passages agree with the implemented behavior; changed generated relationships resolve to real owners | No pending semantic documentation debt; design/history/tests stay non-authoritative; only changed relationships are regenerated |
| `admission-ownership-closure` | The owners changed by this unit | Install this unit's behavior and direct consumer changes | Actual dependency and state ownership remain within D-001/D-011 and the declared unit boundary | No competing guard/default/placement/committed/input authority, new graph node, forbidden import or independent extra algorithm; necessary proof and documentation land with this unit |
| `admission-work-closure` | The text lifecycle phases changed by this unit | Admit/read/update a draft or prepare/install/clean up a terminal as applicable to this unit | No implicit document projection, displaced scene work or compensating mutation; changed terminals consume one prepared package | Explicit host document reads are outside measured regions; existing owner-authorized normalization stays in its original phase |

Depends On:
- Unit 1 — produces: shared validity and retained stale identity; consumed as: same-target admission revalidation
- Unit 4 — produces: captured empty policy; consumed as: ID and context policy parity

### [ ] Unit 6: Forward stock double-tap empty policy

Owner: CanvasTextEditingOverlay admission subscription
Boundary: R-011/D-002 stock surface policy capture
Verification Profile: `BEHAVIOR_CHANGE`
Change: Expose emptyTextBehavior on the stock overlay with keepElement default and forward it on actual double-tap auto-admission. Preserve already-captured session policy when overlay properties change or admission repeats. Update overlay signature documentation and compile examples, including a matched overlay/startForElement configuration example.

Acceptance Outcomes:

| Outcome key | Starting state | System action | Observable result | Required side conditions |
| --- | --- | --- | --- | --- |
| `overlay-policy-capture` | Stock double-tap and explicit ID admission with matching or omitted empty policy | Auto-start through real context delivery, change overlay policy while active, then confirm whitespace | Both routes apply the same captured policy; omitted policy keeps the block; property changes and repeat starts cannot rewrite the active policy | Traverse the real context subscription and terminal; no extra session replacement, update-before-delete or document draft mutation |
| `overlay-public-closure` | The public seam changed by this unit | Compile retained and migrated external call patterns against the public barrel | New readable types/members are exported and registered; all implementations and exhaustive consumers agree with actual declarations | Old call shapes/defaults and documented exceptions remain valid; migration documentation is concrete and no manual export inventory is introduced |
| `overlay-durable-closure` | The behavior or seam description changed by this unit | Publish its current owner documentation and actual proof relationships | Applicable I-001–I-005 owner passages agree with the implemented behavior; changed generated relationships resolve to real owners | No pending semantic documentation debt; design/history/tests stay non-authoritative; only changed relationships are regenerated |
| `overlay-ownership-closure` | The owners changed by this unit | Install this unit's behavior and direct consumer changes | Actual dependency and state ownership remain within D-001/D-011 and the declared unit boundary | No competing guard/default/placement/committed/input authority, new graph node, forbidden import or independent extra algorithm; necessary proof and documentation land with this unit |

Depends On:
- Unit 5 — produces: common ID/context admission; consumed as: stock double-tap admission
- Unit 4 — produces: complete empty-policy deletion behavior; consumed as: confirmation through stock overlay

### [ ] Unit 7: Resolve the runtime font default before layout

Owner: Runtime config and effective frame/session text input
Boundary: D-010 immutable family fallback across existing consumers
Verification Profile: `BEHAVIOR_CHANGE`
Change: Add nullable immutable defaultFontFamily and validate using existing per-element constraints and canonical limits. Resolve stored family or runtime fallback through one runtime policy before initial measurement/frame projection; draft, render rows, layout keys, cached painters, TextStyle and StrutStyle consume effective input. Keep original nullable family in base/seed and accepted updates. Update config consumers/compile examples and public/frame/cache semantics; no setter, theme lookup, persistence or font loader.

Acceptance Outcomes:

| Outcome key | Starting state | System action | Observable result | Required side conditions |
| --- | --- | --- | --- | --- |
| `effective-font-consistency` | Two runtimes with independent defaults and text with null or explicit stored family | Measure, lay out, paint and edit equivalent inherited/explicit text | Inherited text matches its explicit-family equivalent across measured geometry, keys, actual paint and overlay styles; explicit family wins and runtimes remain independent | Use available distinguishable font metrics where geometry is asserted; null default preserves fallback; invalid default is rejected by existing family constraints |
| `stored-family-preserved` | Existing null/explicit-family text under a runtime default | Read/encode, edit and confirm the element | Stored family stays null or the original explicit value and Schema v1 output retains its existing shape | Effective display still uses fallback; no default is written to element/document metadata; codec round-trip preserves values |
| `font-public-closure` | The public seam changed by this unit | Compile retained and migrated external call patterns against the public barrel | New readable types/members are exported and registered; all implementations and exhaustive consumers agree with actual declarations | Old call shapes/defaults and documented exceptions remain valid; migration documentation is concrete and no manual export inventory is introduced |
| `font-durable-closure` | The behavior or seam description changed by this unit | Publish its current owner documentation and actual proof relationships | Applicable I-001–I-005 owner passages agree with the implemented behavior; changed generated relationships resolve to real owners | No pending semantic documentation debt; design/history/tests stay non-authoritative; only changed relationships are regenerated |
| `font-ownership-closure` | The owners changed by this unit | Install this unit's behavior and direct consumer changes | Actual dependency and state ownership remain within D-001/D-011 and the declared unit boundary | No competing guard/default/placement/committed/input authority, new graph node, forbidden import or independent extra algorithm; necessary proof and documentation land with this unit |
| `font-work-closure` | The text lifecycle phases changed by this unit | Admit/read/update a draft or prepare/install/clean up a terminal as applicable to this unit | No implicit document projection, displaced scene work or compensating mutation; changed terminals consume one prepared package | Explicit host document reads are outside measured regions; existing owner-authorized normalization stays in its original phase |

Depends On: None

### [ ] Unit 8: Separate destination selection from layer installation

Owner: Existing addElement placement rule, edit preparation and its structural replay consumer
Boundary: D-007 existing named/last/default destination policy only; no new text session, public API or Store transaction redesign
Verification Profile: `REFACTOR`
Change: Expose the existing destination decision as a non-mutating internal result containing the selected layer and whether it currently exists. Make current sparse and materialized addElement paths consume that decision before their existing layer installation. Consolidate the repeated default choice across their direct structural replay consumer without changing insertion/index normalization or the accepted default. The current edit paths must use the shared decision immediately; a later new-text admission can read it without starting a CanvasEdit or touching layers. Keep the selector at the existing placement-owning layer with edit/runtime consuming its facts through allowed dependencies; no Store-to-edit reverse dependency or new owner node. Update the owning edit contract to distinguish choosing a destination from installing it.

Acceptance Outcomes:

| Outcome key | Starting state | System action | Observable result | Required side conditions |
| --- | --- | --- | --- | --- |
| `destination-selection-pure` | Named existing/absent destination, omitted destination with or without content layers, and an edit-local changed layer order | Resolve the destination and then perform ordinary addElement through sparse/materialized/replay consumers | The read-only result chooses the same layer the existing operation installs into; current edit-local order remains authoritative inside edits | Resolution creates no layer, opens no long-lived edit, advances no document revision and leaves selection/IDs unchanged; no copied default-choice rule or literal |
| `destination-placement-preserved` | Existing insertion cases with explicit index, append and previously absent destination | Run existing addElement and deferred draw insertion after the policy extraction | Full element/layer placement, normalized indices and ordinary insertion effects are unchanged | Existing validation, rollback and no-op rules remain; Store finalization/install are untouched |
| `destination-durable-closure` | The separated decision/installation responsibility | Publish its existing owner description and changed proof relationships | Edit documentation describes the shared decision and actual consumers | No new architecture node, policy registry or documentation authority |
| `destination-ownership-closure` | Existing edit/Store/runtime dependency direction | Migrate all direct consumers of the extracted rule | One owning destination rule serves current consumers within the existing owner DAG | Source inspection rejects a remaining manual default mirror or a new reverse dependency |

Depends On: None

### [ ] Unit 9: Consolidate existing prepared insertion sealing

Owner: Runtime prepared insertion construction through existing EditKernel
Boundary: D-008/D-009 deferred add, exact entry/layer facts and action sealing; current stroke/line consumers only
Verification Profile: `REFACTOR`
Change: Consolidate the duplicated deferred addElement plus exact prepared-entry projection and action-sealing sequence used by stroke and line. Both current routes must use that preparation immediately; keep their concrete element/action construction and pointer cleanup at their existing owners. Return the already-closed prepared insertion and its exact facts without a resolver call or installation. Reuse the existing candidate projection, validation and consume/discard lifetime rather than implementing another transaction mechanism. Preserve all current public requests/actions, and update the preparation seam description in the existing edit contract. No new public creation variant is introduced in this unit.

Acceptance Outcomes:

| Outcome key | Starting state | System action | Observable result | Required side conditions |
| --- | --- | --- | --- | --- |
| `prepared-insertion-preserved` | Existing stroke/line insertion into an existing or operation-created layer | Prepare, accept, refuse or fail the current draw operation through the consolidated path | Resolver observes the same exact entry/layerIndex/createsLayer before one accepted installation; original action and cleanup order are preserved | Prepared edit handle is already closed; refusal/failure installs nothing; lease terminal cardinality and ID admission are unchanged; both existing consumers use the same preparation |
| `insertion-durable-closure` | The consolidated insertion preparation seam | Publish its actual current owner description and proof relationships | The edit contract identifies one closed prepared insertion handoff with real consumers | Public draw semantics and current owner directions remain unchanged |
| `insertion-ownership-closure` | Existing runtime composition and EditKernel/Store installation | Replace the duplicate current preparation sequences | Runtime composes one preparation; EditKernel/Store retain finalization and install | No generic transaction framework, unused helper or alternate commit path remains |

Depends On:
- Unit 8 — produces: destination decision consumed by addElement; consumed as: destination facts for the existing deferred insertion

### [ ] Unit 10: Complete new text as one transient-to-insert lifecycle

Owner: Runtime new-origin session using existing draft, placement and prepared insertion owners
Boundary: D-007/D-008 new-origin guard and one insertion branch only
Verification Profile: `BEHAVIOR_CHANGE`
Change: Activate startNew for a new-origin session by binding a seed to the existing draft/geometry lifetime and capturing the destination result from Unit 8 with epoch/ID/existence guards. At finish, trim-empty closes unchanged; nonempty delegates to Unit 9's prepared insertion and the established common terminal. Add the readable creation request/action variants and migrate their direct public consumers atomically: CanvasTextCreateCommitRequest uses the prepared entry/layerIndex/createsLayer, createText is appended to the enum, and CanvasTextCreateActionPayload carries requestId/created text length without a fictional previous value or duplicated element ID. This unit owns only new-origin admission/guard and dispatch wiring. Destination choice, normalization, draft formatting, layout/anchor calculation, prepared-entry projection, lease settlement and delivery must already exist and are consumed unchanged. Publish the corresponding creation semantics and concrete external switch/port migration in the current owners with this cutover.

Acceptance Outcomes:

| Outcome key | Starting state | System action | Observable result | Required side conditions |
| --- | --- | --- | --- | --- |
| `new-admission-policy` | Runtime is read-only, or the active slot holds a valid/stale existing session or a valid/stale new session | Call startNew with an otherwise valid unoccupied-ID seed and eligible destination | Read-only or occupied-slot admission is refused through the typed result, according to the shared admission precedence | Preserve the original session identity and all draft text/style/geometry/policy/placement; no replacement, cancellation, request/action, layer/element/selection/document revision change; successful creation admission is possible only after explicit slot release and when writable |
| `transient-new-draft` | A valid seed, including a destination layer absent from the document | Start, type/format, cancel or confirm trim-empty text through the stock overlay/port | No element/layer/selection/document revision/history or dirty transition occurs at any intermediate stage; cancel/empty confirmation clears the session | No placeholder or compensating deletion; empty confirmation is unchanged and bypasses preparation/resolver; origin is readable; seed revision and generation zero are documented non-Store facts |
| `creation-destination-guard` | A new draft with captured epoch, chosen layer and existence, and unoccupied seed ID | Change last layer, remove existing destination, externally occupy prospective layer or ID, replace epoch, or edit unrelated data; then confirm | Conflicting conditions return stale and retain a noncommittable readable draft; unrelated edits keep the captured destination without retargeting | Duplicate seed ID refuses at start; invalid seed/placement keeps existing validation errors; index/append normalization remains addElement-owned; repeated start/commit cannot revive stale creation |
| `atomic-text-creation` | A valid nonempty new draft, including an unchanged nonempty seed and a prospective layer | Confirm and accept or refuse the creation proposal | Exactly one CanvasTextCreateCommitRequest carries full prepared entry, layerIndex, createsLayer and common facts; accept returns committed and installs the final block/layer atomically; refusal returns rejected with a retryable draft | No fictional before, no trimming stored nonempty text, no installation during resolver; final text/B/I/U/placement/anchor match draft; refusal/discard retains draft; ordinary CanvasCommitAccept is compatible |
| `creation-terminal-delivery` | A prepared new text insertion | Accept or exercise resolver/lease mutation attempts, pre-install failures and post-install notification failures | Creation observes the same one-install, one-lease-terminal and ordered delivery boundary as existing text completion | Zero side effects before acceptance; matching cleanup only; replacement session from close listener survives; failure after install cannot become rejected |
| `text-action-meaning` | Accepted new text versus accepted existing text/style change | Read actual public actions and payload variants | New text emits one createText with creation-only readable payload; existing edits retain one editText with original payload semantics | RequestId matches the session; enclosing elementIds identifies the target; lengths match accepted values; failed/cancelled/empty-new attempts emit neither action |
| `new-stored-family-preserved` | A null/explicit-family seed under a runtime default | Edit/format, confirm creation and encode the accepted document | Inherited family affects geometry/display but the accepted seed-derived family and Schema v1 remain unchanged | The final anchor uses the effective family; no serialized runtime font metadata or forced family override |
| `action-ordinal-compatibility` | The existing CanvasActionType declaration before this change | Add the creation action type to the public declaration | Every existing enum value retains its name and ordinal; createText is appended after all existing values | No reorder, deletion or insertion among old values; no manually maintained copied enum inventory is introduced as authority |
| `creation-public-closure` | The public seam changed by this unit | Compile retained and migrated external call patterns against the public barrel | New readable types/members are exported and registered; all implementations and exhaustive consumers agree with actual declarations | Old call shapes/defaults and documented exceptions remain valid; migration documentation is concrete and no manual export inventory is introduced |
| `creation-durable-closure` | The behavior or seam description changed by this unit | Publish its current owner documentation and actual proof relationships | Applicable I-001–I-005 owner passages agree with the implemented behavior; changed generated relationships resolve to real owners | No pending semantic documentation debt; design/history/tests stay non-authoritative; only changed relationships are regenerated |
| `creation-ownership-closure` | The owners changed by this unit | Install this unit's behavior and direct consumer changes | Actual dependency and state ownership remain within D-001/D-011 and the declared unit boundary | No competing guard/default/placement/committed/input authority, new graph node, forbidden import or independent extra algorithm; necessary proof and documentation land with this unit |
| `creation-work-closure` | The text lifecycle phases changed by this unit | Admit/read/update a draft or prepare/install/clean up a terminal as applicable to this unit | No implicit document projection, displaced scene work or compensating mutation; changed terminals consume one prepared package | Explicit host document reads are outside measured regions; existing owner-authorized normalization stays in its original phase |

Depends On:
- Unit 8 — produces: pure selected-destination and existence facts; consumed as: captured creation admission facts
- Unit 9 — produces: closed prepared insertion with exact entry/layer facts; consumed as: new-text terminal proposal and install/discard lifetime
- Unit 2 — produces: typed finish and adapters; consumed as: new-origin result mapping
- Unit 3 — produces: draft formatting and anchor geometry; consumed as: seed draft and final candidate
- Unit 5 — produces: single-slot typed admission; consumed as: new-origin admission/refusal
- Unit 7 — produces: effective versus stored family handoff; consumed as: seed measurement and accepted storage

### [ ] Unit 11: Demonstrate one-gesture host Undo and Redo

Owner: Existing public external-consumer history proof and public integration guidance
Boundary: R-013/A-013 cross-owner replay contract
Verification Profile: `BEHAVIOR_CHANGE`
Change: Extend the existing public-only host history scenario and its concrete migration example to cover a complete text gesture: existing text/style update, new insertion and policy deletion. Build history from immutable request facts and append only in lease.committed; replay through existing edit APIs. Show save/dirty handling for rejected/stale finish and matching overlay/ID policy. This is independently owned external-access/replay evidence, not deferred runtime branch tests or engine history implementation.

Acceptance Outcomes:

| Outcome key | Starting state | System action | Observable result | Required side conditions |
| --- | --- | --- | --- | --- |
| `host-gesture-history` | A public-only host with an empty history and text edits under the new APIs | Complete update/create/delete gestures, then Undo and Redo; attempt cancel, unchanged, empty-new, rejected and stale finishes | One history entry is appended per accepted gesture; Undo/Redo restores complete values and placement; unsuccessful gestures append none and do not dirty the document | Creation Undo removes only its operation-created layer when empty; deletion restores original entry rather than an intermediate empty text; save does not treat rejected/stale as success; no internal imports or engine history state |
| `history-durable-closure` | The behavior or seam description changed by this unit | Publish its current owner documentation and actual proof relationships | Applicable I-001–I-005 owner passages agree with the implemented behavior; changed generated relationships resolve to real owners | No pending semantic documentation debt; design/history/tests stay non-authoritative; only changed relationships are regenerated |
| `history-ownership-closure` | The owners changed by this unit | Install this unit's behavior and direct consumer changes | Actual dependency and state ownership remain within D-001/D-011 and the declared unit boundary | No competing guard/default/placement/committed/input authority, new graph node, forbidden import or independent extra algorithm; necessary proof and documentation land with this unit |

Depends On:
- Unit 4 — produces: original-entry deletion facts; consumed as: deletion Undo/Redo
- Unit 6 — produces: matched stock policy configuration; consumed as: public host integration example
- Unit 10 — produces: creation request/lease/action public seam; consumed as: creation Undo/Redo and unsuccessful-gesture silence

## Verification Matrix

| Evidence key | Covers | Evidence class | Evidence surface | Pre-implementation witness | Pass signal | Evidence constraints and rejected proxy | Adversarial false-positive case and kill signal | Durable impact | Artifact target | Admission |
| --- | --- | --- | --- | --- | --- | --- | --- | --- | --- | --- |
| `delivery-evidence` | `common-terminal-delivery` | `TEST` | Existing runtime text and common delivery fixtures, retained with the typed terminal change; established root commands: `dart test test/runtime/text_editing_port_test.dart`; `dart test test/runtime/runtime_state_publication_test.dart` | The typed result adapter is absent; existing order remains the regression baseline for the new terminal | Actual request/state/lease/action/observer/close trace and resulting state remain equivalent | Use existing actual callback/prepare/consume seams and replacement-session scenarios; helper structure is not an oracle | False positive: Final text is correct despite close before guard release or lease abortion after install; kill signal: Trace/state assertions show wrong order, terminal count or replacement session loss | `NONE` | None | None |
| `guard-comparison-evidence` | `guard-authority-shared` | `SOURCE_QUERY` | Bounded inspection of runtime/interaction guard producers and direct consumers | Current runtime and interaction each implement the same comparator | One owning comparison serves all current consumers with non-consuming reads and explicit command retirement | Inspect actual call flow and rule ownership; equal copies or an exact helper name are not proof | False positive: Both comparators are edited identically but remain competing policies; kill signal: A second manually maintained rule or a read path consuming registry facts fails inspection | `NONE` | None | None |
| `stale-evidence` | `stale-retention`, `formatting-stale-retention` | `TEST` | Runtime stale lifecycle in `test/runtime/fixtures/text_editing_port_fixture.dart`; existing interaction guard and paint-suppression fixtures provide adjacent regression coverage; established root commands: `dart test test/interaction/text_edit_stale_commit_guard_test.dart`; `dart test test/runtime/text_edit_paint_suppression_test.dart` | Current stale session/direct commits clear the active draft; updateText does not refuse stale mutation | Same identity/text/style/geometry survives conflict and retry, stale mutation is silent, committed target/revisions stay intact and explicit cancellation works | Use real target edits/replacements and observe suppression/identity/revisions/resolver silence; bool false alone is rejected | False positive: Commit returns false after clearing the draft or retry obtains a fresh valid guard; kill signal: Retained identity/value checks, repeated mutation/commit and committed-state comparison fail | `EXTEND_COVERAGE` | `test/runtime/fixtures/text_editing_port_fixture.dart` | `stale-evidence-admission` |
| `finish-evidence` | `typed-finish` | `TEST` | Runtime terminal behavior in `test/runtime/fixtures/text_editing_port_fixture.dart` with stock overlay adapter behavior in `test/surface/fixtures/text_editing_overlay_fixture.dart` | finishActive and typed results are absent | All six results match document/session behavior and legacy mappings including no matching direct session | Cross actual entrypoints and observe requests, draft/style and terminal state; constructing result enums is insufficient | False positive: All enum branches exist but legacy direct commit bypasses the active draft; kill signal: Adapter behavior produces wrong request/value/state or bool/result mismatch | `EXTEND_COVERAGE` | `test/runtime/fixtures/text_editing_port_fixture.dart` and `test/surface/fixtures/text_editing_overlay_fixture.dart` | `finish-evidence-admission` |
| `input-evidence` | `formatting-input-stability` | `TEST` | Stock widget editor in `test/surface/fixtures/text_editing_overlay_fixture.dart`; established root commands: `dart test test/surface/text_editing_overlay_test.dart` | There is no draft formatting API; formatting cannot be exercised without committing externally | EditableText keeps focus, noncollapsed selection/composition and session through B/I/U and continued typing | Observe editing value and real input after formatting, with untouched document; text/style equality alone is rejected | False positive: Bold appears but controller reset collapses selection or clears composition; kill signal: Before/after editing-value and continued-input assertions fail | `EXTEND_COVERAGE` | `test/surface/fixtures/text_editing_overlay_fixture.dart` | `input-evidence-admission` |
| `geometry-evidence` | `formatted-geometry` | `TEST` | Runtime anchor cases in `test/runtime/fixtures/text_editing_port_fixture.dart` and frame measurement owner `test/frame/fixtures/measured_text_layout_fixture.dart`; established root commands: `dart test test/frame/measured_text_layout_test.dart` | Session geometry and commit preparation currently use base formatting only | Draft bounds/world anchor agree with accepted frame for style-only and mixed changes | Metrics must distinguish chosen styles; compare measured geometric outputs, not only text/flags or helper calls | False positive: Formatting paints correctly but accepted transform uses old metrics; kill signal: Measured bounds or anchor differs from accepted frame | `EXTEND_COVERAGE` | `test/runtime/fixtures/text_editing_port_fixture.dart` and `test/frame/fixtures/measured_text_layout_fixture.dart` | `geometry-evidence-admission` |
| `draft-update-evidence` | `atomic-draft-update` | `TEST` | Runtime prepared text/update/no-op owner `test/runtime/fixtures/text_editing_port_fixture.dart` | Preparation sends only text and text equality ignores formatting | One full before/after request, document revision/install and action for changed text/B/I/U; zero for cancelled/net-equal draft | Record intermediate states and counts, full values and resolver silence; final element equality is insufficient | False positive: A style update and text update commit separately or toggled-back draft advances revision; kill signal: Request/install/revision/action counts or no-op silence fail | `EXTEND_COVERAGE` | `test/runtime/fixtures/text_editing_port_fixture.dart` | `draft-update-evidence-admission` |
| `deletion-evidence` | `empty-policy-deletion` | `TEST` | Runtime text completion owner `test/runtime/fixtures/text_editing_port_fixture.dart` using existing deletion eligibility/resolver support | No captured empty policy exists; empty text takes update/equality path | Whitespace and originally-empty delete-policy input yield one original-entry deletion request and accepted deletion, or retained rejection; keep default behaves compatibly | Compare complete original entry/placement and operation/lease counts, including non-deletable target; final absence is insufficient | False positive: An empty update is committed before deletion; kill signal: Two operations or request entry no longer matching original fails | `EXTEND_COVERAGE` | `test/runtime/fixtures/text_editing_port_fixture.dart` | `deletion-evidence-admission` |
| `deletion-delivery-evidence` | `deletion-terminal-delivery` | `TEST` | Runtime text lifecycle `test/runtime/fixtures/text_editing_port_fixture.dart` composed with existing common delivery failure seams | Policy-selected deletion has no matching text-session terminal route | Accepted and failed deletion preserves exact guard/lease/install/notification ordering and draft outcome | Observe actual callback reads/mutation attempts and state, not just resolver invocation | False positive: Deletion removes the block but consumes session on refusal or aborts lease after accepted notification failure; kill signal: Draft loss, leaked state, wrong lease terminal/order or replaced-session loss fails | `EXTEND_COVERAGE` | `test/runtime/fixtures/text_editing_port_fixture.dart` | `deletion-delivery-evidence-admission` |
| `id-evidence` | `id-admission` | `TEST` | Public runtime port exercised by `test/runtime/fixtures/text_editing_port_fixture.dart` | Only request-based admission exists; empty ID targets cannot be admitted directly | Every specified typed refusal and valid same-target reuse is distinguishable with document unchanged | Cross real port using actual target facts, monitor context stream silence and identities; result DTO construction is rejected | False positive: All errors return one refusal or same-target stale is silently restarted; kill signal: Expected refusal, context silence and identity/guard outcome disagree | `EXTEND_COVERAGE` | `test/runtime/fixtures/text_editing_port_fixture.dart` | `id-evidence-admission` |
| `overlay-policy-evidence` | `overlay-policy-capture` | `TEST` | Actual stock context subscription and widget lifecycle in `test/surface/fixtures/text_editing_overlay_fixture.dart` | Overlay forwards no empty policy | ID and double-tap produce matching deletion/keep outcomes and capture policy once | Actual double-tap/context delivery to completion, omitted option and live property change; constructor-field assertions are rejected | False positive: Explicit ID tests pass while stock double-tap still keeps empty text; kill signal: Stock request/result or captured-policy identity differs | `EXTEND_COVERAGE` | `test/surface/fixtures/text_editing_overlay_fixture.dart` | `overlay-policy-evidence-admission` |
| `font-evidence` | `effective-font-consistency` | `TEST` | Frame layout/render owner `test/frame/fixtures/measured_text_layout_fixture.dart`, runtime text owner `test/runtime/fixtures/text_editing_port_fixture.dart`, stock overlay owner `test/surface/fixtures/text_editing_overlay_fixture.dart` | Runtime config and frame projection have no default family | Inherited and explicit equivalent inputs have matching geometry and painted output, family-sensitive keys and matching TextStyle/StrutStyle; independent runtime defaults remain isolated | Use a reliably available distinguishable font fixture for geometry/paint; exercise null, valid, empty and over-limit defaults using the owning per-element constraints and canonical limit; config field equality or indistinguishable fallback font is insufficient | False positive: Overlay uses the family but measurement/cache/paint still uses null or another runtime default; kill signal: Geometry/paint/key/style comparison or cross-runtime isolation differs | `EXTEND_COVERAGE` | `test/frame/fixtures/measured_text_layout_fixture.dart`, `test/runtime/fixtures/text_editing_port_fixture.dart` and `test/surface/fixtures/text_editing_overlay_fixture.dart` | `font-evidence-admission` |
| `storage-evidence` | `stored-family-preserved`, `new-stored-family-preserved` | `TEST` | Runtime existing/new commit observations plus `test/codec/schema_v1/canonical_encode_roundtrip_test.dart`; established root commands: `dart test test/codec/schema_v1/canonical_encode_roundtrip_test.dart` | No runtime-default confirmation path exists to prove effective versus stored separation | Read/encode/round-trip preserves null/explicit family and schema shape after editing/creation under a default | Observe public stored values and codec output as well as effective display; visual correctness is insufficient | False positive: The text looks correct because inherited family was written into the element; kill signal: Null/explicit value or serialized-shape assertion fails | `EXTEND_COVERAGE` | `test/runtime/fixtures/text_editing_port_fixture.dart` and `test/codec/schema_v1/canonical_encode_roundtrip_test.dart` | `storage-evidence-admission` |
| `transient-evidence` | `transient-new-draft` | `TEST` | New-origin lifecycle in `test/runtime/fixtures/text_editing_port_fixture.dart` with stock cancellation/empty-confirm behavior in `test/surface/fixtures/text_editing_overlay_fixture.dart` | Starting text requires an existing committed element | Intermediate document/layers/selection/revisions and resolver/action/lease counts remain unchanged through start/edit/cancel/empty confirm | Include absent destination and whitespace-only draft; inspect intermediate states, not only final absence; host dirty/history is separately proved by host-history-evidence | False positive: Placeholder and layer are created then deleted on cancel; kill signal: Any intermediate committed effect or count increment fails | `EXTEND_COVERAGE` | `test/runtime/fixtures/text_editing_port_fixture.dart` and `test/surface/fixtures/text_editing_overlay_fixture.dart` | `transient-evidence-admission` |
| `creation-guard-evidence` | `creation-destination-guard` | `TEST` | New-origin runtime admission/confirmation owner `test/runtime/fixtures/text_editing_port_fixture.dart` | No creation guard/admission exists | Captured destination survives unrelated changes; conflicting destination/ID/epoch produces retained stale with no insertion or resolver | Exercise real public structure changes and duplicate-ID admission; successful insertion only is insufficient | False positive: Implementation recalculates last layer at commit and all happy-path creation tests pass; kill signal: Retained destination mismatch, insertion after conflict, lost draft or retry revival fails | `EXTEND_COVERAGE` | `test/runtime/fixtures/text_editing_port_fixture.dart` | `creation-guard-evidence-admission` |
| `creation-evidence` | `atomic-text-creation` | `TEST` | Runtime prepared insertion through `test/runtime/fixtures/text_editing_port_fixture.dart` and stock new-origin overlay consumer in `test/surface/fixtures/text_editing_overlay_fixture.dart` | No transient text insertion or creation-request variant exists | One exact prepared creation entry/layer metadata is visible before document insertion; full final value matches accepted draft and geometry | Include unchanged nonempty seed, untrimmed nonempty input, prospective/existing layers, refusal and discard; final text alone is insufficient | False positive: Request has fictional before value or creates layer before resolver acceptance; kill signal: Request shape/full facts, resolver-time document and one-operation counts fail | `EXTEND_COVERAGE` | `test/runtime/fixtures/text_editing_port_fixture.dart` and `test/surface/fixtures/text_editing_overlay_fixture.dart` | `creation-evidence-admission` |
| `creation-delivery-evidence` | `creation-terminal-delivery` | `TEST` | Runtime creation lifecycle `test/runtime/fixtures/text_editing_port_fixture.dart` composed with existing prepare/consume/common delivery seams | No new-origin completion crosses guarded delivery | Actual creation state, lease, action, observer and close trace satisfies D-009 on acceptance and each failure boundary | Use existing behavioral fault seams and mutation attempts; no generic injector or helper assertion | False positive: Resolver call count is one but mutation precedes acceptance or post-install failure aborts; kill signal: Trace, committed state, draft retention and lease terminal checks fail | `EXTEND_COVERAGE` | `test/runtime/fixtures/text_editing_port_fixture.dart` | `creation-delivery-evidence-admission` |
| `action-evidence` | `existing-edit-action`, `text-action-meaning` | `TEST` | Public action observations in `test/runtime/fixtures/text_editing_port_fixture.dart` | Creation action/payload are absent; only editText exists for text completion | Creation and existing text/style modification emit exactly their distinct action/payload once with correct IDs and lengths | Observe actual public action stream after commit and unsuccessful attempts; request kind and export compilation alone are insufficient | False positive: Creation request is correct but emits editText or both action types; kill signal: Action count/type/payload or ID/length checks fail | `EXTEND_COVERAGE` | `test/runtime/fixtures/text_editing_port_fixture.dart` | `action-evidence-admission` |
| `host-history-evidence` | `host-gesture-history` | `TEST` | `test/api_contract/commit_confirmation_history_public_behavior_test.dart`, using the existing shared consumer harness; established root commands: `dart test test/api_contract/commit_confirmation_history_public_behavior_test.dart` | Existing history scenario lacks new text creation and one text/B/I/U/empty-policy gesture | Public-only Undo/Redo restores complete document/placement and operation-created layer provenance; exactly one entry/dirty transition per accepted gesture and none otherwise | Append only from lease.committed; replay through public edits; compare full documents and retained/removed layers; action counts alone are insufficient | False positive: History records accepted action but cannot restore original formatting or removes a pre-existing layer; kill signal: Full Undo/Redo document, layer provenance, history count or unsuccessful dirty-state assertion fails | `EXTEND_COVERAGE` | `test/api_contract/commit_confirmation_history_public_behavior_test.dart` | `host-history-evidence-admission` |
| `public-migration-evidence` | `finish-public-closure`, `formatting-public-closure`, `empty-policy-public-closure`, `admission-public-closure`, `overlay-public-closure`, `font-public-closure`, `creation-public-closure` | `BUILD_OR_COMPILE` | Public compile-as-written and integration fixtures, actual facade exports and canonical registry consumer; apply to each producing unit; established root commands: `dart test test/api_contract/public_api_v1_compiles_as_written_test.dart`; `dart test test/api_contract/public_integration_compile_fixture_test.dart`; `dart run tool/guardrails/run.dart --suite=api` | New port members/results/creation variants cannot currently be compiled or read by an external consumer | Retained call forms compile; migrated implements and exhaustive request/action/payload switches compile; exposed result types are readable through root barrel | Public-only fixtures plus resolved namespace/registry parity and concrete example inspection; internal compilation or copied expected-name sets are insufficient | False positive: Internal build passes while an unexported result type or missing port member breaks a real consumer; kill signal: Public compile/namespace check or actual declared-member versus migration-example comparison fails | `EXTEND_COVERAGE` | `test/api_contract/public_api_v1_compiles_as_written_test.dart` and `test/api_contract/fixtures/public_integration_compile_fixture.dart` | `public-migration-evidence-admission` |
| `durable-handoff-evidence` | `destination-durable-closure`, `insertion-durable-closure`, `stale-durable-closure`, `finish-durable-closure`, `formatting-durable-closure`, `empty-policy-durable-closure`, `admission-durable-closure`, `overlay-durable-closure`, `font-durable-closure`, `creation-durable-closure`, `history-durable-closure` | `MANUAL_INSPECTION` | Changed current owner documents under I-001–I-005 and their structured/generated relationships; review in the producing unit | Current public/runtime owners describe context-only text-only sessions and stale dismissal; no creation/default-font semantics exist | Each changed semantic owner matches its unit behavior and references actual code/proof; generated relationships come from their registries | Bounded semantic comparison to D-001–D-012 and actual declarations; documentation checks prove links/structure, never behavior; wording token assertions are rejected | False positive: Generated pages look current while owning contract still mandates stale loss or names nonexistent proof; kill signal: A contradictory owner statement or unresolved actual relationship fails review | `NONE` | None | None |
| `ownership-evidence` | `destination-ownership-closure`, `insertion-ownership-closure`, `stale-ownership-closure`, `finish-ownership-closure`, `formatting-ownership-closure`, `empty-policy-ownership-closure`, `admission-ownership-closure`, `overlay-ownership-closure`, `font-ownership-closure`, `creation-ownership-closure`, `history-ownership-closure` | `SOURCE_QUERY` | Changed-owner state/consumer inspection plus existing graph/import/text-surface enforcement | Current changed routes have a duplicated guard comparator; new admission/draft/creation/font consumers are absent | Every changed production owner respects D-001 and the package boundary; manual guard/default/placement/name policy mirrors are absent | Inspect actual producer/consumer directions and state lifetimes; passing functional tests alone cannot prove ownership | False positive: Behavior works via duplicated committed state or surface-local measurement; kill signal: Competing authority or forbidden dependency found in changed-owner inspection fails | `NONE` | None | None |
| `text-work-evidence` | `stale-work-closure`, `finish-work-closure`, `formatting-work-closure`, `empty-policy-work-closure`, `admission-work-closure`, `font-work-closure`, `creation-work-closure` | `TEST` | Existing runtime text/prepared delivery probes and sparse EditKernel proof, with bounded inspection of draft/admission/cleanup consumers | Current text evidence has no phase observations for the absent formatting/deletion/new-origin routes; existing sparse paths provide the baseline | No implicit document projection in measured text lifecycle regions; one prepared package for each changed terminal; cleanup does not compensate with mutation | Observe existing projection/install/preparation probes with explicit host reads outside measured regions; inspect phase-local scene-work paths; final document equality and timing are rejected | False positive: Request facts are correct after readDocument materialization during start or cleanup; kill signal: Unexpected projection/build/install count or forbidden whole-scene phase work fails | `EXTEND_COVERAGE` | `test/runtime/fixtures/text_editing_port_fixture.dart` | `text-work-evidence-admission` |
| `destination-selection-evidence` | `destination-selection-pure` | `TEST` | Existing edit structural owner test/edit/fixtures/sparse_edit_session/sparse_edit_session_structure_fixture.dart; source inspection of all default-choice consumers | Current destination helpers combine choice with layer admission and no pure result is available | Read-only resolution selects the actual ordinary-insertion destination without mutation; all current consumers use the same choice | Observe full structure/revisions/selection and edit-local versus committed order; helper-call counts or equal copied literals are rejected | False positive: query returns the right ID after creating a layer; kill signal: any intermediate layer/revision/selection mutation or remaining competing rule fails | `EXTEND_COVERAGE` | `test/edit/fixtures/sparse_edit_session/sparse_edit_session_structure_fixture.dart` | `destination-selection-admission` |
| `destination-placement-evidence` | `destination-placement-preserved` | `TEST` | Existing sparse/materialized structural placement and Store structural editor fixtures, before and after; root commands: `dart test test/edit/sparse_edit_session_test.dart`; `dart test test/store/structural_editor_test.dart` | Not required: REFACTOR preserves existing placement cases and their independent sequential oracle | Existing full placement and structural-effect observations remain unchanged across named/omitted/indexed insertion and rollback | Use actual committed and edit-local order, not an expected value derived from the new selector | False positive: shared selector uses committed order after an edit-local reorder; kill signal: existing placement oracle or rollback effects differ | `NONE` | None | None |
| `prepared-insertion-evidence` | `prepared-insertion-preserved` | `TEST` | Existing test/runtime/fixtures/draw_commit_delivery_fixture.dart before and after; root command: `dart test test/runtime/draw_commit_delivery_test.dart` | Not required: REFACTOR preserves current exact-entry, refusal, ID and lease behavior covered by the existing draw owner | Stroke and line retain exact requests, one install, closed edit handles, original actions, cleanup and lease terminals | Observe real prepared requests and callback-time state through both routes; private helper shape and final element presence alone are rejected | False positive: shared helper inserts before resolver or misses createsLayer; kill signal: resolver-time state, exact-entry provenance or lease/action/ID assertions fail | `NONE` | None | None |
| `new-admission-evidence` | `new-admission-policy` | `TEST` | New-origin admission through the real public runtime port in test/runtime/fixtures/text_editing_port_fixture.dart | startNew is absent; existing ID/context admission tests cannot detect a new-origin bypass of the shared slot/read-only policy | startNew refuses when read-only or when an existing/new, valid/stale session occupies the slot; all original session values and committed state remain unchanged | Exercise read-only and occupied-slot conditions separately, including stale retained sessions, then explicit cancellation and successful writable admission; observe the real typed result and session identity, not only final element absence | False positive: startNew silently replaces an existing draft while creating no document element; kill signal: refusal/identity/full draft or committed-state comparison fails | `EXTEND_COVERAGE` | `test/runtime/fixtures/text_editing_port_fixture.dart` | `new-admission-admission` |
| `action-ordinal-evidence` | `action-ordinal-compatibility` | `SOURCE_QUERY` | Bounded comparison of the pre-change and resulting CanvasActionType declaration in lib/src/contracts/public/canvas_actions.dart | The current enum ends with editText and has no createText | All pre-existing members remain in the same order and createText is the only appended value | Compare actual declaration before/after, not a copied name/ordinal allowlist; compilation, registry parity and action-type runtime observations alone cannot prove ordinal preservation | False positive: createText is inserted before editText while every consumer still compiles; kill signal: any previous member's position changes or the new value is not appended | `NONE` | None | None |

## Permanent Artifact Admissions

### `stale-evidence-admission`: Stale

Covers: `stale-retention`, `formatting-stale-retention`
Impact: `EXTEND_COVERAGE`
Failure family: stale evidence
Failure mode or stable invariant: Same identity/text/style/geometry survives conflict and retry, stale mutation is silent, committed target/revisions stay intact and explicit cancellation works
Verification owner: Runtime stale lifecycle in `test/runtime/fixtures/text_editing_port_fixture.dart`; existing interaction guard and paint-suppression fixtures provide adjacent regression coverage
Current verification gap: Current stale session/direct commits clear the active draft; updateText does not refuse stale mutation
Failing witness: Current stale session/direct commits clear the active draft; updateText does not refuse stale mutation
Durable and refactor-stable value: Consumer-visible results, state and failure boundaries remain falsifiable after private decomposition; use real target edits/replacements and observe suppression/identity/revisions/resolver silence; bool false alone is rejected
Artifact target: `test/runtime/fixtures/text_editing_port_fixture.dart`

### `finish-evidence-admission`: Finish

Covers: `typed-finish`
Impact: `EXTEND_COVERAGE`
Failure family: finish evidence
Failure mode or stable invariant: All six results match document/session behavior and legacy mappings including no matching direct session
Verification owner: Runtime terminal behavior in `test/runtime/fixtures/text_editing_port_fixture.dart` with stock overlay adapter behavior in `test/surface/fixtures/text_editing_overlay_fixture.dart`
Current verification gap: finishActive and typed results are absent
Failing witness: finishActive and typed results are absent
Durable and refactor-stable value: Consumer-visible results, state and failure boundaries remain falsifiable after private decomposition; cross actual entrypoints and observe requests, draft/style and terminal state; constructing result enums is insufficient
Artifact target: `test/runtime/fixtures/text_editing_port_fixture.dart` and `test/surface/fixtures/text_editing_overlay_fixture.dart`

### `input-evidence-admission`: Input

Covers: `formatting-input-stability`
Impact: `EXTEND_COVERAGE`
Failure family: input evidence
Failure mode or stable invariant: EditableText keeps focus, noncollapsed selection/composition and session through B/I/U and continued typing
Verification owner: Stock widget editor in `test/surface/fixtures/text_editing_overlay_fixture.dart`
Current verification gap: There is no draft formatting API; formatting cannot be exercised without committing externally
Failing witness: There is no draft formatting API; formatting cannot be exercised without committing externally
Durable and refactor-stable value: Consumer-visible results, state and failure boundaries remain falsifiable after private decomposition; observe editing value and real input after formatting, with untouched document; text/style equality alone is rejected
Artifact target: `test/surface/fixtures/text_editing_overlay_fixture.dart`

### `geometry-evidence-admission`: Geometry

Covers: `formatted-geometry`
Impact: `EXTEND_COVERAGE`
Failure family: geometry evidence
Failure mode or stable invariant: Draft bounds/world anchor agree with accepted frame for style-only and mixed changes
Verification owner: Runtime anchor cases in `test/runtime/fixtures/text_editing_port_fixture.dart` and frame measurement owner `test/frame/fixtures/measured_text_layout_fixture.dart`
Current verification gap: Session geometry and commit preparation currently use base formatting only
Failing witness: Session geometry and commit preparation currently use base formatting only
Durable and refactor-stable value: Consumer-visible results, state and failure boundaries remain falsifiable after private decomposition; metrics must distinguish chosen styles; compare measured geometric outputs, not only text/flags or helper calls
Artifact target: `test/runtime/fixtures/text_editing_port_fixture.dart` and `test/frame/fixtures/measured_text_layout_fixture.dart`

### `draft-update-evidence-admission`: Draft update

Covers: `atomic-draft-update`
Impact: `EXTEND_COVERAGE`
Failure family: draft update evidence
Failure mode or stable invariant: One full before/after request, document revision/install and action for changed text/B/I/U; zero for cancelled/net-equal draft
Verification owner: Runtime prepared text/update/no-op owner `test/runtime/fixtures/text_editing_port_fixture.dart`
Current verification gap: Preparation sends only text and text equality ignores formatting
Failing witness: Preparation sends only text and text equality ignores formatting
Durable and refactor-stable value: Consumer-visible results, state and failure boundaries remain falsifiable after private decomposition; record intermediate states and counts, full values and resolver silence; final element equality is insufficient
Artifact target: `test/runtime/fixtures/text_editing_port_fixture.dart`

### `deletion-evidence-admission`: Deletion

Covers: `empty-policy-deletion`
Impact: `EXTEND_COVERAGE`
Failure family: deletion evidence
Failure mode or stable invariant: Whitespace and originally-empty delete-policy input yield one original-entry deletion request and accepted deletion, or retained rejection; keep default behaves compatibly
Verification owner: Runtime text completion owner `test/runtime/fixtures/text_editing_port_fixture.dart` using existing deletion eligibility/resolver support
Current verification gap: No captured empty policy exists; empty text takes update/equality path
Failing witness: No captured empty policy exists; empty text takes update/equality path
Durable and refactor-stable value: Consumer-visible results, state and failure boundaries remain falsifiable after private decomposition; compare complete original entry/placement and operation/lease counts, including non-deletable target; final absence is insufficient
Artifact target: `test/runtime/fixtures/text_editing_port_fixture.dart`

### `deletion-delivery-evidence-admission`: Deletion delivery

Covers: `deletion-terminal-delivery`
Impact: `EXTEND_COVERAGE`
Failure family: deletion delivery evidence
Failure mode or stable invariant: Accepted and failed deletion preserves exact guard/lease/install/notification ordering and draft outcome
Verification owner: Runtime text lifecycle `test/runtime/fixtures/text_editing_port_fixture.dart` composed with existing common delivery failure seams
Current verification gap: Policy-selected deletion has no matching text-session terminal route
Failing witness: Policy-selected deletion has no matching text-session terminal route
Durable and refactor-stable value: Consumer-visible results, state and failure boundaries remain falsifiable after private decomposition; observe actual callback reads/mutation attempts and state, not just resolver invocation
Artifact target: `test/runtime/fixtures/text_editing_port_fixture.dart`

### `id-evidence-admission`: Id

Covers: `id-admission`
Impact: `EXTEND_COVERAGE`
Failure family: id evidence
Failure mode or stable invariant: Every specified typed refusal and valid same-target reuse is distinguishable with document unchanged
Verification owner: Public runtime port exercised by `test/runtime/fixtures/text_editing_port_fixture.dart`
Current verification gap: Only request-based admission exists; empty ID targets cannot be admitted directly
Failing witness: Only request-based admission exists; empty ID targets cannot be admitted directly
Durable and refactor-stable value: Consumer-visible results, state and failure boundaries remain falsifiable after private decomposition; cross real port using actual target facts, monitor context stream silence and identities; result DTO construction is rejected
Artifact target: `test/runtime/fixtures/text_editing_port_fixture.dart`

### `overlay-policy-evidence-admission`: Overlay policy

Covers: `overlay-policy-capture`
Impact: `EXTEND_COVERAGE`
Failure family: overlay policy evidence
Failure mode or stable invariant: ID and double-tap produce matching deletion/keep outcomes and capture policy once
Verification owner: Actual stock context subscription and widget lifecycle in `test/surface/fixtures/text_editing_overlay_fixture.dart`
Current verification gap: Overlay forwards no empty policy
Failing witness: Overlay forwards no empty policy
Durable and refactor-stable value: Consumer-visible results, state and failure boundaries remain falsifiable after private decomposition; actual double-tap/context delivery to completion, omitted option and live property change; constructor-field assertions are rejected
Artifact target: `test/surface/fixtures/text_editing_overlay_fixture.dart`

### `font-evidence-admission`: Font

Covers: `effective-font-consistency`
Impact: `EXTEND_COVERAGE`
Failure family: font evidence
Failure mode or stable invariant: Inherited and explicit equivalent inputs have matching geometry and painted output, family-sensitive keys and matching TextStyle/StrutStyle; independent runtime defaults remain isolated
Verification owner: Frame layout/render owner `test/frame/fixtures/measured_text_layout_fixture.dart`, runtime text owner `test/runtime/fixtures/text_editing_port_fixture.dart`, stock overlay owner `test/surface/fixtures/text_editing_overlay_fixture.dart`
Current verification gap: Runtime config and frame projection have no default family
Failing witness: Runtime config and frame projection have no default family
Durable and refactor-stable value: Consumer-visible results, state and failure boundaries remain falsifiable after private decomposition; use a reliably available distinguishable font fixture for geometry/paint; consume existing family limit for validation; config field equality or indistinguishable fallback font is insufficient
Artifact target: `test/frame/fixtures/measured_text_layout_fixture.dart`, `test/runtime/fixtures/text_editing_port_fixture.dart` and `test/surface/fixtures/text_editing_overlay_fixture.dart`

### `storage-evidence-admission`: Storage

Covers: `stored-family-preserved`, `new-stored-family-preserved`
Impact: `EXTEND_COVERAGE`
Failure family: storage evidence
Failure mode or stable invariant: Read/encode/round-trip preserves null/explicit family and schema shape after editing/creation under a default
Verification owner: Runtime existing/new commit observations plus `test/codec/schema_v1/canonical_encode_roundtrip_test.dart`
Current verification gap: No runtime-default confirmation path exists to prove effective versus stored separation
Failing witness: No runtime-default confirmation path exists to prove effective versus stored separation
Durable and refactor-stable value: Consumer-visible results, state and failure boundaries remain falsifiable after private decomposition; observe public stored values and codec output as well as effective display; visual correctness is insufficient
Artifact target: `test/runtime/fixtures/text_editing_port_fixture.dart` and `test/codec/schema_v1/canonical_encode_roundtrip_test.dart`

### `transient-evidence-admission`: Transient

Covers: `transient-new-draft`
Impact: `EXTEND_COVERAGE`
Failure family: transient evidence
Failure mode or stable invariant: Intermediate document/layers/selection/revisions and resolver/action/lease counts remain unchanged through start/edit/cancel/empty confirm
Verification owner: New-origin lifecycle in `test/runtime/fixtures/text_editing_port_fixture.dart` with stock cancellation/empty-confirm behavior in `test/surface/fixtures/text_editing_overlay_fixture.dart`
Current verification gap: Starting text requires an existing committed element
Failing witness: Starting text requires an existing committed element
Durable and refactor-stable value: Consumer-visible results, state and failure boundaries remain falsifiable after private decomposition; include absent destination and whitespace-only draft; inspect intermediate states, not only final absence; host dirty/history is separately proved by host-history-evidence
Artifact target: `test/runtime/fixtures/text_editing_port_fixture.dart` and `test/surface/fixtures/text_editing_overlay_fixture.dart`

### `creation-guard-evidence-admission`: Creation guard

Covers: `creation-destination-guard`
Impact: `EXTEND_COVERAGE`
Failure family: creation guard evidence
Failure mode or stable invariant: Captured destination survives unrelated changes; conflicting destination/ID/epoch produces retained stale with no insertion or resolver
Verification owner: New-origin runtime admission/confirmation owner `test/runtime/fixtures/text_editing_port_fixture.dart`
Current verification gap: No creation guard/admission exists
Failing witness: No creation guard/admission exists
Durable and refactor-stable value: Consumer-visible results, state and failure boundaries remain falsifiable after private decomposition; exercise real public structure changes and duplicate-ID admission; successful insertion only is insufficient
Artifact target: `test/runtime/fixtures/text_editing_port_fixture.dart`

### `creation-evidence-admission`: Creation

Covers: `atomic-text-creation`
Impact: `EXTEND_COVERAGE`
Failure family: creation evidence
Failure mode or stable invariant: One exact prepared creation entry/layer metadata is visible before document insertion; full final value matches accepted draft and geometry
Verification owner: Runtime prepared insertion through `test/runtime/fixtures/text_editing_port_fixture.dart` and stock new-origin overlay consumer in `test/surface/fixtures/text_editing_overlay_fixture.dart`
Current verification gap: No transient text insertion or creation-request variant exists
Failing witness: No transient text insertion or creation-request variant exists
Durable and refactor-stable value: Consumer-visible results, state and failure boundaries remain falsifiable after private decomposition; include unchanged nonempty seed, untrimmed nonempty input, prospective/existing layers, refusal and discard; final text alone is insufficient
Artifact target: `test/runtime/fixtures/text_editing_port_fixture.dart` and `test/surface/fixtures/text_editing_overlay_fixture.dart`

### `creation-delivery-evidence-admission`: Creation delivery

Covers: `creation-terminal-delivery`
Impact: `EXTEND_COVERAGE`
Failure family: creation delivery evidence
Failure mode or stable invariant: Actual creation state, lease, action, observer and close trace satisfies D-009 on acceptance and each failure boundary
Verification owner: Runtime creation lifecycle `test/runtime/fixtures/text_editing_port_fixture.dart` composed with existing prepare/consume/common delivery seams
Current verification gap: No new-origin completion crosses guarded delivery
Failing witness: No new-origin completion crosses guarded delivery
Durable and refactor-stable value: Consumer-visible results, state and failure boundaries remain falsifiable after private decomposition; use existing behavioral fault seams and mutation attempts; no generic injector or helper assertion
Artifact target: `test/runtime/fixtures/text_editing_port_fixture.dart`

### `action-evidence-admission`: Action

Covers: `existing-edit-action`, `text-action-meaning`
Impact: `EXTEND_COVERAGE`
Failure family: action evidence
Failure mode or stable invariant: Creation and existing text/style modification emit exactly their distinct action/payload once with correct IDs and lengths
Verification owner: Public action observations in `test/runtime/fixtures/text_editing_port_fixture.dart`
Current verification gap: Creation action/payload are absent; only editText exists for text completion
Failing witness: Creation action/payload are absent; only editText exists for text completion
Durable and refactor-stable value: Consumer-visible results, state and failure boundaries remain falsifiable after private decomposition; observe actual public action stream after commit and unsuccessful attempts; request kind and export compilation alone are insufficient
Artifact target: `test/runtime/fixtures/text_editing_port_fixture.dart`

### `host-history-evidence-admission`: Host history

Covers: `host-gesture-history`
Impact: `EXTEND_COVERAGE`
Failure family: host history evidence
Failure mode or stable invariant: Public-only Undo/Redo restores complete document/placement and operation-created layer provenance; exactly one entry/dirty transition per accepted gesture and none otherwise
Verification owner: `test/api_contract/commit_confirmation_history_public_behavior_test.dart`, using the existing shared consumer harness
Current verification gap: Existing history scenario lacks new text creation and one text/B/I/U/empty-policy gesture
Failing witness: Existing history scenario lacks new text creation and one text/B/I/U/empty-policy gesture
Durable and refactor-stable value: Consumer-visible results, state and failure boundaries remain falsifiable after private decomposition; append only from lease.committed; replay through public edits; compare full documents and retained/removed layers; action counts alone are insufficient
Artifact target: `test/api_contract/commit_confirmation_history_public_behavior_test.dart`

### `public-migration-evidence-admission`: Public migration

Covers: `finish-public-closure`, `formatting-public-closure`, `empty-policy-public-closure`, `admission-public-closure`, `overlay-public-closure`, `font-public-closure`, `creation-public-closure`
Impact: `EXTEND_COVERAGE`
Failure family: public migration evidence
Failure mode or stable invariant: Retained call forms compile; migrated implements and exhaustive request/action/payload switches compile; exposed result types are readable through root barrel
Verification owner: Public compile-as-written and integration fixtures, actual facade exports and canonical registry consumer; apply to each producing unit
Current verification gap: New port members/results/creation variants cannot currently be compiled or read by an external consumer
Failing witness: New port members/results/creation variants cannot currently be compiled or read by an external consumer
Durable and refactor-stable value: Consumer-visible results, state and failure boundaries remain falsifiable after private decomposition; public-only fixtures plus resolved namespace/registry parity and concrete example inspection; internal compilation or copied expected-name sets are insufficient
Artifact target: `test/api_contract/public_api_v1_compiles_as_written_test.dart` and `test/api_contract/fixtures/public_integration_compile_fixture.dart`

### `text-work-evidence-admission`: Text work

Covers: `stale-work-closure`, `finish-work-closure`, `formatting-work-closure`, `empty-policy-work-closure`, `admission-work-closure`, `font-work-closure`, `creation-work-closure`
Impact: `EXTEND_COVERAGE`
Failure family: text work evidence
Failure mode or stable invariant: No implicit document projection in measured text lifecycle regions; one prepared package for each changed terminal; cleanup does not compensate with mutation
Verification owner: Existing runtime text/prepared delivery probes and sparse EditKernel proof, with bounded inspection of draft/admission/cleanup consumers
Current verification gap: Current text tests do not cover phase-local projection/install behavior across new-origin and formatting/deletion terminals
Failing witness: Current text evidence has no phase observations for the absent formatting/deletion/new-origin routes; existing sparse paths provide the baseline
Durable and refactor-stable value: Consumer-visible results, state and failure boundaries remain falsifiable after private decomposition; observe existing projection/install/preparation probes with explicit host reads outside measured regions; inspect phase-local scene-work paths; final document equality and timing are rejected
Artifact target: `test/runtime/fixtures/text_editing_port_fixture.dart`
### `destination-selection-admission`: Non-mutating destination selection

Covers: `destination-selection-pure`
Impact: `EXTEND_COVERAGE`
Failure family: selecting a destination mutates document structure or disagrees with current insertion
Failure mode or stable invariant: destination resolution is non-mutating and shares the same named/last/default rule with actual insertion
Verification owner: Existing edit structural placement proof
Current verification gap: Current helpers combine selection and ensureLayer; no read-only resolution observation exists
Failing witness: The current destination operation creates a prospective layer rather than returning pure admission facts
Durable and refactor-stable value: Committed/edit-local destination and no-mutation behavior remain observable independently of the private selector representation
Artifact target: `test/edit/fixtures/sparse_edit_session/sparse_edit_session_structure_fixture.dart`

### `new-admission-admission`: Shared new-session admission policy

Covers: `new-admission-policy`
Impact: `EXTEND_COVERAGE`
Failure family: new-origin admission bypasses read-only or replaces an occupied active-session slot
Failure mode or stable invariant: startNew rejects without changing the existing session or committed state whenever shared admission denies the request
Verification owner: Existing runtime text-editing port behavior fixture
Current verification gap: Existing admission cases cover request/ID-based existing targets, not new-origin admission
Failing witness: startNew does not exist; future new-origin admission could replace a retained draft without any current owner assertion detecting it
Durable and refactor-stable value: Typed admission, session identity/full draft retention and document silence remain directly observable after internal refactors
Artifact target: `test/runtime/fixtures/text_editing_port_fixture.dart`


## Verification Gate

| Check | Scope | Future command or evidence | Pass signal |
| --- | --- | --- | --- |
| Changed-owner static checks | Every Dart-producing unit, from repository root | `dart analyze`; `dcm analyze .`; `dcm calculate-metrics` separately for actual changed production owners under lib/src/contracts/public, lib/src/api, lib/src/runtime, lib/src/interaction, lib/src/edit, the direct lib/src/store placement consumer, lib/src/frame, lib/src/surface and actual changed test/tool scopes | No unresolved diagnostics; specific justified declaration-level metric exceptions only, never metric-driven fragmentation or global relaxation |
| Ownership closure | Every changed owner; `ownership-evidence` | `dart run tool/architecture_graph/check.dart`; `dart run tool/architecture_graph/generate_views.dart --check`; `dart test test/guardrails/import_boundaries_test.dart`; `dart test test/guardrails/text_surface_guardrail_checks_test.dart`; bounded Matrix source inspection | Current owner graph/import/measurement boundaries hold; no new graph node or alternate authority; no runtime behavior credit from source scans |
| Work budget closure | Cross-unit text lifecycle; `text-work-evidence` | Review existing phase probes and changed-owner source paths for admission, draft mutation/read, sparse prepare/install and cleanup after each new route lands | No phase hides forbidden whole-document projection, scene work or a compensating mutation; explicit host reads are separate; no benchmark system added |
| Documentation consistency | Every unit changing current docs or registries | `dart run docs/tool/sync_generated_docs.dart --check`; `dart run docs/tool/check_docs.dart`; if stale, use `dart run docs/tool/sync_generated_docs.dart` and review generated changes before rerunning; use `dart run docs/tool/generate_context_capsules.dart` only when capsule inputs change | Links/relationships/generated navigation agree with their owners; bounded semantic review closes I-001–I-005 without prose-token product proof |
| Reviewable unit scope | Each completed unit; `ownership-evidence` | Inspect the actual diff against its single result and dependencies; review authored logic separately from generated/mechanical churn | One dominant algorithm or atomic seam, no deferred required proof/docs or independently reversible extra result; no unsupported numerical size threshold |
| Finding disposition | All implementation/review findings; `durable-handoff-evidence` | Resolve in-scope findings at their owner; apply H-001 owner/install contradiction, H-002 missing atomic public history facts, H-003 changed font lifetime/persistence and H-004 additional compatibility break as architecture re-entry conditions | No unresolved material finding or silently reinterpreted source/enforcement conflict. H conditions are future invalidation triggers, not current blockers; unrelated confirmed work follows existing FOLLOW_UPS authority without widening this contract |
| Diff hygiene | Whole change | `git diff --check` | Exit 0 |
| Lifecycle closure | This active contract and source design; `durable-handoff-evidence` | After all units, findings and required evidence close, move this same filename into docs/history/plans; move the source design with its same filename into docs/history/designs only when no active plan references it and its complete accepted handoff is covered | No premature closure, duplicate planning index or dangling active-source route; canonical current behavior remains in implementation/contracts/registries |
