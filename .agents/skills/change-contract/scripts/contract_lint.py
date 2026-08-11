#!/usr/bin/env python3
"""Deterministic structural lint for normalized Change Contract artifacts."""
from __future__ import annotations

import argparse
import json
import re
import sys
from collections import Counter, defaultdict
from dataclasses import dataclass
from pathlib import Path
from typing import Any, Iterable


@dataclass(frozen=True)
class Finding:
    message: str


@dataclass(frozen=True)
class ContractVocabulary:
    profiles: frozenset[str]
    obligations: frozenset[str]
    no_obligation: str


@dataclass(frozen=True)
class ContractSchema:
    version: int
    vocabulary_path: str
    artifact_headings: dict[str, str]
    contract_sections: tuple[str, ...]
    blocker_sections: tuple[str, ...]
    source_categories: tuple[str, ...]
    classification_fields: tuple[str, ...]
    boundary_fields: tuple[str, ...]
    unit_fields: tuple[str, ...]
    admission_fields: tuple[str, ...]
    source_none_literal: str
    source_user_request_literal: str
    source_repository_relative_pattern: str
    source_absolute_path_pattern: str
    form_none_literal: str
    table_columns: dict[str, tuple[str, ...]]
    semantic_key_pattern: str
    evidence_classes: frozenset[str]
    durable_impacts: frozenset[str]
    unit_heading_pattern: str
    admission_heading_pattern: str
    dependency_pattern: str
    required_gate_checks: tuple[str, ...]
    required_gate_checks_by_obligation: dict[str, tuple[str, ...]]
    template_marker_pattern: str
    template_marker_recognizer_pattern: str
    template_markers: tuple[str, ...]
    legacy_placeholder_tokens: tuple[str, ...]


SCHEMA_KEYS = {
    "version",
    "vocabulary",
    "artifact_headings",
    "contract_sections",
    "blocker_sections",
    "source_categories",
    "classification_fields",
    "boundary_fields",
    "unit_fields",
    "admission_fields",
    "source_none_literal",
    "source_user_request_literal",
    "source_repository_relative_pattern",
    "source_absolute_path_pattern",
    "form_none_literal",
    "table_columns",
    "semantic_key_pattern",
    "evidence_classes",
    "durable_impacts",
    "unit_heading_pattern",
    "admission_heading_pattern",
    "dependency_pattern",
    "required_gate_checks",
    "required_gate_checks_by_obligation",
    "template_marker_pattern",
    "template_marker_recognizer_pattern",
    "template_markers",
    "legacy_placeholder_tokens",
}

TABLE_NAMES = {
    "Source Inputs",
    "Blocking Decisions",
    "Decision Trace",
    "Acceptance Outcomes",
    "Verification Matrix",
    "Verification Gate",
}


def _unique_strings(value: Any, name: str) -> tuple[str, ...]:
    if (
        not isinstance(value, list)
        or not value
        or not all(isinstance(item, str) and item for item in value)
        or len(value) != len(set(value))
    ):
        raise ValueError(f"{name} must be a non-empty array of unique strings")
    return tuple(value)


def load_contract_vocabulary(path: Path) -> ContractVocabulary:
    data = json.loads(path.read_text())
    if not isinstance(data, dict) or set(data) != {
        "profiles",
        "obligations",
        "no_obligation",
    }:
        raise ValueError("contract vocabulary has unexpected keys")
    profiles = _unique_strings(data["profiles"], "contract profiles")
    obligations = _unique_strings(data["obligations"], "contract obligations")
    no_obligation = data["no_obligation"]
    if not isinstance(no_obligation, str) or not no_obligation:
        raise ValueError("no_obligation must be a non-empty string")
    if no_obligation in obligations:
        raise ValueError("no_obligation must not be a material obligation")
    return ContractVocabulary(
        profiles=frozenset(profiles),
        obligations=frozenset(obligations),
        no_obligation=no_obligation,
    )


def load_contract_schema(path: Path) -> ContractSchema:
    data = json.loads(path.read_text())
    if not isinstance(data, dict) or set(data) != SCHEMA_KEYS:
        raise ValueError("contract artifact schema has unexpected keys")
    if data["version"] != 2:
        raise ValueError("contract artifact schema version must be 2")
    vocabulary_path = data["vocabulary"]
    if not isinstance(vocabulary_path, str) or vocabulary_path != "contract-vocabulary.json":
        raise ValueError("contract artifact schema has an unknown vocabulary route")

    headings = data["artifact_headings"]
    if (
        not isinstance(headings, dict)
        or set(headings) != {"contract", "blocker"}
        or not all(isinstance(value, str) and value for value in headings.values())
        or len(set(headings.values())) != 2
    ):
        raise ValueError("artifact_headings must define unique contract and blocker headings")

    tables = data["table_columns"]
    if not isinstance(tables, dict) or set(tables) != TABLE_NAMES:
        raise ValueError("table_columns must define every normalized table")
    table_columns = {
        name: _unique_strings(columns, f"table_columns.{name}")
        for name, columns in tables.items()
    }

    obligation_checks = data["required_gate_checks_by_obligation"]
    if not isinstance(obligation_checks, dict):
        raise ValueError("required_gate_checks_by_obligation must be an object")
    vocabulary = load_contract_vocabulary(path.parent / vocabulary_path)
    if not set(obligation_checks).issubset(vocabulary.obligations):
        raise ValueError("required gate checks reference an unknown obligation")
    normalized_obligation_checks = {
        name: _unique_strings(checks, f"required_gate_checks_by_obligation.{name}")
        for name, checks in obligation_checks.items()
    }

    regex_fields = (
        "semantic_key_pattern",
        "source_repository_relative_pattern",
        "source_absolute_path_pattern",
        "unit_heading_pattern",
        "admission_heading_pattern",
        "dependency_pattern",
        "template_marker_pattern",
        "template_marker_recognizer_pattern",
    )
    for field in regex_fields:
        if not isinstance(data[field], str) or not data[field]:
            raise ValueError(f"{field} must be a non-empty string")
        try:
            re.compile(data[field])
        except re.error as error:
            raise ValueError(f"{field} is not a valid regular expression") from error

    scalar_strings = (
        "source_none_literal",
        "source_user_request_literal",
        "form_none_literal",
    )
    for field in scalar_strings:
        if not isinstance(data[field], str) or not data[field]:
            raise ValueError(f"{field} must be a non-empty string")

    template_markers = _unique_strings(data["template_markers"], "template_markers")
    marker_pattern = re.compile(data["template_marker_pattern"])
    if any(marker_pattern.fullmatch(marker) is None for marker in template_markers):
        raise ValueError("template_markers must match template_marker_pattern")

    return ContractSchema(
        version=data["version"],
        vocabulary_path=vocabulary_path,
        artifact_headings=dict(headings),
        contract_sections=_unique_strings(data["contract_sections"], "contract_sections"),
        blocker_sections=_unique_strings(data["blocker_sections"], "blocker_sections"),
        source_categories=_unique_strings(data["source_categories"], "source_categories"),
        classification_fields=_unique_strings(data["classification_fields"], "classification_fields"),
        boundary_fields=_unique_strings(data["boundary_fields"], "boundary_fields"),
        unit_fields=_unique_strings(data["unit_fields"], "unit_fields"),
        admission_fields=_unique_strings(data["admission_fields"], "admission_fields"),
        source_none_literal=data["source_none_literal"],
        source_user_request_literal=data["source_user_request_literal"],
        source_repository_relative_pattern=data["source_repository_relative_pattern"],
        source_absolute_path_pattern=data["source_absolute_path_pattern"],
        form_none_literal=data["form_none_literal"],
        table_columns=table_columns,
        semantic_key_pattern=data["semantic_key_pattern"],
        evidence_classes=frozenset(_unique_strings(data["evidence_classes"], "evidence_classes")),
        durable_impacts=frozenset(_unique_strings(data["durable_impacts"], "durable_impacts")),
        unit_heading_pattern=data["unit_heading_pattern"],
        admission_heading_pattern=data["admission_heading_pattern"],
        dependency_pattern=data["dependency_pattern"],
        required_gate_checks=_unique_strings(data["required_gate_checks"], "required_gate_checks"),
        required_gate_checks_by_obligation=normalized_obligation_checks,
        template_marker_pattern=data["template_marker_pattern"],
        template_marker_recognizer_pattern=data["template_marker_recognizer_pattern"],
        template_markers=template_markers,
        legacy_placeholder_tokens=_unique_strings(data["legacy_placeholder_tokens"], "legacy_placeholder_tokens"),
    )


REFERENCES_DIR = Path(__file__).resolve().parents[1] / "references"
SCHEMA_PATH = REFERENCES_DIR / "contract-artifact-schema.json"
CONTRACT_SCHEMA = load_contract_schema(SCHEMA_PATH)
VOCABULARY_PATH = REFERENCES_DIR / CONTRACT_SCHEMA.vocabulary_path
CONTRACT_VOCABULARY = load_contract_vocabulary(VOCABULARY_PATH)

H1_RE = re.compile(r"^# (.+)$", re.MULTILINE)
H2_RE = re.compile(r"^## (.+)$", re.MULTILINE)
H3_RE = re.compile(r"^### (.+)$", re.MULTILINE)
FIELD_RE = re.compile(r"^([A-Za-z][A-Za-z0-9 -]*):(?:[ \t]*(.*))$", re.MULTILINE)
FENCE_RE = re.compile(r"^ {0,3}(`{3,}|~{3,})")


def _mask_fenced_code(text: str, *, fenced_mask: str = " ") -> str:
    """Blank fenced-code contents while preserving structural source offsets."""
    masked: list[str] = []
    fence_character: str | None = None
    fence_length = 0
    for line in text.splitlines(keepends=True):
        body = line.rstrip("\r\n")
        newline = line[len(body):]
        fence = FENCE_RE.match(body)
        if fence_character is None:
            if fence is not None:
                marker = fence.group(1)
                fence_character = marker[0]
                fence_length = len(marker)
                masked.append(fenced_mask * len(body) + newline)
            else:
                masked.append(line)
            continue

        closes_fence = re.fullmatch(
            rf" {{0,3}}{re.escape(fence_character)}{{{fence_length},}}[ \t]*",
            body,
        )
        if closes_fence:
            fence_character = None
            fence_length = 0
            masked.append(fenced_mask * len(body) + newline)
        else:
            masked.append(fenced_mask * len(body) + newline)
    return "".join(masked)


def _table_only_finding(content: str, context: str) -> Finding | None:
    lines = content.splitlines()
    table_start = next((index for index, line in enumerate(lines) if line.strip().startswith("|")), None)
    if table_start is None:
        return None
    table_end = table_start
    while table_end < len(lines) and lines[table_end].strip().startswith("|"):
        table_end += 1
    if any(line.strip() for line in lines[:table_start]) or any(line.strip() for line in lines[table_end:]):
        return Finding(f"{context} must contain only its table")
    return None


def _table_only_findings(text: str, schema: ContractSchema) -> list[Finding]:
    sections = _section_spans(text)[1]
    findings: list[Finding] = []
    for context in schema.table_columns:
        content_lines = sections.get(context)
        if content_lines is None:
            continue
        finding = _table_only_finding("".join(content_lines), context)
        if finding is not None:
            findings.append(finding)

    for match in re.finditer(r"^Acceptance Outcomes:[ \t]*$", text, re.MULTILINE):
        next_depends_on = re.search(r"^Depends On:", text[match.end():], re.MULTILINE)
        content = text[match.end():match.end() + next_depends_on.start()] if next_depends_on else text[match.end():]
        finding = _table_only_finding(content, "Acceptance Outcomes")
        if finding is not None:
            findings.append(finding)
    return findings


def _section_spans(text: str) -> tuple[list[str], dict[str, list[str]]]:
    matches = list(H2_RE.finditer(text))
    names = [match.group(1).strip() for match in matches]
    contents: dict[str, list[str]] = defaultdict(list)
    for index, match in enumerate(matches):
        end = matches[index + 1].start() if index + 1 < len(matches) else len(text)
        contents[match.group(1).strip()].append(text[match.end():end])
    return names, contents


def _check_sections(text: str, expected: tuple[str, ...]) -> tuple[list[Finding], dict[str, str]]:
    names, grouped = _section_spans(text)
    findings: list[Finding] = []
    if names != list(expected):
        findings.append(Finding("top-level sections do not match the schema-owned order"))
    for name, count in Counter(names).items():
        if count > 1:
            findings.append(Finding(f"duplicate section `## {name}`"))
    for name in expected:
        if name not in grouped:
            findings.append(Finding(f"missing section `## {name}`"))
        elif not grouped[name][0].strip():
            findings.append(Finding(f"empty section `## {name}`"))
    return findings, {name: values[0] for name, values in grouped.items() if values}


def _parse_fields(
    content: str,
    expected: tuple[str, ...],
    context: str,
    allow_empty: Iterable[str] = (),
) -> tuple[list[Finding], dict[str, str]]:
    matches = list(FIELD_RE.finditer(content))
    names = [match.group(1) for match in matches]
    findings: list[Finding] = []
    if names != list(expected):
        findings.append(Finding(f"{context} fields do not match the schema-owned order"))
    for name, count in Counter(names).items():
        if count > 1:
            findings.append(Finding(f"{context} has duplicate field `{name}`"))
    values: dict[str, str] = {}
    allow_empty_set = set(allow_empty)
    for index, match in enumerate(matches):
        name = match.group(1)
        inline = match.group(2).strip()
        end = matches[index + 1].start() if index + 1 < len(matches) else len(content)
        following = content[match.end():end].strip()
        value = inline or following
        if name in expected and name not in values:
            values[name] = value
        if name in expected and not value and name not in allow_empty_set:
            findings.append(Finding(f"{context} field `{name}` is empty"))
    for name in expected:
        if name not in names:
            findings.append(Finding(f"{context} missing field `{name}`"))
    return findings, values


def _split_table_row(line: str) -> list[str]:
    stripped = line.strip()
    if not stripped.startswith("|") or not stripped.endswith("|"):
        return [stripped]
    cells: list[str] = []
    current: list[str] = []
    preceding_backslashes = 0
    for character in stripped[1:-1]:
        if character == "|" and preceding_backslashes % 2 == 0:
            cells.append("".join(current).strip())
            current = []
            preceding_backslashes = 0
            continue
        current.append(character)
        if character == "\\":
            preceding_backslashes += 1
        else:
            preceding_backslashes = 0
    cells.append("".join(current).strip())
    return cells


def _parse_table(
    content: str,
    columns: tuple[str, ...],
    context: str,
) -> tuple[list[Finding], list[list[str]]]:
    findings: list[Finding] = []
    source_lines = content.splitlines()
    table_start = next(
        (index for index, line in enumerate(source_lines) if line.strip().startswith("|")),
        None,
    )
    if table_start is None:
        return [Finding(f"{context} is missing its table or data rows")], []
    table_end = table_start
    while table_end < len(source_lines) and source_lines[table_end].strip().startswith("|"):
        table_end += 1
    lines = [line.strip() for line in source_lines[table_start:table_end]]
    if any(line.strip().startswith("|") for line in source_lines[table_end:]):
        findings.append(Finding(f"{context} has disconnected pipe-prefixed content"))
    if len(lines) < 2:
        return findings + [Finding(f"{context} is missing its table header or separator")], []
    if _split_table_row(lines[0]) != list(columns):
        findings.append(Finding(f"{context} table columns do not match the schema"))
    separators = _split_table_row(lines[1])
    if len(separators) != len(columns) or not all(re.fullmatch(r":?-{3,}:?", item) for item in separators):
        findings.append(Finding(f"{context} table separator is malformed"))
    rows: list[list[str]] = []
    for line in lines[2:]:
        cells = _split_table_row(line)
        if len(cells) != len(columns) or any(not cell for cell in cells):
            findings.append(Finding(f"{context} has a malformed or empty table row"))
            continue
        rows.append(cells)
    if not rows:
        findings.append(Finding(f"{context} has no complete data rows"))
    return findings, rows


def _parse_table_section(
    content: str,
    columns: tuple[str, ...],
    context: str,
) -> tuple[list[Finding], list[list[str]]]:
    findings, rows = _parse_table(content, columns, context)
    table_only_finding = _table_only_finding(content, context)
    if table_only_finding is not None:
        findings.append(table_only_finding)
    return findings, rows


def _marker_value(value: str, schema: ContractSchema) -> bool:
    stripped = value.strip()
    if len(stripped) >= 2 and stripped.startswith("`") and stripped.endswith("`"):
        stripped = stripped[1:-1]
    return stripped in schema.template_markers


def _single_key(
    value: str,
    schema: ContractSchema,
    context: str,
    *,
    template: bool = False,
) -> tuple[list[Finding], str | None]:
    if template and _marker_value(value, schema):
        return [], None
    match = re.fullmatch(r"`([^`]+)`", value)
    if not match or not re.fullmatch(schema.semantic_key_pattern, match.group(1)):
        return [Finding(f"{context} must be one lowercase kebab-case key")], None
    return [], match.group(1)


def _key_list(
    value: str,
    schema: ContractSchema,
    context: str,
    *,
    template: bool = False,
) -> tuple[list[Finding], tuple[str, ...]]:
    if template and _marker_value(value, schema):
        return [], ()
    parts = value.split(", ")
    keys: list[str] = []
    findings: list[Finding] = []
    for part in parts:
        item_findings, key = _single_key(part, schema, context, template=template)
        findings.extend(item_findings)
        if key is not None:
            keys.append(key)
    if not parts or not keys:
        findings.append(Finding(f"{context} must reference at least one key"))
    if len(keys) != len(set(keys)):
        findings.append(Finding(f"{context} contains a duplicate key"))
    return findings, tuple(keys)


def _enum_token(
    value: str,
    allowed: frozenset[str],
    context: str,
    *,
    template: bool = False,
    schema: ContractSchema | None = None,
) -> tuple[list[Finding], str | None]:
    if template and schema is not None and _marker_value(value, schema):
        return [], None
    match = re.fullmatch(r"`([^`]+)`", value)
    if not match or match.group(1) not in allowed:
        return [Finding(f"{context} has an invalid value")], None
    return [], match.group(1)


def _duplicates(values: Iterable[str], kind: str) -> list[Finding]:
    return [Finding(f"duplicate {kind} `{value}`") for value, count in Counter(values).items() if count > 1]


def _valid_source_authority(value: str, schema: ContractSchema) -> bool:
    return (
        value == schema.source_user_request_literal
        or re.fullmatch(schema.source_repository_relative_pattern, value) is not None
        or re.fullmatch(schema.source_absolute_path_pattern, value) is not None
    )


def _check_sources(content: str, schema: ContractSchema, *, template: bool = False) -> list[Finding]:
    findings, rows = _parse_table_section(content, schema.table_columns["Source Inputs"], "Source Inputs")
    if findings:
        return findings
    categories: dict[str, list[list[str]]] = defaultdict(list)
    source_keys: list[str] = []
    for row_number, row in enumerate(rows, start=1):
        category, source_id, location = row
        if category not in schema.source_categories:
            findings.append(Finding(f"Source Inputs row {row_number} has an invalid Category"))
            continue
        categories[category].append(row)
        if source_id == schema.source_none_literal:
            if location != schema.source_none_literal:
                findings.append(Finding(f"Source Inputs row {row_number} None source must use exact `none` cells"))
            continue
        key_findings, key = _single_key(
            source_id,
            schema,
            f"Source Inputs row {row_number} Source ID",
            template=template,
        )
        findings.extend(key_findings)
        if key is not None:
            source_keys.append(key)
        if location == schema.source_none_literal:
            findings.append(Finding(f"Source Inputs row {row_number} concrete source requires a location"))
        elif not (template and _marker_value(location, schema)) and not _valid_source_authority(location, schema):
            findings.append(Finding(f"Source Inputs row {row_number} has an invalid Location or authority"))
    for category in schema.source_categories:
        category_rows = categories.get(category, [])
        if not category_rows:
            findings.append(Finding(f"Source Inputs is missing Category `{category}`"))
        elif any(row[1] == schema.source_none_literal for row in category_rows) and len(category_rows) != 1:
            findings.append(Finding(f"Source Inputs Category `{category}` cannot mix `none` with concrete sources"))
    findings.extend(_duplicates(source_keys, "Source Inputs source key"))
    return findings


def _check_repository_evidence(content: str) -> list[Finding]:
    rows = [line.strip() for line in content.splitlines() if line.strip()]
    if not rows:
        return [Finding("Repository Evidence must contain at least one row")]
    return [
        Finding(f"Repository Evidence row {row_number} is malformed")
        for row_number, row in enumerate(rows, start=1)
        if re.fullmatch(r"- `[^`]+` / .+ -> .+", row) is None
    ]


def _check_goal(content: str) -> list[Finding]:
    paragraphs = [paragraph for paragraph in re.split(r"\n[ \t]*\n", content.strip()) if paragraph.strip()]
    if len(paragraphs) != 1:
        return [Finding("Goal must contain exactly one non-empty paragraph")]
    return []


def _check_blocker(text: str, schema: ContractSchema, *, template: bool = False) -> list[Finding]:
    findings, sections = _check_sections(text, schema.blocker_sections)
    findings.extend(_check_goal(sections.get("Goal", "")))
    findings.extend(_check_sources(sections.get("Source Inputs", ""), schema, template=template))
    decision_findings, decision_rows = _parse_table_section(
        sections.get("Blocking Decisions", ""), schema.table_columns["Blocking Decisions"], "Blocking Decisions"
    )
    findings.extend(decision_findings)
    decision_keys: list[str] = []
    for row_number, row in enumerate(decision_rows, start=1):
        key_findings, key = _single_key(
            row[0],
            schema,
            f"Blocking Decisions row {row_number} Decision ID",
            template=template,
        )
        findings.extend(key_findings)
        if key is not None:
            decision_keys.append(key)
    findings.extend(_duplicates(decision_keys, "Blocking Decisions decision key"))
    if any(name == "Execution Units" for name in H2_RE.findall(text)) or any(
        re.fullmatch(r"\[[ xX]\] Unit [1-9][0-9]*: .+", name) for name in H3_RE.findall(text)
    ):
        findings.append(Finding("Contract Blocker contains provisional implementation content"))
    findings.extend(_check_repository_evidence(sections.get("Repository Evidence", "")))
    return findings


def _parse_classification(
    content: str,
    schema: ContractSchema,
    vocabulary: ContractVocabulary,
    *,
    template: bool = False,
) -> tuple[list[Finding], str | None, frozenset[str]]:
    findings, values = _parse_fields(content, schema.classification_fields, "Classification")
    profile: str | None = None
    profile_match = re.fullmatch(r"`([^`]+)`", values.get("Profile", ""))
    if template and _marker_value(values.get("Profile", ""), schema):
        pass
    elif not profile_match or profile_match.group(1) not in vocabulary.profiles:
        findings.append(Finding("Classification has an invalid Profile"))
    else:
        profile = profile_match.group(1)

    obligation_value = values.get("Obligations", "")
    token_parts = obligation_value.split(", ")
    tokens: list[str] = []
    if obligation_value and not (template and _marker_value(obligation_value, schema)):
        for part in token_parts:
            token_match = re.fullmatch(r"`([^`]+)`", part)
            if token_match:
                tokens.append(token_match.group(1))
    allowed = vocabulary.obligations | {vocabulary.no_obligation}
    if not (template and _marker_value(obligation_value, schema)) and (
        len(tokens) != len(token_parts) or any(token not in allowed for token in tokens)
    ):
        findings.append(Finding("Classification has invalid Obligations"))
    if len(tokens) != len(set(tokens)):
        findings.append(Finding("Classification has duplicate Obligations"))
    if vocabulary.no_obligation in tokens and len(tokens) != 1:
        findings.append(Finding(f"`{vocabulary.no_obligation}` cannot be combined with material Obligations"))
    return findings, profile, frozenset(tokens) - {vocabulary.no_obligation}


@dataclass(frozen=True)
class _Unit:
    number: int
    outcomes: tuple[str, ...]
    outcome_table_is_structurally_valid: bool


def _parse_units(
    content: str,
    schema: ContractSchema,
    vocabulary: ContractVocabulary,
    *,
    template: bool = False,
) -> tuple[list[Finding], list[_Unit]]:
    findings: list[Finding] = []
    heading_matches = list(H3_RE.finditer(content))
    heading_pattern = re.compile(schema.unit_heading_pattern)
    parsed_headings: list[tuple[re.Match[str], re.Match[str]]] = []
    for heading in heading_matches:
        full_line = f"### {heading.group(1)}"
        parsed = heading_pattern.fullmatch(full_line)
        if parsed is None:
            findings.append(Finding(f"Execution Units has invalid heading `{full_line}`"))
        else:
            parsed_headings.append((heading, parsed))
    if not parsed_headings:
        return findings + [Finding("full contract has no unchecked execution units")], []

    numbers = [int(parsed.group(1)) for _, parsed in parsed_headings]
    if numbers != list(range(1, len(numbers) + 1)):
        findings.append(Finding(f"unit numbers must be unique and contiguous from 1; found {numbers}"))
    known_numbers = set(numbers)
    units: list[_Unit] = []
    all_outcomes: list[str] = []
    for index, (heading, parsed) in enumerate(parsed_headings):
        number = int(parsed.group(1))
        end = parsed_headings[index + 1][0].start() if index + 1 < len(parsed_headings) else len(content)
        block = content[heading.end():end]
        field_findings, values = _parse_fields(
            block,
            schema.unit_fields,
            f"Unit {number}",
            allow_empty={"Acceptance Outcomes"},
        )
        findings.extend(field_findings)
        profile_match = re.fullmatch(r"`([^`]+)`", values.get("Verification Profile", ""))
        if not (template and _marker_value(values.get("Verification Profile", ""), schema)) and (
            not profile_match or profile_match.group(1) not in vocabulary.profiles
        ):
            findings.append(Finding(f"Unit {number} has an invalid Verification Profile"))

        table_findings, rows = _parse_table_section(
            values.get("Acceptance Outcomes", ""),
            schema.table_columns["Acceptance Outcomes"],
            "Acceptance Outcomes",
        )
        findings.extend(table_findings)
        outcome_keys: list[str] = []
        outcome_table_is_structurally_valid = not table_findings
        if outcome_table_is_structurally_valid:
            for row in rows:
                key_findings, key = _single_key(
                    row[0], schema, f"Unit {number} outcome key", template=template
                )
                findings.extend(key_findings)
                if key is not None:
                    outcome_keys.append(key)
                    all_outcomes.append(key)
        units.append(
            _Unit(
                number=number,
                outcomes=tuple(outcome_keys),
                outcome_table_is_structurally_valid=outcome_table_is_structurally_valid,
            )
        )

        depends = values.get("Depends On", "")
        if depends == schema.form_none_literal:
            dependencies: list[int] = []
        else:
            dependency_lines = [line.strip() for line in depends.splitlines() if line.strip()]
            dependencies = []
            for line in dependency_lines:
                dependency_match = re.fullmatch(schema.dependency_pattern, line)
                if dependency_match is None:
                    findings.append(Finding(f"Unit {number} has malformed dependency `{line}`"))
                    continue
                if not all(description.strip() for description in dependency_match.group(2, 3)):
                    findings.append(Finding(f"Unit {number} dependency descriptions must contain non-whitespace text"))
                dependency = int(dependency_match.group(1))
                dependencies.append(dependency)
                if dependency not in known_numbers:
                    findings.append(Finding(f"Unit {number} depends on unknown Unit {dependency}"))
                if dependency >= number:
                    findings.append(Finding(f"Unit {number} dependency Unit {dependency} is not topological"))
            if not dependency_lines:
                findings.append(Finding(f"Unit {number} Depends On is empty"))
            if len(dependencies) != len(set(dependencies)):
                findings.append(Finding(f"Unit {number} has duplicate dependencies"))
    findings.extend(_duplicates(all_outcomes, "outcome key"))
    return findings, units


@dataclass(frozen=True)
class _MatrixRow:
    key: str
    covers: tuple[str, ...]
    impact: str | None
    artifact: str
    admissions: tuple[str, ...]


def _parse_matrix(
    content: str,
    schema: ContractSchema,
    *,
    template: bool = False,
) -> tuple[list[Finding], list[_MatrixRow], bool]:
    columns = schema.table_columns["Verification Matrix"]
    findings, rows = _parse_table_section(content, columns, "Verification Matrix")
    if findings:
        return findings, [], False
    parsed_rows: list[_MatrixRow] = []
    evidence_keys: list[str] = []
    for row_number, row in enumerate(rows, start=1):
        cells = dict(zip(columns, row))
        key_findings, key = _single_key(
            cells["Evidence key"], schema, f"Verification Matrix row {row_number} Evidence key", template=template
        )
        cover_findings, covers = _key_list(
            cells["Covers"], schema, f"Verification Matrix row {row_number} Covers", template=template
        )
        class_findings, _ = _enum_token(
            cells["Evidence class"], schema.evidence_classes, f"Verification Matrix row {row_number} Evidence class",
            template=template, schema=schema,
        )
        impact_findings, impact = _enum_token(
            cells["Durable impact"], schema.durable_impacts, f"Verification Matrix row {row_number} Durable impact",
            template=template, schema=schema,
        )
        findings.extend(key_findings + cover_findings + class_findings + impact_findings)
        artifact = cells["Artifact target"]
        admission_value = cells["Admission"]
        admission_keys: tuple[str, ...] = ()
        if impact == "NONE":
            if artifact != schema.form_none_literal:
                findings.append(Finding(f"Verification Matrix row {row_number} NONE impact requires Artifact target None"))
            if admission_value != schema.form_none_literal:
                findings.append(Finding(f"Verification Matrix row {row_number} NONE impact requires Admission None"))
        elif impact is not None:
            if artifact == schema.form_none_literal:
                findings.append(Finding(f"Verification Matrix row {row_number} non-NONE impact requires an Artifact target"))
            if impact in {"ADD", "EXTEND_COVERAGE"}:
                if admission_value == schema.form_none_literal:
                    findings.append(Finding(f"Verification Matrix row {row_number} {impact} requires an admission"))
                else:
                    admission_findings, admission_keys = _key_list(
                        admission_value,
                        schema,
                        f"Verification Matrix row {row_number} Admission",
                        template=template,
                    )
                    findings.extend(admission_findings)
            elif admission_value != schema.form_none_literal:
                findings.append(Finding(f"Verification Matrix row {row_number} impact {impact} requires Admission None"))
        if key is not None:
            evidence_keys.append(key)
            parsed_rows.append(_MatrixRow(key, covers, impact, artifact, admission_keys))
    findings.extend(_duplicates(evidence_keys, "evidence key"))
    return findings, parsed_rows, True


@dataclass(frozen=True)
class _Admission:
    key: str
    covers: tuple[str, ...]
    impact: str | None
    artifact: str


def _parse_admissions(
    content: str,
    schema: ContractSchema,
    *,
    template: bool = False,
) -> tuple[list[Finding], list[_Admission]]:
    stripped = content.strip()
    if stripped == schema.form_none_literal:
        return [], []
    if template and _marker_value(stripped, schema):
        return [], []
    findings: list[Finding] = []
    headings = list(H3_RE.finditer(content))
    heading_pattern = re.compile(schema.admission_heading_pattern)
    parsed: list[tuple[re.Match[str], re.Match[str]]] = []
    for heading in headings:
        full_line = f"### {heading.group(1)}"
        match = heading_pattern.fullmatch(full_line)
        if match is None:
            findings.append(Finding(f"Permanent Artifact Admissions has invalid heading `{full_line}`"))
        else:
            parsed.append((heading, match))
    if not parsed:
        return findings + [Finding("Permanent Artifact Admissions must be exact None or contain admission entries")], []
    if content[:parsed[0][0].start()].strip():
        findings.append(Finding("Permanent Artifact Admissions has content before its first entry"))
    admissions: list[_Admission] = []
    keys: list[str] = []
    for index, (heading, match) in enumerate(parsed):
        key = match.group(1)
        end = parsed[index + 1][0].start() if index + 1 < len(parsed) else len(content)
        block = content[heading.end():end]
        field_findings, values = _parse_fields(block, schema.admission_fields, f"Admission `{key}`")
        findings.extend(field_findings)
        cover_findings, covers = _key_list(
            values.get("Covers", ""), schema, f"Admission `{key}` Covers", template=template
        )
        impact_findings, impact = _enum_token(
            values.get("Impact", ""), schema.durable_impacts, f"Admission `{key}` Impact",
            template=template, schema=schema,
        )
        findings.extend(cover_findings + impact_findings)
        artifact = values.get("Artifact target", "")
        if impact not in {"ADD", "EXTEND_COVERAGE"}:
            findings.append(Finding(f"Admission `{key}` Impact must be ADD or EXTEND_COVERAGE"))
        admissions.append(_Admission(key, covers, impact, artifact))
        keys.append(key)
    findings.extend(_duplicates(keys, "admission key"))
    return findings, admissions


def _check_gate(content: str, schema: ContractSchema, obligations: frozenset[str]) -> list[Finding]:
    findings, rows = _parse_table_section(content, schema.table_columns["Verification Gate"], "Verification Gate")
    if findings:
        return findings
    checks = [row[0] for row in rows]
    required = list(schema.required_gate_checks)
    for obligation in obligations:
        required.extend(schema.required_gate_checks_by_obligation.get(obligation, ()))
    for check in required:
        count = checks.count(check)
        if count != 1:
            findings.append(Finding(f"Verification Gate requires exactly one `{check}` row; found {count}"))
    findings.extend(_duplicates(checks, "Verification Gate check"))
    for row in rows:
        if row[0] == "Diff hygiene" and row[2] != "`git diff --check`":
            findings.append(Finding("Verification Gate Diff hygiene must use exact `git diff --check`"))
    return findings


def _check_contract(
    text: str,
    schema: ContractSchema,
    vocabulary: ContractVocabulary,
    *,
    template: bool = False,
) -> list[Finding]:
    findings, sections = _check_sections(text, schema.contract_sections)
    findings.extend(_check_goal(sections.get("Goal", "")))
    findings.extend(_check_sources(sections.get("Source Inputs", ""), schema, template=template))
    classification_findings, _, obligations = _parse_classification(
        sections.get("Classification", ""), schema, vocabulary, template=template
    )
    findings.extend(classification_findings)
    findings.extend(_check_repository_evidence(sections.get("Repository Evidence", "")))
    boundary_findings, _ = _parse_fields(sections.get("Boundaries", ""), schema.boundary_fields, "Boundaries")
    findings.extend(boundary_findings)

    unit_findings, units = _parse_units(
        sections.get("Execution Units", ""), schema, vocabulary, template=template
    )
    findings.extend(unit_findings)
    outcome_keys = {key for unit in units for key in unit.outcomes}
    outcome_tables_are_structurally_valid = bool(units) and all(
        unit.outcome_table_is_structurally_valid for unit in units
    )

    decision_columns = schema.table_columns["Decision Trace"]
    decision_findings, decision_rows = _parse_table_section(
        sections.get("Decision Trace", ""), decision_columns, "Decision Trace"
    )
    findings.extend(decision_findings)
    decision_keys: list[str] = []
    decision_targets: list[str] = []
    if not decision_findings:
        for row_number, row in enumerate(decision_rows, start=1):
            cells = dict(zip(decision_columns, row))
            key_findings, key = _single_key(
                cells["Decision ID"], schema, f"Decision Trace row {row_number} Decision ID", template=template
            )
            target_findings, target = _single_key(
                cells["Acceptance or evidence target"], schema, f"Decision Trace row {row_number} target", template=template
            )
            findings.extend(key_findings + target_findings)
            if key is not None:
                decision_keys.append(key)
            if target is not None:
                decision_targets.append(target)
    findings.extend(_duplicates(decision_keys, "decision key"))

    matrix_findings, matrix_rows, matrix_is_structurally_valid = _parse_matrix(
        sections.get("Verification Matrix", ""), schema, template=template
    )
    admission_findings, admissions = _parse_admissions(
        sections.get("Permanent Artifact Admissions", ""), schema, template=template
    )
    findings.extend(matrix_findings + admission_findings)
    evidence_keys = {row.key for row in matrix_rows}
    admission_by_key = {admission.key: admission for admission in admissions}

    if matrix_is_structurally_valid and outcome_tables_are_structurally_valid:
        for target in decision_targets:
            if target not in outcome_keys and target not in evidence_keys:
                findings.append(Finding(f"Decision Trace references unknown acceptance or evidence target `{target}`"))

        outcome_rows: dict[str, list[_MatrixRow]] = defaultdict(list)
        for row in matrix_rows:
            for outcome in row.covers:
                if outcome not in outcome_keys:
                    findings.append(Finding(f"evidence `{row.key}` covers unknown outcome `{outcome}`"))
                else:
                    outcome_rows[outcome].append(row)
            for admission_key in row.admissions:
                if admission_key not in admission_by_key:
                    findings.append(Finding(f"evidence `{row.key}` references unknown admission `{admission_key}`"))

        for outcome in sorted(outcome_keys):
            rows = outcome_rows.get(outcome, [])
            if not rows:
                findings.append(Finding(f"outcome `{outcome}` has no Verification Matrix evidence"))
            impacts = {row.impact for row in rows}
            if "NONE" in impacts and any(impact != "NONE" for impact in impacts):
                findings.append(Finding(f"outcome `{outcome}` mixes NONE and non-NONE durable impacts"))

        referenced_admissions: set[str] = set()
        for row in matrix_rows:
            if row.impact not in {"ADD", "EXTEND_COVERAGE"}:
                continue
            referenced_admissions.update(row.admissions)
            known = [admission_by_key[key] for key in row.admissions if key in admission_by_key]
            for admission in known:
                if admission.impact != row.impact:
                    findings.append(Finding(f"admission `{admission.key}` Impact does not match evidence `{row.key}`"))
                if admission.artifact != row.artifact:
                    findings.append(Finding(f"admission `{admission.key}` Artifact target does not match evidence `{row.key}`"))
            for admission in known:
                for outcome in row.covers:
                    if outcome not in admission.covers:
                        findings.append(
                            Finding(
                                f"admission `{admission.key}` does not cover evidence `{row.key}` outcome `{outcome}`"
                            )
                        )

        for admission in admissions:
            if admission.key not in referenced_admissions:
                findings.append(Finding(f"admission `{admission.key}` is not referenced by ADD or EXTEND_COVERAGE evidence"))
            for outcome in admission.covers:
                if outcome not in outcome_keys:
                    findings.append(Finding(f"admission `{admission.key}` covers unknown outcome `{outcome}`"))
                    continue
                matching_rows = [
                    row
                    for row in matrix_rows
                    if row.impact in {"ADD", "EXTEND_COVERAGE"}
                    and admission.key in row.admissions
                    and outcome in row.covers
                ]
                if not matching_rows:
                    findings.append(Finding(f"admission `{admission.key}` outcome `{outcome}` has no matching matrix row"))

        if not admissions and any(row.impact in {"ADD", "EXTEND_COVERAGE"} for row in matrix_rows):
            findings.append(Finding("Permanent Artifact Admissions cannot be None when durable coverage is added or extended"))

    findings.extend(_check_gate(sections.get("Verification Gate", ""), schema, obligations))
    return findings


def lint_text(text: str, template: bool = False) -> list[Finding]:
    schema = CONTRACT_SCHEMA
    findings: list[Finding] = []
    structural_text = _mask_fenced_code(text)
    table_envelope_text = _mask_fenced_code(text, fenced_mask="x")
    h1s = H1_RE.findall(structural_text)
    expected_headings = set(schema.artifact_headings.values())
    if len(h1s) != 1:
        findings.append(Finding(f"expected exactly one H1, found {len(h1s)}"))
        return findings + _check_markers(text, schema, template=template)
    heading = h1s[0].strip()
    if heading not in expected_headings:
        findings.append(Finding(f"unexpected H1 `# {heading}`"))
        return findings + _check_markers(text, schema, template=template)
    findings.extend(_check_markers(text, schema, template=template))
    if heading == schema.artifact_headings["blocker"]:
        findings.extend(_check_blocker(structural_text, schema, template=template))
    else:
        findings.extend(_check_contract(structural_text, schema, CONTRACT_VOCABULARY, template=template))
    structural_table_findings = {finding.message for finding in _table_only_findings(structural_text, schema)}
    findings.extend(
        finding
        for finding in _table_only_findings(table_envelope_text, schema)
        if finding.message not in structural_table_findings
    )
    return findings


def _check_markers(text: str, schema: ContractSchema, *, template: bool) -> list[Finding]:
    if template:
        findings = [
            Finding(f"unknown fill marker `{match.group(0)}`")
            for match in re.finditer(schema.template_marker_recognizer_pattern, text)
            if match.group(0) not in schema.template_markers
        ]
    else:
        findings = [
            Finding(f"unrendered template marker `{match.group(0)}`")
            for match in re.finditer(schema.template_marker_pattern, text)
        ]
    for token in schema.legacy_placeholder_tokens:
        for _ in re.finditer(rf"\b{re.escape(token)}\b", text):
            findings.append(Finding(f"legacy placeholder token `{token}`"))
    return findings


def lint_file(path: Path, template: bool = False) -> list[Finding]:
    return lint_text(path.read_text(encoding="utf-8"), template=template)


def main(argv: list[str] | None = None) -> int:
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument("contract", nargs="?", help="Path to an active contract, or - for stdin")
    parser.add_argument("--template", type=Path, help="Path to a Change Contract template")
    try:
        args = parser.parse_args(argv)
    except SystemExit as error:
        return int(error.code) if isinstance(error.code, int) else 2
    if (args.contract is None) == (args.template is None):
        parser.print_usage(sys.stderr)
        return 2
    path = args.template if args.template is not None else args.contract
    assert path is not None
    try:
        text = sys.stdin.read() if path == "-" else Path(path).read_text(encoding="utf-8")
    except (OSError, UnicodeError) as error:
        print(f"contract_lint: ERROR: {error}", file=sys.stderr)
        return 2
    findings = lint_text(text, template=args.template is not None)
    if findings:
        for finding in findings:
            print(f"contract_lint: {finding.message}", file=sys.stderr)
        return 1
    print("contract_lint: PASS")
    return 0


if __name__ == "__main__":
    raise SystemExit(main())
