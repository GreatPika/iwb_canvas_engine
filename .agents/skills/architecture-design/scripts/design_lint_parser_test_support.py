from __future__ import annotations

import importlib
import importlib.util
import re
import unittest
from pathlib import Path
from types import ModuleType
from typing import Protocol, cast

from design_lint_model import DesignSchema, Finding, ParsedDesign, TypedReference


class _ParserModule(Protocol):
    def parse_design(
        self,
        text: str,
        schema: DesignSchema,
        *,
        template: bool = False,
        checkpoint: str | None = None,
    ) -> tuple[ParsedDesign | None, list[Finding]]: ...

    def parse_reference_list(
        self,
        value: str,
        *,
        allowed: frozenset[str],
        schema: DesignSchema,
    ) -> tuple[tuple[TypedReference, ...], list[Finding]]: ...

    def parse_vocabulary_list(
        self,
        value: str,
        *,
        allowed: frozenset[str],
    ) -> tuple[tuple[str, ...], list[Finding]]: ...


def _load_parser_module() -> _ParserModule | None:
    if importlib.util.find_spec("design_lint_parser") is None:
        return None
    module = importlib.import_module("design_lint_parser")
    if not isinstance(module, ModuleType):
        raise AssertionError("design_lint_parser must load as a Python module")
    return cast(_ParserModule, module)


_PARSER_MODULE = _load_parser_module()
if _PARSER_MODULE is not None:
    parse_design = _PARSER_MODULE.parse_design
    parse_reference_list = _PARSER_MODULE.parse_reference_list
    parse_vocabulary_list = _PARSER_MODULE.parse_vocabulary_list
else:

    def parse_design(
        text: str,
        schema: DesignSchema,
        *,
        template: bool = False,
        checkpoint: str | None = None,
    ) -> tuple[ParsedDesign | None, list[Finding]]:
        del text, schema, template, checkpoint
        raise AssertionError("design_lint_parser module is required")

    def parse_reference_list(
        value: str,
        *,
        allowed: frozenset[str],
        schema: DesignSchema,
    ) -> tuple[tuple[TypedReference, ...], list[Finding]]:
        del value, allowed, schema
        raise AssertionError("complete typed-value parser functions are required")

    def parse_vocabulary_list(
        value: str,
        *,
        allowed: frozenset[str],
    ) -> tuple[tuple[str, ...], list[Finding]]:
        del value, allowed
        raise AssertionError("complete typed-value parser functions are required")


class ParserTestCase(unittest.TestCase):
    @staticmethod
    def schema() -> DesignSchema:
        raw: dict[str, object] = {
            "frontmatter": {
                "fields": [
                    "schema",
                    "date",
                    "commit",
                    "branch",
                    "disposition",
                    "outcome",
                ],
                "dispositions": [
                    "READY_FOR_CONTRACT",
                    "BLOCKED",
                    "DESIGN_NOT_REQUIRED",
                ],
                "date_pattern": r"^[0-9]{4}-[0-9]{2}-[0-9]{2}$",
                "commit_pattern": r"^[0-9a-f]{7,40}$",
                "outcome_pattern": r"^R-[0-9]{3}$",
            },
            "sections": {
                "order": [
                    "Basis",
                    "Candidate Analysis",
                    "Decision Register",
                    "Impact Register",
                    "Assurance Register",
                    "Stop Conditions",
                    "Contract Interface",
                    "Diagrams",
                    "Readiness Matrix",
                    "Open Blockers",
                ],
                "required": {
                    "READY_FOR_CONTRACT": [
                        "Basis",
                        "Candidate Analysis",
                        "Decision Register",
                        "Impact Register",
                        "Assurance Register",
                        "Stop Conditions",
                        "Contract Interface",
                        "Diagrams",
                        "Readiness Matrix",
                        "Open Blockers",
                    ],
                    "BLOCKED": [
                        "Basis",
                        "Candidate Analysis",
                        "Open Blockers",
                    ],
                    "DESIGN_NOT_REQUIRED": [
                        "Basis",
                        "Candidate Analysis",
                        "Readiness Matrix",
                        "Open Blockers",
                    ],
                },
                "optional": {
                    "READY_FOR_CONTRACT": [],
                    "BLOCKED": [
                        "Decision Register",
                        "Assurance Register",
                        "Diagrams",
                        "Readiness Matrix",
                    ],
                    "DESIGN_NOT_REQUIRED": ["Diagrams"],
                },
            },
            "basis": {
                "source_header": ["ID", "Kind", "Locator", "Use"],
                "source_kinds": [
                    "prior_design",
                    "research",
                    "plan",
                    "user",
                    "repository",
                    "other",
                ],
                "evidence_header": ["ID", "Source", "Locator", "Observed fact"],
                "requirement_header": [
                    "ID",
                    "Kind",
                    "Statement",
                    "Basis",
                    "Open shape",
                ],
                "requirement_kinds": [
                    "outcome",
                    "constraint",
                    "user_decision",
                    "repository_rule",
                    "exclusion",
                ],
                "source_coverage_header": ["Kind", "Sources or none"],
            },
            "candidate": {
                "fields": ["Comparison", "Result", "Result basis"],
                "comparison_values": [
                    "two_or_three",
                    "single_viable",
                    "not_applicable",
                    "blocked",
                ],
                "result_patterns": [
                    r"^selected F-[0-9]{3}$",
                    r"^not_required$",
                    r"^blocked B-[0-9]{3}(?:, B-[0-9]{3})*$",
                ],
                "forms_header": [
                    "ID",
                    "Form",
                    "Hard constraints",
                    "Main trade-off",
                    "Basis",
                ],
                "material_prefix": ["ID", "Material obligation"],
                "material_suffix": ["Independent authority"],
                "future_pressure_header": [
                    "ID",
                    "Pressure",
                    "Basis",
                    "Treatment",
                    "Closure refs",
                    "Accepted cost or risk",
                ],
                "future_pressure_none_dispositions": [
                    "DESIGN_NOT_REQUIRED",
                ],
                "future_pressure_none_literal": "None",
                "pressure_treatments": ["absorbed", "deferred", "rejected"],
                "yes_no": ["yes", "no"],
            },
            "decision": {
                "fields": [
                    "Concerns",
                    "Lock",
                    "Open",
                    "Basis",
                    "Form",
                    "Realizes",
                    "Depends on",
                    "Contract targets",
                    "Rationale",
                ],
                "concerns": ["form", "owner"],
                "contract_targets": ["classification", "owner", "unit_family"],
                "assurance_required_concerns": ["owner"],
                "concern_contract_target_map": {
                    "form": ["classification"],
                    "owner": ["owner"],
                },
            },
            "assurance": {
                "fields": [
                    "Verifies",
                    "Claim",
                    "Failure",
                    "Oracle",
                    "Proxy risk",
                    "Evidence constraints",
                    "Architecture seam",
                ],
                "verifies_patterns": {
                    "requirement": r"^R-[0-9]{3}$",
                    "decision_concern": r"^D-[0-9]{3}/[a-z][a-z0-9_]*$",
                    "impact": r"^I-[0-9]{3}$",
                },
            },
            "impact": {
                "fields": [
                    "Action",
                    "Surface",
                    "Required by",
                    "Resulting authority",
                    "Contract requirement",
                ],
                "actions": ["create", "update", "supersede", "retire", "remove"],
                "none_literal": "None",
            },
            "guard": {
                "fields": ["Trigger", "Invalidates", "Resolution requires"],
            },
            "contract": {
                "fields": [
                    "Profile",
                    "Obligations",
                    "ADR Impact",
                    "Sources",
                    "Requirements",
                    "Commitments",
                    "Assurance",
                    "Impacts",
                    "Stops",
                ],
                "adr_pattern": (
                    r"^(?:none|create ADR-[0-9]{4}|"
                    r"(?:supersede|retire) ADR-[0-9]{4}"
                    r"(?:, ADR-[0-9]{4})*)$"
                ),
            },
            "coverage": {
                "architecture_header": ["Concern", "Status", "Support refs"],
                "architecture_concerns": ["owner"],
                "ready_architecture_statuses": ["closed", "not_applicable"],
                "existing_architecture_statuses": [
                    "already_closed",
                    "not_applicable",
                ],
                "gate_header": ["Gate", "Status", "Support refs"],
                "core_gates": ["Ownership"],
                "conditional_gates": ["State/Data Ownership"],
                "ready_core_status": "pass",
                "ready_conditional_statuses": ["pass", "not_applicable"],
                "existing_core_status": "already_closed",
                "existing_conditional_statuses": [
                    "already_closed",
                    "not_applicable",
                ],
                "blocking_failure_statuses": ["failed", "unresolved"],
                "gate_required_ref_groups": {
                    "Ownership": [["D"]],
                    "State/Data Ownership": [["D"], ["A"]],
                },
                "concern_gate_map": {"owner": ["Ownership"]},
            },
            "diagram": {
                "fields": ["Type", "Question", "Supports"],
                "types": ["context", "sequence"],
                "type_language_map": {
                    "context": "mermaid",
                    "sequence": "mermaid",
                },
            },
            "blocker": {
                "fields": [
                    "Kind",
                    "Gate",
                    "Need",
                    "Blocks because",
                    "Resolution requires",
                    "Related",
                ],
                "kinds": ["research", "user_decision"],
                "additional_gates": [
                    "Source Authority",
                    "Candidate Comparison",
                    "Disposition",
                ],
                "disposition_kinds_map": {
                    "BLOCKED": ["research", "user_decision"],
                },
            },
            "locators": {
                "evidence_line_pattern": r"^line [1-9][0-9]*$",
                "evidence_range_pattern": r"^lines [1-9][0-9]*-[1-9][0-9]*$",
                "evidence_surface_exceptions": [
                    "new_path",
                    "generated_output",
                    "command_surface",
                    "configuration_surface",
                ],
            },
            "forbidden_tokens": {
                "active_tokens": ["TODO", "TBD"],
                "template_markers": {
                    "{{DATE}}": 1,
                    "{{COMMIT}}": 1,
                    "{{BRANCH}}": 1,
                    "{{DISPOSITION}}": 1,
                    "{{SOURCE_KIND}}": 1,
                    "{{COMPARISON}}": 1,
                    "{{CONCERNS}}": 1,
                    "{{VERIFIES}}": 1,
                    "{{PROFILE}}": 1,
                    "{{OBLIGATIONS}}": 1,
                },
            },
        }
        patterns = {
            "source": re.compile(r"^S-[0-9]{3}$"),
            "evidence": re.compile(r"^E-[0-9]{3}$"),
            "requirement": re.compile(r"^R-[0-9]{3}$"),
            "form": re.compile(r"^F-[0-9]{3}$"),
            "material_obligation": re.compile(r"^M-[0-9]{3}$"),
            "pressure": re.compile(r"^P-[0-9]{3}$"),
            "decision": re.compile(r"^D-[0-9]{3}$"),
            "assurance": re.compile(r"^A-[0-9]{3}$"),
            "impact": re.compile(r"^I-[0-9]{3}$"),
            "guard": re.compile(r"^H-[0-9]{3}$"),
            "diagram": re.compile(r"^DG-[0-9]{3}$"),
            "blocker": re.compile(r"^B-[0-9]{3}$"),
        }
        return DesignSchema(
            source_path=Path("/repository/design-artifact-schema.json"),
            repository_root=Path("/repository"),
            raw=raw,
            version="architecture-design/v4",
            frontmatter_fields=(
                "schema",
                "date",
                "commit",
                "branch",
                "disposition",
                "outcome",
            ),
            dispositions=(
                "READY_FOR_CONTRACT",
                "BLOCKED",
                "DESIGN_NOT_REQUIRED",
            ),
            id_patterns=patterns,
            vocabulary_route="contract-vocabulary.json",
        )

    @staticmethod
    def minimal_design() -> str:
        return """---
schema: architecture-design/v4
date: 2026-08-11
commit: abc1234
branch: parser-test
disposition: BLOCKED
outcome: R-001
---

# Design: Parser Boundary

## Basis

### Sources

| ID | Kind | Locator | Use |
| --- | --- | --- | --- |
| S-001 | repository | `AGENTS.md` | Repository authority |

### Source Coverage

| Kind | Sources or none |
| --- | --- |
| repository | S-001 |

### Evidence

| ID | Source | Locator | Observed fact |
| --- | --- | --- | --- |
| E-001 | S-001 | `line 1` | The repository owns the rule. |

### Requirements

| ID | Kind | Statement | Basis | Open shape |
| --- | --- | --- | --- | --- |
| R-001 | outcome | Parse every owned line. | S-001, E-001 | Parser internals remain open. |

## Candidate Analysis

- Comparison: `blocked`
- Result: `blocked B-001`
- Result basis: B-001, R-001

### Forms

| ID | Form | Hard constraints | Main trade-off | Basis |
| --- | --- | --- | --- | --- |
| F-001 | Cursor parser | pass | Explicit ownership state | R-001 |

### Material-Obligation Delta

| ID | Material obligation | F-001 | Independent authority |
| --- | --- | --- | --- |
| M-001 | R-001 | yes | R-001 |

### Future Pressures

| ID | Pressure | Basis | Treatment | Closure refs | Accepted cost or risk |
| --- | --- | --- | --- | --- | --- |
| P-001 | More record kinds | R-001 | absorbed | B-001 | Closed grammar maintenance |

## Diagrams

### DG-001 — Parser state
- Type: `context`
- Question: Which construct owns this line?
- Supports: R-001
```mermaid
graph TD
```

## Open Blockers

### B-001 — Parser implementation
- Kind: `user_decision`
- Gate: `Disposition`
- Need: Implement the closed parser.
- Blocks because: The parser module does not exist.
- Resolution requires: Implement and verify the parser.
- Related: R-001
"""

    @classmethod
    def ready_design(cls) -> str:
        text = cls.minimal_design()
        text = text.replace(
            "disposition: BLOCKED",
            "disposition: READY_FOR_CONTRACT",
        )
        text = text.replace("- Comparison: `blocked`", "- Comparison: `single_viable`")
        text = text.replace("- Result: `blocked B-001`", "- Result: `selected F-001`")
        text = text.replace(
            "- Result basis: B-001, R-001",
            "- Result basis: F-001, M-001, R-001, E-001",
        )
        text = text.replace(
            "| P-001 | More record kinds | R-001 | absorbed | B-001 |",
            "| P-001 | More record kinds | R-001 | absorbed | D-001 |",
        )
        text = text.replace(
            "## Diagrams",
            """## Decision Register

### D-001 — Parser ownership
- Concerns: `form`, `owner`
- Lock: Every non-empty line has one canonical owner.
- Open: Cursor helper decomposition remains open.
- Basis: R-001, E-001
- Form: F-001
- Realizes: M-001
- Depends on: none
- Contract targets: `classification`, `owner`, `unit_family`
- Rationale: A cursor keeps structural ownership deterministic.

## Impact Register

None

## Assurance Register

### A-001 — Ownership witness
- Verifies: R-001, D-001/owner
- Claim: Unowned and multiply owned lines fail.
- Failure: A line bypasses the closed grammar.
- Oracle: Parse the controlled artifact and inspect findings.
- Proxy risk: Substring extraction can miss trailing text.
- Evidence constraints: Exercise the real parser.
- Architecture seam: none

## Stop Conditions

### H-001 — Parser contradiction
- Trigger: The schema declares a construct the parser cannot own.
- Invalidates: D-001, A-001
- Resolution requires: Re-open parser design against the canonical schema.

## Contract Interface

- Profile: `REFACTOR`
- Obligations: `None`
- ADR Impact: none
- Sources: S-001
- Requirements: R-001
- Commitments: D-001
- Assurance: A-001
- Impacts: none
- Stops: H-001

## Diagrams""",
        )
        text = text.replace("- Supports: R-001", "- Supports: D-001, A-001")
        text = text.replace(
            "## Open Blockers",
            """## Readiness Matrix

### Architecture Closure

| Concern | Status | Support refs |
| --- | --- | --- |
| owner | closed | D-001 |

### Gate Closure

| Gate | Status | Support refs |
| --- | --- | --- |
| Ownership | pass | D-001, A-001 |

## Open Blockers""",
        )
        blocker = """### B-001 — Parser implementation
- Kind: `user_decision`
- Gate: `Disposition`
- Need: Implement the closed parser.
- Blocks because: The parser module does not exist.
- Resolution requires: Implement and verify the parser.
- Related: R-001"""
        return text.replace(blocker, "None")

    @staticmethod
    def messages(findings: list[Finding]) -> str:
        return "\n".join(finding.message for finding in findings)

    def assert_has(
        self, text: str, expected: str, schema: DesignSchema | None = None
    ) -> None:
        _, findings = parse_design(text, schema or self.schema())
        self.assertIn(expected, self.messages(findings))
