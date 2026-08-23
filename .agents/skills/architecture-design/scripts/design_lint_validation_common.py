from __future__ import annotations

import re
from collections import defaultdict
from collections.abc import Mapping, Sequence
from dataclasses import dataclass
from typing import cast

from design_lint_model import DesignSchema, ParsedDesign, Record, Table


_SYNTHETIC_KINDS = frozenset({"candidate", "contract"})


def _ordered_records(
    parsed: ParsedDesign,
    kind: str,
    section_name: str,
) -> list[Record]:
    section = parsed.sections.get(section_name)
    if section is None:
        return [record for record in parsed.records.values() if record.kind == kind]
    result: list[Record] = []
    seen_keys: set[str] = set()
    for identifier in section.record_ids:
        record = parsed.records.get(identifier)
        if record is None or record.kind != kind:
            continue
        result.append(record)
        seen_keys.add(identifier)
    result.extend(
        record
        for key, record in parsed.records.items()
        if record.kind == kind and key not in seen_keys
    )
    return result


def _selected_form(parsed: ParsedDesign) -> str | None:
    candidate = parsed.records.get("CANDIDATE")
    if candidate is None:
        return None
    value = _strip_code(candidate.fields.get("Result", ""))
    prefix = "selected "
    return value[len(prefix) :] if value.startswith(prefix) else None


def _strip_code(value: str) -> str:
    stripped = value.strip()
    if len(stripped) >= 2 and stripped.startswith("`") and stripped.endswith("`"):
        return stripped[1:-1]
    return stripped


def _csv_tokens(value: str) -> list[str]:
    if not value.strip():
        return []
    return [_strip_code(part) for part in value.split(",") if part.strip()]


def _code_tokens(value: str) -> list[str]:
    return _csv_tokens(value)


@dataclass(frozen=True)
class _DecisionConcernIndex:
    records: tuple[Record, ...]
    by_id: Mapping[str, Record]
    concerns_by_id: Mapping[str, tuple[str, ...]]
    owners_by_concern: Mapping[str, tuple[str, ...]]

    @classmethod
    def build(cls, decisions: Sequence[Record]) -> _DecisionConcernIndex:
        records = tuple(decisions)
        concerns_by_id = {
            decision.identifier: tuple(
                _code_tokens(decision.fields.get("Concerns", ""))
            )
            for decision in records
        }
        owners: dict[str, list[str]] = defaultdict(list)
        for decision in records:
            for concern in dict.fromkeys(concerns_by_id[decision.identifier]):
                owners[concern].append(decision.identifier)
        return cls(
            records=records,
            by_id={decision.identifier: decision for decision in records},
            concerns_by_id=concerns_by_id,
            owners_by_concern={
                concern: tuple(identifiers)
                for concern, identifiers in owners.items()
            },
        )

    def owners(self, concern: str) -> tuple[str, ...]:
        return self.owners_by_concern.get(concern, ())

    def owns(self, decision_id: str, concern: str) -> bool:
        return concern in self.concerns_by_id.get(decision_id, ())


def _code_values(value: str) -> list[str] | None:
    if not value.strip():
        return None
    result: list[str] = []
    for part in value.split(","):
        token = part.strip()
        if (
            len(token) < 3
            or not token.startswith("`")
            or not token.endswith("`")
            or "`" in token[1:-1]
        ):
            return None
        result.append(token[1:-1])
    return result


def _single_reference(value: str) -> str | None:
    tokens = _csv_tokens(value)
    return tokens[0] if len(tokens) == 1 else None


def _reference_type(reference: str) -> str:
    if reference == "CONTRACT":
        return "CONTRACT"
    return reference.split("-", 1)[0]


def _duplicates(values: list[str]) -> list[str]:
    seen: set[str] = set()
    result: list[str] = []
    for value in values:
        if value in seen and value not in result:
            result.append(value)
        seen.add(value)
    return result


def _schema_object(schema: DesignSchema, key: str) -> Mapping[str, object]:
    value = schema.raw[key]
    assert isinstance(value, Mapping)
    return value


def _rows_by_key(table: Table | None) -> dict[str, tuple[str, ...]]:
    if table is None:
        return {}
    return {row[0]: row for row in table.rows if row}


def _table_row_line(table: Table | None, key: str) -> int:
    if table is None:
        return 0
    for index, row in enumerate(table.rows):
        if row and row[0] == key:
            return table.row_lines[index]
    return table.row_lines[0] if table.row_lines else 0


def _is_meaningful(value: str, schema: DesignSchema) -> bool:
    stripped = _strip_code(value).strip()
    if not stripped or (stripped.startswith("{{") and stripped.endswith("}}")):
        return False
    forbidden = _schema_object(schema, "forbidden_tokens")
    placeholders = cast(list[str], forbidden["placeholder_values"])
    normalized = stripped.lower().strip(" .,:;!?()[]{}")
    return normalized not in set(placeholders)


def _normalize_semantic(value: str) -> str:
    return " ".join(_strip_code(value).casefold().split()).strip(" .,:;!?()[]{}")


def _contains_token(value: str, token: str) -> bool:
    return (
        re.search(
            rf"(?<![A-Za-z0-9_-]){re.escape(token)}(?![A-Za-z0-9_-])",
            value,
            flags=re.IGNORECASE,
        )
        is not None
    )
