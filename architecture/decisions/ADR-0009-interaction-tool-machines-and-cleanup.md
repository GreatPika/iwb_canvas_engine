# ADR-0009: Compose interaction as tool machines with centralized cleanup and admitted asynchronous requests

- Status: accepted
- Date: 2026-06-10
- Implementation state: implemented
- Source designs:
  - `docs/history/designs/2026-05-19-double-tap-context-action.md`
  - `docs/history/designs/2026-05-19-pointer-tool-cleanup-coordinator.md`
  - `docs/history/designs/2026-06-02-p11-draw-tools.md`
  - `docs/history/designs/2026-06-02-p12-eraser-and-context-action-request.md`
  - `docs/history/designs/2026-06-03-p12-findings-closure.md`
  - `docs/history/designs/2026-06-10-api-surface-invalid-terminal-cleanup.md`
  - `docs/history/research/2026-05-19-pointer-tool-cleanup-coordinator.md`
- Current owners:
  - `docs/contracts/interaction_engine.md`
- Supersedes: none
- Superseded by: none
- Retirement design: none
- Retired on: none

## Context

Move, selection, draw, line, eraser, context action, and text-request workflows
share pointer admission, preview, cancellation, stale-terminal handling, tool or
mode changes, runtime disposal, load cleanup, and public observation. If each
tool performs its own cleanup or directly mutates committed owners, equivalent
terminal paths can leave different transient state or bypass atomic edits.

Context requests introduce a second boundary: target resolution can be reliable,
rejected, stale, or budget-limited, and delivery is asynchronous to the input
call. Treating a failed resolution as empty canvas or retaining consumed request
facts would turn uncertainty and historical requests into live behavior.

Public pointer inputs can also contain non-finite positions. Dropping an invalid
up or cancel like an invalid move would strand an active session; allowing it to
continue through coordinate normalization could accidentally commit with an
unusable terminal sample.

## Decision

The interaction engine is the sole composition owner for tool machines. Each
machine owns tool-specific transient state and returns typed preview, mutation
intent, or cleanup outcomes. Accepted mutations route through the existing edit
boundary; tools do not read or mutate concrete store or selection owners.

One interaction-internal cleanup coordinator calculates effect-only cleanup for
cancel, stale or invalid terminal, tool/mode change, load, interactive disable,
runtime disposal, and no-op terminal paths. The interaction engine is its only
caller. The coordinator does not publish state, emit actions or requests,
schedule repaint, invoke resolvers, or open edits.

Host-recognized double tap enters the context-action route directly. A context
request is created only after an admitted target result, delivered
asynchronously, and represented by live guard facts until consumed or cleaned
up. Reliability failure is not converted into an empty-canvas request. Consumed
or retired request facts are removed rather than retained as a growing history.

Non-finite down and move samples are rejected without entering a session.
Non-finite up or cancel is represented as a no-position terminal cleanup input:
it may end matching transient state but cannot commit a mutation or reserve an
action timestamp.

## Rationale

Composed machines keep tool-specific policy local while the interaction engine
retains one admission, cleanup, preview, and commit-routing boundary. A pure
cleanup coordinator eliminates duplicated teardown ordering without becoming a
second state owner.

Typed context admission and live-only request facts preserve the difference
between a genuine empty-canvas target and an unreliable query. The separate
terminal-cleanup input lets unusable terminal coordinates end a lifecycle safely
without pretending they are valid positions.

## Consequences

- Tool machines cannot bypass edit atomicity or concrete-owner boundaries.
- All terminal and external interruption paths must converge on the same cleanup
  policy while preserving tool-specific no-op semantics.
- Request consumers must tolerate asynchronous delivery and stale/consumed ids.
- Cleanup-only terminals may clear preview/session state but cannot publish an
  accepted action or document mutation.
- Interaction repaint targets and public state are emitted by the owning
  composition layers after typed outcomes, not by the cleanup coordinator.

## Current owners and enforcement

`docs/contracts/interaction_engine.md` owns pointer admission, machine
composition, preview, cleanup, terminal commits, request admission and lifecycle,
and repaint targeting.

The current routes are `lib/src/interaction/interaction_engine.dart`,
`lib/src/interaction/pointer_tool_cleanup_coordinator.dart`,
`lib/src/interaction/pointer_sample_normalizer.dart`, the tool machines under
`lib/src/interaction/`, `lib/src/interaction/context_action_router.dart`, and
`lib/src/interaction/interaction_request_registry.dart`. Current boundary and
behavior proofs remain registered with the current contract rather than copied
into this ADR.

## Source evidence

The 2026-05-19 designs selected direct host double tap and a single cleanup
coordinator. The P11 and P12 designs selected tool-machine mutation routing,
eraser/context admission, and asynchronous request behavior. The P12 findings
design selected admitted/rejected target results and consume/remove request
facts. The 2026-06-10 design selected a public no-position terminal cleanup
shape. The earlier research observation that no coordinator existed is a stale
snapshot retained only as context.

Commit `048fa6c2` on 2026-06-10 recorded the execution Change Contract for the
last retained refinement. Commits `694cd434`, `c7533efa`, and `714a56dd`
implemented API, runtime, and surface terminal-cleanup routing, and `46709cad`
recorded verified completion. Earlier P11/P12 execution and implementation
commits establish the retained machine, cleanup, and request routes. Together
with the current owner, they establish the header date and implemented state.
