from __future__ import annotations

from collections import defaultdict
from collections.abc import Mapping, Sequence
from dataclasses import dataclass
from typing import cast

from design_lint_model import (
    ContractVocabulary,
    DesignSchema,
    Finding,
    ParsedDesign,
    Record,
    Table,
)

from design_lint_validation_common import (
    _DecisionConcernIndex,
    _code_tokens,
    _csv_tokens,
    _ordered_records,
    _schema_object,
    _selected_form,
)


@dataclass(frozen=True)
class _AssuranceIndex:
    records: tuple[Record, ...]
    verifies_by_id: Mapping[str, tuple[str, ...]]
    ids_by_target: Mapping[str, frozenset[str]]
    all_verified: frozenset[str]

    @classmethod
    def build(cls, assurance_records: Sequence[Record]) -> _AssuranceIndex:
        records = tuple(assurance_records)
        verifies_by_id = {
            record.identifier: tuple(_csv_tokens(record.fields.get("Verifies", "")))
            for record in records
        }
        ids_by_target: dict[str, set[str]] = defaultdict(set)
        for record in records:
            for target in verifies_by_id[record.identifier]:
                ids_by_target[target].add(record.identifier)
        return cls(
            records=records,
            verifies_by_id=verifies_by_id,
            ids_by_target={
                target: frozenset(identifiers)
                for target, identifiers in ids_by_target.items()
            },
            all_verified=frozenset(ids_by_target),
        )


class _GateSupportIndex:
    def __init__(self, table: Table | None) -> None:
        self.table = table
        self.support_by_gate: dict[str, frozenset[str]] = {}
        self._first_lines: dict[str, int] = {}
        if table is None:
            return
        for row, line in zip(table.rows, table.row_lines):
            if not row:
                continue
            gate = row[0]
            self._first_lines.setdefault(gate, line)
            references = _csv_tokens(row[2]) if len(row) >= 3 else []
            self.support_by_gate[gate] = frozenset(references)

    def line(self, gate: str) -> int:
        if gate in self._first_lines:
            return self._first_lines[gate]
        if self.table is not None and self.table.row_lines:
            return self.table.row_lines[0]
        return 0

    def assurance_ids_used(
        self,
        usage_rows: tuple[tuple[str, ...], ...] | None,
    ) -> frozenset[str]:
        if usage_rows is None:
            rows = self.table.rows if self.table is not None else ()
        else:
            rows = usage_rows
        return frozenset(
            reference
            for row in rows
            if len(row) >= 3
            for reference in _csv_tokens(row[2])
            if reference.startswith("A-")
        )


def _validate_assurance_target_ownership(
    assurance_records: list[Record],
    decisions: list[Record],
) -> list[Finding]:
    decision_index = _DecisionConcernIndex.build(decisions)
    assurance_index = _AssuranceIndex.build(assurance_records)
    findings: list[Finding] = []
    for assurance in assurance_index.records:
        for reference in assurance_index.verifies_by_id[assurance.identifier]:
            decision_id, separator, concern = reference.partition("/")
            if not separator or not decision_id.startswith("D-"):
                continue
            if decision_id not in decision_index.by_id:
                continue
            if not decision_index.owns(decision_id, concern):
                findings.append(
                    Finding(
                        assurance.field_lines.get("Verifies", assurance.line),
                        "assurance",
                        f"assurance {assurance.identifier} references concern "
                        f"{concern} not owned by {decision_id}",
                    )
                )
    return findings


def _validate_gate_assurance_semantics(
    gates: Table | None,
    gate_names: list[str],
    decisions: list[Record],
    assurance_records: list[Record],
    coverage: Mapping[str, object],
    *,
    usage_rows: tuple[tuple[str, ...], ...] | None = None,
) -> list[Finding]:
    gate_index = _GateSupportIndex(gates)
    decision_index = _DecisionConcernIndex.build(decisions)
    assurance_index = _AssuranceIndex.build(assurance_records)
    evaluated = set(gate_names)
    used_assurances = gate_index.assurance_ids_used(usage_rows)

    findings: list[Finding] = []
    for assurance in assurance_index.records:
        if assurance.identifier not in used_assurances:
            findings.append(
                Finding(
                    assurance.line,
                    "assurance-usage",
                    f"assurance {assurance.identifier} must participate in Gate Closure",
                )
            )

    concern_gate_map = cast(Mapping[str, object], coverage["concern_gate_map"])
    for decision in decision_index.records:
        for concern in decision_index.concerns_by_id[decision.identifier]:
            raw_gates = concern_gate_map.get(concern)
            if not isinstance(raw_gates, list):
                continue
            exact = f"{decision.identifier}/{concern}"
            exact_assurances = assurance_index.ids_by_target.get(exact, frozenset())
            for gate in cast(list[str], raw_gates):
                if gate not in evaluated:
                    continue
                support = gate_index.support_by_gate.get(gate, frozenset())
                if decision.identifier not in support or not support.intersection(
                    exact_assurances
                ):
                    findings.append(
                        Finding(
                            gate_index.line(gate),
                            "assurance-gate",
                            f"gate {gate} requires assurance for {exact}",
                        )
                    )
    return findings


def _outcome_findings(
    parsed: ParsedDesign,
    outcome: Record,
    decisions: Sequence[Record],
    assurance: _AssuranceIndex,
) -> list[Finding]:
    findings: list[Finding] = []
    selected = _selected_form(parsed)
    carried = any(
        record.fields.get("Form") == selected
        and outcome.identifier in _csv_tokens(record.fields.get("Basis", ""))
        for record in decisions
    )
    if not carried:
        findings.append(
            Finding(
                outcome.line,
                "outcome",
                f"outcome requirement {outcome.identifier} must be carried by a "
                "selected decision",
            )
        )
    if outcome.identifier not in assurance.all_verified:
        findings.append(
            Finding(
                outcome.line,
                "assurance",
                f"outcome requirement {outcome.identifier} requires exact assurance",
            )
        )
    return findings


def _direct_decision_reference_findings(
    assurance: _AssuranceIndex,
    schema: DesignSchema,
) -> list[Finding]:
    decision_pattern = schema.id_patterns["decision"]
    findings: list[Finding] = []
    for record in assurance.records:
        if any(
            decision_pattern.fullmatch(reference) is not None
            for reference in assurance.verifies_by_id[record.identifier]
        ):
            findings.append(
                Finding(
                    record.field_lines.get("Verifies", record.line),
                    "assurance",
                    f"assurance {record.identifier} must use exact D/concern references",
                )
            )
    return findings


def _required_assurance_findings(
    parsed: ParsedDesign,
    decisions: Sequence[Record],
    assurance: _AssuranceIndex,
    schema: DesignSchema,
) -> list[Finding]:
    decision_schema = _schema_object(schema, "decision")
    required_concerns = set(
        cast(list[str], decision_schema["assurance_required_concerns"])
    )
    findings: list[Finding] = []
    for decision in decisions:
        for concern in _code_tokens(decision.fields.get("Concerns", "")):
            if concern not in required_concerns:
                continue
            exact = f"{decision.identifier}/{concern}"
            if exact not in assurance.all_verified:
                findings.append(
                    Finding(
                        decision.line,
                        "assurance",
                        f"decision {decision.identifier} concern {concern} "
                        "requires exact assurance",
                    )
                )

    for impact in _ordered_records(parsed, "I", "Impact Register"):
        if impact.identifier not in assurance.all_verified:
            findings.append(
                Finding(
                    impact.line,
                    "assurance",
                    f"durable impact {impact.identifier} requires exact assurance",
                )
            )
    return findings


def validate_assurance(
    parsed: ParsedDesign,
    schema: DesignSchema,
    vocabulary: ContractVocabulary | None,
    *,
    template: bool = False,
    checkpoint: bool = False,
) -> list[Finding]:
    del vocabulary
    if template or parsed.frontmatter.get("disposition") != "READY_FOR_CONTRACT":
        return []

    requirements = _ordered_records(parsed, "R", "Basis")
    outcomes = [
        record for record in requirements if record.fields.get("Kind") == "outcome"
    ]
    decisions = _ordered_records(parsed, "D", "Decision Register")
    assurance_records = _ordered_records(parsed, "A", "Assurance Register")
    assurance = _AssuranceIndex.build(assurance_records)

    findings: list[Finding] = []
    if len(outcomes) == 1:
        findings.extend(_outcome_findings(parsed, outcomes[0], decisions, assurance))
    findings.extend(_direct_decision_reference_findings(assurance, schema))
    findings.extend(_validate_assurance_target_ownership(assurance_records, decisions))
    findings.extend(_required_assurance_findings(parsed, decisions, assurance, schema))

    if not checkpoint:
        coverage = _schema_object(schema, "coverage")
        gate_names = [
            *cast(list[str], coverage["core_gates"]),
            *cast(list[str], coverage["conditional_gates"]),
        ]
        findings.extend(
            _validate_gate_assurance_semantics(
                parsed.tables.get("Gate Closure"),
                gate_names,
                decisions,
                assurance_records,
                coverage,
            )
        )
    return findings
