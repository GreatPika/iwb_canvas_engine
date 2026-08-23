from __future__ import annotations

import re
from collections.abc import Callable, Iterator
from typing import cast

from design_lint_model import DesignSchema, Finding, Record, Table, TypedReference

from design_lint_parser_common import (
    _Context,
    _code_scalar,
    _csv_parts,
    _is_deferred_marker_value,
    _match_identifier_semantic,
    _match_reference,
    _schema_object,
)


_SEMANTIC_LABELS = {
    "source": "S",
    "evidence": "E",
    "requirement": "R",
    "form": "F",
    "material_obligation": "M",
    "pressure": "P",
    "decision": "D",
    "decision_concern": "D",
    "assurance": "A",
    "impact": "I",
    "guard": "H",
    "diagram": "DG",
    "blocker": "B",
    "contract": "CONTRACT",
}

_RecordValidator = Callable[[_Context, Record], None]
_TableValidator = Callable[[_Context, Table], None]


_ReferenceValidator = Callable[[TypedReference, str, str, int], Finding | None]


def _collect_references(
    value: str,
    *,
    schema: DesignSchema,
    line: int,
    validate: _ReferenceValidator,
) -> tuple[tuple[TypedReference, ...], list[Finding]]:
    tokens = _csv_parts(value)
    if tokens is None:
        return (), [Finding(line, "typed-value", "unparsed text in reference list")]

    references: list[TypedReference] = []
    findings: list[Finding] = []
    seen: set[str] = set()
    for token in tokens:
        matched = _match_reference(token, schema)
        if matched is None:
            findings.append(
                Finding(line, "typed-value", f"unparsed text in reference `{token}`")
            )
            continue
        reference, semantic = matched
        policy_finding = validate(reference, semantic, token, line)
        if policy_finding is not None:
            findings.append(policy_finding)
        if reference.raw in seen:
            findings.append(
                Finding(line, "typed-value", f"duplicate reference {reference.raw}")
            )
        else:
            seen.add(reference.raw)
        references.append(reference)
    return (() if findings else tuple(references)), findings


def parse_reference_list(
    value: str,
    *,
    allowed: frozenset[str],
    schema: DesignSchema,
) -> tuple[tuple[TypedReference, ...], list[Finding]]:
    def validate_kind(
        reference: TypedReference,
        _semantic: str,
        token: str,
        line: int,
    ) -> Finding | None:
        if reference.kind in allowed:
            return None
        kinds = ", ".join(sorted(allowed))
        return Finding(
            line,
            "typed-value",
            f"only {kinds} references are allowed; found {token}",
        )

    return _collect_references(
        value,
        schema=schema,
        line=0,
        validate=validate_kind,
    )


def parse_vocabulary_list(
    value: str,
    *,
    allowed: frozenset[str],
) -> tuple[tuple[str, ...], list[Finding]]:
    values: list[str] = []
    findings: list[Finding] = []
    seen: set[str] = set()
    tokens = _csv_parts(value)
    if tokens is None:
        return (), [Finding(0, "typed-value", "unparsed text in vocabulary list")]

    for token in tokens:
        match = re.fullmatch(r"`([^`\r\n]+)`", token)
        if match is None:
            findings.append(
                Finding(
                    0, "typed-value", f"unparsed text in vocabulary value `{token}`"
                )
            )
            continue
        item = match.group(1)
        if item not in allowed:
            findings.append(
                Finding(0, "typed-value", f"unknown vocabulary value `{item}`")
            )
        if item in seen:
            findings.append(
                Finding(0, "typed-value", f"duplicate vocabulary value {item}")
            )
        else:
            seen.add(item)
        values.append(item)
    return (() if findings else tuple(values)), findings


def _validate_typed_values(context: _Context) -> None:
    for record in context.records.values():
        if record.identifier == "CANDIDATE":
            _validate_candidate_record(context, record)
        elif record.identifier == "CONTRACT":
            _validate_contract_record(context, record)
        else:
            semantic = _match_identifier_semantic(record.identifier, context.schema)
            if semantic is not None:
                _validate_canonical_record(context, record, semantic)
    for table in context.tables.values():
        _validate_table_values(context, table)


def _validate_candidate_record(context: _Context, record: Record) -> None:
    candidate = _schema_object(context.schema, "candidate")
    _add_vocabulary(
        context,
        record.fields.get("Comparison", ""),
        frozenset(cast(list[str], candidate["comparison_values"])),
        record.field_lines.get("Comparison", record.line),
    )

    result_value = record.fields.get("Result", "")
    result = _code_scalar(result_value)
    if not _is_deferred_marker_value(context, result_value) and result != "not_required":
        wrapper, separator, payload = result.partition(" ")
        if wrapper == "selected" and separator:
            reference_match = _match_reference(payload, context.schema)
            if reference_match is not None and reference_match[1] == "form":
                context.references.append(reference_match[0])
            else:
                _add_candidate_result_finding(context, record)
        elif wrapper == "blocked" and separator:
            _add_references(
                context,
                payload,
                frozenset({"blocker"}),
                record.field_lines.get("Result", record.line),
            )
        else:
            _add_candidate_result_finding(context, record)

    _add_references(
        context,
        record.fields.get("Result basis", ""),
        None,
        record.field_lines.get("Result basis", record.line),
    )


def _add_candidate_result_finding(context: _Context, record: Record) -> None:
    context.findings.append(
        Finding(
            record.field_lines.get("Result", record.line),
            "typed-value",
            "unparsed candidate result",
        )
    )


def _validate_contract_record(context: _Context, record: Record) -> None:
    for field_name in ("Profile", "Obligations"):
        _validate_code_list_syntax(
            context,
            record.fields.get(field_name, ""),
            record.field_lines.get(field_name, record.line),
        )

    contract = _schema_object(context.schema, "contract")
    adr = record.fields.get("ADR Impact", "")
    if (
        not _is_deferred_marker_value(context, adr)
        and re.fullmatch(cast(str, contract["adr_pattern"]), adr) is None
    ):
        context.findings.append(
            Finding(
                record.field_lines.get("ADR Impact", record.line),
                "typed-value",
                "ADR action and target value is invalid",
            )
        )

    reference_fields = {
        "Sources": (frozenset({"source"}), False),
        "Requirements": (frozenset({"requirement"}), False),
        "Commitments": (frozenset({"decision"}), False),
        "Assurance": (frozenset({"assurance"}), False),
        "Impacts": (frozenset({"impact"}), True),
        "Stops": (frozenset({"guard"}), True),
    }
    for field_name, (allowed, allow_none) in reference_fields.items():
        _add_references(
            context,
            record.fields.get(field_name, ""),
            allowed,
            record.field_lines.get(field_name, record.line),
            allow_none=allow_none,
        )


def _validate_decision_record(context: _Context, record: Record) -> None:
    decision = _schema_object(context.schema, "decision")
    _add_vocabulary(
        context,
        record.fields.get("Concerns", ""),
        frozenset(cast(list[str], decision["concerns"])),
        record.field_lines.get("Concerns", record.line),
    )
    _add_references(
        context,
        record.fields.get("Basis", ""),
        frozenset({"requirement", "evidence"}),
        record.field_lines.get("Basis", record.line),
    )
    _add_references(
        context,
        record.fields.get("Form", ""),
        frozenset({"form"}),
        record.field_lines.get("Form", record.line),
    )
    _add_references(
        context,
        record.fields.get("Realizes", ""),
        frozenset({"material_obligation"}),
        record.field_lines.get("Realizes", record.line),
        allow_none=True,
    )
    _add_references(
        context,
        record.fields.get("Depends on", ""),
        frozenset({"decision"}),
        record.field_lines.get("Depends on", record.line),
        allow_none=True,
    )
    _add_vocabulary(
        context,
        record.fields.get("Contract targets", ""),
        frozenset(cast(list[str], decision["contract_targets"])),
        record.field_lines.get("Contract targets", record.line),
    )


def _validate_assurance_record(context: _Context, record: Record) -> None:
    _add_references(
        context,
        record.fields.get("Verifies", ""),
        frozenset({"requirement", "decision_concern", "impact"}),
        record.field_lines.get("Verifies", record.line),
        assurance=True,
    )


def _validate_impact_record(context: _Context, record: Record) -> None:
    impact = _schema_object(context.schema, "impact")
    _add_known_value(
        context,
        record.fields.get("Action", ""),
        frozenset(cast(list[str], impact["actions"])),
        record.field_lines.get("Action", record.line),
        "unknown durable impact action",
    )
    _add_references(
        context,
        record.fields.get("Required by", ""),
        frozenset({"requirement", "decision"}),
        record.field_lines.get("Required by", record.line),
    )


def _validate_guard_record(context: _Context, record: Record) -> None:
    _add_references(
        context,
        record.fields.get("Invalidates", ""),
        frozenset({"decision", "assurance", "impact"}),
        record.field_lines.get("Invalidates", record.line),
    )


def _validate_diagram_record(context: _Context, record: Record) -> None:
    diagram = _schema_object(context.schema, "diagram")
    _add_vocabulary(
        context,
        record.fields.get("Type", ""),
        frozenset(cast(list[str], diagram["types"])),
        record.field_lines.get("Type", record.line),
    )
    _add_references(
        context,
        record.fields.get("Supports", ""),
        None,
        record.field_lines.get("Supports", record.line),
    )


def _validate_blocker_record(context: _Context, record: Record) -> None:
    blocker = _schema_object(context.schema, "blocker")
    coverage = _schema_object(context.schema, "coverage")
    gates = {
        *cast(list[str], blocker["additional_gates"]),
        *cast(list[str], coverage["core_gates"]),
        *cast(list[str], coverage["conditional_gates"]),
    }
    _add_vocabulary(
        context,
        record.fields.get("Kind", ""),
        frozenset(cast(list[str], blocker["kinds"])),
        record.field_lines.get("Kind", record.line),
    )
    _add_vocabulary(
        context,
        record.fields.get("Gate", ""),
        frozenset(gates),
        record.field_lines.get("Gate", record.line),
    )
    _add_references(
        context,
        record.fields.get("Related", ""),
        None,
        record.field_lines.get("Related", record.line),
    )


_CANONICAL_RECORD_VALIDATORS: dict[str, _RecordValidator] = {
    "decision": _validate_decision_record,
    "assurance": _validate_assurance_record,
    "impact": _validate_impact_record,
    "guard": _validate_guard_record,
    "diagram": _validate_diagram_record,
    "blocker": _validate_blocker_record,
}


def _validate_canonical_record(
    context: _Context,
    record: Record,
    semantic: str,
) -> None:
    validator = _CANONICAL_RECORD_VALIDATORS.get(semantic)
    if validator is not None:
        validator(context, record)


def _table_rows(table: Table) -> Iterator[tuple[dict[str, str], int]]:
    for row, line in zip(table.rows, table.row_lines):
        yield dict(zip(table.header, row)), line


def _validate_sources_table(context: _Context, table: Table) -> None:
    basis = _schema_object(context.schema, "basis")
    source_kinds = frozenset(cast(list[str], basis["source_kinds"]))
    for values, line in _table_rows(table):
        kind = values.get("Kind", "")
        _add_known_value(context, kind, source_kinds, line, "unknown source kind")
        locator = values.get("Locator", "")
        if kind == "user" and locator == "user request":
            continue
        if (
            not _is_deferred_marker_value(context, locator)
            and _code_scalar(locator) == ""
        ):
            context.findings.append(
                Finding(
                    line,
                    "typed-value",
                    "source locator must be one complete code value",
                )
            )


def _validate_source_coverage_table(context: _Context, table: Table) -> None:
    for row, line in zip(table.rows, table.row_lines):
        _add_references(
            context,
            row[1],
            frozenset({"source"}),
            line,
            allow_none=True,
        )


def _validate_evidence_table(context: _Context, table: Table) -> None:
    locators = _schema_object(context.schema, "locators")
    allowed_locators = set(cast(list[str], locators["evidence_surface_exceptions"]))
    line_pattern = cast(str, locators["evidence_line_pattern"])
    range_pattern = cast(str, locators["evidence_range_pattern"])
    for values, line in _table_rows(table):
        _add_references(
            context,
            values.get("Source", ""),
            frozenset({"source"}),
            line,
        )
        locator_value = values.get("Locator", "")
        locator = _code_scalar(locator_value)
        if (
            not _is_deferred_marker_value(context, locator_value)
            and re.fullmatch(line_pattern, locator) is None
            and re.fullmatch(range_pattern, locator) is None
            and locator not in allowed_locators
        ):
            context.findings.append(
                Finding(line, "typed-value", "evidence locator is invalid")
            )


def _validate_requirements_table(context: _Context, table: Table) -> None:
    basis = _schema_object(context.schema, "basis")
    requirement_kinds = frozenset(cast(list[str], basis["requirement_kinds"]))
    for values, line in _table_rows(table):
        _add_known_value(
            context,
            values.get("Kind", ""),
            requirement_kinds,
            line,
            "unknown requirement kind",
        )
        _add_references(
            context,
            values.get("Basis", ""),
            frozenset({"source", "evidence"}),
            line,
        )


def _validate_forms_table(context: _Context, table: Table) -> None:
    for values, line in _table_rows(table):
        _add_references(
            context,
            values.get("Basis", ""),
            frozenset({"requirement", "evidence"}),
            line,
        )


def _validate_material_table(context: _Context, table: Table) -> None:
    candidate = _schema_object(context.schema, "candidate")
    yes_no = frozenset(cast(list[str], candidate["yes_no"]))
    prefix = cast(list[str], candidate["material_prefix"])
    suffix = cast(list[str], candidate["material_suffix"])
    form_columns = table.header[len(prefix) : len(table.header) - len(suffix)]

    for values, line in _table_rows(table):
        obligation = values.get("Material obligation", "")
        first = obligation.split(maxsplit=1)[0] if obligation else ""
        if not _is_deferred_marker_value(context, obligation):
            if context.schema.id_patterns["requirement"].fullmatch(obligation):
                _add_references(
                    context,
                    obligation,
                    frozenset({"requirement"}),
                    line,
                )
            elif context.schema.id_patterns["requirement"].fullmatch(first):
                context.findings.append(
                    Finding(
                        line,
                        "typed-value",
                        "unparsed text after common mandatory requirement reference",
                    )
                )

        for column in form_columns:
            _add_known_value(
                context,
                values.get(column, ""),
                yes_no,
                line,
                f"unknown membership value for {column}",
            )
        _add_references(
            context,
            values.get("Independent authority", ""),
            frozenset({"requirement", "evidence"}),
            line,
            allow_none=True,
        )


def _validate_future_pressures_table(context: _Context, table: Table) -> None:
    candidate = _schema_object(context.schema, "candidate")
    treatments = frozenset(cast(list[str], candidate["pressure_treatments"]))
    for values, line in _table_rows(table):
        _add_references(
            context,
            values.get("Basis", ""),
            frozenset({"source", "evidence", "requirement"}),
            line,
        )
        _add_known_value(
            context,
            values.get("Treatment", ""),
            treatments,
            line,
            "unknown pressure treatment",
        )
        _add_references(context, values.get("Closure refs", ""), None, line)


def _validate_status_table(
    context: _Context,
    table: Table,
    *,
    statuses: frozenset[str],
    unknown_message: str,
    allow_contract: bool = False,
) -> None:
    for row, line in zip(table.rows, table.row_lines):
        _add_known_value(context, row[1], statuses, line, unknown_message)
        _add_references(
            context,
            row[2],
            None,
            line,
            allow_contract=allow_contract,
        )


def _validate_architecture_closure_table(context: _Context, table: Table) -> None:
    coverage = _schema_object(context.schema, "coverage")
    statuses = frozenset(
        {
            *cast(list[str], coverage["ready_architecture_statuses"]),
            *cast(list[str], coverage["existing_architecture_statuses"]),
            *cast(list[str], coverage["blocking_failure_statuses"]),
        }
    )
    _validate_status_table(
        context,
        table,
        statuses=statuses,
        unknown_message="unknown architecture status",
    )


def _validate_gate_closure_table(context: _Context, table: Table) -> None:
    coverage = _schema_object(context.schema, "coverage")
    statuses = frozenset(
        {
            cast(str, coverage["ready_core_status"]),
            cast(str, coverage["existing_core_status"]),
            *cast(list[str], coverage["ready_conditional_statuses"]),
            *cast(list[str], coverage["existing_conditional_statuses"]),
            *cast(list[str], coverage["blocking_failure_statuses"]),
        }
    )
    _validate_status_table(
        context,
        table,
        statuses=statuses,
        unknown_message="unknown gate status",
        allow_contract=True,
    )


_TABLE_VALIDATORS: dict[str, _TableValidator] = {
    "Sources": _validate_sources_table,
    "Source Coverage": _validate_source_coverage_table,
    "Evidence": _validate_evidence_table,
    "Requirements": _validate_requirements_table,
    "Forms": _validate_forms_table,
    "Material-Obligation Delta": _validate_material_table,
    "Future Pressures": _validate_future_pressures_table,
    "Architecture Closure": _validate_architecture_closure_table,
    "Gate Closure": _validate_gate_closure_table,
}


def _validate_table_values(context: _Context, table: Table) -> None:
    validator = _TABLE_VALIDATORS.get(table.name)
    if validator is not None:
        validator(context, table)


def _add_known_value(
    context: _Context,
    value: str,
    allowed: frozenset[str],
    line: int,
    message: str,
) -> None:
    if not _is_deferred_marker_value(context, value) and value not in allowed:
        context.findings.append(Finding(line, "typed-value", message))


def _add_vocabulary(
    context: _Context,
    value: str,
    allowed: frozenset[str],
    line: int,
) -> None:
    if _is_deferred_marker_value(context, value):
        return
    _values, findings = parse_vocabulary_list(value, allowed=allowed)
    _append_relined(context, findings, line)


def _validate_code_list_syntax(context: _Context, value: str, line: int) -> None:
    if _is_deferred_marker_value(context, value):
        return
    tokens = _csv_parts(value)
    if tokens is None:
        context.findings.append(
            Finding(line, "typed-value", "unparsed text in vocabulary list")
        )
        return
    seen: set[str] = set()
    for token in tokens:
        match = re.fullmatch(r"`([^`\r\n]+)`", token)
        if match is None:
            context.findings.append(
                Finding(line, "typed-value", "unparsed text in vocabulary value")
            )
            return
        if match.group(1) in seen:
            context.findings.append(
                Finding(
                    line, "typed-value", f"duplicate vocabulary value {match.group(1)}"
                )
            )
            return
        seen.add(match.group(1))


def _reference_policy_finding(
    reference: TypedReference,
    semantic: str,
    token: str,
    line: int,
    *,
    allowed_semantics: frozenset[str] | None,
    assurance: bool,
    allow_contract: bool,
) -> Finding | None:
    if semantic == "contract" and not allow_contract:
        return Finding(
            line,
            "typed-value",
            "CONTRACT is not allowed in this reference field",
        )
    if assurance and semantic == "decision":
        return Finding(
            line,
            "typed-value",
            "decision assurance requires an exact concern",
        )
    if allowed_semantics is None or semantic in allowed_semantics:
        return None
    labels = ", ".join(sorted(_SEMANTIC_LABELS[item] for item in allowed_semantics))
    return Finding(
        line,
        "typed-value",
        f"only {labels} references are allowed; found {token}",
    )


def _add_references(
    context: _Context,
    value: str,
    allowed_semantics: frozenset[str] | None,
    line: int,
    *,
    allow_none: bool = False,
    assurance: bool = False,
    allow_contract: bool = False,
) -> None:
    if _is_deferred_marker_value(context, value):
        return
    if allow_none and value == "none":
        return

    references, findings = _collect_references(
        value,
        schema=context.schema,
        line=line,
        validate=lambda reference, semantic, token, finding_line: (
            _reference_policy_finding(
                reference,
                semantic,
                token,
                finding_line,
                allowed_semantics=allowed_semantics,
                assurance=assurance,
                allow_contract=allow_contract,
            )
        ),
    )
    if findings:
        context.findings.extend(findings)
    else:
        context.references.extend(references)


def _append_relined(context: _Context, findings: list[Finding], line: int) -> None:
    context.findings.extend(
        Finding(line, finding.code, finding.message) for finding in findings
    )
