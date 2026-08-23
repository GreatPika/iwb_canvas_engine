from __future__ import annotations

import re
from dataclasses import dataclass

from design_lint_model import (
    ContractVocabulary,
    DesignSchema,
    Finding,
    ParsedDesign,
    Record,
)

from design_lint_validation_common import (
    _code_values,
    _contains_token,
    _csv_tokens,
    _duplicates,
    _ordered_records,
    _reference_type,
    _rows_by_key,
    _table_row_line,
)


@dataclass(frozen=True)
class _ContractProjection:
    field: str
    kind: str
    section: str


@dataclass(frozen=True)
class _AdrImpact:
    record: Record
    action: str
    declared_targets: tuple[str, ...]
    matching_targets: tuple[str, ...]


@dataclass(frozen=True)
class _AdrDeclaration:
    raw: str
    action: str
    separator: str
    targets: tuple[str, ...]

    @classmethod
    def parse(cls, value: str) -> _AdrDeclaration:
        action, separator, targets_value = value.partition(" ")
        targets = tuple(
            target.strip() for target in targets_value.split(",") if target.strip()
        )
        return cls(value, action, separator, targets)

    @property
    def transitions(self) -> frozenset[tuple[str, str]]:
        if self.raw == "none" or not self.separator or not self.targets:
            return frozenset()
        return frozenset((self.action, target) for target in self.targets)

    @property
    def has_declared_targets(self) -> bool:
        return self.raw != "none" and bool(self.separator) and bool(self.targets)


_CONTRACT_PROJECTIONS = (
    _ContractProjection("Sources", "S", "Basis"),
    _ContractProjection("Requirements", "R", "Basis"),
    _ContractProjection("Commitments", "D", "Decision Register"),
    _ContractProjection("Assurance", "A", "Assurance Register"),
    _ContractProjection("Impacts", "I", "Impact Register"),
    _ContractProjection("Stops", "H", "Stop Conditions"),
)
_ADR_ACTIONS = frozenset({"create", "supersede", "retire"})
_ADR_TOKEN_PATTERN = re.compile(r"(?<![A-Za-z0-9_-])ADR-[0-9]{4}(?![A-Za-z0-9_-])")
_ADR_TOKEN_PATTERN_CASELESS = re.compile(
    r"(?<![A-Za-z0-9_-])ADR-[0-9]{4}(?![A-Za-z0-9_-])",
    flags=re.IGNORECASE,
)


def _profile_findings(
    contract: Record,
    vocabulary: ContractVocabulary | None,
) -> list[Finding]:
    profile_values = _code_values(contract.fields.get("Profile", ""))
    line = contract.field_lines.get("Profile", contract.line)
    if profile_values is None or len(profile_values) != 1:
        return [
            Finding(
                line,
                "contract-profile",
                "Contract Interface Profile must be one complete canonical value",
            )
        ]
    if vocabulary is None or profile_values[0] not in vocabulary.profiles:
        return [
            Finding(
                line,
                "contract-profile",
                f"unknown Contract Interface Profile {profile_values[0]}",
            )
        ]
    return []


def _obligation_findings(
    contract: Record,
    vocabulary: ContractVocabulary | None,
) -> list[Finding]:
    obligation_values = _code_values(contract.fields.get("Obligations", ""))
    line = contract.field_lines.get("Obligations", contract.line)
    if obligation_values is None or not obligation_values:
        return [
            Finding(
                line,
                "contract-obligations",
                "Contract Interface Obligations must use complete canonical values",
            )
        ]

    findings = [
        Finding(
            line,
            "contract-obligations",
            f"Contract Interface Obligations contains duplicate {duplicate}",
        )
        for duplicate in _duplicates(obligation_values)
    ]
    if vocabulary is None:
        return findings

    findings.extend(
        Finding(
            line,
            "contract-obligations",
            f"unknown Contract Interface Obligation {obligation}",
        )
        for obligation in obligation_values
        if obligation not in vocabulary.obligations
        and obligation != vocabulary.no_obligation
    )
    if vocabulary.no_obligation in obligation_values and len(obligation_values) != 1:
        findings.append(
            Finding(
                line,
                "contract-obligations",
                "Contract Interface no-obligation value cannot be combined",
            )
        )
    return findings


def _projection_findings(parsed: ParsedDesign, contract: Record) -> list[Finding]:
    findings: list[Finding] = []
    for projection in _CONTRACT_PROJECTIONS:
        value = contract.fields.get(projection.field, "")
        actual = [] if value == "none" else _csv_tokens(value)
        expected = [
            record.identifier
            for record in _ordered_records(
                parsed,
                projection.kind,
                projection.section,
            )
        ]
        line = contract.field_lines.get(projection.field, contract.line)
        for duplicate in _duplicates(actual):
            findings.append(
                Finding(
                    line,
                    "contract-projection",
                    f"Contract Interface {projection.field} contains duplicate "
                    f"reference {duplicate}",
                )
            )
        if any(
            _reference_type(reference) != projection.kind for reference in actual
        ):
            findings.append(
                Finding(
                    line,
                    "contract-projection",
                    f"Contract Interface {projection.field} accepts only "
                    f"{projection.kind} references",
                )
            )
        if actual != expected:
            findings.append(
                Finding(
                    line,
                    "contract-projection",
                    f"Contract Interface {projection.field} must equal canonical "
                    "record order",
                )
            )
    return findings


def _adr_impacts(impacts: list[Record]) -> list[_AdrImpact]:
    result: list[_AdrImpact] = []
    for impact in impacts:
        surface = impact.fields.get("Surface", "")
        declared_targets = tuple(dict.fromkeys(_ADR_TOKEN_PATTERN.findall(surface)))
        matching_targets = tuple(
            dict.fromkeys(
                target.upper() for target in _ADR_TOKEN_PATTERN_CASELESS.findall(surface)
            )
        )
        result.append(
            _AdrImpact(
                record=impact,
                action=impact.fields.get("Action", ""),
                declared_targets=declared_targets,
                matching_targets=matching_targets,
            )
        )
    return result


def _index_matching_impacts(
    impacts: list[_AdrImpact],
) -> dict[tuple[str, str], list[Record]]:
    index: dict[tuple[str, str], list[Record]] = {}
    for impact in impacts:
        for target in impact.matching_targets:
            index.setdefault((impact.action, target), []).append(impact.record)
    return index


def _validate_adr_impact_record(
    impact: Record,
    *,
    action: str,
    target: str,
) -> list[Finding]:
    findings: list[Finding] = []
    required = _csv_tokens(impact.fields.get("Required by", ""))
    authorities = _csv_tokens(impact.fields.get("Resulting authority", ""))
    if not authorities or not set(authorities) <= set(required):
        findings.append(
            Finding(
                impact.field_lines.get("Resulting authority", impact.line),
                "adr-impact",
                f"{impact.identifier}.Resulting authority must correspond to "
                "Required by",
            )
        )

    requirement = impact.fields.get("Contract requirement", "")
    if (
        not _contains_token(requirement, action)
        or not _contains_token(requirement, target)
        or any(
            not _contains_token(requirement, authority) for authority in authorities
        )
    ):
        findings.append(
            Finding(
                impact.field_lines.get("Contract requirement", impact.line),
                "adr-impact",
                f"{impact.identifier}.Contract requirement must name {action} "
                f"{target} and resulting authority",
            )
        )
    return findings


def _missing_adr_projection_findings(
    declaration: _AdrDeclaration,
    impacts: list[_AdrImpact],
    line: int,
) -> list[Finding]:
    declared_transitions = declaration.transitions
    if declaration.raw != "none" and not declared_transitions:
        return []

    findings: list[Finding] = []
    for impact in impacts:
        if impact.action not in _ADR_ACTIONS:
            continue
        for target in impact.declared_targets:
            if (impact.action, target) not in declared_transitions:
                findings.append(
                    Finding(
                        line,
                        "adr-impact",
                        f"durable impact {impact.record.identifier} action "
                        f"{impact.action} for {target} is missing from ADR Impact",
                    )
                )
    return findings


def _declared_adr_transition_findings(
    declaration: _AdrDeclaration,
    impacts: list[_AdrImpact],
    line: int,
) -> list[Finding]:
    if not declaration.has_declared_targets:
        return []

    matching_impacts = _index_matching_impacts(impacts)
    findings: list[Finding] = []
    for target in declaration.targets:
        matching = matching_impacts.get((declaration.action, target.upper()), [])
        if not matching:
            findings.append(
                Finding(
                    line,
                    "adr-impact",
                    f"ADR Impact action {declaration.action} has no matching "
                    f"durable impact for {target}",
                )
            )
            continue
        for impact in matching:
            findings.extend(
                _validate_adr_impact_record(
                    impact,
                    action=declaration.action,
                    target=target,
                )
            )
    return findings


def _adr_findings(parsed: ParsedDesign, contract: Record) -> list[Finding]:
    declaration = _AdrDeclaration.parse(contract.fields.get("ADR Impact", ""))
    impacts = _adr_impacts(_ordered_records(parsed, "I", "Impact Register"))
    line = contract.field_lines.get("ADR Impact", contract.line)
    findings = _missing_adr_projection_findings(declaration, impacts, line)
    findings.extend(_declared_adr_transition_findings(declaration, impacts, line))
    return findings


def _stop_condition_findings(
    parsed: ParsedDesign,
    contract: Record,
    *,
    ready: bool,
) -> list[Finding]:
    if not ready or _ordered_records(parsed, "H", "Stop Conditions"):
        return []
    stop_conditions = parsed.sections.get("Stop Conditions")
    return [
        Finding(
            stop_conditions.line
            if stop_conditions is not None
            else contract.field_lines.get("Stops", contract.line),
            "contract-stop",
            "ready design requires at least one explicit contract stop condition",
        )
    ]


def _handoff_findings(parsed: ParsedDesign) -> list[Finding]:
    gate_table = parsed.tables.get("Gate Closure")
    handoff = _rows_by_key(gate_table).get("Handoff Consumability")
    if handoff is None or len(handoff) < 3 or _csv_tokens(handoff[2]) != ["CONTRACT"]:
        return []
    return [
        Finding(
            _table_row_line(gate_table, "Handoff Consumability"),
            "handoff",
            "CONTRACT alone cannot prove Handoff Consumability",
        )
    ]


def validate_contract_interface(
    parsed: ParsedDesign,
    schema: DesignSchema,
    vocabulary: ContractVocabulary | None,
    *,
    template: bool = False,
) -> list[Finding]:
    del schema
    if template:
        return []

    ready = parsed.frontmatter.get("disposition") == "READY_FOR_CONTRACT"
    contract = parsed.records.get("CONTRACT")
    if contract is None:
        return (
            [
                Finding(
                    parsed.body_line,
                    "contract-interface",
                    "ready design requires Contract Interface",
                )
            ]
            if ready
            else []
        )

    findings = _profile_findings(contract, vocabulary)
    findings.extend(_obligation_findings(contract, vocabulary))
    findings.extend(_projection_findings(parsed, contract))
    findings.extend(_adr_findings(parsed, contract))
    findings.extend(_stop_condition_findings(parsed, contract, ready=ready))
    findings.extend(_handoff_findings(parsed))
    return findings


def validate_diagrams(
    parsed: ParsedDesign,
    schema: DesignSchema,
    vocabulary: ContractVocabulary | None,
    *,
    template: bool = False,
) -> list[Finding]:
    del parsed, schema, vocabulary, template
    return []
