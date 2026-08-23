from __future__ import annotations

from dataclasses import dataclass
from typing import Sequence, cast

from design_lint_model import Finding, Record, Table

from design_lint_parser_common import (
    _Context,
    _FIELD_PATTERN,
    _SEPARATOR_CELL_PATTERN,
    _SectionSlice,
    _code_scalar,
    _heading_level,
    _is_fenced,
    _level_headings,
    _match_identifier_semantic,
    _outside_fence_nonempty,
    _reference_kind,
    _schema_object,
    _split_table_row,
    _strip_code_scalar,
)


def _subsections(
    context: _Context,
    section: _SectionSlice,
    expected: tuple[str, ...],
) -> dict[str, tuple[int, int]]:
    headings = _level_headings(context, section.heading_index + 1, section.end_index, 3)
    actual: list[str] = []
    result: dict[str, tuple[int, int]] = {}
    for position, index in enumerate(headings):
        context.consume(index)
        name = context.lines[index][4:].strip()
        end = (
            headings[position + 1]
            if position + 1 < len(headings)
            else section.end_index
        )
        actual.append(name)
        if name not in expected:
            context.findings.append(
                Finding(index + 1, "sections", f"unknown subsection `{name}`")
            )
            continue
        if name in result:
            context.findings.append(
                Finding(index + 1, "sections", f"duplicate subsection `{name}`")
            )
            continue
        result[name] = (index, end)
    if tuple(actual) != expected:
        context.findings.append(
            Finding(
                section.heading_index + 1,
                "sections",
                f"{section.name} subsections must appear exactly in schema order",
            )
        )
    return result


@dataclass(frozen=True)
class _TableHeader:
    index: int
    cells: tuple[str, ...]
    valid: bool


@dataclass(frozen=True)
class _TableSeparator:
    index: int | None
    valid: bool


def _parse_table_header(
    context: _Context,
    name: str,
    index: int,
    expected_header: Sequence[str],
) -> _TableHeader | None:
    cells, error = _split_table_row(context.lines[index])
    if cells is None:
        context.findings.append(
            Finding(index + 1, "table", f"{name} table header is missing")
        )
        return None

    context.consume(index)
    if error is not None:
        context.findings.append(Finding(index + 1, "table", error))
    valid = tuple(cells) == tuple(expected_header)
    if not valid:
        context.findings.append(
            Finding(index + 1, "table", f"{name} table header is invalid")
        )
    return _TableHeader(index, tuple(cells), valid)


def _parse_table_separator(
    context: _Context,
    name: str,
    header: _TableHeader,
    following: Sequence[int],
) -> _TableSeparator:
    index = following[0] if following else None
    valid = False
    if index is not None:
        if index != header.index + 1:
            context.findings.append(
                Finding(index + 1, "table", f"{name} table rows must be contiguous")
            )
        cells, error = _split_table_row(context.lines[index])
        if cells is not None:
            context.consume(index)
            if error is not None:
                context.findings.append(Finding(index + 1, "table", error))
            valid = len(cells) == len(header.cells) and all(
                _SEPARATOR_CELL_PATTERN.fullmatch(cell) for cell in cells
            )
    if not valid:
        context.findings.append(
            Finding(
                header.index + 1,
                "table",
                f"{name} table separator is missing or invalid",
            )
        )
    return _TableSeparator(index, valid)


def _parse_table_rows(
    context: _Context,
    name: str,
    candidates: Sequence[int],
    *,
    expected_columns: int,
    previous_index: int,
    materialize: bool,
) -> tuple[list[tuple[str, ...]], list[int]]:
    rows: list[tuple[str, ...]] = []
    row_lines: list[int] = []
    gap_seen = False
    late_row_reported = False
    previous = previous_index
    for index in candidates:
        if index != previous + 1:
            gap_seen = True
        cells, error = _split_table_row(context.lines[index])
        if cells is None:
            gap_seen = True
            previous = index
            continue

        context.consume(index)
        if gap_seen and not late_row_reported:
            context.findings.append(
                Finding(index + 1, "table", f"{name} table rows must be contiguous")
            )
            late_row_reported = True

        row_valid = error is None
        if error is not None:
            context.findings.append(Finding(index + 1, "table", error))
        if len(cells) != expected_columns:
            row_valid = False
            context.findings.append(
                Finding(index + 1, "table", f"{name} row has the wrong column count")
            )
        elif any(not cell for cell in cells):
            row_valid = False
            context.findings.append(
                Finding(index + 1, "table", f"{name} row has a blank semantic cell")
            )
        if row_valid and materialize:
            rows.append(tuple(cells))
            row_lines.append(index + 1)
        previous = index
    return rows, row_lines


def _parse_table(
    context: _Context,
    section: str,
    name: str,
    start: int,
    end: int,
    expected_header: Sequence[str],
    record_semantic: str | None,
) -> None:
    indices = _outside_fence_nonempty(context, start, end)
    if not indices:
        context.findings.append(Finding(start, "table", f"{name} requires a table"))
        return

    header = _parse_table_header(context, name, indices[0], expected_header)
    if header is None:
        return

    following = [index for index in indices if index > header.index]
    separator = _parse_table_separator(context, name, header, following)
    row_candidates = following[1:] if separator.index is not None else []
    previous_index = separator.index if separator.valid else header.index
    assert previous_index is not None
    rows, row_lines = _parse_table_rows(
        context,
        name,
        row_candidates,
        expected_columns=len(expected_header),
        previous_index=previous_index,
        materialize=header.valid and separator.valid,
    )
    if not rows:
        context.findings.append(
            Finding(header.index + 1, "table", f"{name} requires at least one data row")
        )

    table = Table(name, header.cells, tuple(rows), tuple(row_lines))
    context.add_table(section, table, header.index + 1)
    if record_semantic is not None:
        _table_records(context, section, table, record_semantic)


def _table_records(
    context: _Context,
    section: str,
    table: Table,
    semantic: str,
) -> None:
    for row, line in zip(table.rows, table.row_lines):
        if len(row) != len(table.header):
            context.findings.append(
                Finding(line, "table", f"{table.name} row cannot be materialized")
            )
            continue
        identifier = _strip_code_scalar(row[0])
        pattern = context.schema.id_patterns[semantic]
        if pattern.fullmatch(identifier) is None:
            context.findings.append(
                Finding(line, "id", f"invalid record identifier `{identifier}`")
            )
            continue
        fields = dict(zip(table.header[1:], row[1:]))
        context.add_record(
            section,
            Record(
                identifier=identifier,
                kind=_reference_kind(identifier),
                title=row[1] if len(row) > 1 else identifier,
                fields=fields,
                field_lines={name: line for name in fields},
                line=line,
            ),
        )


def _parse_none_or_records(
    context: _Context,
    section: str,
    start: int,
    end: int,
    semantic: str,
    level: int,
    expected_fields: tuple[str, ...],
    *,
    none_literal: str = "None",
    required: bool = False,
) -> None:
    outside = _outside_fence_nonempty(context, start, end)
    if required and not outside:
        context.findings.append(
            Finding(start, "records", f"{section} requires {none_literal} or records")
        )
    none_lines = [
        index for index in outside if context.lines[index].strip() == none_literal
    ]
    for index in none_lines:
        context.consume(index)
    if len(none_lines) > 1:
        context.findings.append(
            Finding(
                none_lines[1] + 1,
                "records",
                f"{none_literal} form must appear exactly once",
            )
        )
    headings = [
        index for index in outside if _heading_level(context.lines[index]) is not None
    ]
    if none_lines and headings:
        context.findings.append(
            Finding(
                none_lines[0] + 1,
                "records",
                f"{none_literal} is exclusive with {semantic} records",
            )
        )
    if none_lines and len(outside) != len(none_lines) + len(headings):
        context.findings.append(
            Finding(
                none_lines[0] + 1,
                "records",
                f"{none_literal} form must be the only content",
            )
        )
    synthetic = _SectionSlice(section, start - 1, end)
    _parse_records(
        context,
        synthetic,
        semantic,
        level,
        expected_fields,
        custom_start=start,
    )


def _parse_records(
    context: _Context,
    section: _SectionSlice,
    semantic: str,
    level: int,
    expected_fields: tuple[str, ...],
    *,
    diagram: bool = False,
    custom_start: int | None = None,
) -> None:
    start = custom_start if custom_start is not None else section.heading_index + 1
    headings = [
        index
        for index in range(start, section.end_index)
        if not _is_fenced(context, index)
        and _heading_level(context.lines[index]) is not None
    ]
    for position, index in enumerate(headings):
        context.consume(index)
        end = (
            headings[position + 1]
            if position + 1 < len(headings)
            else section.end_index
        )
        heading_level = _heading_level(context.lines[index])
        content = (
            context.lines[index][heading_level + 1 :].strip() if heading_level else ""
        )
        parts = content.split(" — ", 1)
        if heading_level != level or len(parts) != 2 or not parts[1].strip():
            context.findings.append(
                Finding(
                    index + 1, "records", f"unknown heading `{context.lines[index]}`"
                )
            )
            continue
        identifier, title = parts[0].strip(), parts[1].strip()
        matched_semantic = _match_identifier_semantic(identifier, context.schema)
        if matched_semantic != semantic:
            context.findings.append(
                Finding(
                    index + 1,
                    "records",
                    f"invalid {semantic} record heading `{identifier}`",
                )
            )
            continue
        fields, field_lines = _parse_field_block(
            context,
            index + 1,
            end,
            expected_fields,
            index + 1,
        )
        record = Record(
            identifier=identifier,
            kind=_reference_kind(identifier),
            title=title,
            fields=fields,
            field_lines=field_lines,
            line=index + 1,
        )
        context.add_record(section.name, record)
        if diagram:
            _parse_diagram_fences(context, record, index + 1, end)


def _parse_field_block(
    context: _Context,
    start: int,
    end: int,
    expected_fields: tuple[str, ...],
    owner_line: int,
) -> tuple[dict[str, str], dict[str, int]]:
    fields: dict[str, str] = {}
    field_lines: dict[str, int] = {}
    order: list[str] = []
    for index in range(start, end):
        if _is_fenced(context, index) or not context.lines[index].strip():
            continue
        match = _FIELD_PATTERN.fullmatch(context.lines[index])
        if match is None:
            continue
        context.consume(index)
        name, value = match.groups()
        name = name.strip()
        order.append(name)
        if name not in expected_fields:
            context.findings.append(
                Finding(index + 1, "fields", f"unknown field `{name}`")
            )
            continue
        if name in fields:
            context.findings.append(
                Finding(index + 1, "fields", f"duplicate field `{name}`")
            )
            continue
        fields[name] = value.strip()
        field_lines[name] = index + 1
    if tuple(order) != expected_fields:
        context.findings.append(
            Finding(
                owner_line,
                "fields",
                "record fields must appear exactly once in schema order",
            )
        )
    return fields, field_lines


def _parse_diagram_fences(
    context: _Context,
    record: Record,
    start: int,
    end: int,
) -> None:
    fences = [
        fence for fence in context.fences.values() if start <= fence.open_index < end
    ]
    if len(fences) != 1:
        context.findings.append(
            Finding(
                record.line,
                "diagram",
                "each DG record requires exactly one fenced diagram",
            )
        )
    diagram = _schema_object(context.schema, "diagram")
    diagram_type = _code_scalar(record.fields.get("Type", ""))
    languages = cast(dict[str, str], diagram["type_language_map"])
    expected_language = languages.get(diagram_type)
    for fence in fences:
        context.consume(fence.open_index)
        close = (
            fence.close_index if fence.close_index is not None else len(context.lines)
        )
        body = []
        for index in range(fence.open_index + 1, close):
            context.consume(index)
            if context.lines[index].strip():
                body.append(context.lines[index])
        if fence.close_index is not None:
            context.consume(fence.close_index)
        if not body:
            context.findings.append(
                Finding(
                    fence.open_index + 1,
                    "diagram",
                    "DG requires a non-empty fenced diagram",
                )
            )
        if expected_language is not None and fence.language != expected_language:
            context.findings.append(
                Finding(
                    fence.open_index + 1,
                    "diagram",
                    f"DG fence language must be `{expected_language}`",
                )
            )
