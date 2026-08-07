# Architecture Decision Records

This directory records the durable rationale behind architecture decisions for
`iwb_canvas_engine`. It is the canonical owner of ADR lifecycle, numbering,
catalog lookup, and supersession relationships. It does not own current package
behavior.

Current architecture, contracts, registries, code, and their existing
verification surfaces remain authoritative for changing facts. An ADR explains
why a durable decision was made, the alternatives and consequences that shaped
it, and where the current owners now live. It must not copy inventories,
thresholds, route tables, API membership, schemas, or other facts that can
change under those owners.

## Record shape

### Filename and numbering

- Use `ADR-NNNN-short-slug.md` with a four-digit, zero-padded identifier.
- Assign identifiers sequentially and never reuse or renumber them.
- Keep the filename stable after acceptance, including after supersession or
  retirement.
- Reserve an identifier only when its ADR file and catalog row are added in the
  same change. The next identifier is `ADR-0001`.

### Required header

Every ADR starts with one H1 title followed immediately by these fields in this
order:

```markdown
# ADR-NNNN: Decision title

- Status: accepted
- Date: YYYY-MM-DD
- Implementation state: implemented
- Source designs:
  - `path/to/source.md`
- Current owners:
  - `path/to/current-owner.md`
- Supersedes: none
- Superseded by: none
- Retirement design: none
- Retired on: none
```

Allowed `Status` values are `accepted`, `superseded`, and `retired`. Allowed
`Implementation state` values are `implemented`, `partially implemented`, and
`modeled`. Use `none` rather than omitting an empty relationship or retirement
field.

`Source designs` is the stable header name for source evidence. It may list
historical designs, plans, or research under the retrospective synthesis rules
below. `Current owners` names the live semantic owners and must not promote a
historical artifact, generated projection, or test into a current-fact owner.

### Required sections

Each ADR contains these sections in this order:

1. `Context`
2. `Decision`
3. `Rationale`
4. `Consequences`
5. `Current owners and enforcement`
6. `Source evidence`

The `Current owners and enforcement` section links to current sources instead
of restating their changing details. The `Source evidence` section explains how
the cited evidence supports the decision date, selected form, alternatives,
and consequences. A later replacement is explained in the successor ADR. The
predecessor's transition changes only its header; its body is not rewritten,
apart from the non-semantic repairs allowed below.

## When to consult and change ADRs

Consult every applicable accepted ADR before designing a durable architecture
change. Each architecture design declares its closed impact using exactly one
of these forms:

```text
ADR Impact: none
ADR Impact: create
ADR Impact: supersede ADR-NNNN[, ...]
ADR Impact: retire ADR-NNNN[, ...]
```

The initial ADR-0001 through ADR-0015 retrospective synthesis may create records
from the accepted historical evidence mapped in
`docs/history/research/2026-08-07-architecture-decision-candidate-inventory.md`
without a new active design. The inventory contains 14 source groups; its
performance lineage group is intentionally split into ADR-0014 for the old
custom numeric route and ADR-0015 for the current Flutter profile route. That
split produces 15 bootstrap records and is not an extra unmapped decision. This
bootstrap creates ADR-0014 as `superseded` with `Superseded by: ADR-0015`, and
ADR-0015 as `accepted` with `Supersedes: ADR-0014`. That specific retrospective
bootstrap transition is permitted without a new active design. The bootstrap
exception ends when those initial records are committed. Every later create,
supersede, or retire transition requires an approved active architecture design
and its declared `ADR Impact`. Planning and review consume that declared impact;
they do not invent a new decision, expand the impact, or select a different
lifecycle transition.

Repairs to a path, link, or typo that do not change meaning are non-semantic and
do not require an architecture design or a new ADR. A repair must not alter the
decision, rationale, consequences, lifecycle, or relationship graph.

## Lifecycle

### Status

- `accepted` means the decision is the retained architectural choice. It may be
  implemented, partially implemented, or modeled.
- `superseded` means a later ADR replaced the whole decision. The old record
  remains available as historical rationale.
- `retired` means the decision no longer applies and has no replacement ADR.
  A retired ADR records the retirement design and retirement date.

Status changes update the ADR header only. Catalog membership, link, and title
remain unchanged unless the filename or title itself legitimately changes under
this policy. Superseded and retired identifiers remain reserved and their files
are never deleted merely because their decisions are no longer current. Once
the transition is recorded, superseded and retired records are immutable except
for the non-semantic path, link, and typo repairs defined above. Reusing
equivalent rationale later requires a new identifier and an approved
architecture design.

### Implementation state

Implementation state is a navigation hint, not lifecycle status. It records
whether the selected decision has reached implementation, only part of its
scope has reached implementation, or it remains modeled. It may change without
changing `Status`. For a superseded or retired ADR it may record the maturity
the decision reached before replacement or retirement.

Implementation evidence belongs in current owners and enforcement surfaces.
The ADR links to that evidence but does not become its source of truth.

### Supersession

Supersession relationships are symmetric and acyclic:

- If ADR A lists ADR B under `Superseded by`, ADR B must list ADR A under
  `Supersedes`.
- When a replacement is created, the new direct successor is `accepted` and
  every predecessor it directly replaces becomes `superseded`.
- If that successor is later superseded, it retains its historical `Supersedes`
  links while its own status changes to `superseded`.
- One ADR may replace multiple earlier ADRs, but each superseded ADR has at most
  one direct successor.
- Backlinks remain symmetric, and a relationship must never create a path back
  to the superseding ADR.
- A supersession transition updates the headers of all involved ADRs atomically.
- Supersession changes the decision lifecycle, not the authority of current
  architecture, contracts, registries, code, or verification owners.

### Retirement

Retirement is used only when no ADR replaces the decision. A retired ADR sets
`Retirement design` to the surviving design evidence that authorized removal
and `Retired on` to its `YYYY-MM-DD` retirement date. Its `Supersedes` and
`Superseded by` fields remain `none` unless a separate, already recorded
relationship is required to explain an earlier lineage without presenting the
retirement itself as supersession.

`Current owners` remains mandatory and non-empty for a retired ADR. It names
the live semantic authorities for the affected domain that own or confirm the
old decision's absence. It does not name former implementation owners and does
not imply that a replacement ADR exists.

### Retrospective synthesis

The initial catalog is synthesized retrospectively from repository evidence.
The `Date` is the date when the full decision scope was accepted, not the date
when the ADR file was written.

Historical research may be cited when no design survives for an accepted
decision. In that case the ADR body explains the evidence for the date and may
identify a repository commit as supporting evidence. It must not invent or link
to a deleted path. Historical evidence remains evidence only; current owners
remain authoritative for present behavior.

## Catalog

| ID | Record | Decision |
|---|---|---|

Add each ADR file, its catalog row, and its concern lookup entry atomically; do
not reserve an identifier for a record that does not exist.

The catalog is navigation only. ADR headers are the sole owners of each
record's lifecycle, date, implementation state, and supersession or retirement
relationships; the catalog does not mirror those facts.

## Lookup by concern

| Concern | ADRs |
|---|---|

Add each concern entry in the same change as its ADR file and catalog row.

## Maintenance rules

- Add an ADR file, catalog row, and concern lookup entry atomically when
  assigning a new ADR number.
- Update all involved ADR headers atomically when creating or changing a
  supersession relationship; catalog rows remain navigation only.
- Update an ADR's current-owner links when an owner moves, but do not rewrite
  its historical rationale to mirror the new owner's changing facts.
- Record a changed architectural choice in a new ADR and link it through
  supersession; do not silently rewrite an accepted decision into a different
  decision.
- Keep historical source artifacts unchanged. Corrections or clarifications
  belong in the ADR or the current owner appropriate to the fact.
- Do not add a second ADR registry, numbering file, supersession index, or
  generated mirror. This README is the catalog and lookup owner.
