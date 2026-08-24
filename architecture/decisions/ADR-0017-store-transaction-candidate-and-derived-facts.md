# ADR-0017: Coordinate sparse Store work through one candidate and owner-derived published facts

- Status: accepted
- Date: 2026-08-10
- Implementation state: partially implemented
- Source designs:
  - `docs/planning/designs/2026-08-10-sparse-commit-transaction-candidate.md`
- Current owners:
  - `docs/architecture/03_data_model.md`
  - `docs/contracts/edit_kernel.md`
- Supersedes: none
- Superseded by: none
- Retirement design: none
- Retired on: none

## Context

Sparse Store preparation previously coordinated independently published
snapshots. That made current cross-owner facts, finalization work, and
publication count harder to preserve as transactions grew. List-based order
also retained rank-shift cost, while route-generated IDs needed a rollback-safe
candidate without moving runtime delivery policy into the Store.

## Decision

1. Store sparse preparation uses one private transaction candidate that composes
   the existing family, resource, and structural owners and scalar facts.
2. The shared implicit AVL order algorithm is reused through separate mutable
   instances; no transaction gains a second order authority.
3. Final acceptance and touched facts derive from normalized owner facts, and
   Store publishes at most one immutable aggregate after owner finalization.
4. Route-generated IDs use a non-mutating, rollback-safe admission candidate;
   route and runtime delivery adoption remain separate work.

## Rationale

One coordination lifecycle makes live-owner reads and exact finalization order
observable without recreating family rows, descriptors, or order state. Shared
algorithm code preserves rank semantics while independent instances prevent
cross-transaction mutation. Owner-derived final facts avoid mutation-history
truth and prevent repeated aggregate publication. A non-mutating ID candidate
preserves failed-route rollback without making the Store own interaction timing.

### Alternatives rejected

- Rebuild a `CommittedDocument` after each sparse mutation or each frozen
  owner: it creates intermediate aggregate publication and stale cross-owner
  decision risk.
- Mirror family rows, descriptors, or order in an aggregate coordinator: it
  would introduce a second mutable truth and synchronization burden.
- Share one mutable indexed-order instance between transactions: it violates
  transaction isolation even when the AVL algorithm itself is shared.
- Derive accepted facts from mutation history or reserve route IDs eagerly:
  both lose final-fact authority or make failed routes irreversible.

## Consequences

- Accepted sparse preparation has zero or one aggregate publication and remains
  projection-free.
- Owner normalization, freeze, and derived-fact publication stay at their
  existing owner seams.
- Store candidate and indexed/derived infrastructure are implemented now.
- EditSession/DraftDocument now share one sole `StoreSparseMutation` journal:
  every successful sparse operation appends the unchanged DTO once, and explicit
  promotion consumes that list directly through exhaustive Draft application
  before discarding it through a write-only Draft mutation capability. Draft's
  promotion target opens and releases the materialized document around replay.
  Closure/listener replay is retired. Sparse structural ordering now uses
  owner-local lazy indexed sequences and one current location view seeded from
  the existing committed element-location facts; list orders and placement
  overrides are retired. Sparse resource decisions now combine Store's direct
  committed image/vector count summaries with session-local affected-id deltas,
  updated for every accepted row transition and clear barrier. This retires
  sparse accepted-element scans and copied count inventories; Store remains the
  owner of committed summaries and final relationship policy. Draft structural
  state now uses direct layer/element maps, one current placement view, and
  separate owner-local indexed orders; public Draft projection materializes
  those orders only on explicit reads. Its one insertion-ordered keyed descriptor
  owner also maintains exact image/vector counts from current rows, so resource
  decisions avoid descriptor `indexWhere` and all-element reference scans. Draft
  replacement now builds scalars, structure, descriptors/counts, selection
  validity, revisions, and touches in one fresh backing after existing
  validation, then atomically swaps that backing once; failed construction
  retains the prior backing without mutable alias sharing. Route-generated-ID/
  runtime delivery is still outside this decision; this ADR does not claim those
  routes are delivered.
- This complements ADR-0003's store-finalized accepted facts rather than
  superseding its edit-lifecycle decision.

## Current owners and enforcement

`docs/architecture/03_data_model.md` owns current Store candidate and compact
fact ownership. `docs/contracts/edit_kernel.md` owns Store finalization at the
edit boundary. Direct Store behavioral and owner-event fixtures enforce the
candidate lifecycle; their current inventory remains owned by
`docs/verification/tests.md`.

## Source evidence

The source design records the selected transaction candidate, implicit AVL,
owner-derived publication, and rollback-safe generated-ID decisions with an
ADR creation impact. The active Store data-model and edit-kernel contract own
the changing implementation facts; ADR-0003 provides the retained rationale
for store-finalized accepted edit transactions.
