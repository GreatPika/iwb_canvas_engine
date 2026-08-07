# ADR-0002: Separate committed document truth, lazy public projection, selection, and view camera

- Status: accepted
- Date: 2026-05-17
- Implementation state: implemented
- Source designs:
  - `docs/history/research/2026-05-17-frame-meta-revision-split.md`
- Current owners:
  - `docs/architecture/03_data_model.md`
- Supersedes: none
- Superseded by: none
- Retirement design: none
- Retired on: none

## Context

The public document model is useful for application reads, encoding, and
tooling, but using that object graph as live mutable runtime truth would make
ordinary edits, frame work, and selection changes pay for full-document
materialization. Runtime selection and the user's current viewport also have
different persistence and revision semantics from document content.

Camera terminology exposed a specific ownership ambiguity: a document needs a
persisted camera value for saved state, while interactive pan and zoom need a
runtime view that can change without editing the document. A related proposal
would have split a broader frame-metadata revision into finer domains. The
2026-05-17 evidence recorded that proposal as deferred at that time; current
owners now separately track `backgroundRevision` and `gridRevision`.

## Decision

Compact committed tables are the source of truth for persisted document facts.
The public document object is a lazy projection produced for explicit read and
serialization boundaries; it is not the live store and is not materialized by
ordinary runtime hot paths.

Selection identifiers and selection revision are runtime-owned state, separate
from committed document content. The persisted document camera is committed
document state. The runtime view camera is separate runtime state: construction
and successful Schema v1 JSON load initialize it from the persisted camera.
Ordinary persisted-camera edits, including `replaceDraftDocument` within an
edit, do not implicitly change runtime view camera. Later view navigation does
not mutate persisted document state or its public projection. Persisting a
camera change uses the document edit boundary.

Later revision-domain evolution, including the current separate
`backgroundRevision` and `gridRevision`, is outside this ADR's decision scope.
This ADR neither adopts that later split nor invents its provenance.

## Rationale

Separating compact truth from public projection keeps mutation, queries, and
render preparation proportional to the facts they need. It also gives
selection a lifecycle appropriate to interaction rather than serialization.

Separating runtime and persisted cameras prevents navigation from becoming an
implicit document edit while still allowing saved documents to provide an
initial view. Explicit persisted-camera edits keep undo, revision, projection,
and serialization behavior predictable.

## Consequences

- Public document projection may be cached, but committed tables remain its
  authority and invalidate it when persisted facts change.
- Selection changes do not rewrite or serialize the document.
- Runtime camera movement publishes view-state and repaint changes without
  dirtying the document; persisted camera changes use edit semantics.
- Construction and successful Schema v1 JSON load initialize runtime view state
  from persisted state without merging their subsequent ownership; ordinary
  persisted-camera edits do not.
- Background and grid revision ownership follows the current owners and remains
  outside this ADR.

## Current owners and enforcement

`docs/architecture/03_data_model.md` owns the current committed-table,
projection, selection, revision, and camera boundaries. Its linked contract and
release-proof surfaces enforce store/projection separation, selection
separation, camera semantics, and the absence of projection construction from
ordinary hot paths. This ADR does not reproduce their current field or revision
inventories.

## Source evidence

The 2026-05-17 research records the deliberate runtime-view versus
persisted-document camera split, the compact committed store and lazy projection
shape, and the separate selection owner. It also records that the broader
frame-metadata revision split remained deferred at that time. Current owners now
track `backgroundRevision` and `gridRevision` separately, but that later
revision-domain evolution is outside this ADR and no provenance is inferred for
it here. Repository commit `ee806e54` on 2026-05-17 identifies completion of the
runtime-state and camera-ownership step. Because the original step document no
longer survives, this ADR cites the live research artifact and commit evidence
rather than inventing a dead path.
