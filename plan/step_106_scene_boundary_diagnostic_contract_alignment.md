language: english

# Change Contract

## 1. Change Mandate
This change fixes scene import/build diagnostics so the public boundary keeps
one machine-readable contract across parsed JSON and typed snapshot entrypoints,
with `message` remaining derived user-facing text instead of branch-owned
semantics.

## 2. Change Boundary

### Included in the Change
- Collection-limit diagnostics for palette item counts and stroke point counts
  in parsed-map import and typed-snapshot import.
- Optional `naturalSize` diagnostics for wrong-type, non-finite, and range
  failures on image nodes.
- Custom parsed color and enum-like decode branches in
  `lib/src/model/scene_builder_json_parse.dart`.
- Public documentation and changelog updates for the scene boundary error
  contract.

### Not Included in the Change
- JSON schema version changes, field renames, or shape migrations.
- Runtime mutation semantics, rendering behavior, or controller interaction
  behavior.
- Unrelated decode/import failures outside the listed collection-limit,
  optional-size, and custom parse families.
- Renaming boundary-specific field paths that are part of the accepted public
  payload shape, including JSON `localPoints`.

## 3. File Map and Analysis Areas

### Implementation Files
- `lib/src/contract/scene_data_exception.dart`
- `lib/src/model/scene_builder_decode_scene_metadata.dart`
- `lib/src/model/scene_builder_decode_stroke.dart`
- `lib/src/model/scene_builder_json_parse.dart`
- `lib/src/model/scene_policy.dart`
- `lib/src/model/scene_value_validation_palette_grid.dart`
- `lib/src/model/scene_value_validation_node_stroke.dart`
- `lib/src/model/scene_value_validation_node_image.dart`
- `lib/src/model/scene_value_validation_support.dart`
- `README.md`
- `API_GUIDE.md`
- `ARCHITECTURE.md`
- `CHANGELOG.md`

### Test Files
- `test/model/scene_builder_test.dart`
- `test/public_api/scene_builder_test.dart`
- `test/serialization/scene_codec_validation_test.dart`

### Analysis Area
- `lib/src/contract/scene_data_exception.dart`
- `lib/src/model/scene_builder_decode_scene_metadata.dart`
- `lib/src/model/scene_builder_decode_stroke.dart`
- `lib/src/model/scene_builder_json_parse.dart`
- `lib/src/model/scene_policy.dart`
- `lib/src/model/scene_value_validation_*.dart`
- `lib/src/model/scene_value_validation_support.dart`
- `test/model/scene_builder_test.dart`
- `test/public_api/scene_builder_test.dart`
- `test/serialization/scene_codec_validation_test.dart`
- `README.md`
- `API_GUIDE.md`
- `ARCHITECTURE.md`
- `CHANGELOG.md`

### Outside the Change Boundary
- Any files outside the listed zones.
- An exception is allowed only for a targeted change without which a specific
  slice and its verification cannot be closed.

### File Change Rule
- Every modified implementation file must be tied to a specific slice.
- Every new or modified test must be tied to a specific verification.
- Every newly proposed file or directory name must comply with the global
  `AGENTS.md` section `### File naming`.
- Untied changes are considered out of scope for the change.

## 4. Locked Decisions

1. `SceneBuilder.buildFromSnapshot(...)`, `SceneBuilder.buildFromJson(...)`,
   and `decodeScene(...)` continue to use `SceneDataException.code`, `path`,
   and immutable `details` as the machine-readable comparison contract, while
   `message` remains derived user-facing text.
2. This step must remove duplicate ownership of collection-limit message text
   instead of preserving branch-specific `Field ... Field ...` variants as a
   supported contract.
3. Optional `naturalSize` diagnostics must report component-local failures on
   `naturalSize.w` and `naturalSize.h`, matching the existing required-size and
   policy-owned range-path shape.
4. Custom parsed color and enum-like failures must move their machine-readable
   meaning into `SceneDataException.details` templates owned by
   `scene_data_exception.dart`.
5. Public documentation and changelog updates ship in the same change as the
   behavior updates.
6. Typed snapshot validation keeps `ScenePolicy` as the owner that throws
   `SceneDataException`, but validators must be able to pass structured
   diagnostic payloads through the existing validation-reporting seam instead
   of message text alone.
7. When `naturalSize` is present as an object, missing `w` or `h` is a child
   field contract failure and must report `SceneDataErrorCode.missingField` on
   the exact missing child path.
8. Invalid color parse failures use the exact details payload
   `{'template': 'invalidColorLiteral', 'value': <original-literal>}`.
9. Unknown parsed enum-like failures for node type, fill rule, text align, and
   text direction use the exact details payload
   `{'template': 'unknownEnumValue', 'value': <original-literal>}`.

## 5. Result Requirements

1. Oversized palette diagnostics emitted by parsed-map import and typed
   snapshot import report the same deterministic `SceneDataException.code`,
   `path`, `details`, and derived `message`.
2. Stroke point-limit diagnostics no longer duplicate the `Field ...` prefix;
   they report one derived message for the existing boundary path of each
   entrypoint.
3. Optional `naturalSize` wrong-type, non-finite, and range failures expose
   child-path-aware diagnostics on `naturalSize.w` or `naturalSize.h` with
   stable `details`.
4. Invalid color literals and unknown enum-like values for node type,
   fill-rule, text align, and text direction expose stable
   `SceneDataException.details` templates so their semantic category is not
   carried only by `message`.
5. `README.md`, `API_GUIDE.md`, `ARCHITECTURE.md`, and `CHANGELOG.md`
   describe the updated boundary contract consistently.

## 6. Implementation Specification

### 6.1 Analysis Scope
- Reuse the existing public `SceneDataException` factory/template ownership in
  `lib/src/contract/scene_data_exception.dart` instead of introducing a second
  diagnostics contract owner.
- Keep parsed-map import ownership in the existing `scene_builder_decode_*`
  and `scene_builder_json_parse.dart` modules.
- Keep typed snapshot orchestration ownership in `ScenePolicy` and the existing
  `scene_value_validation_*` validators.
- Carry typed-validation parity data through
  `lib/src/model/scene_value_validation_support.dart` by extending the
  validation reporter payload with structured `SceneDataException` inputs
  needed by `ScenePolicy`; do not bypass `ScenePolicy` by throwing directly
  from validators.
- Preserve the current public payload field names and snapshot field names for
  this step.

### 6.2 Target Verification Units
- Public builder contract coverage in `test/public_api/scene_builder_test.dart`.
- Internal model regression coverage in `test/model/scene_builder_test.dart`.
- Parsed JSON / codec parity coverage in
  `test/serialization/scene_codec_validation_test.dart`.
- Final repository verification through the canonical command required by
  `AGENTS.md` for code changes.

### 6.3 Protected States, Data, or Structures
- The accepted parsed JSON field names, including `localPoints`,
  `naturalSize.w`, and `naturalSize.h`.
- The existing public `SceneBuilder`, `decodeScene(...)`, and
  `SceneDataException` API surface.
- The existing `ScenePolicy` ownership of final typed-snapshot
  `SceneDataException` construction.
- Existing duplicate-id, schema-version, and transport-level boundary
  contracts outside the slices listed in this plan.

### 6.4 Allowed Semantic Change Zones
- Ownership and derivation of collection-limit diagnostics.
- Optional image `naturalSize` decode diagnostics.
- Structured validation payload transport between `scene_value_validation_*`
  validators and `ScenePolicy`.
- `SceneDataException.details` templates and their derived message rendering
  for custom parse failures.
- Public documentation and changelog statements about boundary-equivalent
  diagnostics.

### 6.5 Recognition Forms That Must Be Supported Within This Change
- Oversized `palette.penColors`, `palette.backgroundColors`, and
  `palette.gridSizes` collections.
- Oversized stroke point collections on parsed JSON `localPoints`.
- Oversized stroke point collections on typed snapshot `points`.
- Present `naturalSize` objects missing `w`.
- Present `naturalSize` objects missing `h`.
- Optional `naturalSize` component wrong-type failures.
- Optional `naturalSize` component non-finite failures.
- Optional `naturalSize` component range failures.
- Invalid color literals.
- Unknown node type values.
- Unknown path fill-rule values.
- Unknown text align values.
- Unknown text direction values.

### 6.6 Allowed Forms That Do Not Count as Violations
- Boundary-specific field-path differences that already belong to the public
  shape, including JSON `localPoints` versus typed snapshot `points`.
- Existing derived-message wording that still comes from a stable
  `SceneDataException.details` template after this step.
- Existing validator call structure that reports failures through
  `ScenePolicy`, as long as that seam carries structured payloads.
- Failures outside the listed diagnostic families that keep their current
  contract untouched in this step.

### 6.8 Prohibited
- Do not widen this step into JSON schema or payload-shape migrations.
- Do not keep or add tests that treat branch-specific duplicate `Field ...`
  text as the supported contract.
- Do not close Slice 1 by changing only message text while leaving typed
  collection-limit `details` empty.
- Do not leave the behavior for missing `naturalSize.w` or `naturalSize.h`
  unspecified once optional-size parsing is componentized.
- Do not leave invalid color or unknown enum diagnostics dependent on parsing
  `message` text alone after touching those branches.
- Do not introduce a second public error-comparison rule beyond
  `code` / `path` / `details`.

## 7. Execution Rules

1. One slice closes one new verifiable change contract.
2. Every slice must have its own verification.
3. A slice is considered closed only in the change where its verification
   exists and its run is green.
4. Preparatory changes alone do not count as a closed slice.
5. The next slice is forbidden until the previous slice is closed.
6. If a slice closes a failure scenario, diagnostic output confirming the
   trigger point must be attached.
7. If a slice changes an analysis rule, negative and positive scenarios must
   be covered where applicable to the subject of the change.
8. Scope expansion is forbidden until the mandatory slices are closed.
9. The plan must be detailed enough that the implementing agent has no
   material branch in how to execute a slice.
10. Every newly proposed file or directory name must comply with the global
    `AGENTS.md` section `### File naming` before the slice is considered
    valid.
11. If closing a slice would require renaming existing public boundary paths
    such as JSON `localPoints`, stop and add a follow-up step instead of
    widening this one.

## 8. Vertical Slices

### Slice 1. [x] Normalize collection-limit diagnostics

#### Slice Contract
Palette item-count failures and stroke point-limit failures keep one diagnostic
owner per boundary path, and typed snapshot import no longer emits duplicated
`Field ...` prefixes.

#### Change
- Replace the direct full-message throws for palette item counts in
  `lib/src/model/scene_builder_decode_scene_metadata.dart` with structured
  `SceneDataException` construction that leaves final message rendering to
  `scene_data_exception.dart`.
- Replace the direct full-message throw for stroke point-count overflow in
  `lib/src/model/scene_builder_decode_stroke.dart` with structured
  `SceneDataException` construction backed by a dedicated limit template that
  keeps the existing point-specific wording.
- Extend the validation reporter contract in
  `lib/src/model/scene_value_validation_support.dart` so typed validators can
  provide `SceneDataErrorCode` and immutable `details` together with the field
  and source value.
- Update `lib/src/model/scene_value_validation_palette_grid.dart` and
  `lib/src/model/scene_value_validation_node_stroke.dart` so they stop passing
  fully prefixed `Field $field ...` strings through
  `SceneValidationErrorReporter`, and so they pass the exact structured
  limit-details payload needed for parity with the parsed-map path.
- Keep `lib/src/model/scene_policy.dart` as the single owner that throws
  `SceneDataException` for typed-snapshot validation failures, but require it
  to construct those exceptions from the structured reporter payload instead
  of blind `Field $field $message` concatenation.
- Update tests so palette parity compares `code` / `path` / `details` / derived
  `message` across `SceneBuilder.buildFromJson(...)` and
  `SceneBuilder.buildFromSnapshot(...)` for `palette.penColors`,
  `palette.backgroundColors`, and `palette.gridSizes`, and stroke tests assert
  that the typed path no longer duplicates the prefix while preserving its
  current public field path.

#### Verification
- `flutter test test/model/scene_builder_test.dart`
- `flutter test test/public_api/scene_builder_test.dart`
- `flutter test test/serialization/scene_codec_validation_test.dart`

#### Positive Scenarios
- Oversized `palette.penColors` reports the same contract from parsed-map
  import and typed snapshot import.
- Oversized `palette.backgroundColors` reports the same contract from
  parsed-map import and typed snapshot import.
- Oversized `palette.gridSizes` reports the same contract from parsed-map
  import and typed snapshot import.
- Oversized stroke point lists still fail at the current boundary field path
  for each entrypoint with a single derived message.

#### Negative Scenarios
- Typed snapshot import must not produce `Field <path> Field <path> ...`
  diagnostics for palette or stroke limits.
- Typed snapshot import must not keep empty `details` for touched
  collection-limit failures when the parsed-map path exposes structured
  details.
- Parsed-map import must not fall back to empty or generic diagnostics for the
  touched limit failures.

#### Closure Evidence
- Green run of the listed verifications.
- Diagnostic output showing one-prefix failures for typed palette and stroke
  limit regressions.

### Slice 2. [x] Componentize optional `naturalSize` diagnostics

#### Slice Contract
Optional image `naturalSize` failures report the failing child component path
and stable `details` for wrong-type, non-finite, and range cases.

#### Change
- Replace the manual whole-object width/height checks in
  `lib/src/model/scene_builder_json_parse.dart` so optional size parsing
  validates `naturalSize.w` and `naturalSize.h` component-by-component through
  the existing finite-double boundary helpers.
- Preserve the existing nullable-object admission rule for missing
  `naturalSize` and the existing optional-object shape rejection for non-map
  values.
- When `naturalSize` is present, require both `w` and `h`; a missing component
  must fail with `SceneDataErrorCode.missingField` on the exact child path,
  matching the required-size contract.
- Keep range enforcement in the existing policy/validator path so negative or
  oversized component values still fail on the child component path.
- Update `test/serialization/scene_codec_validation_test.dart` to assert
  `code`, `path`, and `details` for missing-component, wrong-type, and
  non-finite optional-size failures instead of relying on whole-object custom
  message text.
- Add or update a public builder parity test in
  `test/public_api/scene_builder_test.dart` that proves parsed-map image
  `naturalSize` failures keep the public builder contract on the child path.

#### Verification
- `flutter test test/serialization/scene_codec_validation_test.dart`
- `flutter test test/public_api/scene_builder_test.dart`

#### Positive Scenarios
- Present `naturalSize` objects missing `w` or `h` fail on the exact missing
  child path with `missingField` details.
- `naturalSize.w` wrong-type fails on `...naturalSize.w` with stable
  field-type details.
- `naturalSize.w` non-finite fails on `...naturalSize.w` with stable
  finite-value details.
- Negative or oversized `naturalSize` components continue to fail on the
  exact child path.

#### Negative Scenarios
- Present `naturalSize` objects with a missing component must not fall back to
  the parent `naturalSize` path.
- Wrong-type and non-finite optional-size failures must not collapse to the
  parent `naturalSize` path.
- Optional-size parsing must not accept only one component while silently
  ignoring the other.

#### Closure Evidence
- Green run of the listed verifications.
- Diagnostic output proving wrong-type and non-finite failures now identify
  the concrete child component path.

### Slice 3. [x] Publish details-first custom parse diagnostics

#### Slice Contract
Invalid color and unknown enum-like parsed-map failures expose stable
`SceneDataException.details` templates, and the public documentation describes
those failures as details-first contracts with derived messages.

#### Change
- Extend `lib/src/contract/scene_data_exception.dart` with the exact detail
  templates and message-derivation branches needed for invalid color literals
  and unknown enum-like values.
- Lock the new public template ids and payload keys exactly as follows:
  invalid color literals use
  `{'template': 'invalidColorLiteral', 'value': <original-literal>}` and
  unknown enum-like values use
  `{'template': 'unknownEnumValue', 'value': <original-literal>}`.
- Update `sceneBuilderParseColor`, `sceneBuilderParseNodeType`,
  `sceneBuilderParsePathFillRule`, `sceneBuilderParseTextAlign`, and
  `sceneBuilderParseTextDirection` in
  `lib/src/model/scene_builder_json_parse.dart` to throw structured
  `SceneDataException` instances whose semantic meaning is carried by
  `details`, not by message-only branches.
- Update `test/serialization/scene_codec_validation_test.dart` and
  `test/model/scene_builder_test.dart` so the touched parse failures assert
  `details` together with `code` and `path`, while keeping the derived message
  checks only as secondary confirmation.
- Update `README.md`, `API_GUIDE.md`, `ARCHITECTURE.md`, and `CHANGELOG.md`
  so the published contract explicitly treats `message` as derived user-facing
  text for the touched parse failures.

#### Verification
- `flutter test test/model/scene_builder_test.dart`
- `flutter test test/serialization/scene_codec_validation_test.dart`

#### Positive Scenarios
- Invalid color literals report a stable details template that distinguishes
  them from other invalid values.
- Unknown node type, fill rule, text align, and text direction values report a
  stable details template that identifies the invalid literal and affected
  field.

#### Negative Scenarios
- Clients must not need to parse `Unknown ...` or `Invalid color: ...` message
  text to classify the touched failures.
- Parsed-map import and `decodeScene(...)` must not diverge on
  `code` / `path` / `details` for the touched parse branches.

#### Closure Evidence
- Green run of the listed verifications.
- Diagnostic output from invalid color and unknown enum scenarios showing the
  populated details templates.

## 9. Final Verification

- `flutter test test/model/scene_builder_test.dart`
- `flutter test test/public_api/scene_builder_test.dart`
- `flutter test test/serialization/scene_codec_validation_test.dart`
- `dart run tool/run_verification_preset.dart run --preset required_code_change --changed-paths-file=<prepared-path-list>`

## 10. Acceptance Criteria

- Result requirements are satisfied.
- Implementation specification is satisfied.
- Execution rules are satisfied.
- Mandatory slices are closed.
- Final verification has passed.
