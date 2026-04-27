# Verification Contract And Workflow Drift

## Purpose

This family owns the repository verification contract and executable workflow
drift checks.

## Target Rules

- Verification presets route changed files to the checks that own them.
- Executable workflow commands are either represented in the verification
  contract or explicitly excluded with proof.

## Owners

- `tool/src/verification_contract/verification_contract_registry.dart`
- `tool/check_verification_contract.dart`
- `.github/workflows/**`

## Forbidden Shapes

- Do not let executable workflow commands drift outside the verification
  contract without a checked rule.

## Mechanical Evidence

- `dart run tool/check_verification_contract.dart`
- `dart run tool/run_tool_tests.dart test/tool/verification_contract_tool_test.dart`

## Status

- `known issue`
- Workflow coverage is tracked by [KI-11](../../../KNOWN_ISSUES.md#ki-11).

## Update Triggers

- Refresh when verification presets, workflow commands, or changed-path routing
  rules change.
