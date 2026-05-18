# Change Contract

Contract Mode: FULL
Contract Profile: SOURCE_OF_TRUTH_DOCS
Contract Obligations: BUG_FIX, PUBLIC_API_CHANGE

## 1. Mandate and Boundary

### Mandate

Close the accepted post-review consistency gaps in the target architecture
documents before API freeze: validating public constructor const policy, codec
public declarations, main-frame `selectionStyle` capture, and explicit persisted
camera write documentation.

### In Scope

- Update normative public API documentation so any public constructor accepting
  caller-provided values with documented runtime validation or sanitization is a
  non-const factory.
- Preserve `const` only for marker/empty/default/private storage forms where
  invalid public state cannot be constructed.
- Align public default values and examples with private const storage or approved
  default constants after public validating constructors stop being `const`.
- Add codec constants and functions to the public API declaration contract while
  keeping codec behavior owned by the codec boundary contract.
- Add `selectionStyle` as an explicit main-frame captured input for selection
  decoration, and align the main paint diagrams with that capture.
- Document the explicit edit boundary for persisting the current runtime view
  camera into the document camera without adding a camera-port convenience
  method.
- Update verification source-of-truth wording and generated/derived indexes as
  needed so future executable tests and guardrails prove the selected contract.

### Out of Scope

- No production Dart implementation under `lib/**`.
- No Dart test implementation under `test/**`.
- No analyzer, guardrail runner, or docs-tool implementation under `tool/**` or
  `docs/tool/**`.
- No schema version change and no codec behavior change.
- No addition of `CanvasCameraPort.persistCurrentOffset`.
- No runtime behavior, rendering behavior, or persistence behavior implementation
  change.
- No change to the already accepted runtime view camera versus persisted document
  camera ownership decision.
- No edit to legacy package files.
- No broad redesign of unrelated public DTOs or verification inventories.
- No execution of `dart analyze`, `dcm analyze .`, or `dcm calculate-metrics .`,
  because the planned work is documentation-only.

## 2. Evidence Map

### Baseline Evidence

These facts describe repository state before execution. They are evidence for
the change, not target-state requirements.

- `docs/contracts/public_api_v1.md:75` states that the Dart declarations in
  the document are normative.
- `docs/contracts/public_api_v1.md:79` through
  `docs/contracts/public_api_v1.md:84` state that
  `docs/_registry/public_api_v1.yaml` is the exported-name inventory while
  `docs/contracts/public_api_v1.md` owns public API semantics, signature rules,
  and declaration contracts.
- `docs/contracts/public_api_v1.md:549` through
  `docs/contracts/public_api_v1.md:554` state that collection and metadata
  constructors are non-const while safe scalar-only DTOs and marker/empty
  variants may remain `const` when they need no runtime validation beyond safe
  defaults.
- `docs/contracts/validation_limits.md:71` through
  `docs/contracts/validation_limits.md:84` list public DTO construction and
  other materialization paths as validation boundaries.
- `docs/contracts/public_api_v1.md:525` through
  `docs/contracts/public_api_v1.md:545` currently show public `const`
  `CanvasSelectionStyle` and `CanvasGridStyle` constructors while also requiring
  finite, non-negative numeric values and opacity range validation.
- `docs/contracts/public_api_v1.md:617` through
  `docs/contracts/public_api_v1.md:637` currently show public `const`
  `CanvasCamera` and `CanvasGrid` constructors.
- `docs/contracts/public_api_v1.md:691` through
  `docs/contracts/public_api_v1.md:746` currently show a public `const`
  `CanvasTransform` constructor while requiring finite components at public
  construction and decode.
- `docs/contracts/public_api_v1.md:1351` through
  `docs/contracts/public_api_v1.md:1427` currently show public `const`
  `CanvasPointerPolicy`, `CanvasPointerSample`, and `CanvasDrawStyle`
  constructors while documenting pointer and draw-style validation.
- `docs/contracts/public_api_v1.md:1506` through
  `docs/contracts/public_api_v1.md:1513` currently show a `const factory`
  `CanvasResourceSource.appKey` and public `const`
  `CanvasAppKeyResourceSource` constructor.
- `docs/contracts/schema_v1.md:116` through `docs/contracts/schema_v1.md:120`
  state that `appKey` requires a non-empty string, length `<= 1024`, with no
  control characters.
- `docs/contracts/public_api_v1.md:2086` through
  `docs/contracts/public_api_v1.md:2097` currently show a public `const`
  `CanvasDataException` constructor with map-shaped `details`.
- `docs/contracts/public_api_v1.md:2151` through
  `docs/contracts/public_api_v1.md:2154` require diagnostic details to be
  sanitized bounded public projection.
- `docs/_registry/public_api_v1.yaml:101` through
  `docs/_registry/public_api_v1.yaml:106` export codec constants and functions.
- `docs/contracts/codec_boundary.md:44` through
  `docs/contracts/codec_boundary.md:50` declare the codec constants and function
  signatures.
- `docs/contracts/codec_boundary.md:73` through
  `docs/contracts/codec_boundary.md:88` own codec decode/encode behavior and
  side-effect boundaries.
- `docs/contracts/frame_rendering.md:61` through
  `docs/contracts/frame_rendering.md:77` list `CapturedMainFrame` fields without
  `selectionStyle`.
- `docs/contracts/cache_policy.md:49` states that `SelectionDecorationPlan` is
  keyed by `selectionRevision`, `structuralRevision`, captured
  `selectionStyle`, and `devicePixelRatio`.
- `docs/diagrams/seq_main_paint.mmd:17` lists main paint request inputs without
  `selectionStyle`, and `docs/diagrams/seq_main_paint.mmd:24` builds
  `CapturedMainFrame` from viewport, device, and `gridStyle.strokeWidth` inputs.
- `docs/diagrams/dfd_main_paint_frame.mmd:92` sends "selection ids and style
  inputs" from `CapturedFrame` to `SelectionDecoration`.
- `docs/contracts/public_api_v1.md:1442` through
  `docs/contracts/public_api_v1.md:1448` define `CanvasCameraPort` without
  `persistCurrentOffset`.
- `docs/contracts/public_api_v1.md:1453` through
  `docs/contracts/public_api_v1.md:1458` state that `CanvasCameraPort` owns the
  runtime view camera and does not change persisted document camera.
- `docs/contracts/operation_matrix.md:63` keeps `CanvasEdit.setCameraOffset` as
  the persisted document camera edit path.
- `docs/contracts/operation_matrix.md:64` keeps `CanvasCameraPort.setOffset` and
  `panBy` as runtime view camera operations.
- `plan/step_6_public_runtime_state_and_view_camera_ownership.md:298` through
  `plan/step_6_public_runtime_state_and_view_camera_ownership.md:302` record
  `CanvasCameraPort.persistCurrentOffset` as rejected for Step 6 because
  `CanvasEdit.setCameraOffset` is already the document mutation boundary.
- `.research/2026-05-19-redesign-review-followup.md:15` summarizes the four
  post-review seams and records the observed public constructor, codec,
  `selectionStyle`, and camera facts.

### Entry Paths

- Public API consistency enters through `docs/contracts/public_api_v1.md`.
- Validation policy enters through `docs/contracts/validation_limits.md`.
- Codec public declaration consistency enters through
  `docs/_registry/public_api_v1.yaml`, `docs/contracts/public_api_v1.md`, and
  `docs/contracts/codec_boundary.md`.
- Frame capture consistency enters through `docs/contracts/frame_rendering.md`,
  `docs/contracts/cache_policy.md`, and main paint diagrams.
- Persisted camera documentation enters through `CanvasCameraPort` and
  `CanvasEdit.setCameraOffset` public contract text.
- Future proof wording enters through `docs/verification/**`,
  `docs/indexes/**`, and `docs/_registry/sections.yaml` when those inventories
  reference changed test or guardrail meanings.

### Current Owners

- `docs/contracts/public_api_v1.md` owns public API declarations, public
  constructor shape, codec public declaration snippets, and the user-facing
  camera example.
- `docs/contracts/validation_limits.md` owns construction and materialization
  validation boundaries.
- `docs/contracts/codec_boundary.md` owns codec decode/encode behavior, not the
  public export inventory.
- `docs/contracts/frame_rendering.md` owns captured frame fields and frame
  capture rules.
- `docs/contracts/cache_policy.md` owns cache keys and style-only cache
  exclusion rules.
- `docs/diagrams/dfd_main_paint_frame.mmd` and
  `docs/diagrams/seq_main_paint.mmd` own the visualized main paint frame flow.
- `docs/verification/**`, `docs/indexes/**`, and `docs/_registry/sections.yaml`
  own future proof descriptions, generated navigation, and registry mappings.
- Root `PLAN.md` owns roadmap ordering and links to step contracts.

### Existing Checks

- `dart run docs/tool/check_docs.dart` is the available structural check for
  documentation entrypoints, registries, ids, paths, and diagram catalog
  consistency.
- `dart run docs/tool/generate_context_capsules.dart --check` is the available
  consistency check for generated context capsules.
- Targeted `rg` searches are the available semantic checks for constructor
  shapes, codec declaration presence, style capture, and rejected camera helper
  absence.
- No root production `lib/**` or Dart `test/**` implementation is part of this
  documentation-only step.

### Valid Precedents

- Step 4 established the public DTO collection/metadata const policy and routed
  future proof through public API, validation, verification, and guardrail docs.
- Step 6 established runtime view camera versus persisted document camera
  ownership and rejected a camera-port persistence helper.
- Step 7 established `backgroundRevision` and `gridRevision` split while keeping
  `CanvasSurface.gridStyle` and `CanvasSurface.selectionStyle` as captured style
  values rather than public revision domains.
- `CanvasDiagnosticsVerbose` already uses a public validating factory returning
  private const storage in `docs/contracts/public_api_v1.md:2118` through
  `docs/contracts/public_api_v1.md:2139`.
- `docs/contracts/codec_boundary.md` already contains the exact codec signatures
  and behavior split to copy into the public API declaration owner without
  moving behavior ownership.

### Repository Rules

- Root `PLAN.md:5` through `PLAN.md:8` require each roadmap step to have a
  linked step document.
- Root `PLAN.md:15` through `PLAN.md:17` state that completed step contracts are
  historical records and current navigation must use the active document map and
  active step contracts.
- Root `PLAN.md:18` through `PLAN.md:19` require completing a step to update
  both the plan index and the linked step document in the same change.
- Documentation is written in English.
- Documentation-only changes do not require `dart analyze`, `dcm analyze .`, or
  `dcm calculate-metrics .`.

### Misleading Patterns

- The old broad phrase "scalar-only DTOs may remain const" looks applicable to
  all scalar constructors, but it is misleading when a public constructor also
  accepts caller-provided values with documented validation or sanitization.
- Keeping codec signatures only in `codec_boundary.md` looks sufficient because
  codec behavior belongs there, but public declarations are owned by
  `public_api_v1.md`.
- `docs/contracts/cache_policy.md` already names captured `selectionStyle`, so
  it can look as if the frame capture is fully aligned even though
  `CapturedMainFrame` and the main sequence omit it.
- Adding `CanvasCameraPort.persistCurrentOffset` looks like a convenient API
  helper, but the accepted camera ownership keeps persisted writes inside the
  edit/document boundary.

## 3. Architecture Decision

### Selected Form

The selected form is a source-of-truth documentation alignment with four locked
decisions:

1. Public constructors with caller-provided values that require documented
   runtime validation or sanitization are non-const factories. `const` remains
   available only for marker/empty/default/private storage forms where invalid
   public state cannot be constructed.
2. Codec constants and functions are declared in `docs/contracts/public_api_v1.md`
   as public API declarations. `docs/contracts/codec_boundary.md` continues to
   own decode/encode behavior, validation order, canonical encoding, and no
   runtime/store side effects.
3. `selectionStyle` is an explicit `CapturedMainFrame` input for
   `SelectionDecorationPlan`. It remains a captured style-only input and must
   not enter ordinary `PaintPlanCache` or `StaticBackgroundCache` identity.
4. The current runtime view camera is persisted only through an explicit
   `CanvasEdit.setCameraOffset(runtime.camera.offset)` edit. No
   `CanvasCameraPort.persistCurrentOffset` method is added.

### Ownership

- `docs/contracts/public_api_v1.md` owns the public constructor declarations,
  codec public declaration snippets, and camera usage example.
- `docs/contracts/validation_limits.md` owns validation-boundary wording that
  explains why public validating constructors cannot remain public `const`.
- `docs/contracts/frame_rendering.md` owns the `CapturedMainFrame` field list.
- `docs/contracts/cache_policy.md` owns the cache exclusion and
  `SelectionDecorationPlan` key rules.
- Main paint diagrams own the visual data flow from surface style input into
  frame capture and selection decoration.
- Verification docs and indexes own future proof wording for constructor shape,
  codec declarations, selection style capture, and explicit persisted camera
  edit boundaries.

### Seam

- Changed public constructor seam: public value constructors that accept
  caller-provided validated values become public factories with private const
  storage/defaults where const defaults are needed.
- Added public declaration seam: codec constants and functions become visible in
  the public API declaration contract while retaining codec behavior ownership.
- Clarified frame capture seam: `CapturedMainFrame` carries `selectionStyle` to
  `SelectionDecorationPlan`.
- Clarified camera seam: camera port remains runtime-view-only, and persisted
  camera writes remain edit/document operations.

### Dependency Direction

Public API declarations depend on validation and codec behavior contracts for
semantics, but validation and codec behavior contracts do not own exported public
declaration shape. Frame capture consumes surface style values and store/runtime
facts without making style values document state or public runtime revisions.
Camera port operations must not call or hide document edit semantics; application
code crosses into persisted state through `CanvasEdit`.

### State and Data Ownership

- Validated public value objects own only valid exposed state after construction.
- Private const storage may hold approved defaults or identity values after the
  public factory validates caller input or bypasses validation only for known
  safe constants.
- Codec schema versions and functions are public API declarations, while codec
  decode/encode data flow remains owned by `CodecBoundary`.
- `selectionStyle` is surface/frame input data for selection decoration.
- Runtime view camera offset is runtime state; persisted document camera is
  document/projection state.

### Entry and Exit Boundaries

- Entry: public constructor calls, runtime config/surface defaults, codec public
  calls, main paint requests, and application camera persistence calls.
- Exit: public API declaration contract, validation limit wording, frame capture
  contract, main paint diagrams, verification inventories, generated indexes,
  and completed roadmap status.

### Verification Strategy

Use documentation semantic proof and structural documentation checks. Semantic
proof must show the selected constructor rule, codec declarations, main-frame
`selectionStyle` capture, and explicit camera edit boundary. Negative proof must
show public validating `const` constructor forms and `persistCurrentOffset` are
absent from active source-of-truth surfaces. Structural proof must run the docs
checks that validate registry/navigation consistency.

### Compatibility and Versioning

This is a breaking correction to the draft public API contract because public
constructor const-ness and public declarations are part of the API shape. It is
accepted before API freeze and before root-package production implementation, so
no released v1 migration shim or schema version migration is introduced. The
migration rule for future implementation is to implement the corrected contract
directly: no public aliases for retired validating `const` forms, no
`persistCurrentOffset` compatibility method, and no schema-version change.

`docs/_registry/public_api_v1.yaml` remains the exported-name inventory. The
codec exported names already exist in that registry, so this step proves public
contract coverage by adding declarations to `public_api_v1.md` and by running
registry/index documentation checks rather than by adding new exported names.

### Decision Ledger

| ID | Decision | Owner | Proof |
|---|---|---|---|
| D1 | Public constructors accepting caller-provided values with documented validation or sanitization are non-const factories; `const` remains only for marker/empty/default/private storage forms that cannot create invalid public state. | `docs/contracts/public_api_v1.md`, `docs/contracts/validation_limits.md` | P1 |
| D2 | Codec public constants and functions are declared in `public_api_v1.md`, while codec behavior remains in `codec_boundary.md`. | `docs/contracts/public_api_v1.md`, `docs/contracts/codec_boundary.md` | P2 |
| D3 | Main frame capture explicitly includes `selectionStyle` for selection decoration, and style-only inputs remain excluded from ordinary paint-plan and static-background cache identity. | `docs/contracts/frame_rendering.md`, `docs/contracts/cache_policy.md`, main paint diagrams | P3 |
| D4 | Persisting the current runtime view camera requires an explicit `CanvasEdit.setCameraOffset(runtime.camera.offset)` edit; no `CanvasCameraPort.persistCurrentOffset` public method is added. | `docs/contracts/public_api_v1.md`, `docs/verification/tests.md` | P4 |

### Rejected Alternatives

- Keep the broad "scalar-only may remain const" wording without separating
  caller-provided validating constructors from marker/default/private storage.
- Add a validator that runs after invalid public DTO exposure instead of making
  the validating public constructor non-const.
- Move codec behavior into `public_api_v1.md`; only declarations belong there.
- Treat `selectionStyle` as a public runtime revision or ordinary paint-plan key.
- Add `surfaceStyleRevision`, `selectionStyleRevision`, or another style revision
  family for this correction.
- Add `CanvasCameraPort.persistCurrentOffset`; it would hide a document edit
  behind the runtime camera port.
- Add production tests, analyzer rules, or runtime implementation in this
  source-of-truth documentation step.

## 4. Execution Guardrails

### Required Order

1. Run P0 and record the current source-of-truth contradictions before changing
   owner docs.
2. Run the neighboring guard searches in P0 to establish the already-correct
   boundaries that must remain true during the fix.
3. Lock the validating constructor rule in public API and validation contracts
   before changing verification wording.
4. Add codec declarations to `public_api_v1.md` without changing
   `codec_boundary.md` behavior.
5. Align `CapturedMainFrame` before changing main paint diagrams.
6. Add the explicit camera edit example and verification wording after confirming
   `persistCurrentOffset` remains absent from public API declarations.
7. Update verification docs, indexes, registries, and context capsules after the
   normative docs and diagrams are stable.
8. Run final documentation semantic and structural proof before marking Step 14
   complete.

### Cross-Slice Constraints

- `CanvasRuntimeConfig`, `CanvasSurface`, and other defaults must not keep public
  `const` constructor calls to validating constructors after D1 is implemented.
- `CanvasTransform.identity` and other approved defaults may use private const
  storage only when they cannot expose invalid public state.
- Codec public declarations must match the exported names in
  `docs/_registry/public_api_v1.yaml` and the existing signatures in
  `docs/contracts/codec_boundary.md`.
- `selectionStyle` may key `SelectionDecorationPlan`, but must not key ordinary
  `PaintPlanCache` or `StaticBackgroundCache`.
- Camera documentation must keep runtime view camera and persisted document
  camera as separate owners.
- Public constructor corrections are proven through the `PUBLIC_API_CHANGE`
  compatibility decision and P1 negative proof; this step must not introduce a
  separate shared-seam migration.

### Forbidden Moves

- Do not add `CanvasCameraPort.persistCurrentOffset`.
- Do not add public aliases for old validating `const` constructors.
- Do not broaden `CanvasRuntimeRevisions` with style or internal cache facts.
- Do not make `selectionStyle` part of ordinary element paint-plan identity.
- Do not change schema v1 version constants or codec behavior.
- Do not edit legacy files.

### Deferred Broad Verification

`dart analyze`, `dcm analyze .`, and `dcm calculate-metrics .` are deferred
because this step changes source-of-truth documentation only. Future production
implementation slices must run the repository-required Dart and DCM checks for
code changes.

## 5. Proof Plan

### P0. Pre-fix contradictions and neighboring guards are visible

This reproduces the current source-of-truth contradictions before owner-side
documentation fixes and establishes neighboring guard facts that must remain
true. Run this once before any owner-side edits, record the output in the
completed step evidence, and do not rerun it after Slice 1 changes the
constructor contradiction.

```sh
sh -c 'rg -n "const (CanvasSelectionStyle|CanvasGridStyle|CanvasCamera|CanvasGrid|CanvasTransform|CanvasPointerPolicy|CanvasPointerSample|CanvasDrawStyle|CanvasDataException)\\(|const factory CanvasResourceSource\\.appKey|const CanvasAppKeyResourceSource\\(" docs/contracts/public_api_v1.md && rg -n "encodeCanvasDocument|decodeCanvasDocument|canvasSchemaVersionWrite|canvasSchemaVersionsRead" docs/_registry/public_api_v1.yaml docs/contracts/codec_boundary.md && ! rg -n "encodeCanvasDocument|decodeCanvasDocument|canvasSchemaVersionWrite|canvasSchemaVersionsRead" docs/contracts/public_api_v1.md && rg -n "SelectionDecorationPlan.*selectionStyle|captured selectionStyle" docs/contracts/cache_policy.md docs/verification/tests.md && if sed -n "/CapturedMainFrame/,/Overlay frame:/p" docs/contracts/frame_rendering.md | rg -q "selectionStyle"; then exit 1; fi && ! rg -n "selectionStyle" docs/diagrams/seq_main_paint.mmd docs/diagrams/dfd_main_paint_frame.mmd && rg -n "CanvasCameraPort\\.setOffset/panBy|CanvasEdit\\.setCameraOffset" docs/contracts/operation_matrix.md && ! rg -n "setCameraOffset\\(runtime\\.camera\\.offset\\)|explicit edit boundary" docs/contracts/public_api_v1.md docs/verification/tests.md'
```

Expected pre-fix signal: public validating `const` constructor declarations are
found in `public_api_v1.md`; codec names are found in the registry and codec
boundary but absent from `public_api_v1.md`; `selectionStyle` is found in
cache/verification docs but absent from the main frame block and main paint
diagrams; camera operation rows remain split between runtime camera and
edit/document camera while the explicit persistence example is absent.

### P1. Validating public constructors are non-const factories

This proves active public API docs no longer expose public `const` constructors
for the validating constructor families covered by this step, and that the
selected rule is present in the public API and verification docs.

```sh
sh -c 'rg -n "caller-provided values.*documented runtime validation|non-const factor|private const storage|marker/empty/default/private storage" docs/contracts/public_api_v1.md docs/contracts/validation_limits.md docs/verification/tests.md docs/verification/guardrails.md && ! rg -n "const (CanvasSelectionStyle|CanvasGridStyle|CanvasCamera|CanvasGrid|CanvasTransform|CanvasPointerPolicy|CanvasPointerSample|CanvasDrawStyle|CanvasDataException)\\(|const factory CanvasResourceSource\\.appKey|const CanvasAppKeyResourceSource\\(" docs/contracts/public_api_v1.md'
```

Expected signal: positive matches for the strict rule and no matches for public
validating `const` constructor declarations.

### P2. Codec declarations are present in the public API contract

This proves every codec exported name has a public declaration in
`public_api_v1.md` while codec behavior remains referenced from
`codec_boundary.md`.

```sh
sh -c 'for pattern in "^const int canvasSchemaVersionWrite = 1;$" "^const Set<int> canvasSchemaVersionsRead = \\{1\\};$" "^Map<String, Object\\?> encodeCanvasDocument\\(CanvasDocument document\\);$" "^String encodeCanvasDocumentToJson\\(CanvasDocument document\\);$" "^CanvasDocument decodeCanvasDocument\\(Map<String, Object\\?> json\\);$" "^CanvasDocument decodeCanvasDocumentFromJson\\(String json\\);$"; do rg -q "$pattern" docs/contracts/public_api_v1.md || exit 1; done; for name in canvasSchemaVersionWrite canvasSchemaVersionsRead encodeCanvasDocument encodeCanvasDocumentToJson decodeCanvasDocument decodeCanvasDocumentFromJson; do rg -q "  - $name$" docs/_registry/public_api_v1.yaml || exit 1; done; rg -n "Codec API|CodecBoundary|schema v1 decode/encode" docs/contracts/public_api_v1.md docs/contracts/codec_boundary.md'
```

Expected signal: every codec declaration has the public API signature locked in
`public_api_v1.md`, every codec name remains exported by the registry, and
behavior ownership text still points to `CodecBoundary`.

### P3. Main frame captures selectionStyle without polluting ordinary caches

This proves the main-frame contract and diagrams carry `selectionStyle`, while
ordinary cache identity still excludes style-only inputs.

```sh
sh -c 'sed -n "/CapturedMainFrame/,/Overlay frame:/p" docs/contracts/frame_rendering.md | rg -q "selectionStyle" && rg -n "selectionStyle" docs/diagrams/dfd_main_paint_frame.mmd docs/diagrams/seq_main_paint.mmd docs/contracts/cache_policy.md docs/verification/tests.md && ! rg -n "^\\| PaintPlanCache \\|.*selectionStyle|^\\| StaticBackgroundCache \\|.*selectionStyle" docs/contracts/cache_policy.md'
```

Expected signal: `selectionStyle` appears inside the `CapturedMainFrame` block,
the main paint diagrams, cache policy, and verification docs, and no
ordinary/static cache key row includes `selectionStyle`.

### P4. Persisted camera remains an explicit edit boundary

This proves active source-of-truth docs show the explicit edit path and do not
introduce `CanvasCameraPort.persistCurrentOffset`.

```sh
sh -c 'rg -n "setCameraOffset\\(runtime\\.camera\\.offset\\)|explicit edit boundary|persist.*runtime view camera" docs/contracts/public_api_v1.md docs/verification/tests.md && ! rg -n "persistCurrentOffset" docs/contracts/public_api_v1.md docs/contracts/operation_matrix.md docs/architecture docs/diagrams docs/verification'
```

Expected signal: explicit edit-boundary wording exists and active docs do not
contain `persistCurrentOffset`.

### P5. Documentation structure remains valid

This proves documentation registries, generated context capsules, indexes, and
diagram catalog references remain structurally consistent.

```sh
dart run docs/tool/generate_context_capsules.dart --check
dart run docs/tool/check_docs.dart
```

Expected signal: both commands exit 0.

### P6. Whitespace validation passes

This proves the planned documentation files have no trailing whitespace or
patch-format whitespace errors.

```sh
git diff --check -- PLAN.md plan/step_14_public_api_contract_consistency_followup.md docs/contracts/public_api_v1.md docs/contracts/validation_limits.md docs/contracts/frame_rendering.md docs/contracts/cache_policy.md docs/diagrams/dfd_main_paint_frame.mmd docs/diagrams/seq_main_paint.mmd docs/verification docs/indexes docs/_registry
```

Expected signal: no output and exit 0.

## 6. Vertical Slices

### Slice 1. [x] Lock validating constructor policy

#### Implements

D1

#### Obligations Covered

BUG_FIX, PUBLIC_API_CHANGE

#### Files

- Primary public contract edit: `docs/contracts/public_api_v1.md` — replaces
  public validating `const` constructor declarations with non-const factories,
  private const storage/defaults, and stricter const-policy prose.
- Validation contract alignment: `docs/contracts/validation_limits.md` —
  clarifies that public construction validation requiring caller input checks
  cannot be represented by public `const` constructors.
- Verification wording alignment: `docs/verification/tests.md` — updates
  planned API contract test wording for validating constructor factories and
  approved const forms.
- Guardrail wording alignment: `docs/verification/guardrails.md` — updates
  `api.dto_immutability` or adjacent wording for the strict const policy.
- Release-gate wording alignment: `docs/verification/release_gates.md` — keeps
  const-policy release proof aligned with the stricter rule.
- Index alignment as needed: `docs/indexes/by_test_area.md` and
  `docs/indexes/by_guardrail.md` — synchronize generated or derived references
  when verification wording changes.

#### Change

Document the strict public constructor rule and update the affected public
declaration snippets for validating constructors, including visual styles,
camera/grid values, transforms, pointer policy/sample, draw style, app-key
resource source, and data exception details.

#### Proof

- Run P0 before editing to reproduce the current validating-constructor
  contradiction and neighboring guard facts.
- Run P1 to prove the strict constructor policy is present and public validating
  `const` forms are absent.

#### Closure

The slice is complete when the public API and validation contracts agree that
caller-provided validating public constructors are non-const factories, while
approved const defaults remain available only through marker/empty/default or
private storage forms.

### Slice 2. [x] Declare codec public API in public_api_v1

#### Implements

D2

#### Obligations Covered

BUG_FIX, PUBLIC_API_CHANGE

#### Files

- Primary public declaration edit: `docs/contracts/public_api_v1.md` — adds the
  public codec constants and function declarations and names the behavior owner.
- Behavior-owner verify-only evidence: `docs/contracts/codec_boundary.md` —
  remains the codec decode/encode behavior contract and must not receive
  behavior changes for this slice.
- Export registry verify-only evidence: `docs/_registry/public_api_v1.yaml` —
  already lists the codec public names and must remain aligned with the copied
  declarations.
- Diagram verify-only evidence: `docs/diagrams/dfd_schema_v1_decode_encode.mmd`
  and `docs/diagrams/seq_schema_v1_decode_encode_order.mmd` — remain behavior
  flow diagrams unless declaration wording changes require label alignment.

#### Change

Add a `Codec API` declaration section to `public_api_v1.md` with the schema
version constants and encode/decode function signatures, while stating that
`codec_boundary.md` owns validation order, canonical encoding, and side effects.

#### Proof

- Use the recorded P0 pre-edit evidence to show that codec names were exported
  and declared in `codec_boundary.md` before they were declared in
  `public_api_v1.md`.
- Run P2 to prove every codec exported name is declared in `public_api_v1.md`
  and behavior ownership still belongs to `CodecBoundary`.

#### Closure

The slice is complete when public codec declarations exist in the public API
contract and no codec behavior ownership has moved out of the codec boundary.

### Slice 3. [x] Align main-frame selectionStyle capture

#### Implements

D3

#### Obligations Covered

BUG_FIX

#### Files

- Primary frame contract edit: `docs/contracts/frame_rendering.md` — adds
  `selectionStyle` to `CapturedMainFrame` and keeps style-only cache exclusion.
- Main DFD alignment: `docs/diagrams/dfd_main_paint_frame.mmd` — shows
  `selectionStyle` as part of main frame capture and as input to selection
  decoration.
- Main sequence alignment: `docs/diagrams/seq_main_paint.mmd` — includes
  `selectionStyle` in the main paint request and captured frame construction.
- Cache policy verify-only evidence: `docs/contracts/cache_policy.md` — keeps
  `SelectionDecorationPlan` keyed by captured `selectionStyle` and keeps
  ordinary/static cache rows free of `selectionStyle`.
- Verification verify-only or alignment file: `docs/verification/tests.md` —
  remains aligned with captured `selectionStyle` rebuilding only
  `SelectionDecorationPlan`.
- Diagram catalog/index alignment as needed: `docs/diagrams/README.md`,
  `docs/indexes/by_test_area.md`, and `docs/_registry/sections.yaml` — update
  only if diagram descriptions or generated references change.

#### Change

Make main frame capture explicitly carry `selectionStyle` for selection
decoration while preserving ordinary paint-plan and static-background cache
exclusion semantics.

#### Proof

- Use the recorded P0 pre-edit evidence to show that captured `selectionStyle`
  was required by cache/verification docs while absent from main-frame capture
  surfaces.
- Run P3 to prove `selectionStyle` appears in main-frame capture surfaces and
  does not appear in ordinary/static cache key rows.

#### Closure

The slice is complete when the frame contract, main DFD, and main sequence all
show the same captured `selectionStyle` data flow to selection decoration.

### Slice 4. [x] Document explicit persisted camera edit boundary

#### Implements

D4

#### Obligations Covered

BUG_FIX

#### Files

- Primary public contract edit: `docs/contracts/public_api_v1.md` — adds a short
  example showing `runtime.edits.edit((edit) { edit.setCameraOffset(runtime.camera.offset); })`
  as the explicit persistence path and states no camera-port helper exists.
- Verification wording alignment: `docs/verification/tests.md` — extends the
  existing camera ownership planned test wording so it proves the explicit edit
  boundary and that `readDocument` returns persisted camera state, not runtime
  view camera state.
- Operation matrix verify-only evidence: `docs/contracts/operation_matrix.md` —
  remains the owner of distinct camera operation effects.
- Architecture verify-only evidence: `docs/architecture/01_runtime_ownership.md`
  and `docs/architecture/03_data_model.md` — remain the camera ownership source
  of truth unless wording must be clarified without changing ownership.

#### Change

Document the explicit application code path for persisting the current runtime
view camera and keep `persistCurrentOffset` out of active public API,
operation-matrix, architecture, diagram, and verification docs.

#### Proof

- Use the recorded P0 pre-edit evidence to establish that neighboring camera
  guard rows already split runtime view camera from persisted document camera
  while the explicit persistence example was absent.
- Run P4 to prove the explicit edit-boundary wording exists and
  `persistCurrentOffset` is absent from active source-of-truth docs.

#### Closure

The slice is complete when camera persistence is documented as an explicit edit
boundary and the runtime camera port remains view-state-only.

### Slice 5. [x] Finalize registries, indexes, and roadmap status

#### Implements

D1, D2, D3, D4

#### Files

- Context and registry alignment: `docs/_registry/sections.yaml`,
  `docs/indexes/by_test_area.md`, `docs/indexes/by_guardrail.md`,
  `docs/indexes/context_coverage.md`, and `docs/indexes/by_subsystem.md` —
  synchronize only when source metadata or verification mappings changed.
- Roadmap completion edit: `PLAN.md` — marks Step 14 complete after slices and
  final proof pass.
- Step contract completion edit:
  `plan/step_14_public_api_contract_consistency_followup.md` — marks completed
  slices and records concrete closure evidence after implementation.
- Explicit non-edit evidence: `.research/2026-05-19-redesign-review-followup.md`
  — remains a factual research note and is not rewritten by this step.

#### Change

Refresh derived documentation references as needed and close the roadmap step
only after the source-of-truth docs, diagrams, verification wording, and proof
commands agree.

#### Proof

- Run P1, P2, P3, P4, P5, and P6.

#### Closure

The slice is complete when all reusable proof IDs pass, all changed references
are synchronized, and Step 14 is marked complete in both `PLAN.md` and this step
file.

## 7. Final Gate

### Run Proof Set

- P1
- P2
- P3
- P4
- P5
- P6

### Done When

- all referenced Decision Ledger decisions have passing proof;
- all Contract Obligations are satisfied;
- final proof IDs P1 through P6 pass after the source-of-truth edits;
- pre-fix reproducer P0 was run before owner-side edits and its expected
  contradiction/neighboring-guard signal was recorded in the completed step;
- the PUBLIC_API_CHANGE compatibility/versioning decision is reflected in the
  completed proof evidence;
- no out-of-scope files were changed;
- whitespace validation passes.
