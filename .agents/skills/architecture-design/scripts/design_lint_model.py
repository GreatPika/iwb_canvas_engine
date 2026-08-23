from __future__ import annotations

import re
from dataclasses import dataclass
from pathlib import Path
from typing import Mapping


@dataclass(frozen=True)
class Finding:
    line: int
    code: str
    message: str


@dataclass(frozen=True)
class ContractVocabulary:
    profiles: frozenset[str]
    obligations: frozenset[str]
    no_obligation: str


@dataclass(frozen=True)
class TypedReference:
    raw: str
    kind: str
    identifier: str
    concern: str | None = None


@dataclass(frozen=True)
class Record:
    identifier: str
    kind: str
    title: str
    fields: Mapping[str, str]
    field_lines: Mapping[str, int]
    line: int


@dataclass(frozen=True)
class Table:
    name: str
    header: tuple[str, ...]
    rows: tuple[tuple[str, ...], ...]
    row_lines: tuple[int, ...]


@dataclass(frozen=True)
class Section:
    name: str
    line: int
    record_ids: tuple[str, ...]
    table_names: tuple[str, ...]


@dataclass(frozen=True)
class ParsedDesign:
    frontmatter: Mapping[str, str]
    sections: Mapping[str, Section]
    records: Mapping[str, Record]
    tables: Mapping[str, Table]
    references: tuple[TypedReference, ...]
    body_line: int


@dataclass(frozen=True)
class DesignSchema:
    source_path: Path
    repository_root: Path
    raw: Mapping[str, object]
    version: str
    frontmatter_fields: tuple[str, ...]
    dispositions: tuple[str, ...]
    id_patterns: Mapping[str, re.Pattern[str]]
    vocabulary_route: str
