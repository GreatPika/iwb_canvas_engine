---
schema: architecture-design/v4
date: 2026-08-27
commit: 07c547da09a44729916fd9fba3f86d84ab628c24
branch: main
disposition: READY_FOR_CONTRACT
outcome: R-001
---

# Design: Eraser Corridor Hot Path

## Basis

### Sources

| ID | Kind | Locator | Use |
| --- | --- | --- | --- |
| S-001 | research | `docs/history/research/2026-06-02-p12-eraser-context-action-request.md` | Historical repository mapping of eraser owners, budgets, preview, terminal commit, cleanup, and verification surfaces |
| S-002 | prior_design | `docs/history/designs/2026-08-24-deletion-eraser-and-selection-policies.md` | Prior accepted eraser deletion design whose terminal budget, resolver, cleanup, and owner boundaries remain applicable |
| S-003 | user | user request | Required long-gesture performance outcome, bounded internal mutable capture, mandatory form comparison, committed duplicate-append baseline, explicit lossy-trade-off direction, exactly one bounded terminal exact pass with named cleanup/no-op failures, public-API exclusion, performance-route constraint, and authority to select the architecture |
| S-004 | repository | `lib/src/interaction/eraser_machine.dart` | Current eraser capture, preview decision, terminal decision, and corridor point-count owner |
| S-005 | repository | `lib/src/interaction/interaction_engine.dart` | Current eraser pointer routing, single append, preview-read, terminal-read, session update, and cleanup coordination |
| S-006 | repository | `lib/src/interaction/interaction_read_port.dart` | Current immutable eraser request/facts boundary and preview/terminal method authority |
| S-007 | repository | `lib/src/runtime/runtime_interaction_read_adapter.dart` | Current full-corridor envelope, spatial candidate, exact-hit, budget, ordering, and terminal projection route |
| S-008 | repository | `lib/src/geometry/geometry_policy.dart` | Current corridor construction, envelope traversal, and preview/terminal budget-input authority |
| S-009 | repository | `lib/src/geometry/hit_test_policy.dart` | Current family-specific exact eraser geometry authority |
| S-010 | repository | `lib/src/contracts/public/canvas_preview.dart` | Current immutable public `CanvasEraserPreview` authority |
| S-011 | repository | `lib/src/frame/frame_drawable_policy.dart` | Current one-point and multi-point eraser overlay drawing behavior |
| S-012 | repository | `docs/contracts/validation_limits.md` | Current mandatory interactive eraser soft-limit and trim-to declarations |
| S-013 | repository | `docs/contracts/geometry.md` | Current corridor, preview/terminal budget, overflow, and no-partial policy authority |
| S-014 | repository | `docs/contracts/interaction_engine.md` | Current interaction ownership, preview, terminal, and cleanup contract |
| S-015 | repository | `docs/diagrams/seq_eraser_commit.mmd` | Current move-read, terminal-read, trim, commit, and cleanup sequence authority |
| S-016 | repository | `docs/diagrams/seq_eraser_exact_budget.mmd` | Current preview and terminal exact-budget sequence authority |
| S-017 | repository | `docs/diagrams/state_eraser.mmd` | Current eraser state-machine authority |
| S-018 | repository | `docs/verification/tests.md` | Current eraser, read-port, overlay, no-partial, and guardrail proof ownership |
| S-019 | repository | `docs/verification/performance.md` | Current official Flutter profile route, non-threshold evidence policy, and retired benchmark prohibition |
| S-020 | repository | `tool/guardrails/src/interaction_guardrail_checks.dart` | Current immutable interaction read-port collection enforcement |
| S-021 | repository | `tool/guardrails/src/geometry_spatial_guardrail_checks.dart` | Current preview/terminal eraser budget-input structural enforcement |
| S-022 | repository | `test/guardrails/interaction_guardrail_enforcement_test.dart` | Current eraser request/facts immutability negative proof |
| S-023 | repository | `architecture/decisions/ADR-0009-interaction-tool-machines-and-cleanup.md` | Retained tool-machine, interaction ownership, centralized cleanup, and edit-boundary rationale |
| S-024 | repository | `docs/contracts/public_api_v1.md` | Current public eraser-preview and erase-action semantic authority |
| S-025 | repository | `lib/src/contracts/public/canvas_actions.dart` | Current public erase action payload declaration |
| S-026 | repository | `lib/src/frame/overlay_preview_planner.dart` | Current direct conversion from public eraser preview to overlay primitive |
| S-027 | repository | `lib/src/surface/overlay_painter.dart` | Current eraser overlay primitive painting route |
| S-028 | repository | `test/diagnostics/fixtures/interaction_diagnostics_fixture.dart` | Current diagnostic fixture implementation of `InteractionReadPort` |
| S-029 | repository | `test/geometry/fixtures/eraser_exact_budget_no_partial_commit_fixture.dart` | Current eraser-overflow fixture implementation of `InteractionReadPort` |
| S-030 | repository | `test/interaction/fixtures/eraser_context_action_routing_fixture.dart` | Current eraser-routing fixture implementation of `InteractionReadPort` |
| S-031 | repository | `test/interaction/fixtures/text_edit_stale_commit_guard_fixture.dart` | Current stale-text fixture implementation of `InteractionReadPort` |
| S-032 | repository | `test/interaction/pointer_session_test.dart` | Current pointer-session test implementation of `InteractionReadPort` |
| S-033 | repository | `lib/src/interaction/pointer_session.dart` | Current active eraser-capture reference carriage and pointer-session shell update authority |
| S-034 | repository | `lib/src/interaction/interaction_runtime_intents.dart` | Current terminal eraser intent and retained corridor point-count carrier |
| S-035 | repository | `lib/src/runtime/runtime_root.dart` | Current eraser preparation, resolver, commit, cleanup, and delivery temporal owner |
| S-036 | repository | `lib/src/runtime/runtime_action_finalizer.dart` | Current public erase-action payload projection owner |
| S-037 | repository | `lib/src/contracts/internal/commit_action_intent.dart` | Current internal erase-action intent and point-count boundary |
| S-038 | repository | `test/interaction/fixtures/terminal_eraser_deletion_resolver_fixture.dart` | Current proof of eraser resolver, cleanup-before-delivery, and accepted-commit failure semantics |
| S-039 | repository | `docs/_registry/public_api_v1.yaml` | Canonical machine-readable public exported-name inventory |
| S-040 | repository | `lib/iwb_canvas_engine.dart` | Current root public barrel |
| S-041 | repository | `tool/guardrails/src/public_api_checks.dart` | Current analyzer-backed registry/barrel parity authority |

### Source Coverage

| Kind | Sources or none |
| --- | --- |
| prior_design | S-002 |
| research | S-001 |
| plan | none |
| user | S-003 |
| repository | S-004, S-005, S-006, S-007, S-008, S-009, S-010, S-011, S-012, S-013, S-014, S-015, S-016, S-017, S-018, S-019, S-020, S-021, S-022, S-023, S-024, S-025, S-026, S-027, S-028, S-029, S-030, S-031, S-032, S-033, S-034, S-035, S-036, S-037, S-038, S-039, S-040, S-041 |
| other | none |

### Evidence

| ID | Source | Locator | Observed fact |
| --- | --- | --- | --- |
| E-001 | S-004 | `lines 78-96` | `PointerEraserCapture` freezes constructor input and each distinct append spreads the full prior point list before another defensive freeze. |
| E-002 | S-005 | `lines 792-825` | Every distinct eraser move appends exactly once, sends the complete proposed corridor through `eraserPreviewFacts`, stores the returned capture, and publishes the returned preview. |
| E-003 | S-005 | `lines 1327-1345` | Eraser terminal appends the terminal point when distinct and sends the complete corridor through `eraserTerminalFacts`. |
| E-004 | S-006 | `lines 253-309` | The read request and both preview and terminal facts defensively copy complete corridor lists; preview additionally owns exact-hit IDs while terminal owns immutable deletion entries. |
| E-005 | S-007 | `lines 326-354` | Preview budget inputs scale with complete corridor length, while preview and terminal both enter the same eraser facts route. |
| E-006 | S-007 | `lines 408-527` | The shared facts route builds a complete-corridor envelope, queries candidates, exact-tests candidates, and reconstructs facts from the complete corridor. |
| E-007 | S-008 | `lines 62-99` | Corridor construction validates and copies every point, envelope construction walks the corridor, preview budgets scale by sample count, and terminal candidate/exact budgets are gesture-fixed. |
| E-008 | S-009 | `lines 165-181` | Exact eraser dispatch and element-family routing are geometry-owned. |
| E-009 | S-009 | `lines 300-949` | Family-specific exact helpers can walk the complete corridor for each candidate. |
| E-010 | S-004 | `lines 30-55` | Preview decisions publish only corridor and thickness while retaining exact-budget overflow only in the internal decision. |
| E-011 | S-004 | `lines 108-124` | `EraserPreviewDecision` exposes the internal exact-budget flag, but no public preview field for tentative IDs or budget state exists. |
| E-012 | S-005 | `lines 813-825` | InteractionEngine consumes the returned eraser capture and public preview but not preview erased IDs or the preview exact-budget flag. |
| E-013 | S-010 | `lines 163-173` | Public `CanvasEraserPreview` is final, exposes only corridor and thickness, and freezes its corridor. |
| E-014 | S-011 | `lines 6-67` | The generic frame drawing helper supports one-point and multi-point polylines and walks the multi-point list. |
| E-015 | S-012 | `lines 23-45` | Validation limits are mandatory and name an interactive eraser soft limit of 8000 points with trim-to 4000. |
| E-016 | S-004 | `lines 78-96` | The maintained capture has duplicate suppression but no 8000/4000 enforcement, decimation, resampling, or bounded storage. |
| E-017 | S-013 | `lines 161-198` | Geometry currently specifies per-sample preview budgets, corridor-only preview on preview overflow, gesture-wide terminal budgets, and cleanup/no-op with no partial effects on terminal overflow. |
| E-018 | S-014 | `lines 332-350` | InteractionEngine is the eraser preview producer and eraser preview remains overlay-only state separated from committed document mutation. |
| E-019 | S-015 | `lines 39-160` | The sequence depicts per-move candidate/exact refresh plus terminal full-corridor work, and claims trim on move and terminal even though maintained capture does not enforce it. |
| E-020 | S-016 | `lines 29-112` | The exact-budget sequence separately owns preview budget branches and terminal all-or-nothing overflow behavior. |
| E-021 | S-017 | `lines 27-156` | The state diagram models candidate refresh on every move, final-corridor terminal evaluation, and cleanup/no-partial terminal failure paths. |
| E-022 | S-018 | `lines 705-998` | Current verification owns eraser budget inputs, read/routing boundaries, terminal no-partial behavior, interaction guardrails, and one-/multi-point overlay behavior. |
| E-023 | S-019 | `lines 28-280` | The official external-public Flutter profile route has no numeric pass threshold, local comparison is supporting evidence only, and retired benchmark infrastructure must not return. |
| E-024 | S-020 | `lines 168-409` | The interaction guardrail enforces defensive immutable collection fields across the read-port boundary; it does not require the eraser corridor field itself to remain. |
| E-025 | S-021 | `lines 836-905` | Geometry/spatial guardrails currently require both preview and terminal budget-input methods and their limited payload shapes. |
| E-026 | S-022 | `lines 212-267` | Guardrail proof currently locks immutable eraser request corridor, facts corridor, and erased-ID shapes and therefore must migrate with the read boundary. |
| E-027 | S-023 | `lines 20-83` | ADR-0009 retains interaction-owned tool machines, centralized cleanup, and terminal mutation through the established edit boundary. |
| E-028 | S-025 | `lines 144-156` | Public erase action payload exposes eraser thickness, erased IDs, and corridor point count without defining a second raw-sample count. |
| E-029 | S-026 | `lines 78-138` | The overlay planner converts `CanvasEraserPreview` into an eraser overlay primitive carrying its corridor and thickness. |
| E-030 | S-027 | `lines 104-112` | The overlay painter sends the eraser primitive corridor through the frame drawing policy. |
| E-031 | S-007 | `line 56` | The production runtime adapter implements `InteractionReadPort`. |
| E-032 | S-028 | `lines 676-739` | The diagnostic fixture implements `InteractionReadPort`, including the preview read. |
| E-033 | S-029 | `lines 163-180` | The eraser-overflow fixture implements both eraser read methods on `InteractionReadPort`. |
| E-034 | S-030 | `lines 819-856` | The eraser-routing fixture implements `InteractionReadPort`, including preview and terminal reads. |
| E-035 | S-031 | `lines 647-687` | The stale-text fixture implements `InteractionReadPort`, including eraser methods. |
| E-036 | S-032 | `lines 417-487` | The pointer-session test fake implements `InteractionReadPort`, including eraser methods. |
| E-037 | S-001 | `lines 978-990` | Historical research maps InteractionEngine as the pointer, preview, cleanup, stale-terminal, and commit-intent owner and records its commit boundary through EditKernel. |
| E-038 | S-002 | `lines 269-273` | The prior accepted design preserves terminal eraser cleanup before fallible public delivery and the existing edit/runtime ownership boundary. |
| E-039 | S-024 | `lines 2429-2435` | The public API contract defines `CanvasEraserPreview` as an immutable corridor plus thickness. |
| E-040 | S-024 | `lines 2583-2592` | The public API contract exposes erase thickness, erased IDs, and `corridorPointCount`. |
| E-041 | S-033 | `lines 163-626` | `PointerSession` stores and forwards `PointerEraserCapture` by identity and rebuilds session/payload shells without walking or copying corridor points. |
| E-042 | S-005 | `lines 1833-1866` | `InteractionEngine` owns centralized pointer cleanup and releases capture reachability by clearing the active session. |
| E-043 | S-034 | `lines 139-181` | `EraserCommitIntent` carries immutable deletion entries, thickness, and the terminal `corridorPointCount` without recomputing corridor geometry. |
| E-044 | S-035 | `lines 3122-3251` | RuntimeRoot prepares eraser deletion/action state before resolver admission, discards or consumes the prepared commit, and performs cleanup before common delivery. |
| E-045 | S-036 | `lines 222-230` | Runtime action finalization copies the internal erase intent's `corridorPointCount` unchanged into `CanvasEraseActionPayload`. |
| E-046 | S-037 | `lines 182-200` | The internal `EraseActionIntent` stores the supplied `corridorPointCount` without deriving a second raw count. |
| E-047 | S-038 | `lines 511-600` | Existing terminal eraser proof requires state/action delivery listener failures after accepted consume to leave the committed deletion final rather than roll it back to cleanup/no-op. |
| E-048 | S-024 | `lines 84-106` | Public declarations plus the public API contract own public semantics/signatures, the registry owns exported names, and root registry/barrel parity is enforced bidirectionally. |
| E-049 | S-039 | `lines 1-104` | The canonical registry already contains `CanvasEraserPreview` and `CanvasEraseActionPayload`; no new public name or classification is required. |
| E-050 | S-040 | `lines 1-13` | The root barrel already exports the action and preview facades that expose the two affected public declarations. |
| E-051 | S-041 | `lines 14-35` | The public API guardrail derives the root namespace through the analyzer and compares it bidirectionally with the canonical registry. |
| E-052 | S-035 | `lines 2416-2499` | Common accepted-commit delivery applies spatial, resource, state/repaint, action, and observer effects after the commit has been consumed. |
| E-053 | S-035 | `lines 2671-2692` | RuntimeRoot finalizes and emits the public action during common post-consume delivery. |

### Requirements

| ID | Kind | Statement | Basis | Open shape |
| --- | --- | --- | --- | --- |
| R-001 | outcome | Long eraser gestures must use bounded active corridor memory and bounded per-move corridor work, eliminating repeated unbounded-prefix capture, read, envelope, and exact-hit processing while preserving one terminal all-or-nothing pass whose stale, invalid, spatial-budget, candidate-budget, and exact-budget failures produce cleanup/no-op with no partial effects. | S-003, E-001, E-002, E-003, E-004, E-005, E-006, E-007, E-015, E-016, E-017, E-019, E-020, E-021, E-037 | Concrete storage type, local helper decomposition, layout, and allocation strategy remain open. |
| R-002 | user_decision | Interaction owns one internal mutable retained corridor that appends distinct points without copy-on-append and never exposes mutable storage across a port or public boundary. Whenever the retained corridor exceeds 8000 points, it is replaced with an endpoint-preserving uniform index resample of 4000 points before further capture; terminal exact hit and `corridorPointCount` operate on that retained approximation. The accepted cost is that discarded detours can miss narrow intersections and shortcut chords can create false positives. | S-003, E-015, E-028, E-040, E-043, E-045, E-046 | Concrete private type, identifiers, storage layout, allocation strategy, and loop structure remain open; the 0.75-unit predecessor decimation is not included. |
| R-003 | constraint | `CanvasEraserPreview` remains the same immutable public corridor/thickness API and continues through the existing planner and painter to render one-point and multi-point overlays from the retained bounded corridor; the canonical exported-name inventory and root barrel remain unchanged. | S-003, E-013, E-014, E-018, E-029, E-030, E-039, E-048, E-049, E-050, E-051 | Snapshot construction and preview equality mechanics remain open. |
| R-004 | constraint | Preview spatial candidate and exact-hit reads leave the move path, while the existing immutable initial down-time one-point preview read seam remains. Pointer-up performs exactly one immutable terminal corridor read and one bounded candidate/exact evaluation against the retained corridor before deletion-entry projection; stale or invalid terminal input, spatial-query overflow, candidate-budget overflow, exact-budget overflow, or an empty exact result discard the whole pre-acceptance result and enter existing cleanup/no-op with no document, selection, spatial, projection, repaint, or action effect. Resolver, preparation, consume, cleanup, and post-consume delivery retain their distinct existing RuntimeRoot semantics rather than acquiring a broader rollback guarantee. | S-003, E-003, E-005, E-006, E-010, E-011, E-012, E-017, E-019, E-020, E-021, E-044, E-047 | Naming and private terminal request decomposition remain open. |
| R-005 | repository_rule | Interaction owns the one active capture and immutable public preview publication; `PointerSession` remains a passive internal reference carrier; capture state never crosses InteractionReadPort; the terminal port remains an immutable fact boundary; runtime adaptation owns terminal read orchestration and entry projection; geometry/spatial retain envelope, candidate, exact-hit, and terminal-budget authority; current runtime/edit owners retain prepare-before-resolver, discard-or-consume, cleanup-before-delivery, and irreversible post-consume delivery semantics. | E-002, E-003, E-006, E-008, E-018, E-024, E-027, E-038, E-041, E-042, E-043, E-044, E-045, E-046, E-047, E-052, E-053 | Declaration names and focused file placement remain open. |
| R-006 | constraint | The committed `db3d178a` single-append meaning remains: each admitted distinct sample is appended once before any possible resample, equal adjacent samples remain suppressed, and terminal endpoint preservation is explicit. | S-003, E-002, E-003 | Whether endpoint admission shares the move helper remains open. |
| R-007 | repository_rule | Verification must directly prove bounded capture and move work, deterministic 8000-to-4000 endpoint-preserving resampling, the documented narrow-intersection/shortcut accuracy boundary, removal of move-time preview reads, preservation of the initial one-point preview seam across every repository-derived implementation and direct consumer, post-resample overlay rendering and preview-only state/action isolation, exactly one terminal read/exact pass, stale/invalid/spatial/candidate/exact-budget/empty pre-acceptance cleanup with no partial effects, immutable terminal facts, retained point-count propagation, and the existing resolver plus irreversible post-consume delivery semantics. Independent failure families require durable admission in `docs/verification/tests.md`. | S-003, E-019, E-020, E-021, E-022, E-024, E-025, E-026, E-031, E-032, E-033, E-034, E-035, E-036, E-043, E-044, E-045, E-046, E-047, E-052, E-053 | Exact focused fixture extensions, observer names, and grouping remain open to the Change Contract. |
| R-008 | exclusion | No public API shape or exported-name change, unbounded trajectory buffer, bounded-memory exact claim, incremental exact state machine, asynchronous terminal protocol, restored predecessor code, restored retired benchmark infrastructure, numeric performance threshold, DiagnosticsHub probe, Change Contract, implementation, or unrelated reusable gesture-buffer abstraction is introduced by this design. | S-003, E-013, E-023, E-027, E-048, E-049, E-050, E-051 | Temporary uncommitted local diagnostics and the existing non-threshold profile route remain supporting evidence only. |
| R-009 | repository_rule | The existing official Flutter profile route must complete every required `eraser_dense_50k` phase and repeat and its existing artifact checker must accept the generated route output. This is a release-blocking completion and artifact-production gate only: it defines no numeric performance verdict, adds no benchmark identifier or schema, and restores no retired benchmark infrastructure. | S-003, E-023 | The profile commands, active catalog, generated-artifact schema, and checker behavior remain owned by `docs/verification/performance.md`; local timing interpretation is supporting evidence only. |

## Candidate Analysis

- Comparison: `two_or_three`
- Result: `selected F-001`
- Result basis: F-001, F-002, F-003, M-001, M-002, M-003, M-004, M-005, M-006, M-007, M-008, M-009, M-010, M-011, R-001, R-002, R-003, R-004, R-005, R-006, R-007, R-008, R-009, E-001, E-005, E-006, E-012, E-015, E-017, E-023, E-024, E-031, E-032, E-033, E-034, E-035, E-036

### Forms

| ID | Form | Hard constraints | Main trade-off | Basis |
| --- | --- | --- | --- | --- |
| F-001 | Interaction-owned bounded mutable retained corridor; initial down keeps the immutable one-point preview read; visual-only move updates publish immutable corridor previews without reads; pointer-up performs one bounded terminal read and exact pass against the retained corridor. | pass | Bounds active memory and removes unconsumed move geometry, but intentionally makes terminal deletion exact only for the endpoint-preserving 8000-to-4000 approximation and can lose narrow detours or add shortcut hits. | R-001, R-002, R-003, R-004, R-005, R-006, R-007, R-009, E-015, E-024, E-031, E-032, E-033, E-034, E-035, E-036 |
| F-002 | Preserve the initial immutable one-point preview read, then preserve every original segment in an append-efficient chunked trajectory without move reads and defer candidate/exact evaluation to one unbounded terminal traversal. | fail R-001, R-002, R-004, R-007, R-008 | Preserves original-segment coverage and removes move reads, but rejects the chosen retained approximation, active memory remains unbounded O(P), terminal geometry is not bounded, and the required post-resample/bounded-terminal proof family cannot apply; a bounded incremental-exact substitute has no current repository proof and is excluded rather than asserted. | R-001, R-002, R-004, R-007, R-008, E-003, E-006, E-009 |
| F-003 | Use the same bounded retained corridor as F-001 but preserve the current full preview read, spatial candidate, and exact-hit evaluation on every move before repeating terminal evaluation. | fail R-004, R-007 | Bounds the prefix size but retains per-move geometry and budget machinery whose IDs and overflow flag have no maintained observable consumer, so it cannot satisfy the required visual-only-move proof family. | R-001, R-002, R-003, R-004, R-007, E-005, E-006, E-010, E-011, E-012, E-017 |

### Material-Obligation Delta

| ID | Material obligation | F-001 | F-002 | F-003 | Independent authority |
| --- | --- | --- | --- | --- | --- |
| M-001 | The first over-limit retained corridor is immediately endpoint-preserving resampled to 4000 before another sample is admitted. | yes | no | yes | R-001, R-002, E-015 |
| M-002 | Terminal deletion intentionally uses the retained approximation rather than every original segment. | yes | no | yes | R-002 |
| M-003 | Move handling omits the read-port call, corridor envelope, spatial query, and exact-hit evaluation. | yes | yes | no | R-004 |
| M-004 | R-003 | yes | yes | yes | R-003 |
| M-005 | Pointer-up uses one bounded retained-corridor read/exact pass and preserves the named pre-acceptance all-or-nothing outcomes. | yes | no | yes | R-001, R-004, E-017, E-019, E-020, E-021 |
| M-006 | The immutable preview-read seam remains for initial down but has no move-time caller. | yes | yes | no | R-004, R-007 |
| M-007 | R-006 | yes | yes | yes | R-006 |
| M-008 | Direct post-resample overlay-rendering and preview-isolation proof has separate durable admission at its existing proof owners. | yes | no | yes | R-007 |
| M-009 | Direct visual-only-move and one bounded terminal-pass proof has admitted failure families with no proxy-only substitution. | yes | no | no | R-007 |
| M-010 | R-009 | yes | yes | yes | R-009 |
| M-011 | R-005 | yes | yes | yes | R-005 |

### Future Pressures

| ID | Pressure | Basis | Treatment | Closure refs | Accepted cost or risk |
| --- | --- | --- | --- | --- | --- |
| P-001 | A future product requirement may prefer original-segment accuracy over bounded active memory. | R-002, R-008 | deferred | D-002 | Meeting that future requirement requires architecture re-entry because the selected retained corridor intentionally cannot reconstruct discarded detours. |
| P-002 | Weak panels and arbitrarily long gestures require a stable upper bound without reviving private benchmark infrastructure. | S-003, E-015, E-023 | absorbed | D-001, A-001, A-012 | The design accepts approximation after overflow and uses direct bounded-work proof plus completion and artifact validation of the existing non-threshold `eraser_dense_50k` profile route rather than a numeric benchmark gate. |

## Decision Register

### D-001 — Bounded retained-corridor ownership and policy
- Concerns: `form`, `owner`, `source_of_truth`, `policy`, `dependency`, `state_data`
- Lock: Interaction owns one mutable active eraser corridor from admitted down until centralized cleanup. Each distinct move or terminal sample is appended exactly once without copy-on-append; equal adjacent points are ignored. If that append produces the first corridor above 8000 points, the same owner immediately replaces it with a 4000-point uniform index resample that preserves the first point and newest endpoint before another sample can be admitted. No minimum-distance decimation is added. The retained corridor is the single source for immutable public preview snapshots, the immutable terminal request, terminal exact geometry, and public erase `corridorPointCount`; no raw-sample count or second exact trajectory is retained. `PointerSession` remains the unchanged passive internal carrier of the capture reference: it neither owns mutation nor snapshots/copies corridor points, and no production owner retains an obsolete session shell across synchronous engine mutation. Mutable storage never crosses the public API or InteractionReadPort. Existing dependency direction remains interaction capture to immutable read port, runtime adapter, geometry/spatial, and current runtime/edit delivery owners.
- Open: Concrete private capture type, field names, storage layout, allocation strategy, resample loop mechanics consistent with uniform index selection, and focused helper placement remain open.
- Basis: R-001, R-002, R-003, R-005, R-006, E-001, E-002, E-003, E-013, E-015, E-024, E-027, E-028, E-041, E-042, E-043, E-045, E-046
- Form: F-001
- Realizes: M-001, M-002, M-004, M-007
- Depends on: none
- Contract targets: `classification`, `owner`, `source_of_truth`, `policy`, `dependency`, `state_data`, `acceptance`, `evidence`, `verification`, `durable_impact`, `unit_family`
- Rationale: The interaction owner already owns gesture capture and preview publication; internal mutation removes copy-on-append, the declared 8000-to-4000 policy bounds active memory, and one retained truth prevents a hidden unbounded exact trajectory from defeating the optimization.

### D-002 — Visual-only moves and one bounded terminal evaluation
- Concerns: `order`, `temporal`, `atomicity`
- Lock: Admitted down keeps the current immutable one-point preview read and publishes the first immutable preview. Each admitted distinct move performs the D-001 append/resample transition and publishes only an immutable visual corridor preview; it performs no InteractionReadPort call, envelope construction, spatial query, candidate ordering, exact hit, or deletion-entry projection. Pointer-up performs the terminal append/resample transition before taking one immutable retained-corridor snapshot and making exactly one terminal read. Runtime adaptation performs one bounded envelope/candidate/exact evaluation against that snapshot under the existing gesture-wide terminal budgets and exposes deletion entries only after complete success. Stale or invalid terminal input, spatial-query overflow, candidate-budget overflow, exact-budget overflow, or an empty exact result enters the existing pre-acceptance cleanup/no-op route with no document, selection, spatial, projection, repaint, or action effect. A nonempty success preserves the current RuntimeRoot order: prepare deletion and action state before resolver admission; discard and cleanup on resolver rejection; or consume the prepared commit, cleanup eraser state, then enter common spatial/resource/state/repaint/action/observer delivery. A delivery failure after consume does not roll back the accepted commit or become cleanup/no-op. Preparation and delivery retain their current failure behavior rather than acquiring a new transaction guarantee. The visual-only move phase, pre-acceptance no-op phase, and irreversible accepted-delivery phase require separate direct route-level proof and durable failure-family ownership; none may be inferred from final action absence or timing.
- Open: Private sequencing helpers, exact cleanup-reason decomposition, snapshot allocation, and reuse of existing terminal-read internals remain open provided there is one read/evaluation and no earlier irreversible effect.
- Basis: R-001, R-004, R-005, R-006, R-007, E-003, E-005, E-006, E-012, E-017, E-019, E-020, E-021, E-027, E-043, E-044, E-045, E-046, E-047, E-052, E-053
- Form: F-001
- Realizes: M-003, M-005, M-006, M-009, M-011
- Depends on: D-001
- Contract targets: `order`, `temporal`, `atomicity`, `acceptance`, `evidence`, `verification`, `durable_impact`, `unit_family`
- Rationale: Move-time exact facts are not consumed by the maintained public or interaction result, so visual-only moves remove the repeated hot work while the existing one-shot terminal boundary preserves both pre-acceptance no-op semantics and the distinct irreversible behavior of an already consumed commit.

### D-003 — Public compatibility and internal consumer migration
- Concerns: `compatibility`, `migration_retirement`
- Lock: `CanvasEraserPreview`, `CanvasEraseActionPayload`, public exports, one-point/multi-point overlay planning, and public stream/revision behavior keep their existing shapes. Only `docs/contracts/public_api_v1.md` changes the semantic meaning of a long-gesture preview corridor and erase `corridorPointCount` to the retained bounded approximation and records the possible missed narrow detour and shortcut false positive; the canonical public registry, root barrel, facade exports, and declaration shapes remain unchanged under the existing analyzer-backed parity guardrail and external compile proof. `lib/src/interaction/interaction_read_port.dart` and `lib/src/runtime/runtime_interaction_read_adapter.dart` retain the immutable initial preview and terminal signatures. The owning `InteractionReadPort` declaration, its repository-derived implementation closure, and direct `eraserPreviewFacts` call closure are authoritative for consumer discovery; the diagnostic, geometry-overflow, eraser-routing, stale-text, and pointer-session implementations declared by S-028 through S-032 are confirmed baseline witnesses, not an exhaustive allowlist. Eraser-routing expectations migrate from per-move preview reads to initial-only before the caller is removed. Confirmed direct-consumer witnesses are `test/geometry/fixtures/eraser_exact_budget_inputs_fixture.dart`, `test/geometry/fixtures/eraser_exact_budget_no_partial_commit_fixture.dart`, `test/guardrails/geometry_eraser_exact_budget_inputs_guardrail_test.dart`, `test/interaction/fixtures/interaction_read_port_fixture.dart`, `test/interaction/fixtures/terminal_eraser_entry_route_work_fixture.dart`, and `test/runtime/fixtures/runtime_config_materialization_fixture.dart`; the current repository-derived call closure, including any additional consumer, retains explicit initial/direct seam coverage unless a behavior expectation depends on move-time calls. Post-resample overlay rendering and preview-only state/action isolation extend their existing proof owners under separate durable admissions rather than creating parallel proof owners. `tool/guardrails/src/interaction_guardrail_checks.dart`, `tool/guardrails/src/geometry_spatial_guardrail_checks.dart`, `test/guardrails/interaction_guardrail_enforcement_test.dart`, and the corresponding `docs/verification/guardrails.md` declarations remain active and are not bypassed or weakened. Any public declaration/export, port signature, or guardrail retirement requires architecture re-entry.
- Open: Exact documentation wording, fixture organization, test names, and whether unchanged fake methods share helpers remain open.
- Basis: R-003, R-004, R-007, R-008, E-013, E-014, E-022, E-024, E-025, E-026, E-028, E-029, E-030, E-031, E-032, E-033, E-034, E-035, E-036, E-048, E-049, E-050, E-051
- Form: F-001
- Realizes: M-008
- Depends on: D-001, D-002
- Contract targets: `compatibility`, `migration_retirement`, `acceptance`, `evidence`, `verification`, `durable_impact`, `unit_family`
- Rationale: No public or port signature is needed for the optimization; retaining the initial immutable seam avoids unrelated interface churn while explicitly retiring only the unobserved move caller and updating the few behavior-sensitive consumers.

### D-004 — Explicit scope and accepted approximation boundary
- Concerns: `in_scope`, `out_of_scope`
- Lock: In scope are eraser capture ownership, bounded resampling, immutable preview derivation, move-time read removal, one terminal retained-corridor pass, affected semantic contracts/diagrams, consumer expectations, direct verification, retained-corridor point-count meaning, and completion plus existing-artifact validation of the maintained non-threshold `eraser_dense_50k` Flutter profile route. Excluded are original-segment accuracy after resampling, unbounded chunks, bounded incremental-exact processing, minimum-distance decimation, asynchronous terminal work, public API additions, new diagnostics, numeric performance thresholds, restored retired benchmark routes, new benchmark identifiers or schemas, importing predecessor code, a reusable cross-tool gesture buffer, and unrelated eraser resolver/commit policy changes.
- Open: None; any excluded mechanism or restoration of original-segment coverage requires architecture re-entry.
- Basis: R-001, R-002, R-008, R-009, E-023
- Form: F-001
- Realizes: M-010
- Depends on: D-001, D-002, D-003
- Contract targets: `scope`, `acceptance`, `evidence`, `verification`, `unit_family`
- Rationale: The boundary keeps the change performance-first and evidence-backed while making the selected accuracy loss visible instead of hiding an O(P) trajectory or inventing a new incremental semantics.

## Impact Register

### I-001 — Interaction eraser capture and route
- Action: update
- Surface: `lib/src/interaction/eraser_machine.dart`; `lib/src/interaction/interaction_engine.dart`
- Required by: D-001, D-002
- Resulting authority: D-001, D-002
- Contract requirement: Replace copy-on-append unbounded capture with the interaction-owned mutable retained corridor, exact duplicate/terminal admission, immediate endpoint-preserving 8000-to-4000 resampling, immutable preview snapshots, no move-time read call, and one immutable bounded terminal read while preserving the committed single-append baseline and centralized cleanup order. Keep `PointerSession` unchanged as a passive same-reference carrier; do not add a second snapshot or corridor copy there.

### I-002 — Eraser semantic contracts and diagrams
- Action: update
- Surface: `docs/contracts/validation_limits.md`; `docs/contracts/geometry.md`; `docs/contracts/interaction_engine.md`; `docs/contracts/public_api_v1.md`; `docs/diagrams/seq_eraser_commit.mmd`; `docs/diagrams/seq_eraser_exact_budget.mmd`; `docs/diagrams/state_eraser.mmd`
- Required by: D-001, D-002, D-003
- Resulting authority: D-001, D-002, D-003
- Contract requirement: Make the retained bounded approximation the documented preview, terminal geometry, and erase point-count truth; define append-before-resample, first/newest endpoint retention, and narrow-detour/shortcut consequences; change move diagrams to visual-only without read/geometry; keep the initial one-point read; preserve one terminal pass and existing global terminal budgets; distinguish pre-acceptance cleanup/no-op from prepare-before-resolver, discard-or-consume, cleanup-before-delivery, and irreversible post-consume delivery; update only public semantic prose while keeping registry, barrel, facades, and declaration shapes unchanged.

### I-003 — Eraser proof ownership and behavior-sensitive consumers
- Action: update
- Surface: `docs/verification/tests.md`; `test/interaction/eraser_context_action_routing_test.dart`; `test/interaction/fixtures/eraser_context_action_routing_fixture.dart`; `test/interaction/pointer_session_test.dart`; `test/geometry/eraser_exact_budget_no_partial_commit_test.dart`; `test/geometry/fixtures/eraser_exact_budget_no_partial_commit_fixture.dart`; `test/interaction/terminal_eraser_deletion_resolver_test.dart`; `test/interaction/fixtures/terminal_eraser_deletion_resolver_fixture.dart`; `test/surface/fixtures/overlay_drawable_policy_fixture.dart`; `test/interaction/fixtures/preview_public_state_fixture.dart`
- Required by: D-001, D-002, D-003
- Resulting authority: D-001, D-002, D-003
- Contract requirement: Admit separate durable failure families for bounded/copy-free move work, sample admission, single mutable-source/passive-carrier identity, cleanup lifecycle, deterministic retained-corridor resampling and its accuracy boundary, move-read regression, single terminal-pass work, post-resample overlay rendering, and post-resample preview-only state/action isolation; extend the existing terminal pre-acceptance no-partial family for the retained corridor and named failures; extend the existing terminal resolver/delivery owner to prove retained-corridor prepare-before-resolver, discard-or-consume, cleanup-before-delivery, and post-consume failure finality; update behavior-sensitive read counts while preserving the initial preview seam. Extend the current overlay, preview-public-state, and terminal-resolver proof owners rather than creating parallel owners. Record concrete owner, failing witness, direct oracle, proxy limits, and durable value for each admission before adding or extending proof.

## Assurance Register

### A-001 — Bounded retained-corridor work
- Verifies: R-001, R-007, D-001/policy, I-001, I-003
- Claim: Move-time capture storage and append/copy work remain bounded by the retained-corridor policy, and the first over-limit corridor is immediately resampled to 4000 before another sample is processed.
- Failure: Move work or active storage grows with an unbounded prior prefix, copy-on-append walks the retained prefix, or a triggering over-limit corridor survives into the next admission.
- Oracle: Drive the real interaction eraser route through one and multiple overflow cycles while an assertion-gated owner work observer reports copied-point work, retained counts, and resample events; doubling input samples beyond the soft limit must increase move work only by the fixed retained bound per move.
- Proxy risk: Final list length or elapsed time alone can pass while every append still copies the bounded prefix; private-field shape assertions overfit implementation.
- Evidence constraints: Observe deterministic work units at the real interaction owner, not wall-clock thresholds or restored benchmarks; permit the triggering append to exceed 8000 only until its immediate resample.
- Architecture seam: D-001

### A-002 — Retained approximation and accuracy boundary
- Verifies: R-002, R-007, D-001/policy, I-002
- Claim: Overflow resampling deterministically selects 4000 uniformly indexed points from the retained input, preserves its first point and newest endpoint, omits minimum-distance decimation, and makes that retained approximation the exact geometry and `corridorPointCount` truth.
- Failure: Resampling changes either endpoint, uses a different count or hidden decimation, terminal exact work sees discarded points, point count reports raw samples, or contracts imply original-segment accuracy after overflow.
- Oracle: Feed a deterministic over-limit corridor through the real capture and terminal route; compare retained indices, endpoints, preview corridor, terminal geometry input, `EraserCommitIntent`, `EraseActionIntent`, and public action point count, then use separate narrow-detour and shortcut-chord witnesses to observe the documented possible miss and possible added hit after resampling.
- Proxy risk: A helper-level resample test can pass while preview, terminal, or action count uses another corridor; testing only endpoints cannot expose a second exact trajectory or the accepted accuracy consequence.
- Evidence constraints: Exercise the owning capture through public preview and terminal read/commit boundaries; lock the documented uniform-index and endpoint policy without importing predecessor code or treating historical tests as authority.
- Architecture seam: D-001

### A-003 — Visual-only move route
- Verifies: R-001, R-004, R-007, D-002/order, D-002/temporal, I-001
- Claim: Initial down performs its one-point preview read and every distinct move publishes a visual retained-corridor preview without a read-port, envelope, spatial, exact-hit, or deletion-projection call.
- Failure: Initial admission loses its read, a move invokes any preview facts or geometry work, a duplicate point publishes work, or move publication no longer follows the append/resample transition.
- Oracle: Exercise the real interaction/runtime route with read and geometry work observers across initial down, duplicate moves, ordinary moves, and a resampling move; count phase-specific calls and observe the immutable preview produced after each admitted transition.
- Proxy risk: A machine-only preview test can pass while the runtime adapter is still invoked, and a final read count cannot distinguish initial from move calls or ordering around resample.
- Evidence constraints: Observe the real phase route with assertion-gated non-public work events; do not use wall-clock thresholds or private helper names as the oracle.
- Architecture seam: D-002

### A-004 — Public declaration and export compatibility
- Verifies: R-003, D-003/compatibility, I-002
- Claim: `CanvasEraserPreview`, `CanvasEraseActionPayload`, and their public exports retain exactly their current declaration shapes, and no mutable capture type or storage becomes public.
- Failure: A public field, constructor parameter, type, or export is added, removed, renamed, or made mutable, or the internal capture becomes reachable through the package API.
- Oracle: Run the existing analyzer-backed registry/root-barrel parity guardrail, trace the affected exported names to S-010 and S-025 through S-040, inspect the unchanged canonical S-039 entries, and compile existing external consumers through the root public barrel.
- Proxy risk: Consumer compilation alone can accept additive public drift, while declaration inspection alone can miss a changed export closure or unusable compatibility.
- Evidence constraints: Use the canonical registry, analyzer-derived root namespace, real public declarations, existing parity guardrail, and external compile proof; do not introduce an API mirror, snapshot registry, duplicate allowlist, or public mutable test hook.
- Architecture seam: D-003

### A-005 — Preview seam consumers and guardrail continuity
- Verifies: R-007, D-003/migration_retirement, I-003
- Claim: Every current implementation derived from `InteractionReadPort` and every current direct preview/budget seam consumer derived from repository call sites retains the immutable initial/direct seam while expecting no move-time calls, including all confirmed D-003 baseline witnesses; existing immutable-collection and geometry-budget guardrails still reject their negative fixtures without weakening scope.
- Failure: A repository-derived implementer or direct consumer no longer compiles or exercises its seam obligation, the discovered closure omits a confirmed baseline witness, a behavior fixture still requires move-time preview reads, mutable capture or lists cross the port, a guardrail is bypassed/removed, or an unrelated signature migration is introduced.
- Oracle: Derive the current implementation closure from the owning interface and the current direct consumer closure from `eraserPreviewFacts` call sites, compile every discovered implementation, compile and execute every discovered direct preview/budget seam consumer, confirm the D-003 baseline witnesses remain covered, exercise real initial and move routing, and run the existing positive and negative guardrail proofs against the unchanged immutable seam.
- Proxy risk: Interface compilation alone misses stale call-count behavior and guardrail weakening; a copied implementer inventory can drift and cannot replace direct consumers.
- Evidence constraints: Treat the owning interface and repository-derived direct call closure as authority and D-003 paths only as confirmed baseline witnesses; use existing direct fixtures and guardrail runners without adding an allowlist, mirror registry, or production marker.
- Architecture seam: D-003

### A-006 — Dependency and scope containment
- Verifies: R-005, R-008, D-001/dependency
- Claim: The change keeps the existing interaction-to-port-to-runtime-to-geometry/edit direction and introduces none of the excluded public, async, diagnostics, benchmark, unbounded, incremental-exact, predecessor-import, or cross-tool gesture abstractions.
- Failure: Production capture depends upward on runtime/geometry internals, mutable state crosses a boundary, a new public or asynchronous protocol appears, retired benchmark paths return, predecessor code is imported, or work moves into an unbounded hidden owner.
- Oracle: Review the resulting dependency graph, public export surface, changed production imports, active capture lifecycle, and durable artifact set against D-001 and D-004, supplemented by existing boundary/public checks.
- Proxy risk: A path-name or token scan can miss semantic aliases and can reject coherent local helpers; passing architecture checks cannot by itself prove absence of hidden retained state.
- Evidence constraints: Inspect real owner edges and public declarations and combine them with A-001 state observation; do not add a feature-local source scanner, copied forbidden list, or new benchmark registry as proof.
- Architecture seam: D-001

### A-007 — Eraser semantic documentation consistency
- Verifies: I-002
- Claim: Validation limits, geometry and interaction contracts, public point-count semantics, and all three eraser diagrams describe one retained-corridor lifecycle: append-before-resample, visual-only moves with the preserved initial read, one terminal pass, explicit approximation, named pre-acceptance cleanup/no-op branches, prepare-before-resolver, discard-or-consume, cleanup-before-delivery, and irreversible post-consume delivery.
- Failure: Any durable source still claims unbounded/full original coverage, move-time candidate refresh, terminal trim that loses the newest endpoint, multiple terminal passes, tentative public IDs, raw-sample point count, post-consume rollback/no-op, or a missing pre-acceptance partial-effect exclusion.
- Oracle: Compare every I-002 source directly with D-001 through D-003 and exercise the corresponding A-002, A-003, A-004, A-009, and A-013 behavior routes so each documented transition has a matching observable branch.
- Proxy risk: Documentation lint can pass while semantic diagrams contradict behavior, and behavior tests can pass while public or validation contracts retain the old promise.
- Evidence constraints: Review the named semantic owners and diagram branches as structured meaning; do not parse prose wording as a test oracle or create a copied documentation inventory outside I-002.
- Architecture seam: D-002

### A-008 — Permanent-artifact admission and proof-owner closure
- Verifies: I-003
- Claim: `docs/verification/tests.md` separately admits the bounded/copy-free-work, sample-admission, mutable-source/carrier, cleanup-lifecycle, retained-resampling/accuracy, move-read, single-terminal-pass, post-resample overlay-rendering, and post-resample preview-isolation failure families and explicitly extends both the existing terminal pre-acceptance no-partial family and existing terminal resolver/post-consume-finality family, with each admission naming its production owner, failing witness, direct oracle, proxy limits, and durable value and routing to the real proof owner.
- Failure: An independent family is missing, merged into an unrelated admission, owned by a fixture, proved only through a proxy, or implemented in a new/extended test without its required admission; or the existing no-partial owner is bypassed by a parallel artifact.
- Oracle: Inspect the authoritative admissions and trace each one to the production seam and real proof behavior in A-001, A-002, A-003, A-009, A-010, A-011, A-013, A-014, A-015, A-016, and A-017, then confirm every new or extended committed proof has exactly the matching admitted family.
- Proxy risk: Test count, filename presence, or registry membership cannot prove admission sufficiency or direct behavior; another test cannot serve as authority for the new proof.
- Evidence constraints: Use `docs/verification/tests.md` as the admission owner and production behavior as the oracle; prohibit natural-language scanners, copied test inventories, fixture-owned semantics, and duplicate no-partial families.
- Architecture seam: D-003

### A-009 — Single terminal-pass work
- Verifies: R-001, R-004, R-007, D-002/order, D-002/temporal, I-001, I-003
- Claim: Pointer-up performs exactly one immutable retained-corridor terminal read and one bounded envelope/candidate/exact evaluation before any commit preparation.
- Failure: Pointer-up invokes the terminal read or bounded geometry evaluation more than once, evaluates a different corridor snapshot, or begins commit preparation before evaluation completes.
- Oracle: Exercise the complete production interaction/runtime route for successful, empty, and budget-overflow terminal outcomes while phase-specific work observers count terminal reads, envelope construction, candidate query/order, exact evaluation, and preparation entry.
- Proxy risk: Final action/state equality cannot detect repeated terminal work, and a read-port count alone cannot detect duplicate geometry evaluation behind one read.
- Evidence constraints: Observe the real interaction/read/runtime/geometry phase boundaries with deterministic work events; do not infer one-pass behavior from timing or from the pre-acceptance atomicity proof.
- Architecture seam: D-002

### A-010 — Retained-corridor overlay rendering
- Verifies: R-003, D-003/compatibility, I-003
- Claim: One-point, ordinary multi-point, and post-resample retained corridors continue through the existing preview planner and painter as visible eraser overlays.
- Failure: Any of the three corridor forms disappears, renders through a different public representation, or bypasses the existing planner/painter route.
- Oracle: Publish real public previews for one-point, ordinary multi-point, and post-resample retained corridors and capture the resulting frames through the current planner and painter.
- Proxy risk: A frame helper test can pass while the public preview route is disconnected, and declaration compatibility cannot prove pixels are produced.
- Evidence constraints: Exercise the real public preview, planner, painter, and captured-frame boundaries without inspecting the mutable capture or adding a second rendering path.
- Architecture seam: D-003

### A-011 — Preview-only state and action isolation
- Verifies: D-003/compatibility, I-003
- Claim: Down-time and move-time retained-corridor preview publication changes only the existing preview state/revision surface and emits no erase action or committed document, selection, spatial, projection, or main-repaint effect.
- Failure: Preview publication mutates a committed or derived owner, advances a non-preview revision, emits an action, or exposes mutable capture state.
- Oracle: Observe the real runtime state, revisions, action stream, document, selection, spatial index, projection, and repaint classifications before and after initial, ordinary-move, and post-resample preview publication.
- Proxy risk: Action absence alone cannot prove revision isolation or absence of hidden derived mutations, while a DTO test cannot observe runtime effects.
- Evidence constraints: Use the existing public preview publication and runtime observation boundaries; do not infer isolation from final terminal state or add a production diagnostics surface.
- Architecture seam: D-003

### A-012 — Official dense-eraser profile completion
- Verifies: R-009
- Claim: The existing official Flutter profile route completes every required `eraser_dense_50k` phase and repeat and its existing artifact checker accepts the complete generated route output, without making a numeric performance pass/fail claim.
- Failure: The profile drive exits nonzero, crashes, hangs, misses overlay completion, omits or malforms a required dense-eraser report/artifact, fails the existing checker, introduces a numeric threshold verdict, or restores any retired benchmark route or identifier.
- Oracle: Run the official external-public Flutter profile command and then the existing artifact-checker command owned by `docs/verification/performance.md`; observe successful route completion and checker acceptance for the active catalog including all `eraser_dense_50k` phases and repeats.
- Proxy risk: Route-contract unit tests cannot prove the profile drive completes, one timeline file cannot prove catalog closure, and local timing comparison cannot supply the forbidden numeric verdict.
- Evidence constraints: Use only the maintained public example profile route, active catalog, generated local artifacts, and existing checker; do not commit artifacts, restore `tool/bench/**` or `test/benchmarks/**`, add benchmark IDs, or infer pass/fail from timing values.
- Architecture seam: D-004

### A-013 — Accepted eraser commit and delivery finality
- Verifies: R-005, R-007, D-002/order, D-002/temporal, D-002/atomicity, I-003
- Claim: A nonempty terminal result preserves prepare-before-resolver order; resolver rejection discards the prepared commit and cleans up without delivery; resolver acceptance consumes the commit, cleans up eraser state before common delivery, propagates retained `corridorPointCount` unchanged, and leaves the accepted commit final when a state or action listener fails during post-consume delivery.
- Failure: Resolver runs before deletion/action preparation, rejection consumes or delivers, acceptance delivers before cleanup, retained point count changes in an intent/finalizer, a post-consume listener failure rolls back the accepted deletion, or the route is reclassified as cleanup/no-op after consume.
- Oracle: Exercise the current terminal eraser resolver fixture and full RuntimeRoot route for rejection, successful acceptance, state-listener failure, and action-listener failure with a post-resample retained corridor; observe preparation, discard/consume, cleanup, spatial/resource/state/repaint/action/observer order, public point count, and final committed document.
- Proxy risk: A final action count cannot distinguish rejection from failed delivery, and a state snapshot alone cannot prove prepare/consume/cleanup order or unchanged point-count propagation.
- Evidence constraints: Extend the existing terminal eraser resolver/delivery proof owner and real runtime boundaries; do not create a parallel transaction model, promise rollback after consume, or infer delivery order from historical design prose.
- Architecture seam: D-002

### A-014 — Eraser sample admission
- Verifies: R-006, R-007, D-001/policy, I-001, I-003
- Claim: Each distinct move or terminal endpoint is admitted exactly once before any resample, equal adjacent samples are ignored, and the newest terminal endpoint survives resampling.
- Failure: A distinct sample is appended twice or skipped, an equal adjacent sample is retained, resampling occurs before the triggering sample is admitted, or terminal endpoint preservation fails.
- Oracle: Drive duplicate moves, ordinary distinct moves, an over-limit triggering move, and a distinct terminal endpoint through the real interaction route; observe admitted-sample events and retained corridor endpoints after each transition.
- Proxy risk: Final length alone cannot distinguish duplicate append from later resample, and helper-only tests cannot prove the engine calls admission once.
- Evidence constraints: Observe the owning interaction route and retained result without locking helper names or concrete storage layout.
- Architecture seam: D-001

### A-015 — Single mutable source and passive carrier
- Verifies: R-002, R-005, R-007, D-001/source_of_truth, D-001/state_data, I-001, I-003
- Claim: Exactly one mutable retained corridor exists; PointerSession forwards the same capture identity without snapshotting or owning mutation; no raw/original exact trajectory or obsolete production session remains reachable.
- Failure: A second mutable or exact corridor is retained, PointerSession copies corridor points or mutates capture, mutable storage crosses a port/public boundary, or an obsolete production session observes later capture mutation.
- Oracle: Observe capture identity and retained storage across engine construction, session-shell updates, move, terminal, and preview/port snapshots while tracing all production capture/session consumers for retained obsolete shells or second trajectories.
- Proxy risk: Equal final lists cannot prove identity or absence of a hidden exact buffer, while a source-field scan cannot prove runtime reachability.
- Evidence constraints: Combine real lifecycle identity/reachability observation with repository-derived consumer closure; do not require a specific private container or add a public diagnostics hook.
- Architecture seam: D-001

### A-016 — Mutable capture cleanup lifecycle
- Verifies: R-001, R-005, R-007, D-001/owner, D-001/state_data, I-001, I-003
- Claim: Cancel, stale terminal, invalid terminal, empty/budget no-op, resolver rejection, successful completion, and post-consume delivery failure all release active mutable eraser capture reachability through the existing centralized cleanup point appropriate to their phase.
- Failure: Any terminal/cancel route leaves the active capture or obsolete session reachable, clears it after an externally observable delivery that requires prior cleanup, or introduces a second cleanup owner.
- Oracle: Exercise each lifecycle exit through the real engine/runtime route and directly observe active-session/capture reachability plus cleanup ordering relative to resolver and delivery events.
- Proxy risk: Preview disappearance alone cannot prove mutable capture release, and garbage collection timing cannot be an oracle for owner reachability.
- Evidence constraints: Use the current centralized cleanup owner and phase events; do not add disposal protocols or private weak-reference tests.
- Architecture seam: D-001

### A-017 — Pre-acceptance no-partial atomicity
- Verifies: R-001, R-004, R-007, D-002/atomicity, I-003
- Claim: Stale, invalid, spatial-budget, candidate-budget, exact-budget, and empty terminal outcomes expose no deletion entries to commit preparation and change no document, selection, spatial, projection, main repaint, or action state.
- Failure: Any named outcome reaches preparation, publishes a partial candidate result, or mutates a committed/derived owner despite performing at most one terminal evaluation.
- Oracle: Exercise each named outcome through the real interaction/read/runtime route and directly compare entry projection, preparation calls, committed state, derived owners, repaint, actions, and cleanup before and after the attempt.
- Proxy risk: Action absence cannot prove no preparation or derived mutation, and the one-pass work oracle cannot prove atomicity.
- Evidence constraints: Extend the existing terminal no-partial proof owner; do not include resolver rejection or post-consume delivery failures in this pre-acceptance family.
- Architecture seam: D-002

## Stop Conditions

### H-001 — Original-segment accuracy becomes mandatory
- Trigger: Product requirements prohibit either missed narrow detours or shortcut-chord false positives after resampling, or require terminal hit testing against every admitted original segment.
- Invalidates: D-001, D-002, D-003, D-004, A-002, A-007, A-015, I-001, I-002, I-003
- Resolution requires: Re-enter architecture to choose between a larger/bounded accuracy contract, evidence-backed bounded incremental processing, or an explicitly accepted unbounded trajectory; do not add a hidden exact buffer beside the retained corridor.

### H-002 — Fixed retained-bound move cost remains unacceptable
- Trigger: Direct A-001 work evidence and the existing external-public profile route show that immutable preview snapshot/render work bounded at 8000 points still fails the supported weak-panel experience and the required remedy changes public preview shape, publication cadence, or rendering ownership.
- Invalidates: D-001, D-002, D-003, D-004, A-001, A-003, A-004, A-006, A-010, A-011, I-001, I-002, I-003
- Resolution requires: Re-enter architecture for a public compatibility, preview publication, or frame-ownership decision; do not restore retired benchmark infrastructure or silently lower validation limits inside implementation.

## Contract Interface

- Profile: `BEHAVIOR_CHANGE`
- Obligations: `PUBLIC_API_CHANGE`, `SEAM_MIGRATION`, `SEQUENCED_MIGRATION_AND_RETIREMENT`, `TEMPORAL_SURFACE_CLOSURE`, `ALL_OR_NOTHING_FAILURE_BOUNDARY`, `SOURCE_OF_TRUTH_SINGULARITY`, `WORK_BUDGET_CLOSURE`
- ADR Impact: none
- Sources: S-001, S-002, S-003, S-004, S-005, S-006, S-007, S-008, S-009, S-010, S-011, S-012, S-013, S-014, S-015, S-016, S-017, S-018, S-019, S-020, S-021, S-022, S-023, S-024, S-025, S-026, S-027, S-028, S-029, S-030, S-031, S-032, S-033, S-034, S-035, S-036, S-037, S-038, S-039, S-040, S-041
- Requirements: R-001, R-002, R-003, R-004, R-005, R-006, R-007, R-008, R-009
- Commitments: D-001, D-002, D-003, D-004
- Assurance: A-001, A-002, A-003, A-004, A-005, A-006, A-007, A-008, A-009, A-010, A-011, A-012, A-013, A-014, A-015, A-016, A-017
- Impacts: I-001, I-002, I-003
- Stops: H-001, H-002

## Diagrams

None: D-001 and D-002 make the retained-corridor ownership, resample transition, visual-only move path, terminal pass, and failure boundary explicit; I-002 owns the required updates to the maintained semantic diagrams.

## Readiness Matrix

### Architecture Closure

| Concern | Status | Support refs |
| --- | --- | --- |
| owner | closed | D-001 |
| in_scope | closed | D-004 |
| out_of_scope | closed | D-004 |
| source_of_truth | closed | D-001 |
| compatibility | closed | D-003 |
| order | closed | D-002 |
| policy | closed | D-001 |
| dependency | closed | D-001 |
| state_data | closed | D-001 |
| migration_retirement | closed | D-003 |
| temporal | closed | D-002 |
| atomicity | closed | D-002 |
| negative_proof_fixture | not_applicable | R-008, E-024, E-026 |
| recognition | not_applicable | R-008, E-023 |

### Gate Closure

| Gate | Status | Support refs |
| --- | --- | --- |
| Owner-Level Fix | pass | D-001, D-002, A-001, A-016, R-001, E-001, E-002, E-005, E-006 |
| Ownership | pass | D-001, A-015, A-016 |
| Source-Of-Truth Singularity | pass | D-001, A-002, A-015 |
| Source-Truth Minimality | pass | D-001, D-003, A-001, A-002, A-005, A-015, F-001, M-001, M-002 |
| Boundary-Owned Policy | pass | D-001, A-002 |
| Dependency Direction | pass | D-001, A-006 |
| Solution Proportionality | pass | F-001, F-002, F-003, M-001, M-002, M-003, M-004, M-005, M-006, M-007, M-008, M-009, M-010, M-011, R-001, R-002, E-015, R-004, R-003, E-017, E-019, E-020, E-021, R-007, R-006, R-009, R-005 |
| Outcome-Proof Fit | pass | A-001, A-003, A-009, A-016, A-017 |
| Verification | pass | A-001, A-002, A-003, A-004, A-005, A-006, A-007, A-008, A-009, A-010, A-011, A-012, A-013, A-014, A-015, A-016, A-017 |
| Future Pressure | pass | P-001, P-002, E-015, E-023 |
| Handoff Consumability | pass | CONTRACT, H-001, H-002 |
| Negative Proof And Fixture Quarantine | not_applicable | R-008, E-024, E-026 |
| State/Data Ownership | pass | D-001, A-015, A-016 |
| Sequenced Migration And Retirement | pass | D-003, A-005, A-008, I-003 |
| Temporal Surface Closure | pass | D-002, A-003, A-009, A-013, A-016, H-002 |
| All-Or-Nothing Failure Boundary | pass | D-002, A-013, A-017, H-001 |
| Bounded Recognition Scope | not_applicable | R-008, E-023 |

## Open Blockers

None
