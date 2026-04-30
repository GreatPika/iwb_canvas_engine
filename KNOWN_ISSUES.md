language: english

# Known Issues

Confirmed active defects only.

## Rules

- Keep entries short.
- One entry per root cause.
- Use repository-local IDs in the format `KI-<number>`.
- Do not put feature ideas, vague risks, or temporary notes here.
- If an issue is listed here, it is unresolved.
- Do not track status here.
- Remove an entry in the same change that fixes it and adds regression proof.
- This file is not an archive.

## Entry Template

- `ID`
- `Severity`
- `Summary`
- `Detection`
- `Evidence`
- `Next action`

## Active Issues

### KI-16

- `ID`: KI-16
- `Severity`: P3
- `Summary`: `PathNode` diagnostic failure fields can become stale or remain
  unset when `enableBuildLocalPathDiagnostics` changes across cache hits or a
  later successful rebuild with diagnostics disabled.
- `Detection`: static inspection of `lib/src/core/path_node.dart`.
- `Evidence`: `_hasMatchingResolvedCache` keys only `svgPathData` and
  `fillRule`, while `_clearRecordedFailure` returns early when diagnostics and
  assertions are disabled; existing `test/core/nodes_test.dart` covers the
  diagnostics-enabled failure path but not diagnostics toggled after a cached
  failure or disabled before a successful rebuild.
- `Next action`: record diagnostics on cached failures when requested and clear
  recorded failures after successful rebuilds regardless of the current
  diagnostics flag, then add regression tests for both toggle directions.

### KI-17

- `ID`: KI-17
- `Severity`: P2
- `Summary`: load-profile diff reports can pass when baseline and current both
  contain the same unexpected benchmark case outside the selected policy's
  required case taxonomy.
- `Detection`: static inspection of `tool/bench/diff_load_profiles.dart` and
  related bench tool tests.
- `Evidence`: `buildDiffReport` compares the union of baseline/current case
  names and checks missing required cases, but it does not fail on
  `allCaseNames - requiredCaseNames`; runner-side policy validation rejects
  unexpected cases, but `test/tool/bench_diff_load_profiles_test.dart` has no
  mirrored-extra-case regression test.
- `Next action`: make diff reports fail on unexpected baseline/current cases
  and add a test where both reports include the full required set plus the same
  extra case.

### KI-18

- `ID`: KI-18
- `Severity`: P2
- `Summary`: parsed-map scene import accepts malformed offset objects with
  non-string extra keys for line endpoints and stroke points, creating schema
  admission parity drift from other JSON object fields.
- `Detection`: static inspection of line/stroke scene-builder decode paths and
  JSON object key guards.
- `Evidence`: `line.localA`, `line.localB`, and `stroke.localPoints[i]` flow
  through `validatedRequireJsonFiniteOffset`, which accepts
  `Map<Object?, Object?>` and reads only `x`/`y`; the shared
  `sceneBuilderCastMap` guard rejects non-string keys but is not applied on
  these offset subobjects.
- `Next action`: apply the shared object-key guard before finite offset
  validation for these fields and add regression tests for non-string extra keys
  on both line endpoints and stroke point items.

### KI-19

- `ID`: KI-19
- `Severity`: P2
- `Summary`: draw terminal cleanup clears stroke and eraser preview buffers
  after terminal exceptions, but it does not guarantee an overlay repaint
  notification to remove the stale preview from the visual layer.
- `Detection`: static inspection of interactive draw terminal cleanup paths and
  `test/interactive/core/interactive_draw_terminal_cleanup_test.dart`.
- `Evidence`: stroke and eraser move paths call `onOverlayStateChanged`, and
  cancel cleanup also notifies after reset, but `commitOnUp` finally blocks only
  clear their path buffers; existing cleanup tests assert state reset on thrown
  terminal work without asserting overlay repaint notification.
- `Next action`: centralize terminal cleanup so buffer reset and overlay
  notification are paired for stroke and eraser terminal failures, then add
  regression tests for thrown stroke commit, eraser commit, and eraser action
  emission.

### KI-20

- `ID`: KI-20
- `Severity`: P2
- `Summary`: public contract hermeticity guardrails ban dangerous exported
  members on only three contract files, leaving other exported contract owner
  files outside that member-level proof surface.
- `Detection`: static inspection of `lib/iwb_canvas_engine.dart`,
  `tool/src/guardrails/rules/public/public_surface_rules.dart`, and public
  guardrail tests.
- `Evidence`: `_checkExportedContractHermeticMembers` scans only
  `snapshot.dart`, `node_spec.dart`, and `node_patch.dart`, while the public
  barrel also exports contract files such as `patch_field.dart`,
  `canvas_pointer_input.dart`, `scene_data_exception.dart`,
  `scene_render_state.dart`, `scene_write_txn.dart`, and `validated.dart`;
  the negative test injects banned members only into `snapshot.dart`.
- `Next action`: derive the scanned contract owner files from the effective
  public export surface and add negative tests for banned members in another
  exported contract file and a validated owner file.
