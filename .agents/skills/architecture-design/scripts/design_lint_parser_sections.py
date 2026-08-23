from __future__ import annotations

from typing import cast

from design_lint_model import Finding, Record

from design_lint_parser_blocks import (
    _parse_field_block,
    _parse_none_or_records,
    _parse_records,
    _parse_table,
    _subsections,
)
from design_lint_parser_common import (
    _Context,
    _SectionSlice,
    _heading_level,
    _level_headings,
    _outside_fence_nonempty,
    _schema_object,
)


def _parse_section(context: _Context, section: _SectionSlice) -> None:
    parsers = {
        "Basis": _parse_basis,
        "Candidate Analysis": _parse_candidate,
        "Decision Register": _parse_decisions,
        "Impact Register": _parse_impacts,
        "Assurance Register": _parse_assurance,
        "Stop Conditions": _parse_guards,
        "Contract Interface": _parse_contract,
        "Diagrams": _parse_diagrams,
        "Readiness Matrix": _parse_readiness,
        "Open Blockers": _parse_blockers,
    }
    parsers[section.name](context, section)


def _parse_basis(context: _Context, section: _SectionSlice) -> None:
    basis = _schema_object(context.schema, "basis")
    specifications = (
        ("Sources", cast(list[str], basis["source_header"]), "source"),
        (
            "Source Coverage",
            cast(list[str], basis["source_coverage_header"]),
            None,
        ),
        ("Evidence", cast(list[str], basis["evidence_header"]), "evidence"),
        (
            "Requirements",
            cast(list[str], basis["requirement_header"]),
            "requirement",
        ),
    )
    subsections = _subsections(
        context, section, tuple(item[0] for item in specifications)
    )
    for name, header, semantic in specifications:
        if name in subsections:
            heading, end = subsections[name]
            _parse_table(
                context, section.name, name, heading + 1, end, header, semantic
            )


def _parse_candidate(context: _Context, section: _SectionSlice) -> None:
    candidate = _schema_object(context.schema, "candidate")
    headings = _level_headings(context, section.heading_index + 1, section.end_index, 3)
    fields_end = headings[0] if headings else section.end_index
    fields, field_lines = _parse_field_block(
        context,
        section.heading_index + 1,
        fields_end,
        tuple(cast(list[str], candidate["fields"])),
        section.heading_index + 1,
    )
    context.add_record(
        section.name,
        Record(
            identifier="CANDIDATE",
            kind="candidate",
            title="Candidate Analysis",
            fields=fields,
            field_lines=field_lines,
            line=section.heading_index + 1,
        ),
    )

    expected_names = ("Forms", "Material-Obligation Delta", "Future Pressures")
    subsections = _subsections(context, section, expected_names)
    if "Forms" in subsections:
        heading, end = subsections["Forms"]
        _parse_table(
            context,
            section.name,
            "Forms",
            heading + 1,
            end,
            cast(list[str], candidate["forms_header"]),
            "form",
        )
    if "Material-Obligation Delta" in subsections:
        heading, end = subsections["Material-Obligation Delta"]
        forms = context.tables.get("Forms")
        form_ids = [row[0] for row in forms.rows] if forms is not None else []
        header = (
            cast(list[str], candidate["material_prefix"])
            + form_ids
            + cast(list[str], candidate["material_suffix"])
        )
        _parse_table(
            context,
            section.name,
            "Material-Obligation Delta",
            heading + 1,
            end,
            header,
            "material_obligation",
        )
    if "Future Pressures" in subsections:
        heading, end = subsections["Future Pressures"]
        none_dispositions = set(
            cast(list[str], candidate["future_pressure_none_dispositions"])
        )
        none_literal = cast(str, candidate["future_pressure_none_literal"])
        content = _outside_fence_nonempty(context, heading + 1, end)
        if (
            not context.template
            and context.disposition in none_dispositions
            and len(content) == 1
            and context.lines[content[0]] == none_literal
        ):
            context.consume(content[0])
        else:
            _parse_table(
                context,
                section.name,
                "Future Pressures",
                heading + 1,
                end,
                cast(list[str], candidate["future_pressure_header"]),
                "pressure",
            )


def _parse_decisions(context: _Context, section: _SectionSlice) -> None:
    _parse_records(
        context,
        section,
        "decision",
        3,
        tuple(cast(list[str], _schema_object(context.schema, "decision")["fields"])),
    )


def _parse_assurance(context: _Context, section: _SectionSlice) -> None:
    _parse_records(
        context,
        section,
        "assurance",
        3,
        tuple(cast(list[str], _schema_object(context.schema, "assurance")["fields"])),
    )


def _parse_impacts(context: _Context, section: _SectionSlice) -> None:
    impact = _schema_object(context.schema, "impact")
    _parse_none_or_records(
        context,
        section.name,
        section.heading_index + 1,
        section.end_index,
        "impact",
        3,
        tuple(cast(list[str], impact["fields"])),
        none_literal=cast(str, impact["none_literal"]),
        required=True,
    )


def _parse_guards(context: _Context, section: _SectionSlice) -> None:
    guard = _schema_object(context.schema, "guard")
    _parse_records(
        context,
        section,
        "guard",
        3,
        tuple(cast(list[str], guard["fields"])),
    )


def _parse_contract(context: _Context, section: _SectionSlice) -> None:
    contract = _schema_object(context.schema, "contract")
    headings = _level_headings(context, section.heading_index + 1, section.end_index, 3)
    fields_end = headings[0] if headings else section.end_index
    fields, field_lines = _parse_field_block(
        context,
        section.heading_index + 1,
        fields_end,
        tuple(cast(list[str], contract["fields"])),
        section.heading_index + 1,
    )
    context.add_record(
        section.name,
        Record(
            identifier="CONTRACT",
            kind="contract",
            title="Contract Interface",
            fields=fields,
            field_lines=field_lines,
            line=section.heading_index + 1,
        ),
    )


def _parse_diagrams(context: _Context, section: _SectionSlice) -> None:
    outside = _outside_fence_nonempty(
        context, section.heading_index + 1, section.end_index
    )
    none_lines = [
        index for index in outside if context.lines[index].startswith("None:")
    ]
    diagram_headings: list[int] = []
    for index in outside:
        if _heading_level(context.lines[index]) != 3:
            continue
        content = context.lines[index][4:].strip()
        identifier = content.split(" — ", 1)[0].strip()
        if context.schema.id_patterns["diagram"].fullmatch(identifier) is not None:
            diagram_headings.append(index)
    if none_lines:
        for index in none_lines:
            context.consume(index)
            if not context.lines[index][5:].strip():
                context.findings.append(
                    Finding(index + 1, "diagram", "diagram None form requires a reason")
                )
        if len(none_lines) != 1:
            context.findings.append(
                Finding(
                    none_lines[0] + 1,
                    "diagram",
                    "Diagrams requires exactly one None form",
                )
            )
        if diagram_headings:
            context.findings.append(
                Finding(
                    none_lines[0] + 1,
                    "diagram",
                    "diagram None form is exclusive with DG records",
                )
            )
    elif not diagram_headings:
        context.findings.append(
            Finding(
                section.heading_index + 1,
                "diagram",
                "Diagrams requires one or more DG records or exactly one None form",
            )
        )
    _parse_records(
        context,
        section,
        "diagram",
        3,
        tuple(cast(list[str], _schema_object(context.schema, "diagram")["fields"])),
        diagram=True,
    )


def _parse_readiness(context: _Context, section: _SectionSlice) -> None:
    coverage = _schema_object(context.schema, "coverage")
    specifications = (
        (
            "Architecture Closure",
            cast(list[str], coverage["architecture_header"]),
        ),
        ("Gate Closure", cast(list[str], coverage["gate_header"])),
    )
    subsections = _subsections(
        context, section, tuple(item[0] for item in specifications)
    )
    for name, header in specifications:
        if name in subsections:
            heading, end = subsections[name]
            _parse_table(context, section.name, name, heading + 1, end, header, None)


def _parse_blockers(context: _Context, section: _SectionSlice) -> None:
    blocker = _schema_object(context.schema, "blocker")
    _parse_none_or_records(
        context,
        section.name,
        section.heading_index + 1,
        section.end_index,
        "blocker",
        3,
        tuple(cast(list[str], blocker["fields"])),
    )
