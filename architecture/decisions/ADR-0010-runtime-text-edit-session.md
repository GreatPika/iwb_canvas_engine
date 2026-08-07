# ADR-0010: Own text-edit sessions in runtime and the Flutter editor overlay in surface

- Status: accepted
- Date: 2026-06-04
- Implementation state: implemented
- Source designs:
  - `docs/history/research/2026-05-18-text-edit-stale-guard.md`
  - `docs/history/designs/2026-06-04-inline-text-editing-contract.md`
- Current owners:
  - `docs/architecture/01_runtime_ownership.md`
  - `docs/contracts/public_api_v1.md`
  - `docs/contracts/frame_rendering.md`
- Supersedes: none
- Superseded by: none
- Retirement design: none
- Retired on: none

## Context

The early text-edit flow left editor lifetime with the application and committed
through an ordinary text update. It lacked a runtime-held active session and a
single engine-derived geometry/style boundary. That shape could not coordinate
stale request guards, live multiline geometry, original-text paint suppression,
read-only admission, and replacement overlays without duplicating measurement
or mutating document visibility.

Owning a Flutter editor inside core runtime would invert platform boundaries.
Leaving all session state in application UI would make the engine unable to
guard the target and provide consistent frame suppression. Hiding committed text
by editing visibility would mutate the target and could invalidate the request
that authorizes the eventual text commit.

## Decision

Runtime owns one active guarded text-edit session and the public text-editing
port. The session exposes engine-derived live text, geometry, and style; runtime
owns admission, conflicting-start and read-only policy, guarded commit, dismiss,
stale detection, and transient paint-suppression identity. Starting editing
remains an application choice after a context request rather than an automatic
core interaction decision.

Frame owns text layout measurement and immutable suppression inputs. Measured
layout is shared with geometry and selection consumers so render, hit,
selection, edit bounds, and overlay placement do not calculate competing text
bounds. While a matching session is active, frame excludes the committed text
record and related decoration without changing committed visibility.

Surface owns the official Flutter `EditableText` overlay and its controller,
focus, scroll, and widget subscription lifecycle. The official overlay is a
replaceable helper; custom overlays consume the same public session geometry,
style, and live text without remeasuring engine layout.

Commit routes through the existing guarded command and edit boundary. Dismiss
clears transient session and suppression state without a document mutation.

## Rationale

Runtime is the narrow owner that can relate request identity, current element
facts, document epoch, session lifecycle, and commit admission without owning a
widget. Frame is already the measurement and painter-input owner. Surface is the
only layer that should own Flutter editing objects and IME/focus behavior.

This three-way split provides one layout source and one stale guard while
keeping platform UI replaceable. Transient suppression avoids double painting
without turning an editing concern into committed document state.

## Consequences

- Applications may use the official overlay, a custom overlay, a menu, or no
  editor without changing runtime ownership.
- Live text and geometry may change during a session while committed text stays
  unchanged until an accepted commit.
- Stale commit rejection and dismiss restore paint participation without partial
  document mutation.
- Surface overlays must consume session geometry and must not introduce a second
  text-layout authority.
- Runtime/session cleanup participates in load, read-only, disposal, and request
  lifecycle without owning Flutter focus or IME state.

## Current owners and enforcement

`docs/architecture/01_runtime_ownership.md` owns the runtime/session/surface
allocation. `docs/contracts/public_api_v1.md` owns text-edit port, session,
admission, commit, dismiss, and public overlay behavior.
`docs/contracts/frame_rendering.md` owns measurement and paint suppression.

The current routes are the runtime text-editing implementation in
`lib/src/runtime/runtime_root.dart`, public API exposure through
`lib/src/api/canvas_text_editing.dart`, frame measurement and suppression under
`lib/src/frame/`, and
`lib/src/surface/text_editing_overlay.dart`. Current guarded-commit,
single-measurement, suppression, and widget-lifecycle proofs remain with the
current owners.

## Source evidence

The 2026-05-18 research records the earlier app-owned snapshot and missing
request/session guards. The 2026-06-04 design selected runtime session ownership,
frame-owned measured layout and suppression, and a replaceable surface-owned
Flutter overlay. It is selected-form evidence, not the acceptance event.

Commit `2119ec77` on 2026-06-04 recorded the execution Change Contract. Commits
`77a0be72`, `a3f61336`, `e3fb55a4`, `2aa5e189`, and `af46d815` implemented the
measurement, public contracts, runtime session, frame suppression, and surface
overlay routes. Later focused fixes and `c2d8b6bb` recorded closure of the text
editing step. Those commits and current owners establish the header date and
implemented state.
