# ADR-0003: Finalize synchronous edits from store-owned accepted facts and eliminate net no-ops

- Status: accepted
- Date: 2026-06-11
- Implementation state: implemented
- Source designs:
  - `docs/history/designs/2026-05-24-p5-edit-core.md`
  - `docs/history/designs/2026-06-06-incremental-edit-store.md`
  - `docs/history/designs/2026-06-11-net-no-op-edit-commit.md`
  - `docs/history/research/2026-05-18-action-events-notification-stream.md`
- Current owners:
  - `docs/contracts/edit_kernel.md`
  - `docs/contracts/operation_matrix.md`
- Supersedes: none
- Superseded by: none
- Retirement design: none
- Retired on: none

## Context

Public edits need a single mutation boundary that can validate multiple changes,
roll them back together, and publish consistent effects. Direct runtime or store
mutation would distribute session guards and failure behavior. An always-eager
mutable document draft would make small edits copy and compare unrelated
document state.

Sparse preparation introduced another risk: provisional touched or revision
deltas could appear to describe an accepted change even when later operations
compensated back to the original facts. Treating those provisional deltas as
truth would publish revisions and invalidations for a net no-op. Treating action
notifications as an undo journal would create a second mutation history owner.

## Decision

The edit kernel owns synchronous, non-nested session lifecycle, handle
validity, callback guards, rollback, and the public edit boundary. The document
store owns committed facts and preparation of sparse or materialized final
state. It performs final equality and returns accepted commit facts rather than
exposing provisional mutation intent as truth.

Only after validation and final comparison may the accepted document and any
prepared selection state be installed atomically. For ordinary sparse and
materialized commits, the commit compiler derives typed cross-owner effects from
store-accepted facts. Explicit `replaceDraftDocument` forced replacement is a
separate route compiled from session replacement facts and retains replacement
semantics even when public content is equal. Runtime composition orders
post-acceptance delivery and public observation without becoming the owner of
edit semantics.

If final committed document facts equal the original facts, the edit is a net
no-op: it performs no install, revision advance, invalidation, projection
eviction, state publication, effect publication, or action publication. An
explicit forced-replacement route may retain replacement semantics even for
equal public content because replacement identity and lifecycle are a separate
accepted operation.

Action events are notifications about accepted user-level actions, not an undo
journal and not a source of committed truth.

## Rationale

This allocation puts final truth with the owner able to compare store facts and
keeps edit orchestration responsible for transaction lifecycle rather than data
ownership. Sparse preparation removes full-document work from ordinary edits
without changing the public edit model. Compiling ordinary effects only from
store-accepted facts, while keeping forced replacement on its explicit
session-facts route, prevents downstream owners from observing speculative
touched sets without erasing replacement semantics.

Final equality is stronger than checking whether mutation methods were called:
it correctly handles compensating operations and preserves revision meaning.

## Consequences

- Any fallible validation and preparation occurs before the irreversible
  install; rejection preserves committed and observable state.
- Downstream owners consume typed accepted effects instead of inspecting drafts
  or recomputing document differences.
- Ordinary sparse edits must not materialize the public projection merely to
  determine effects or equality.
- No-op detection belongs to store finalization and applies consistently across
  callers rather than being patched into individual edit methods.
- Low-level edit mechanics do not imply user-action history semantics.

## Current owners and enforcement

`docs/contracts/edit_kernel.md` owns edit lifecycle, rollback, finalization,
accepted facts, effect compilation, and no-op behavior.
`docs/contracts/operation_matrix.md` owns the cross-owner effects and
observation consequences of accepted operations.

Their registered rollback, sparse-finalization, exact-invalidation, typed-effect,
no-projection, and net-no-op proof surfaces enforce the decision. Exact test and
guardrail inventories remain with those current owners rather than this ADR.

## Source evidence

The 2026-05-24 design selected the edit kernel as the synchronous transaction
owner and rejected direct runtime mutation, a command journal, and store-owned
session lifecycle. The 2026-06-06 design retained that boundary while moving
ordinary preparation to sparse store-owned facts. The 2026-06-11 design selected
store-owned final equality and accepted deltas to close the remaining gap and
eliminate all observable effects for compensating no-ops.
The action-event research supports the separate decision that notifications are
not an undo journal. Commit `18c822a2` on 2026-06-11 recorded the execution
Change Contract adopting D1-D8, and commit `234c14e0` closed verification the
same day. Those commits establish the header date and implemented state.
