---
date: 2026-05-19
researcher: Codex
commit: aefeb90
branch: new-architecture
research_question: "HOLE-007: public error code names in docs/contracts/public_api_v1.md prose, enum values, and tests/guardrails"
---

# Research: Public Error Code Contract Prose

## Summary

`docs/contracts/public_api_v1.md` owns both the public API prose for edit errors and the normative `CanvasDataErrorCode` enum. The edit contract prose now names `duplicateElementId` and `missingResourceReference` for `CanvasDataException` throws, and the enum declares those exact values in the public errors section.

The machine-readable public API inventory lists `CanvasDataException` and `CanvasDataErrorCode` as public names. The guardrail documentation defines `api.public_error_codes_match_contract_prose`, and the corresponding Dart test parses the contract enum and checks prose references against stable enum values.

## Detailed Findings

### 1. Public API Contract Prose
- **Location**: primary `docs/contracts/public_api_v1.md:1229`; additional `docs/contracts/public_api_v1.md:1230`
- **Description**: The edit contract prose states that element id collisions throw `CanvasDataException duplicateElementId` and missing resource references throw `CanvasDataException missingResourceReference`.
- **Dependencies**: The prose references `CanvasDataException` and therefore depends on the public error enum declared later in the same contract at `docs/contracts/public_api_v1.md:2065`.
- **Data flow**: Public edit rule text -> named `CanvasDataException` code -> stable `CanvasDataErrorCode` enum value.

### 2. Public Error Enum
- **Location**: primary `docs/contracts/public_api_v1.md:2065`; additional `docs/contracts/public_api_v1.md:2078`
- **Description**: `CanvasDataErrorCode` is declared in the public API contract and includes `duplicateElementId`, `duplicateLayerId`, `duplicateResourceId`, and `missingResourceReference`.
- **Dependencies**: `CanvasDataException.code` is typed as `CanvasDataErrorCode` at `docs/contracts/public_api_v1.md:2096`.
- **Data flow**: Contract enum declaration -> `CanvasDataException.code` field -> public diagnostic projection.

### 3. Public API Inventory
- **Location**: primary `docs/_registry/public_api_v1.yaml:98`; additional `docs/_registry/public_api_v1.yaml:99`
- **Description**: The public API registry lists `CanvasDataException` and `CanvasDataErrorCode` as exported public names.
- **Dependencies**: The public API contract states that the root barrel exports names from this registry at `docs/contracts/public_api_v1.md:79`.
- **Data flow**: YAML public-name registry -> public barrel export completeness rule -> public error contract names.

### 4. Guardrail And Test Coverage
- **Location**: primary `test/api_contract/public_error_codes_match_contract_prose_test.dart:6`; additional `docs/verification/guardrails.md:142`
- **Description**: The test named `api.public_error_codes_match_contract_prose` reads `docs/contracts/public_api_v1.md`, extracts `CanvasDataErrorCode` values, extracts `throws CanvasDataException ...` prose codes, and verifies that the prose codes are enum values.
- **Dependencies**: The test uses the contract document as input and is documented in `docs/verification/tests.md:322`.
- **Data flow**: Contract Markdown -> enum extraction -> prose-code extraction -> assertion that prose codes are stable enum values.

## Code References
- `docs/contracts/public_api_v1.md:36` - required test entry for `test.api_contract.public_error_codes_match_contract_prose`.
- `docs/contracts/public_api_v1.md:56` - guardrail entry for `api.public_error_codes_match_contract_prose`.
- `docs/contracts/public_api_v1.md:1229` - edit prose uses `duplicateElementId`.
- `docs/contracts/public_api_v1.md:1230` - edit prose uses `missingResourceReference`.
- `docs/contracts/public_api_v1.md:2065` - `CanvasDataErrorCode` enum declaration.
- `docs/contracts/public_api_v1.md:2078` - enum value `duplicateElementId`.
- `docs/contracts/public_api_v1.md:2080` - enum value `duplicateResourceId`.
- `docs/contracts/public_api_v1.md:2081` - enum value `missingResourceReference`.
- `docs/contracts/public_api_v1.md:2096` - `CanvasDataException.code` type is `CanvasDataErrorCode`.
- `docs/_registry/public_api_v1.yaml:98` - public inventory lists `CanvasDataException`.
- `docs/_registry/public_api_v1.yaml:99` - public inventory lists `CanvasDataErrorCode`.
- `docs/tool/check_docs.dart:1` - docs checker is structural only.
- `docs/tool/check_docs.dart:5` - free-form Markdown wording checks belong outside `check_docs.dart`.
- `docs/verification/guardrails.md:142` - guardrail rule for public error-code prose.
- `docs/verification/tests.md:322` - documented path for the public error-code prose test.
- `test/api_contract/public_error_codes_match_contract_prose_test.dart:6` - executable test name.
- `test/api_contract/public_error_codes_match_contract_prose_test.dart:19` - enum value extraction helper.
- `test/api_contract/public_error_codes_match_contract_prose_test.dart:32` - prose `CanvasDataException` code extraction helper.
- `test/api_contract/public_error_codes_match_contract_prose_test.dart:36` - root test/tool shorthand reference scanner.

## Observed Architecture Facts
- Pattern observed: public API semantics and declaration contracts live in `docs/contracts/public_api_v1.md`, while exported-name inventory lives in `docs/_registry/public_api_v1.yaml` (`docs/contracts/public_api_v1.md:79`, `docs/_registry/public_api_v1.yaml:98`).
- Data flow: public contract prose -> `CanvasDataException` code names -> `CanvasDataErrorCode` enum -> guardrail test assertion (`docs/contracts/public_api_v1.md:1229`, `docs/contracts/public_api_v1.md:2065`, `test/api_contract/public_error_codes_match_contract_prose_test.dart:11`).
- Key dependencies: the structural docs checker does not own free-form Markdown wording checks; those belong in tests or guardrails (`docs/tool/check_docs.dart:1`, `docs/tool/check_docs.dart:5`).

## Open Questions

None observed.
