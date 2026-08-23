from __future__ import annotations

from collections.abc import Mapping, Sequence
from dataclasses import dataclass
from typing import cast

from design_lint_model import (
    ContractVocabulary,
    DesignSchema,
    Finding,
    ParsedDesign,
    Record,
)

from design_lint_validation_common import (
    _code_tokens,
    _csv_tokens,
    _duplicates,
    _ordered_records,
    _schema_object,
    _selected_form,
)


@dataclass(frozen=True)
class _DecisionPolicy:
    allowed_concerns: frozenset[str]
    allowed_targets: frozenset[str]
    required_targets_by_concern: Mapping[str, tuple[str, ...]]

    @classmethod
    def from_schema(cls, schema: DesignSchema) -> _DecisionPolicy:
        raw = _schema_object(schema, "decision")
        target_map = cast(Mapping[str, object], raw["concern_contract_target_map"])
        return cls(
            allowed_concerns=frozenset(cast(list[str], raw["concerns"])),
            allowed_targets=frozenset(cast(list[str], raw["contract_targets"])),
            required_targets_by_concern={
                concern: tuple(cast(list[str], targets))
                for concern, targets in target_map.items()
                if isinstance(targets, list)
            },
        )


@dataclass(frozen=True)
class _DecisionView:
    record: Record
    concerns: tuple[str, ...]
    targets: tuple[str, ...]

    @classmethod
    def from_record(cls, record: Record) -> _DecisionView:
        return cls(
            record=record,
            concerns=tuple(_code_tokens(record.fields.get("Concerns", ""))),
            targets=tuple(_code_tokens(record.fields.get("Contract targets", ""))),
        )

    @property
    def identifier(self) -> str:
        return self.record.identifier


class _DecisionGraph:
    def __init__(self, identifiers: Sequence[str]) -> None:
        self.identifiers = tuple(identifiers)
        self.positions = {
            identifier: index for index, identifier in enumerate(self.identifiers)
        }
        self.dependencies: dict[str, tuple[str, ...]] = {}

    def set_dependencies(self, identifier: str, dependencies: Sequence[str]) -> None:
        self.dependencies[identifier] = tuple(dependencies)

    def contains_cycle(self) -> bool:
        visiting: set[str] = set()
        visited: set[str] = set()

        def visit(identifier: str) -> bool:
            if identifier in visiting:
                return True
            if identifier in visited:
                return False
            visiting.add(identifier)
            for dependency in self.dependencies.get(identifier, ()):
                if dependency in self.dependencies and visit(dependency):
                    return True
            visiting.remove(identifier)
            visited.add(identifier)
            return False

        return any(visit(identifier) for identifier in self.identifiers)


def _invalid_unique_tokens(
    values: Sequence[str],
    allowed: frozenset[str],
) -> bool:
    tokens = list(values)
    return not tokens or bool(_duplicates(tokens)) or any(
        token not in allowed for token in tokens
    )


def _decision_shape_findings(
    decision: _DecisionView,
    policy: _DecisionPolicy,
) -> list[Finding]:
    record = decision.record
    findings: list[Finding] = []
    if _invalid_unique_tokens(decision.concerns, policy.allowed_concerns):
        findings.append(
            Finding(
                record.field_lines.get("Concerns", record.line),
                "decision-concern",
                f"decision {record.identifier} has invalid or duplicate concerns",
            )
        )
    if _invalid_unique_tokens(decision.targets, policy.allowed_targets):
        findings.append(
            Finding(
                record.field_lines.get("Contract targets", record.line),
                "decision-target",
                f"decision {record.identifier} has invalid or duplicate Contract targets",
            )
        )
    for concern in decision.concerns:
        for target in policy.required_targets_by_concern.get(concern, ()):
            if target not in decision.targets:
                findings.append(
                    Finding(
                        record.field_lines.get("Contract targets", record.line),
                        "decision-target",
                        f"decision {record.identifier} concern {concern} requires "
                        f"Contract target {target}",
                    )
                )
    return findings


def _dependency_findings(
    decision: _DecisionView,
    graph: _DecisionGraph,
    schema: DesignSchema,
) -> list[Finding]:
    record = decision.record
    value = record.fields.get("Depends on", "")
    if value == "none":
        graph.set_dependencies(record.identifier, ())
        return []

    dependencies = _csv_tokens(value)
    pattern = schema.id_patterns["decision"]
    if not dependencies or any(pattern.fullmatch(token) is None for token in dependencies):
        graph.set_dependencies(record.identifier, ())
        return [
            Finding(
                record.field_lines.get("Depends on", record.line),
                "decision-dependency",
                "Depends on accepts only D references",
            )
        ]

    graph.set_dependencies(record.identifier, dependencies)
    findings: list[Finding] = []
    for dependency in dependencies:
        if dependency not in graph.positions:
            findings.append(
                Finding(
                    record.field_lines.get("Depends on", record.line),
                    "decision-dependency",
                    f"decision {record.identifier} depends on unknown {dependency}",
                )
            )
        elif graph.positions[dependency] >= graph.positions[record.identifier]:
            findings.append(
                Finding(
                    record.field_lines.get("Depends on", record.line),
                    "decision-order",
                    f"dependency must precede decision {record.identifier}",
                )
            )
    return findings


def validate_decisions(
    parsed: ParsedDesign,
    schema: DesignSchema,
    vocabulary: ContractVocabulary | None,
    *,
    template: bool = False,
) -> list[Finding]:
    del vocabulary
    if template:
        return []

    decisions = [
        _DecisionView.from_record(record)
        for record in _ordered_records(parsed, "D", "Decision Register")
    ]
    policy = _DecisionPolicy.from_schema(schema)
    graph = _DecisionGraph([decision.identifier for decision in decisions])
    findings: list[Finding] = []
    for decision in decisions:
        findings.extend(_decision_shape_findings(decision, policy))
        findings.extend(_dependency_findings(decision, graph, schema))

    if graph.contains_cycle():
        section = parsed.sections.get("Decision Register")
        findings.append(
            Finding(
                section.line if section is not None else parsed.body_line,
                "decision-cycle",
                "decision dependencies must be acyclic",
            )
        )
    return findings


@dataclass(frozen=True)
class _ImpactRequirement:
    record: Record
    decisions: tuple[str, ...]

    @classmethod
    def from_record(
        cls,
        record: Record,
        parsed: ParsedDesign,
    ) -> _ImpactRequirement:
        return cls(
            record=record,
            decisions=tuple(
                reference
                for reference in _csv_tokens(record.fields.get("Required by", ""))
                if (decision := parsed.records.get(reference)) is not None
                and decision.kind == "D"
            ),
        )


@dataclass(frozen=True)
class _DurableImpactIndex:
    decisions: tuple[_DecisionView, ...]
    impacts: tuple[_ImpactRequirement, ...]
    required_by_decision: frozenset[str]
    targets_by_decision: Mapping[str, frozenset[str]]

    @classmethod
    def build(cls, parsed: ParsedDesign) -> _DurableImpactIndex:
        decisions = tuple(
            _DecisionView.from_record(record)
            for record in _ordered_records(parsed, "D", "Decision Register")
        )
        impacts = tuple(
            _ImpactRequirement.from_record(record, parsed)
            for record in _ordered_records(parsed, "I", "Impact Register")
        )
        return cls(
            decisions=decisions,
            impacts=impacts,
            required_by_decision=frozenset(
                identifier
                for impact in impacts
                for identifier in impact.decisions
            ),
            targets_by_decision={
                decision.identifier: frozenset(decision.targets)
                for decision in decisions
            },
        )


def _missing_impact_findings(
    index: _DurableImpactIndex,
    selected_form: str | None,
) -> list[Finding]:
    findings: list[Finding] = []
    for decision in index.decisions:
        if decision.record.fields.get("Form") != selected_form:
            continue
        if "durable_impact" not in decision.targets:
            continue
        if decision.identifier in index.required_by_decision:
            continue
        findings.append(
            Finding(
                decision.record.field_lines.get("Contract targets", decision.record.line),
                "durable-impact",
                f"selected durable_impact decision {decision.identifier} "
                "requires an Impact Register reference",
            )
        )
    return findings


def _invalid_impact_owner_findings(
    index: _DurableImpactIndex,
) -> list[Finding]:
    findings: list[Finding] = []
    for impact in index.impacts:
        for decision_id in impact.decisions:
            if "durable_impact" in index.targets_by_decision.get(
                decision_id, frozenset()
            ):
                continue
            findings.append(
                Finding(
                    impact.record.field_lines.get("Required by", impact.record.line),
                    "durable-impact",
                    f"durable impact {impact.record.identifier} Required by decision "
                    f"{decision_id} must target durable_impact",
                )
            )
    return findings


def validate_durable_impact_correspondence(
    parsed: ParsedDesign,
    schema: DesignSchema,
    vocabulary: ContractVocabulary | None,
    *,
    template: bool = False,
) -> list[Finding]:
    del schema, vocabulary
    if template or parsed.frontmatter.get("disposition") != "READY_FOR_CONTRACT":
        return []

    index = _DurableImpactIndex.build(parsed)
    return [
        *_missing_impact_findings(index, _selected_form(parsed)),
        *_invalid_impact_owner_findings(index),
    ]
