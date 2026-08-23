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
    Table,
)

from design_lint_validation_assurance import (
    _validate_assurance_target_ownership,
    _validate_gate_assurance_semantics,
)
from design_lint_validation_common import (
    _DecisionConcernIndex,
    _csv_tokens,
    _ordered_records,
    _reference_type,
    _schema_object,
    _strip_code,
)


@dataclass(frozen=True)
class _ClosureRow:
    raw: tuple[str, ...]
    line: int

    @property
    def name(self) -> str:
        return self.raw[0]

    @property
    def status(self) -> str:
        return self.raw[1] if len(self.raw) >= 2 else ""

    @property
    def references(self) -> tuple[str, ...]:
        return tuple(_csv_tokens(self.raw[2])) if len(self.raw) >= 3 else ()

    @property
    def complete(self) -> bool:
        return len(self.raw) >= 3


class _ClosureTableView:
    def __init__(self, table: Table | None) -> None:
        self.table = table
        self.by_name: dict[str, _ClosureRow] = {}
        self._first_lines: dict[str, int] = {}
        if table is None:
            return
        for row, line in zip(table.rows, table.row_lines):
            if not row:
                continue
            name = row[0]
            self._first_lines.setdefault(name, line)
            self.by_name[name] = _ClosureRow(row, self._first_lines[name])

    def row(self, name: str) -> _ClosureRow | None:
        return self.by_name.get(name)

    def line(self, name: str) -> int:
        if name in self._first_lines:
            return self._first_lines[name]
        if self.table is not None and self.table.row_lines:
            return self.table.row_lines[0]
        return 0

    def physical_names(self) -> list[str]:
        if self.table is None:
            return []
        return [row[0] for row in self.table.rows if row]


@dataclass(frozen=True)
class _CoveragePolicy:
    architecture_concerns: tuple[str, ...]
    core_gates: tuple[str, ...]
    conditional_gates: tuple[str, ...]
    ready_architecture_statuses: frozenset[str]
    ready_core_status: str
    ready_conditional_statuses: frozenset[str]
    existing_architecture_statuses: frozenset[str]
    existing_core_status: str
    existing_conditional_statuses: frozenset[str]
    blocking_failure_statuses: frozenset[str]
    required_reference_groups: Mapping[str, tuple[tuple[str, ...], ...]]
    gates_by_concern: Mapping[str, tuple[str, ...]]

    @classmethod
    def from_mapping(cls, coverage: Mapping[str, object]) -> _CoveragePolicy:
        raw_required_groups = cast(
            Mapping[str, object], coverage["gate_required_ref_groups"]
        )
        raw_concern_gates = cast(Mapping[str, object], coverage["concern_gate_map"])
        return cls(
            architecture_concerns=tuple(
                cast(list[str], coverage["architecture_concerns"])
            ),
            core_gates=tuple(cast(list[str], coverage["core_gates"])),
            conditional_gates=tuple(cast(list[str], coverage["conditional_gates"])),
            ready_architecture_statuses=frozenset(
                cast(list[str], coverage["ready_architecture_statuses"])
            ),
            ready_core_status=cast(str, coverage["ready_core_status"]),
            ready_conditional_statuses=frozenset(
                cast(list[str], coverage["ready_conditional_statuses"])
            ),
            existing_architecture_statuses=frozenset(
                cast(list[str], coverage["existing_architecture_statuses"])
            ),
            existing_core_status=cast(str, coverage["existing_core_status"]),
            existing_conditional_statuses=frozenset(
                cast(list[str], coverage["existing_conditional_statuses"])
            ),
            blocking_failure_statuses=frozenset(
                cast(list[str], coverage["blocking_failure_statuses"])
            ),
            required_reference_groups={
                gate: tuple(
                    tuple(cast(list[str], raw_group))
                    for raw_group in raw_groups
                    if isinstance(raw_group, list)
                )
                for gate, raw_groups in raw_required_groups.items()
                if isinstance(raw_groups, list)
            },
            gates_by_concern={
                concern: tuple(cast(list[str], gates))
                for concern, gates in raw_concern_gates.items()
                if isinstance(gates, list)
            },
        )

    @property
    def gate_order(self) -> tuple[str, ...]:
        return (*self.core_gates, *self.conditional_gates)


def _has_only_support_types(
    references: Sequence[str],
    allowed_types: frozenset[str],
) -> bool:
    return bool(references) and all(
        _reference_type(reference) in allowed_types for reference in references
    )


def _closed_architecture_findings(
    row: _ClosureRow,
    concern: str,
    decisions: _DecisionConcernIndex,
) -> list[Finding]:
    owners = decisions.owners(concern)
    decision_refs = [
        reference for reference in row.references if reference.startswith("D-")
    ]
    findings: list[Finding] = []
    if not owners:
        findings.append(
            Finding(
                row.line,
                "architecture-closure",
                f"Architecture Closure {concern} closed requires an owning decision",
            )
        )
    for decision_ref in decision_refs:
        if decision_ref not in decisions.by_id or not decisions.owns(
            decision_ref, concern
        ):
            findings.append(
                Finding(
                    row.line,
                    "architecture-closure",
                    f"Architecture Closure {concern} references a decision "
                    "without the matching concern",
                )
            )
    for owner in owners:
        if owner not in decision_refs:
            findings.append(
                Finding(
                    row.line,
                    "architecture-closure",
                    f"decision {owner} concern {concern} lacks reverse "
                    "Architecture Closure coverage",
                )
            )
    return findings


def _ready_architecture_row_findings(
    row: _ClosureRow,
    concern: str,
    decisions: _DecisionConcernIndex,
    policy: _CoveragePolicy,
) -> list[Finding]:
    if row.status not in policy.ready_architecture_statuses:
        return [
            Finding(
                row.line,
                "architecture-closure",
                f"Architecture Closure {concern} has invalid ready status {row.status}",
            )
        ]
    if row.status == "closed":
        return _closed_architecture_findings(row, concern, decisions)
    if row.status == "not_applicable" and (
        decisions.owners(concern)
        or not _has_only_support_types(row.references, frozenset({"R", "E"}))
    ):
        return [
            Finding(
                row.line,
                "architecture-closure",
                f"not_applicable concern {concern} requires R/E support and "
                "no owning decision",
            )
        ]
    return []


def _validate_architecture_row_semantics(
    architecture: _ClosureTableView,
    concerns: Sequence[str],
    decisions: _DecisionConcernIndex,
    policy: _CoveragePolicy,
) -> list[Finding]:
    findings: list[Finding] = []
    for concern in concerns:
        row = architecture.row(concern)
        if row is not None and row.complete:
            findings.extend(
                _ready_architecture_row_findings(row, concern, decisions, policy)
            )
    return findings


def _ready_gate_row_findings(
    row: _ClosureRow,
    gate: str,
    policy: _CoveragePolicy,
) -> list[Finding]:
    findings: list[Finding] = []
    if gate in policy.core_gates and row.status != policy.ready_core_status:
        findings.append(
            Finding(
                row.line,
                "gate-status",
                f"core gate {gate} must use status {policy.ready_core_status}",
            )
        )
    elif (
        gate in policy.conditional_gates
        and row.status not in policy.ready_conditional_statuses
    ):
        findings.append(
            Finding(
                row.line,
                "gate-status",
                f"conditional gate {gate} has invalid ready status {row.status}",
            )
        )

    if row.status == policy.ready_core_status:
        reference_types = {
            _reference_type(reference) for reference in row.references
        }
        for group in policy.required_reference_groups.get(gate, ()):
            if not reference_types.intersection(group):
                findings.append(
                    Finding(
                        row.line,
                        "gate-support",
                        f"gate {gate} lacks required {'/'.join(group)} support",
                    )
                )
    elif row.status == "not_applicable" and not _has_only_support_types(
        row.references, frozenset({"R", "E"})
    ):
        findings.append(
            Finding(
                row.line,
                "gate-support",
                f"not_applicable gate {gate} requires R/E support",
            )
        )
    return findings


def _gate_owner_findings(
    gates: _ClosureTableView,
    evaluated_gates: frozenset[str],
    decisions: _DecisionConcernIndex,
    policy: _CoveragePolicy,
) -> list[Finding]:
    findings: list[Finding] = []
    for concern, concern_gates in policy.gates_by_concern.items():
        owners = decisions.owners(concern)
        for gate in concern_gates:
            if gate not in evaluated_gates:
                continue
            row = gates.row(gate)
            if (
                row is None
                or len(row.raw) < 2
                or row.status != policy.ready_core_status
            ):
                for owner in owners:
                    findings.append(
                        Finding(
                            gates.line(gate),
                            "gate-owner",
                            f"gate {gate} must be owned by {owner}/{concern}",
                        )
                    )
                continue
            support = row.references
            if not owners:
                findings.append(
                    Finding(
                        row.line,
                        "gate-owner",
                        f"gate {gate} pass requires an owning decision for {concern}",
                    )
                )
            for owner in owners:
                if owner not in support:
                    findings.append(
                        Finding(
                            row.line,
                            "gate-owner",
                            f"gate {gate} must be owned by {owner}/{concern}",
                        )
                    )
    return findings


def _validate_gate_row_semantics(
    gates: _ClosureTableView,
    gate_names: Sequence[str],
    decisions: _DecisionConcernIndex,
    policy: _CoveragePolicy,
) -> list[Finding]:
    findings: list[Finding] = []
    for gate in gate_names:
        row = gates.row(gate)
        if row is not None and row.complete:
            findings.extend(_ready_gate_row_findings(row, gate, policy))
    findings.extend(
        _gate_owner_findings(gates, frozenset(gate_names), decisions, policy)
    )
    return findings


def _validate_existing_architecture_row_semantics(
    architecture: _ClosureTableView,
    concerns: Sequence[str],
    policy: _CoveragePolicy,
) -> list[Finding]:
    findings: list[Finding] = []
    for concern in concerns:
        row = architecture.row(concern)
        if row is None or not row.complete:
            continue
        if row.status not in policy.existing_architecture_statuses:
            findings.append(
                Finding(
                    row.line,
                    "architecture-closure",
                    f"Architecture Closure {concern} has invalid existing status "
                    f"{row.status}",
                )
            )
        if not _has_only_support_types(row.references, frozenset({"R", "E"})):
            findings.append(
                Finding(
                    row.line,
                    "architecture-closure",
                    f"existing Architecture Closure {concern} requires R/E support",
                )
            )
    return findings


def _validate_existing_gate_row_semantics(
    gates: _ClosureTableView,
    gate_names: Sequence[str],
    policy: _CoveragePolicy,
) -> list[Finding]:
    findings: list[Finding] = []
    for gate in gate_names:
        row = gates.row(gate)
        if row is None or not row.complete:
            continue
        if gate in policy.core_gates and row.status != policy.existing_core_status:
            findings.append(
                Finding(
                    row.line,
                    "gate-status",
                    f"core gate {gate} must use existing status "
                    f"{policy.existing_core_status}",
                )
            )
        elif (
            gate in policy.conditional_gates
            and row.status not in policy.existing_conditional_statuses
        ):
            findings.append(
                Finding(
                    row.line,
                    "gate-status",
                    f"conditional gate {gate} has invalid existing status {row.status}",
                )
            )
        if not _has_only_support_types(row.references, frozenset({"R", "E"})):
            findings.append(
                Finding(
                    row.line,
                    "gate-support",
                    f"existing gate {gate} requires R/E support",
                )
            )
    return findings


def validate_readiness(
    parsed: ParsedDesign,
    schema: DesignSchema,
    vocabulary: ContractVocabulary | None,
    *,
    template: bool = False,
) -> list[Finding]:
    del vocabulary
    disposition = parsed.frontmatter.get("disposition")
    if template or disposition not in {
        "READY_FOR_CONTRACT",
        "DESIGN_NOT_REQUIRED",
    }:
        return []

    coverage = _schema_object(schema, "coverage")
    policy = _CoveragePolicy.from_mapping(coverage)
    readiness_section = parsed.sections.get("Readiness Matrix")
    readiness_line = (
        readiness_section.line if readiness_section is not None else parsed.body_line
    )
    decision_index = _DecisionConcernIndex.build(
        _ordered_records(parsed, "D", "Decision Register")
    )

    findings: list[Finding] = []
    architecture = _ClosureTableView(parsed.tables.get("Architecture Closure"))
    if (
        architecture.table is None
        or architecture.physical_names() != list(policy.architecture_concerns)
    ):
        findings.append(
            Finding(
                readiness_line,
                "architecture-closure",
                "Architecture Closure rows must exactly match schema concern order",
            )
        )
    if disposition == "DESIGN_NOT_REQUIRED":
        findings.extend(
            _validate_existing_architecture_row_semantics(
                architecture, policy.architecture_concerns, policy
            )
        )
    else:
        findings.extend(
            _validate_architecture_row_semantics(
                architecture, policy.architecture_concerns, decision_index, policy
            )
        )

    gates = _ClosureTableView(parsed.tables.get("Gate Closure"))
    if gates.table is None or gates.physical_names() != list(policy.gate_order):
        findings.append(
            Finding(
                readiness_line,
                "gate-closure",
                "Gate Closure rows must exactly match schema gate order",
            )
        )
    if disposition == "DESIGN_NOT_REQUIRED":
        findings.extend(
            _validate_existing_gate_row_semantics(gates, policy.gate_order, policy)
        )
    else:
        findings.extend(
            _validate_gate_row_semantics(
                gates, policy.gate_order, decision_index, policy
            )
        )
    return findings


@dataclass(frozen=True)
class _BlockerPolicy:
    allowed_kinds: frozenset[str]
    additional_gates: frozenset[str]
    coverage: _CoveragePolicy
    raw_coverage: Mapping[str, object]

    @classmethod
    def from_schema(
        cls,
        schema: DesignSchema,
        disposition: str,
    ) -> _BlockerPolicy | None:
        blocker_schema = _schema_object(schema, "blocker")
        kinds_map = cast(
            Mapping[str, object], blocker_schema["disposition_kinds_map"]
        )
        raw_allowed_kinds = kinds_map.get(disposition)
        if not isinstance(raw_allowed_kinds, list) or not all(
            isinstance(kind, str) for kind in raw_allowed_kinds
        ):
            return None
        raw_coverage = _schema_object(schema, "coverage")
        return cls(
            allowed_kinds=frozenset(cast(list[str], raw_allowed_kinds)),
            additional_gates=frozenset(
                cast(list[str], blocker_schema["additional_gates"])
            ),
            coverage=_CoveragePolicy.from_mapping(raw_coverage),
            raw_coverage=raw_coverage,
        )

    @property
    def known_gates(self) -> frozenset[str]:
        return frozenset((*self.coverage.gate_order, *self.additional_gates))


@dataclass(frozen=True)
class _BlockerSet:
    records: tuple[Record, ...]
    identifiers: tuple[str, ...]
    gates: tuple[tuple[Record, str], ...]

    @classmethod
    def build(cls, blockers: Sequence[Record]) -> _BlockerSet:
        records = tuple(blockers)
        return cls(
            records=records,
            identifiers=tuple(blocker.identifier for blocker in records),
            gates=tuple(
                (blocker, _strip_code(blocker.fields.get("Gate", "")))
                for blocker in records
            ),
        )

    @property
    def failed_gate(self) -> str:
        return self.gates[0][1]


@dataclass(frozen=True)
class _FailedGate:
    index: int
    row: tuple[str, ...]
    line: int

    @property
    def name(self) -> str:
        return self.row[0] if self.row else ""

    @property
    def support(self) -> tuple[str, ...]:
        return tuple(_csv_tokens(self.row[2])) if len(self.row) >= 3 else ()


def _blocker_identity_and_kind_findings(
    parsed: ParsedDesign,
    blockers: _BlockerSet,
    *,
    disposition: str,
    allowed_kinds: frozenset[str],
) -> list[Finding]:
    candidate = parsed.records.get("CANDIDATE")
    result = _strip_code(candidate.fields.get("Result", "")) if candidate else ""
    wrapper, separator, raw_candidate_blockers = result.partition(" ")
    candidate_blockers = _csv_tokens(raw_candidate_blockers) if separator else []

    findings: list[Finding] = []
    if (
        wrapper != "blocked"
        or set(candidate_blockers) != set(blockers.identifiers)
        or len(candidate_blockers) != len(blockers.identifiers)
    ):
        findings.append(
            Finding(
                candidate.field_lines.get("Result", candidate.line)
                if candidate is not None
                else parsed.body_line,
                "blocker-identity",
                "Candidate Result must reference exact blocker set "
                f"{', '.join(blockers.identifiers)}",
            )
        )
    for blocker in blockers.records:
        blocker_kind = _strip_code(blocker.fields.get("Kind", ""))
        if blocker_kind not in allowed_kinds:
            findings.append(
                Finding(
                    blocker.field_lines.get("Kind", blocker.line),
                    "blocker-kind",
                    f"{disposition} blocker {blocker.identifier} has unsupported kind "
                    f"{blocker_kind}",
                )
            )
    return findings


def _unknown_blocker_gate_findings(
    blockers: _BlockerSet,
    policy: _BlockerPolicy,
) -> list[Finding]:
    return [
        Finding(
            blocker.field_lines.get("Gate", blocker.line),
            "blocker-gate",
            f"blocker {blocker.identifier} references unknown gate {gate}",
        )
        for blocker, gate in blockers.gates
        if gate not in policy.known_gates
    ]


def _missing_partial_matrix_findings(
    blockers: _BlockerSet,
    policy: _BlockerPolicy,
) -> list[Finding]:
    return [
        Finding(
            blocker.field_lines.get("Gate", blocker.line),
            "blocker-profile",
            f"blocker gate {gate} requires a partial readiness matrix",
        )
        for blocker, gate in blockers.gates
        if gate not in policy.additional_gates
    ]


def _partial_architecture_findings(
    parsed: ParsedDesign,
    gate_table: Table,
    decisions: _DecisionConcernIndex,
    policy: _BlockerPolicy,
) -> tuple[list[Finding], _ClosureTableView, list[str]]:
    architecture_table = parsed.tables.get("Architecture Closure")
    architecture = _ClosureTableView(architecture_table)
    findings: list[Finding] = []
    if architecture_table is None:
        names: list[str] = []
        findings.append(
            Finding(
                gate_table.row_lines[0] if gate_table.row_lines else parsed.body_line,
                "blocker-profile",
                "partial readiness matrix requires Architecture Closure",
            )
        )
    else:
        names = architecture.physical_names()
        expected_prefix = list(policy.coverage.architecture_concerns[: len(names)])
        if names != expected_prefix:
            findings.append(
                Finding(
                    architecture_table.row_lines[0]
                    if architecture_table.row_lines
                    else parsed.body_line,
                    "blocker-profile",
                    "partial Architecture Closure must be an exact concern prefix",
                )
            )
    findings.extend(
        _validate_architecture_row_semantics(
            architecture, names, decisions, policy.coverage
        )
    )
    return findings, architecture, names


def _find_failed_gates(
    table: Table,
    failure_statuses: frozenset[str],
) -> list[_FailedGate]:
    return [
        _FailedGate(index, row, table.row_lines[index])
        for index, row in enumerate(table.rows)
        if len(row) >= 2 and row[1] in failure_statuses
    ]


def _partial_gate_shape_findings(
    parsed: ParsedDesign,
    table: Table,
    gates: _ClosureTableView,
    failure: _FailedGate,
    blockers: _BlockerSet,
    policy: _BlockerPolicy,
) -> list[Finding]:
    findings: list[Finding] = []
    blocker_gate = blockers.failed_gate
    last_index = len(table.rows) - 1
    if failure.index != last_index:
        findings.append(
            Finding(
                failure.line,
                "blocker-profile",
                f"partial Gate Closure must stop at blocker gate {blocker_gate}",
            )
        )

    actual_names = gates.physical_names()
    gate_positions = {
        gate: index for index, gate in enumerate(policy.coverage.gate_order)
    }
    if blocker_gate in gate_positions:
        expected_names = list(
            policy.coverage.gate_order[: gate_positions[blocker_gate] + 1]
        )
        if actual_names != expected_names and failure.index == last_index:
            findings.append(
                Finding(
                    table.row_lines[0] if table.row_lines else parsed.body_line,
                    "blocker-profile",
                    f"partial Gate Closure must be the exact prefix through "
                    f"{blocker_gate}",
                )
            )
    elif blocker_gate in policy.additional_gates:
        findings.append(
            Finding(
                table.row_lines[0] if table.row_lines else parsed.body_line,
                "blocker-profile",
                f"blocker gate {blocker_gate} precedes readiness evaluation",
            )
        )

    if failure.name != blocker_gate:
        findings.append(
            Finding(
                failure.line,
                "blocker-profile",
                f"partial Gate Closure must fail at blocker gate {blocker_gate}",
            )
        )
    failure_blockers = {
        reference for reference in failure.support if reference.startswith("B-")
    }
    if failure_blockers != set(blockers.identifiers):
        findings.append(
            Finding(
                failure.line,
                "blocker-identity",
                "partial Gate Closure failure must reference exact blocker set "
                f"{', '.join(blockers.identifiers)}",
            )
        )
    return findings


def validate_blockers(
    parsed: ParsedDesign,
    schema: DesignSchema,
    vocabulary: ContractVocabulary | None,
    *,
    template: bool = False,
) -> list[Finding]:
    del vocabulary
    if template:
        return []

    disposition = parsed.frontmatter.get("disposition", "")
    policy = _BlockerPolicy.from_schema(schema, disposition)
    if policy is None:
        return []

    blocker_records = _ordered_records(parsed, "B", "Open Blockers")
    candidate = parsed.records.get("CANDIDATE")
    if not blocker_records:
        return [
            Finding(
                candidate.line if candidate is not None else parsed.body_line,
                "blocker-profile",
                f"{disposition} requires an exact blocker",
            )
        ]

    blockers = _BlockerSet.build(blocker_records)
    findings = _blocker_identity_and_kind_findings(
        parsed,
        blockers,
        disposition=disposition,
        allowed_kinds=policy.allowed_kinds,
    )
    findings.extend(_unknown_blocker_gate_findings(blockers, policy))

    gate_table = parsed.tables.get("Gate Closure")
    if gate_table is None:
        findings.extend(_missing_partial_matrix_findings(blockers, policy))
        return findings

    gates = _ClosureTableView(gate_table)
    if len({gate for _, gate in blockers.gates}) != 1:
        findings.append(
            Finding(
                gate_table.row_lines[-1] if gate_table.row_lines else parsed.body_line,
                "blocker-profile",
                "partial readiness matrix requires all blockers at its failed gate",
            )
        )

    decisions = _ordered_records(parsed, "D", "Decision Register")
    decision_index = _DecisionConcernIndex.build(decisions)
    assurance_records = _ordered_records(parsed, "A", "Assurance Register")
    architecture_findings, _, _ = _partial_architecture_findings(
        parsed, gate_table, decision_index, policy
    )
    findings.extend(architecture_findings)
    findings.extend(_validate_assurance_target_ownership(assurance_records, decisions))

    failures = _find_failed_gates(
        gate_table, policy.coverage.blocking_failure_statuses
    )
    if len(failures) != 1:
        findings.append(
            Finding(
                gate_table.row_lines[-1] if gate_table.row_lines else parsed.body_line,
                "blocker-profile",
                "partial Gate Closure requires exactly one failed or unresolved row",
            )
        )
        return findings

    failure = failures[0]
    evaluated_gate_names = [
        row[0] for row in gate_table.rows[: failure.index] if row
    ]
    findings.extend(
        _validate_gate_row_semantics(
            gates, evaluated_gate_names, decision_index, policy.coverage
        )
    )
    findings.extend(
        _validate_gate_assurance_semantics(
            gate_table,
            evaluated_gate_names,
            decisions,
            assurance_records,
            policy.raw_coverage,
            usage_rows=gate_table.rows[: failure.index + 1],
        )
    )
    findings.extend(
        _partial_gate_shape_findings(
            parsed, gate_table, gates, failure, blockers, policy
        )
    )
    return findings
