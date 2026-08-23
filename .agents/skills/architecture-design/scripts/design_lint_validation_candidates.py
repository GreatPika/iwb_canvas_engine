from __future__ import annotations

from collections import Counter
from dataclasses import dataclass
from typing import Iterable

from design_lint_model import (
    ContractVocabulary,
    DesignSchema,
    Finding,
    ParsedDesign,
    Record,
    Table,
)

from design_lint_validation_common import (
    _code_tokens,
    _csv_tokens,
    _duplicates,
    _is_meaningful,
    _normalize_semantic,
    _ordered_records,
    _reference_type,
    _rows_by_key,
    _selected_form,
    _strip_code,
    _table_row_line,
)


@dataclass(frozen=True)
class _MaterialRow:
    identifier: str
    obligation: str
    memberships: tuple[str, ...]
    authority: tuple[str, ...]
    line: int


_COMPARISON_CARDINALITY = {
    "two_or_three": (
        frozenset({2, 3}),
        "two_or_three comparison requires two or three forms",
    ),
    "single_viable": (
        frozenset({1}),
        "single_viable comparison requires exactly one form",
    ),
}


def _meaningful_field_findings(
    records: Iterable[Record],
    fields: tuple[str, ...],
    schema: DesignSchema,
) -> list[Finding]:
    findings: list[Finding] = []
    for record in records:
        for field_name in fields:
            if _is_meaningful(record.fields.get(field_name, ""), schema):
                continue
            findings.append(
                Finding(
                    record.field_lines.get(field_name, record.line),
                    "meaningful-field",
                    f"{record.identifier}.{field_name} must be meaningful",
                )
            )
    return findings


def _candidate_shape_findings(
    candidate: Record,
    *,
    ready: bool,
    form_ids: list[str],
    comparison: str,
    selected: str | None,
) -> list[Finding]:
    if not ready:
        return []

    findings: list[Finding] = []
    if not 1 <= len(form_ids) <= 3:
        findings.append(
            Finding(
                candidate.line,
                "candidate-cardinality",
                "ready comparison requires one to three forms",
            )
        )

    cardinality_rule = _COMPARISON_CARDINALITY.get(comparison)
    if cardinality_rule is not None:
        allowed_counts, message = cardinality_rule
        if len(form_ids) not in allowed_counts:
            findings.append(
                Finding(
                    candidate.field_lines.get("Comparison", candidate.line),
                    "candidate-cardinality",
                    message,
                )
            )

    if selected is None or selected not in form_ids:
        findings.append(
            Finding(
                candidate.field_lines.get("Result", candidate.line),
                "candidate-result",
                "Candidate Result must select exactly one defined form",
            )
        )
    return findings


def _material_rows(matrix: Table) -> list[_MaterialRow]:
    rows: list[_MaterialRow] = []
    for row, line in zip(matrix.rows, matrix.row_lines):
        if not row or len(row) != len(matrix.header):
            continue
        authority = _csv_tokens(row[-1])
        rows.append(
            _MaterialRow(
                identifier=_strip_code(row[0]),
                obligation=_strip_code(row[1]),
                memberships=tuple(row[2:-1]),
                authority=() if authority == ["none"] else tuple(authority),
                line=line,
            )
        )
    return rows


def _realization_counts(decisions: list[Record], selected: str | None) -> Counter[str]:
    return Counter(
        material
        for decision in decisions
        if decision.fields.get("Form") == selected
        for material in _csv_tokens(decision.fields.get("Realizes", ""))
        if material != "none"
    )


@dataclass(frozen=True)
class _MaterialFacts:
    selected_has: bool
    selected_differs_from_another_form: bool
    common: bool
    realized: int
    duplicate_requirement: str | None

    @classmethod
    def derive(
        cls,
        row: _MaterialRow,
        *,
        selected_index: int | None,
        realization_counts: Counter[str],
        requirement_statements: dict[str, str],
    ) -> _MaterialFacts:
        selected_has = (
            selected_index is not None
            and selected_index < len(row.memberships)
            and row.memberships[selected_index] == "yes"
        )
        selected_differs = selected_has and any(
            value == "no"
            for index, value in enumerate(row.memberships)
            if index != selected_index
        )
        common = bool(row.memberships) and all(
            value == "yes" for value in row.memberships
        )
        return cls(
            selected_has=selected_has,
            selected_differs_from_another_form=selected_differs,
            common=common,
            realized=realization_counts.get(row.identifier, 0),
            duplicate_requirement=requirement_statements.get(
                _normalize_semantic(row.obligation)
            ),
        )


def _material_membership_findings(row: _MaterialRow) -> list[Finding]:
    if "yes" in row.memberships:
        return []
    return [
        Finding(
            row.line,
            "candidate-membership",
            f"material obligation {row.identifier} must belong to at least one form",
        )
    ]


def _material_authority_findings(
    row: _MaterialRow,
    facts: _MaterialFacts,
    *,
    selected: str | None,
    ready: bool,
) -> list[Finding]:
    findings: list[Finding] = []
    if facts.selected_differs_from_another_form and not row.authority:
        findings.append(
            Finding(
                row.line,
                "candidate-authority",
                f"selected-only material obligation {row.identifier} requires "
                "independent R/E authority",
            )
        )
    if ready and not facts.selected_has and row.authority:
        findings.append(
            Finding(
                row.line,
                "candidate-authority",
                f"selected form {selected} omits independently authorized "
                f"obligation {row.identifier}",
            )
        )
    return findings


def _material_realization_findings(
    row: _MaterialRow,
    facts: _MaterialFacts,
    *,
    ready: bool,
    decisions_available: bool,
) -> list[Finding]:
    if not ready or not decisions_available:
        return []
    findings: list[Finding] = []
    if facts.selected_has and facts.realized != 1:
        findings.append(
            Finding(
                row.line,
                "candidate-realization",
                f"selected material obligation {row.identifier} must be realized exactly",
            )
        )
    if not facts.selected_has and facts.realized:
        findings.append(
            Finding(
                row.line,
                "candidate-realization",
                f"unselected material obligation {row.identifier} must not be realized",
            )
        )
    return findings


def _material_owner_findings(
    row: _MaterialRow,
    facts: _MaterialFacts,
    schema: DesignSchema,
) -> list[Finding]:
    if facts.common:
        if schema.id_patterns["requirement"].fullmatch(row.obligation) is None:
            return [
                Finding(
                    row.line,
                    "candidate-owner",
                    f"common mandatory material obligation {row.identifier} must use "
                    "an exact R reference",
                )
            ]
        return []
    if facts.duplicate_requirement is not None:
        return [
            Finding(
                row.line,
                "candidate-owner",
                f"material obligation {row.identifier} duplicates canonical "
                f"requirement {facts.duplicate_requirement}",
            )
        ]
    return []


def _validate_material_row(
    row: _MaterialRow,
    *,
    selected: str | None,
    selected_index: int | None,
    ready: bool,
    decisions_available: bool,
    realization_counts: Counter[str],
    requirement_statements: dict[str, str],
    schema: DesignSchema,
) -> list[Finding]:
    facts = _MaterialFacts.derive(
        row,
        selected_index=selected_index,
        realization_counts=realization_counts,
        requirement_statements=requirement_statements,
    )
    findings = _material_membership_findings(row)
    findings.extend(
        _material_authority_findings(row, facts, selected=selected, ready=ready)
    )
    findings.extend(
        _material_realization_findings(
            row,
            facts,
            ready=ready,
            decisions_available=decisions_available,
        )
    )
    findings.extend(_material_owner_findings(row, facts, schema))
    return findings


def _validate_material_matrix(
    parsed: ParsedDesign,
    schema: DesignSchema,
    matrix: Table,
    *,
    candidate_line: int,
    form_ids: list[str],
    selected: str | None,
    ready: bool,
    decisions: list[Record],
    decisions_available: bool,
) -> tuple[list[Finding], list[str]]:
    findings: list[Finding] = []
    observed_form_columns = list(matrix.header[2:-1])
    if observed_form_columns != form_ids:
        findings.append(
            Finding(
                candidate_line,
                "candidate-membership",
                "Material-Obligation Delta form columns must exactly match "
                "compared forms",
            )
        )

    selected_index = (
        observed_form_columns.index(selected) if selected in observed_form_columns else None
    )
    requirement_statements = {
        _normalize_semantic(record.fields.get("Statement", "")): record.identifier
        for record in _ordered_records(parsed, "R", "Basis")
    }
    realization_counts = _realization_counts(decisions, selected)
    independent_refs: list[str] = []

    for row in _material_rows(matrix):
        for reference in row.authority:
            if reference not in independent_refs:
                independent_refs.append(reference)
        findings.extend(
            _validate_material_row(
                row,
                selected=selected,
                selected_index=selected_index,
                ready=ready,
                decisions_available=decisions_available,
                realization_counts=realization_counts,
                requirement_statements=requirement_statements,
                schema=schema,
            )
        )
    return findings, independent_refs


def _solution_projection_findings(
    parsed: ParsedDesign,
    *,
    ready: bool,
    form_ids: list[str],
    materials: list[Record],
    independent_refs: list[str],
) -> list[Finding]:
    gate_table = parsed.tables.get("Gate Closure")
    solution_row = _rows_by_key(gate_table).get("Solution Proportionality")
    if not ready or solution_row is None or len(solution_row) < 3:
        return []

    line = _table_row_line(gate_table, "Solution Proportionality")
    actual = _csv_tokens(solution_row[2])
    findings = [
        Finding(
            line,
            "candidate-projection",
            f"Solution Proportionality contains duplicate reference {duplicate}",
        )
        for duplicate in _duplicates(actual)
    ]
    expected = [
        *form_ids,
        *[record.identifier for record in materials],
        *independent_refs,
    ]
    if actual != expected:
        findings.append(
            Finding(
                line,
                "candidate-projection",
                "Solution Proportionality must exactly project F/M and independent R/E",
            )
        )
    return findings


def validate_candidates(
    parsed: ParsedDesign,
    schema: DesignSchema,
    vocabulary: ContractVocabulary | None,
    *,
    template: bool = False,
    checkpoint: bool = False,
) -> list[Finding]:
    del vocabulary
    if template:
        return []

    candidate = parsed.records.get("CANDIDATE")
    if candidate is None:
        return []

    candidate_section = parsed.sections.get("Candidate Analysis")
    candidate_line = (
        candidate_section.line if candidate_section is not None else candidate.line
    )
    forms = _ordered_records(parsed, "F", "Candidate Analysis")
    materials = _ordered_records(parsed, "M", "Candidate Analysis")
    pressures = _ordered_records(parsed, "P", "Candidate Analysis")
    form_ids = [record.identifier for record in forms]
    comparison = _strip_code(candidate.fields.get("Comparison", ""))
    selected = _selected_form(parsed)
    ready = parsed.frontmatter.get("disposition") == "READY_FOR_CONTRACT"

    findings = _candidate_shape_findings(
        candidate,
        ready=ready,
        form_ids=form_ids,
        comparison=comparison,
        selected=selected,
    )

    decisions = _ordered_records(parsed, "D", "Decision Register")
    decisions_available = not checkpoint or "Decision Register" in parsed.sections
    form_owners = [
        record
        for record in decisions
        if "form" in _code_tokens(record.fields.get("Concerns", ""))
        and record.fields.get("Form") == selected
    ]
    if ready and decisions_available and len(form_owners) != 1:
        findings.append(
            Finding(
                candidate_line,
                "candidate-owner",
                "ready design requires exactly one selected form-owning decision",
            )
        )

    findings.extend(
        _meaningful_field_findings(
            forms,
            ("Form", "Hard constraints", "Main trade-off", "Basis"),
            schema,
        )
    )
    findings.extend(
        _meaningful_field_findings(materials, ("Material obligation",), schema)
    )
    findings.extend(
        _meaningful_field_findings(
            pressures,
            (
                "Pressure",
                "Basis",
                "Treatment",
                "Closure refs",
                "Accepted cost or risk",
            ),
            schema,
        )
    )

    independent_refs: list[str] = []
    matrix = parsed.tables.get("Material-Obligation Delta")
    if matrix is not None:
        matrix_findings, independent_refs = _validate_material_matrix(
            parsed,
            schema,
            matrix,
            candidate_line=candidate_line,
            form_ids=form_ids,
            selected=selected,
            ready=ready,
            decisions=decisions,
            decisions_available=decisions_available,
        )
        findings.extend(matrix_findings)

    findings.extend(
        _solution_projection_findings(
            parsed,
            ready=ready,
            form_ids=form_ids,
            materials=materials,
            independent_refs=independent_refs,
        )
    )
    return findings


def _validate_checkpoint_pressure_references(parsed: ParsedDesign) -> list[Finding]:
    findings: list[Finding] = []
    for record in _ordered_records(parsed, "P", "Candidate Analysis"):
        for reference in _csv_tokens(record.fields.get("Closure refs", "")):
            kind = _reference_type(reference.partition("/")[0])
            if kind not in {"D", "A", "I", "B"}:
                findings.append(
                    Finding(
                        record.field_lines.get("Closure refs", record.line),
                        "typed-edge",
                        "only A, B, D, I references are allowed; found " + reference,
                    )
                )
    return findings
