from __future__ import annotations

from dataclasses import dataclass, replace

from design_lint_model import (
    ContractVocabulary,
    DesignSchema,
    ParsedDesign,
    Record,
    Table,
)


@dataclass(frozen=True)
class _Graph:
    parsed: ParsedDesign
    schema: DesignSchema
    vocabulary: ContractVocabulary

    def replace_record(self, identifier: str, **fields: str) -> _Graph:
        records = dict(self.parsed.records)
        current = records[identifier]
        records[identifier] = replace(
            current,
            fields={**current.fields, **fields},
        )
        return replace(self, parsed=replace(self.parsed, records=records))

    def add_record(self, section_name: str, record: Record) -> _Graph:
        records = dict(self.parsed.records)
        records[record.identifier] = record
        sections = dict(self.parsed.sections)
        section = sections[section_name]
        sections[section_name] = replace(
            section,
            record_ids=(*section.record_ids, record.identifier),
        )
        return replace(
            self,
            parsed=replace(self.parsed, records=records, sections=sections),
        )

    def remove_record(self, section_name: str, identifier: str) -> _Graph:
        records = dict(self.parsed.records)
        records.pop(identifier)
        sections = dict(self.parsed.sections)
        section = sections[section_name]
        sections[section_name] = replace(
            section,
            record_ids=tuple(
                current for current in section.record_ids if current != identifier
            ),
        )
        return replace(
            self,
            parsed=replace(self.parsed, records=records, sections=sections),
        )

    def replace_table(self, name: str, table: Table) -> _Graph:
        tables = dict(self.parsed.tables)
        tables[name] = table
        return replace(self, parsed=replace(self.parsed, tables=tables))

    def replace_table_row(
        self,
        name: str,
        key: str,
        row: tuple[str, ...],
    ) -> _Graph:
        table = self.parsed.tables[name]
        rows = tuple(row if current[0] == key else current for current in table.rows)
        return self.replace_table(name, replace(table, rows=rows))

    def with_extra_outcome(self, identifier: str) -> _Graph:
        record = _record(
            identifier,
            "R",
            {
                "Kind": "outcome",
                "Statement": "A second outcome must also be delivered.",
                "Basis": "S-004",
                "Open shape": "Its incidental implementation shape remains open.",
            },
            33,
        )
        graph = self.add_record("Basis", record)
        table = graph.parsed.tables["Requirements"]
        return graph.replace_table(
            "Requirements",
            replace(
                table,
                rows=(
                    *table.rows,
                    (
                        identifier,
                        "outcome",
                        "A second outcome must also be delivered.",
                        "S-004",
                        "Its incidental implementation shape remains open.",
                    ),
                ),
                row_lines=(*table.row_lines, 33),
            ),
        )

    def with_dependency(self, decision: str, dependency: str) -> _Graph:
        return self.replace_record(decision, **{"Depends on": dependency})

    def with_forward_dependency(self, decision: str, dependency: str) -> _Graph:
        return self.with_dependency(decision, dependency)

    def replace_frontmatter(self, **fields: str) -> _Graph:
        return replace(
            self,
            parsed=replace(
                self.parsed,
                frontmatter={**self.parsed.frontmatter, **fields},
            ),
        )

    def with_assured_impact(self) -> _Graph:
        graph = self.add_record(
            "Impact Register",
            _record(
                "I-001",
                "I",
                {
                    "Action": "update",
                    "Surface": "The repository-owned durable result surface.",
                    "Required by": "D-002",
                    "Resulting authority": "D-002",
                    "Contract requirement": (
                        "Update the durable result under D-002 authority."
                    ),
                },
                82,
            ),
        )
        graph = graph.add_record(
            "Assurance Register",
            _record(
                "A-003",
                "A",
                {
                    "Verifies": "I-001",
                    "Claim": "The durable result surface follows the selected authority.",
                    "Failure": "The durable surface retains a stale authority.",
                    "Oracle": "Inspect the committed durable owner after the update.",
                    "Proxy risk": "A local object can pass without the durable update.",
                    "Evidence constraints": "Use the repository-visible durable surface.",
                    "Architecture seam": "The durable authority boundary is exercised.",
                },
                72,
            ),
        )
        graph = graph.replace_record(
            "D-002",
            **{
                "Contract targets": (
                    f"{graph.parsed.records['D-002'].fields['Contract targets']}, "
                    "`durable_impact`"
                )
            },
        )
        graph = graph.replace_record(
            "CONTRACT",
            Assurance="A-001, A-002, A-003",
            Impacts="I-001",
        ).replace_record(
            "H-001",
            Invalidates="D-001, D-002, A-001, A-002, A-003, I-001",
        )
        gate = graph.parsed.tables["Gate Closure"]
        verification = next(row for row in gate.rows if row[0] == "Verification")
        handoff = next(row for row in gate.rows if row[0] == "Handoff Consumability")
        graph = graph.replace_table_row(
            "Gate Closure",
            "Verification",
            (verification[0], verification[1], f"{verification[2]}, A-003"),
        )
        return graph.replace_table_row(
            "Gate Closure",
            "Handoff Consumability",
            (handoff[0], handoff[1], f"{handoff[2]}, A-003, I-001"),
        )

    def with_assured_adr_impact(self) -> _Graph:
        return (
            self.with_assured_impact()
            .replace_record(
                "CONTRACT",
                **{"ADR Impact": "supersede ADR-0001"},
            )
            .replace_record(
                "I-001",
                Action="supersede",
                Surface="ADR-0001 and its repository authority route.",
                **{
                    "Required by": "D-002",
                    "Resulting authority": "D-002",
                    "Contract requirement": (
                        "Supersede ADR-0001 under D-002 resulting authority."
                    ),
                },
            )
        )


def _record(
    identifier: str,
    kind: str,
    fields: dict[str, str],
    line: int,
    *,
    title: str | None = None,
) -> Record:
    return Record(
        identifier=identifier,
        kind=kind,
        title=title or identifier,
        fields=fields,
        field_lines={name: line for name in fields},
        line=line,
    )


def _table(
    name: str,
    header: tuple[str, ...],
    rows: tuple[tuple[str, ...], ...],
    first_line: int,
) -> Table:
    return Table(
        name=name,
        header=header,
        rows=rows,
        row_lines=tuple(range(first_line, first_line + len(rows))),
    )
