---
date: 2026-08-25
researcher: agent
commit: 3de57d2f
branch: main
research_question: "How is selection deletion availability currently represented, computed, exposed, and covered by tests for the proposed has-any-deletable selection fact?"
---

# Research: Selection Delete Availability

## Summary

`CanvasSelectionDeleteAvailability` is a public immutable value type with two required boolean fields: `hasSelection` and `allSelectedElementsDeletable` (`lib/src/contracts/public/canvas_deletion.dart:19`, `lib/src/contracts/public/canvas_deletion.dart:21`, `lib/src/contracts/public/canvas_deletion.dart:22`, `lib/src/contracts/public/canvas_deletion.dart:27`). Its equality and hash code use those same two fields (`lib/src/contracts/public/canvas_deletion.dart:30`, `lib/src/contracts/public/canvas_deletion.dart:32`, `lib/src/contracts/public/canvas_deletion.dart:38`). The public selection port exposes this type through `deleteAvailability` (`lib/src/contracts/public/canvas_runtime.dart:213`, `lib/src/contracts/public/canvas_runtime.dart:215`).

The runtime obtains deletion availability from `SelectionDeleteFacts`. The command-facts adapter reads the selected IDs, projects deletion entries, filters the projected entries by `element.isDeletable`, and creates `SelectionDeleteFacts` with selection and all-selected eligibility facts (`lib/src/runtime/runtime_command_facts_adapter.dart:64`, `lib/src/runtime/runtime_command_facts_adapter.dart:65`, `lib/src/runtime/runtime_command_facts_adapter.dart:66`, `lib/src/runtime/runtime_command_facts_adapter.dart:68`, `lib/src/runtime/runtime_command_facts_adapter.dart:80`). `SelectionDeleteFacts.availability` currently constructs the public value from its two boolean fields (`lib/src/contracts/internal/command_facts_port.dart:29`, `lib/src/contracts/internal/command_facts_port.dart:43`).

The public contract documentation contains the same two-field declaration and describes availability as derived from committed selection and document facts; it states that an empty selection has both fields false (`docs/contracts/public_api_v1.md:528`, `docs/contracts/public_api_v1.md:529`, `docs/contracts/public_api_v1.md:1746`, `docs/contracts/public_api_v1.md:1747`). Existing fixtures observe empty, deletable-only, non-deletable-only, and mixed selections through the current two-field value (`test/api/fixtures/selection_port_fixture.dart:44`, `test/api/fixtures/selection_port_fixture.dart:59`, `test/api/fixtures/selection_port_fixture.dart:76`, `test/api/fixtures/selection_transform_commands_fixture.dart:234`, `test/api/fixtures/selection_transform_commands_fixture.dart:239`).

## Detailed Findings

### 1. Public deletion availability contract

- **Location**: `lib/src/contracts/public/canvas_deletion.dart:19`.
- **Description**: `CanvasSelectionDeleteAvailability` is annotated `@immutable`, declared `final`, and has a `const` constructor. Its constructor requires `hasSelection` and `allSelectedElementsDeletable`; the class exposes both as `bool` fields (`lib/src/contracts/public/canvas_deletion.dart:19`, `lib/src/contracts/public/canvas_deletion.dart:21`, `lib/src/contracts/public/canvas_deletion.dart:22`, `lib/src/contracts/public/canvas_deletion.dart:27`).
- **Dependencies**: The declaration imports `package:flutter/foundation.dart` for `@immutable` (`lib/src/contracts/public/canvas_deletion.dart:1`, `lib/src/contracts/public/canvas_deletion.dart:19`).
- **Data flow**: A consumer reads `CanvasSelectionPort.deleteAvailability` (`lib/src/contracts/public/canvas_runtime.dart:213`, `lib/src/contracts/public/canvas_runtime.dart:215`) and receives this value type.

### 2. Public export and normative contract

- **Location**: `lib/src/api/canvas_runtime.dart:21`.
- **Description**: The runtime public facade exports the public runtime contract and `canvas_deletion.dart` (`lib/src/api/canvas_runtime.dart:21`, `lib/src/api/canvas_runtime.dart:22`). The root package barrel exports the runtime facade (`lib/iwb_canvas_engine.dart:15`). The Public API v1 registry lists the type name in `public_exports` (`docs/_registry/public_api_v1.yaml:12`).
- **Dependencies**: `docs/contracts/public_api_v1.md` identifies Dart declarations as authoritative (`docs/contracts/public_api_v1.md:84`) and includes `CanvasSelectionDeleteAvailability` in its value-equality list (`docs/contracts/public_api_v1.md:201`, `docs/contracts/public_api_v1.md:209`).
- **Data flow**: The normative document declares the public class with the same two required named parameters and fields (`docs/contracts/public_api_v1.md:528`, `docs/contracts/public_api_v1.md:529`). It declares `deleteAvailability` on the selection port (`docs/contracts/public_api_v1.md:1716`, `docs/contracts/public_api_v1.md:1718`).

### 3. Internal deletion facts and availability construction

- **Location**: `lib/src/contracts/internal/command_facts_port.dart:29`.
- **Description**: `SelectionDeleteFacts` stores `hasSelection`, `allSelectedElementsDeletable`, and an unmodifiable `deletableEntries` list (`lib/src/contracts/internal/command_facts_port.dart:30`, `lib/src/contracts/internal/command_facts_port.dart:34`, `lib/src/contracts/internal/command_facts_port.dart:36`, `lib/src/contracts/internal/command_facts_port.dart:38`). Its `availability` getter constructs `CanvasSelectionDeleteAvailability` from `hasSelection` and `allSelectedElementsDeletable` (`lib/src/contracts/internal/command_facts_port.dart:43`, `lib/src/contracts/internal/command_facts_port.dart:44`).
- **Dependencies**: The internal contract imports `canvas_deletion.dart` and `DeletionEntryFacts` (`lib/src/contracts/internal/command_facts_port.dart:5`, `lib/src/contracts/internal/command_facts_port.dart:7`).
- **Data flow**: `deletableIds` maps `deletableEntries` to IDs (`lib/src/contracts/internal/command_facts_port.dart:40`). `removalEntriesFor` returns all deletable entries for `partial`; for `allOrNone`, it returns them only when `allSelectedElementsDeletable` is true (`lib/src/contracts/internal/command_facts_port.dart:56`, `lib/src/contracts/internal/command_facts_port.dart:59`).

### 4. Runtime fact computation and projection boundary

- **Location**: `lib/src/runtime/runtime_command_facts_adapter.dart:64`.
- **Description**: `RuntimeCommandFactsAdapter.selectionDeleteFacts()` reads selected IDs from the selection facts port, invokes `projectDeletionEntries(selected)`, and filters the returned entries using `entry.element.isDeletable` (`lib/src/runtime/runtime_command_facts_adapter.dart:64`, `lib/src/runtime/runtime_command_facts_adapter.dart:65`, `lib/src/runtime/runtime_command_facts_adapter.dart:66`, `lib/src/runtime/runtime_command_facts_adapter.dart:68`, `lib/src/runtime/runtime_command_facts_adapter.dart:69`). `hasSelection` is created from `selected.isNotEmpty`; `allSelectedElementsDeletable` requires a non-empty selected set and matching selected, projected, and deletable entry counts (`lib/src/runtime/runtime_command_facts_adapter.dart:78`, `lib/src/runtime/runtime_command_facts_adapter.dart:80`, `lib/src/runtime/runtime_command_facts_adapter.dart:81`, `lib/src/runtime/runtime_command_facts_adapter.dart:82`).
- **Dependencies**: `RuntimeRoot` constructs the adapter with the selection kernel and the store as `deletionEntryProjection` (`lib/src/runtime/runtime_root.dart:379`, `lib/src/runtime/runtime_root.dart:381`, `lib/src/runtime/runtime_root.dart:383`). `DocumentStoreKernel` implements `DeletionEntryProjectionPort` (`lib/src/store/document_store_kernel.dart:130`), and `SelectionKernel` implements `SelectionFactsPort` (`lib/src/selection/selection_kernel.dart:14`).
- **Data flow**: selected IDs -> `DeletionEntryProjectionPort.projectDeletionEntries` -> projected entries -> entries with `element.isDeletable` -> `SelectionDeleteFacts` (`lib/src/runtime/runtime_command_facts_adapter.dart:65`, `lib/src/runtime/runtime_command_facts_adapter.dart:66`, `lib/src/runtime/runtime_command_facts_adapter.dart:68`, `lib/src/runtime/runtime_command_facts_adapter.dart:80`). The adapter's `selectionDeleteFacts()` body does not invoke its frame, resource, document-summary, or geometry fields (`lib/src/runtime/runtime_command_facts_adapter.dart:34`, `lib/src/runtime/runtime_command_facts_adapter.dart:64`).

### 5. Runtime and public-port route

- **Location**: `lib/src/runtime/runtime_root.dart:1163`.
- **Description**: `RuntimeRoot.selectionDeleteAvailability` reads fresh deletion facts and returns their `availability` (`lib/src/runtime/runtime_root.dart:1163`, `lib/src/runtime/runtime_root.dart:1164`). `_RuntimeSelectionPort.deleteAvailability` delegates to that getter (`lib/src/runtime/runtime_root.dart:3457`, `lib/src/runtime/runtime_root.dart:3465`, `lib/src/runtime/runtime_root.dart:3466`). `CanvasRuntime.selection` returns the root selection port (`lib/src/api/canvas_runtime.dart:37`, `lib/src/api/canvas_runtime.dart:40`).
- **Dependencies**: The root creates `_RuntimeSelectionPort` as its public selection port (`lib/src/runtime/runtime_root.dart:387`, `lib/src/runtime/runtime_root.dart:389`).
- **Data flow**: `CanvasRuntime.selection` -> `_RuntimeSelectionPort.deleteAvailability` -> `RuntimeRoot.selectionDeleteAvailability` -> `CommandFactsPort.selectionDeleteFacts()` -> `SelectionDeleteFacts.availability` (`lib/src/api/canvas_runtime.dart:40`, `lib/src/runtime/runtime_root.dart:3466`, `lib/src/runtime/runtime_root.dart:1163`, `lib/src/contracts/internal/command_facts_port.dart:43`).

### 6. Existing test observations

- **Location**: `test/api/fixtures/selection_port_fixture.dart:22`.
- **Description**: The selection-port fixture observes `(hasSelection: false, allSelectedElementsDeletable: false)` for an empty selection (`test/api/fixtures/selection_port_fixture.dart:40`, `test/api/fixtures/selection_port_fixture.dart:44`). It observes `(true, true)` after selecting `content-a` (`test/api/fixtures/selection_port_fixture.dart:54`, `test/api/fixtures/selection_port_fixture.dart:59`) and `(true, false)` after changing that selected element to `isDeletable: false` (`test/api/fixtures/selection_port_fixture.dart:70`, `test/api/fixtures/selection_port_fixture.dart:76`, `test/api/fixtures/selection_port_fixture.dart:85`).
- **Dependencies**: The fixture constructs a document containing two default `CanvasRectElement` content elements (`test/api/fixtures/selection_port_fixture.dart:185`, `test/api/fixtures/selection_port_fixture.dart:194`, `test/api/fixtures/selection_port_fixture.dart:198`).
- **Data flow**: fixture document -> runtime selection or edit -> `runtime.selection.deleteAvailability` assertion (`test/api/fixtures/selection_port_fixture.dart:23`, `test/api/fixtures/selection_port_fixture.dart:45`, `test/api/fixtures/selection_port_fixture.dart:61`, `test/api/fixtures/selection_port_fixture.dart:86`).

- **Location**: `test/api/fixtures/selection_transform_commands_fixture.dart:217`.
- **Description**: The all-or-none fixture selects `rect-a` and `not-deletable-a`, then observes `(true, false)` through `deleteAvailability` (`test/api/fixtures/selection_transform_commands_fixture.dart:217`, `test/api/fixtures/selection_transform_commands_fixture.dart:234`, `test/api/fixtures/selection_transform_commands_fixture.dart:239`). The same fixture observes `(true, true)` for a selection containing `locked-a` and later observes an action whose element IDs contain `locked-a` (`test/api/fixtures/selection_transform_commands_fixture.dart:254`, `test/api/fixtures/selection_transform_commands_fixture.dart:268`, `test/api/fixtures/selection_transform_commands_fixture.dart:270`, `test/api/fixtures/selection_transform_commands_fixture.dart:276`, `test/api/fixtures/selection_transform_commands_fixture.dart:278`).
- **Dependencies**: The fixture document defines `not-deletable-a` with `isDeletable: false` (`test/api/fixtures/selection_transform_commands_fixture.dart:340`, `test/api/fixtures/selection_transform_commands_fixture.dart:383`) and `locked-a` with `isLocked: true` (`test/api/fixtures/selection_transform_commands_fixture.dart:340`, `test/api/fixtures/selection_transform_commands_fixture.dart:350`).
- **Data flow**: fixture selection -> public `deleteAvailability` -> `deleteSelection` -> action/document assertions (`test/api/fixtures/selection_transform_commands_fixture.dart:234`, `test/api/fixtures/selection_transform_commands_fixture.dart:239`, `test/api/fixtures/selection_transform_commands_fixture.dart:245`, `test/api/fixtures/selection_transform_commands_fixture.dart:247`, `test/api/fixtures/selection_transform_commands_fixture.dart:248`).

- **Location**: `test/runtime/fixtures/command_facts_port_fixture.dart:83`.
- **Description**: The command-facts fixture expects three deletable IDs, `hasSelection == true`, `allSelectedElementsDeletable == false`, and an availability value containing those two booleans (`test/runtime/fixtures/command_facts_port_fixture.dart:83`, `test/runtime/fixtures/command_facts_port_fixture.dart:84`, `test/runtime/fixtures/command_facts_port_fixture.dart:89`, `test/runtime/fixtures/command_facts_port_fixture.dart:91`). It also observes the partial and all-or-none removal results (`test/runtime/fixtures/command_facts_port_fixture.dart:98`, `test/runtime/fixtures/command_facts_port_fixture.dart:102`).
- **Dependencies**: This fixture creates `RuntimeCommandFactsAdapter` with fixture frame, selection, resource, and deletion-projection ports (`test/runtime/fixtures/command_facts_port_fixture.dart:50`, `test/runtime/fixtures/command_facts_port_fixture.dart:51`, `test/runtime/fixtures/command_facts_port_fixture.dart:55`).
- **Data flow**: fixture ports -> `RuntimeCommandFactsAdapter.selectionDeleteFacts()` -> availability and removal assertions (`test/runtime/fixtures/command_facts_port_fixture.dart:41`, `test/runtime/fixtures/command_facts_port_fixture.dart:44`, `test/runtime/fixtures/command_facts_port_fixture.dart:45`, `test/runtime/fixtures/command_facts_port_fixture.dart:92`).

- **Location**: `test/api_contract/public_equality_policy_test.dart:49`.
- **Description**: The equality-policy consumer fixture checks equality of separately constructed availability values, inequality when `allSelectedElementsDeletable` differs, and lookup of an equivalent availability value in a `Set` (`test/api_contract/public_equality_policy_test.dart:49`, `test/api_contract/public_equality_policy_test.dart:59`, `test/api_contract/public_equality_policy_test.dart:71`, `test/api_contract/public_equality_policy_test.dart:77`). The public API compile fixture constructs an availability value, reads the selection-port getter, and defines that getter in a consumer implementation (`test/api_contract/public_api_v1_compiles_as_written_test.dart:329`, `test/api_contract/public_api_v1_compiles_as_written_test.dart:335`, `test/api_contract/public_api_v1_compiles_as_written_test.dart:691`, `test/api_contract/public_api_v1_compiles_as_written_test.dart:923`, `test/api_contract/public_api_v1_compiles_as_written_test.dart:931`).

## Code References

- `lib/src/contracts/public/canvas_deletion.dart:21` - public availability value type declaration.
- `lib/src/contracts/internal/command_facts_port.dart:29` - internal deletion fact object and availability getter.
- `lib/src/runtime/runtime_command_facts_adapter.dart:64` - selected-ID projection and deletable-entry filtering.
- `lib/src/runtime/runtime_root.dart:379` - construction of the command-facts adapter.
- `lib/src/runtime/runtime_root.dart:1163` - runtime getter that reads availability from fresh deletion facts.
- `lib/src/runtime/runtime_root.dart:3466` - public selection-port delegation.
- `lib/src/contracts/public/canvas_runtime.dart:215` - public selection-port getter declaration.
- `lib/src/api/canvas_runtime.dart:22` - public export of deletion declarations.
- `docs/contracts/public_api_v1.md:528` - documented availability declaration.
- `test/api/fixtures/selection_port_fixture.dart:44` - empty-selection availability observation.
- `test/api/fixtures/selection_transform_commands_fixture.dart:239` - mixed-selection availability observation.
- `test/runtime/fixtures/command_facts_port_fixture.dart:83` - command-facts availability observation.

## Search Coverage

- **Inspected**: `lib/src/contracts/public/canvas_deletion.dart` (all 67 lines); `lib/src/contracts/internal/command_facts_port.dart` (all 84 lines); `lib/src/runtime/runtime_command_facts_adapter.dart` (all 192 lines); `lib/src/api/canvas_runtime.dart` (all 58 lines); `lib/iwb_canvas_engine.dart` (all 19 lines); the availability-relevant sections of `lib/src/contracts/public/canvas_runtime.dart`, `lib/src/runtime/runtime_root.dart`, `docs/contracts/public_api_v1.md`, and the listed API, runtime, and contract test fixtures.
- **Searched**: `CanvasSelectionDeleteAvailability`, `SelectionDeleteFacts`, `selectionDeleteFacts`, `deletableEntries`, `deleteAvailability`, `projectDeletionEntries`, and `elementById` across `lib`, `test`, `docs/contracts`, and `docs/_registry`.
- **Not found**: A second constructor of `CanvasSelectionDeleteAvailability`; a second runtime implementation of `selectionDeleteFacts()`; another `CanvasSelectionPort.deleteAvailability` implementation on the runtime route; or a direct `elementById` invocation in `RuntimeCommandFactsAdapter.selectionDeleteFacts()`.
- **Not inspected**: The complete Store projection implementation and all Store indexes were not read in this research; their participation is recorded only from the traced declarations and the targeted findings at `lib/src/store/document_store_kernel.dart:130`, `lib/src/store/document_store_kernel.dart:505`, and `lib/src/store/document_store_kernel.dart:547`.

## Observed Architecture Facts

- **Pattern observed**: Public selection read access delegates through the runtime root to a command-facts boundary, rather than storing availability on the public port (`lib/src/api/canvas_runtime.dart:40`, `lib/src/runtime/runtime_root.dart:1163`, `lib/src/runtime/runtime_root.dart:3466`, `lib/src/contracts/internal/command_facts_port.dart:9`).
- **Data flow**: selection facts -> deletion-entry projection -> deletable-entry filter -> `SelectionDeleteFacts` -> public availability (`lib/src/runtime/runtime_command_facts_adapter.dart:65`, `lib/src/runtime/runtime_command_facts_adapter.dart:66`, `lib/src/runtime/runtime_command_facts_adapter.dart:68`, `lib/src/runtime/runtime_command_facts_adapter.dart:80`, `lib/src/contracts/internal/command_facts_port.dart:43`).
- **Key dependencies**: The root wires `SelectionKernel` and `DocumentStoreKernel` into `RuntimeCommandFactsAdapter` (`lib/src/runtime/runtime_root.dart:379`, `lib/src/runtime/runtime_root.dart:381`, `lib/src/runtime/runtime_root.dart:383`); the public availability type is exposed through the runtime facade and root barrel (`lib/src/api/canvas_runtime.dart:22`, `lib/iwb_canvas_engine.dart:15`).

## Open Questions

No open questions were recorded within the inspected paths.
