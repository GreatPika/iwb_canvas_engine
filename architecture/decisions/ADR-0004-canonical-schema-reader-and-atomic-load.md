# ADR-0004: Load Schema v1 JSON through one codec reader and an atomic staged store install

- Status: accepted
- Date: 2026-06-14
- Implementation state: implemented
- Source designs:
  - `docs/history/designs/2026-05-26-p6-load-document.md`
  - `docs/history/designs/2026-06-07-canonical-schema-v1-json-load-api.md`
  - `docs/history/designs/2026-06-14-schema-v1-reader-consolidation.md`
  - `docs/history/research/2026-06-14-schema-v1-load-read-paths.md`
- Current owners:
  - `docs/contracts/load_document.md`
  - `docs/contracts/schema_v1.md`
  - `docs/contracts/codec_boundary.md`
- Supersedes: none
- Superseded by: none
- Retirement design: none
- Retired on: none

## Context

External JSON is untrusted boundary input, while replacing a live document
affects store facts, selection, runtime view state, interaction cleanup,
revisions, caches, repaint, and public observation. Decoding into a public
document and then loading it would add an eager public projection to the runtime
path and blur the distinction between wire validation and committed storage.

Separate public-decode and runtime-load parsers also duplicated Schema v1
traversal and field admission. The copies could drift even if both appeared to
accept the same examples. Conversely, sharing a retained generic fact graph or
public builder API would add allocation and expose internal load shapes.

## Decision

The codec owns one canonical Schema v1 reader for wire traversal, version and
field admission, and dependency-neutral decoded facts. The reader emits those
facts through codec-owned sink boundaries:

- public decode uses a codec-local sink that builds public values;
- runtime load uses an isolated store-oriented sink that prepares committed rows
  without materializing a public document.

Runtime load prepares parsing, validation, import identity, committed store
state, and interaction cleanup before the irreversible install. Preparation is
isolated from live state. Rejection before install makes no replacement-related
change to the committed document, selection, view camera or revisions, caches,
effects, actions, public state, or listener state. Diagnostics may record the
rejected input or failure before install. Success installs the replacement and
prepared cross-owner state as one atomic operation, then publishes the accepted
effects and one coherent public observation.

The public runtime load boundary accepts canonical Schema v1 JSON rather than a
public document DTO. Codec code does not own runtime side effects, and store
import code does not become a second wire-format reader.

## Rationale

One reader prevents semantic drift in wire admission while sink-specific
materialization preserves the different needs of public decode and runtime
load. The store path stays compact and lazy-projection-safe without making
internal rows public.

Staging all fallible work before interaction interruption and install gives the
replacement operation a clear commit point. It also prevents cleanup failures
or partial state publication from leaving a mixed old/new runtime.

## Consequences

- Schema evolution and known-field admission have one codec traversal owner.
- Reader facts and sink contracts must remain dependency-neutral and must not
  become a retained duplicate document model.
- Runtime load does not build a public document unless a later explicit read
  requests the projection.
- Interaction cleanup and all replacement facts must be prepared before install;
  post-install work is accepted delivery rather than rollback-capable parsing.
- Rejected loads may produce diagnostics, but they do not publish or install
  replacement-related runtime state or effects.
- Public decode remains side-effect-free even though it shares reader semantics
  with runtime load.

## Current owners and enforcement

`docs/contracts/schema_v1.md` owns wire-format semantics.
`docs/contracts/codec_boundary.md` owns the canonical reader and sink boundary.
`docs/contracts/load_document.md` owns staged replacement, failure preservation,
install ordering, and public observation.

Their registered codec, staged-load, atomicity, no-runtime-side-effect, and
lazy-projection proof surfaces enforce the current form. The exact schema and
proof inventories remain authoritative in those documents.

## Source evidence

The 2026-05-26 design selected prepared cleanup before atomic install. The
2026-06-07 design selected canonical JSON as the runtime boundary and rejected
public-document, public-row, and runtime-facade decoding forms. Research on
2026-06-14 established that two traversals still existed. The consolidation
design on that date selected one codec reader with separate public and store
sinks and identified the duplicated readers as the form to retire. Commit
`b44dae87` on 2026-06-14 recorded the execution Change Contract adopting D1-D8.
Commits `07211dd4`, `12a6eef4`, and `64f134ca` established the canonical reader
seam, routed the public decoder through it, and documented the current-owner
seam that same day. Those commits establish the header date and implemented
state.
