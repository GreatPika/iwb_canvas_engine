#!/usr/bin/env python3
"""Lint the canonical architecture-design/v4 Markdown artifact."""

from __future__ import annotations

import argparse
import json
import re
import sys
from pathlib import Path

from design_lint_model import DesignSchema, Finding
from design_lint_parser import parse_design
from design_lint_schema import load_schema as _load_schema
from design_lint_schema import load_vocabulary
from design_lint_validation import validate_checkpoint_design, validate_design


SCHEMA_PATH = (
    Path(__file__).resolve().parents[1] / "references" / "design-artifact-schema.json"
)


def load_schema(path: Path = SCHEMA_PATH) -> DesignSchema:
    return _load_schema(path)


def lint_text(
    text: str,
    template: bool = False,
    *,
    schema_path: Path = SCHEMA_PATH,
    vocabulary_path: Path | None = None,
) -> list[Finding]:
    schema = load_schema(schema_path)
    vocabulary = None if template else load_vocabulary(schema, vocabulary_path)
    parsed, findings = parse_design(text, schema, template=template)
    if parsed is None or findings:
        return findings
    return validate_design(parsed, schema, vocabulary, template=template)


def lint_checkpoint_text(
    text: str,
    *,
    checkpoint: str,
    schema_path: Path = SCHEMA_PATH,
    vocabulary_path: Path | None = None,
) -> list[Finding]:
    schema = load_schema(schema_path)
    sections = schema.raw.get("sections")
    assert isinstance(sections, dict)
    order = sections.get("order")
    assert isinstance(order, list)
    if checkpoint not in order:
        return [Finding(1, "checkpoint", f"unknown checkpoint `{checkpoint}`")]
    vocabulary = load_vocabulary(schema, vocabulary_path)
    parsed, findings = parse_design(text, schema, checkpoint=checkpoint)
    if parsed is None or findings:
        return findings
    return validate_checkpoint_design(parsed, schema, vocabulary, checkpoint=checkpoint)


def lint_file(
    path: Path,
    template: bool = False,
    *,
    schema_path: Path = SCHEMA_PATH,
    vocabulary_path: Path | None = None,
) -> list[Finding]:
    return lint_text(
        path.read_text(encoding="utf-8"),
        template,
        schema_path=schema_path,
        vocabulary_path=vocabulary_path,
    )


def lint_checkpoint_file(
    path: Path,
    *,
    checkpoint: str,
    schema_path: Path = SCHEMA_PATH,
    vocabulary_path: Path | None = None,
) -> list[Finding]:
    return lint_checkpoint_text(
        path.read_text(encoding="utf-8"),
        checkpoint=checkpoint,
        schema_path=schema_path,
        vocabulary_path=vocabulary_path,
    )


def main(argv: list[str] | None = None) -> int:
    parser = argparse.ArgumentParser(
        description="Lint an active architecture-design/v4 artifact.",
    )
    parser.add_argument("design", nargs="?", type=Path)
    parser.add_argument("--template", type=Path)
    parser.add_argument("--checkpoint")
    try:
        arguments = parser.parse_args(argv)
    except SystemExit as error:
        return int(error.code) if isinstance(error.code, int) else 2
    if (arguments.design is None) == (arguments.template is None) or (
        arguments.checkpoint is not None and arguments.template is not None
    ):
        parser.print_usage(sys.stderr)
        return 2

    path = arguments.template if arguments.template is not None else arguments.design
    assert path is not None
    try:
        if arguments.checkpoint is None:
            findings = lint_file(
                path,
                arguments.template is not None,
                schema_path=SCHEMA_PATH,
            )
        else:
            findings = lint_checkpoint_file(
                path,
                checkpoint=arguments.checkpoint,
                schema_path=SCHEMA_PATH,
            )
    except (
        OSError,
        UnicodeDecodeError,
        json.JSONDecodeError,
        re.error,
        ValueError,
    ) as error:
        print(f"design_lint: {error}", file=sys.stderr)
        return 2

    for finding in findings:
        print(
            f"{path}:{finding.line}: {finding.code}: {finding.message}",
            file=sys.stderr,
        )
    return 1 if findings else 0


if __name__ == "__main__":
    raise SystemExit(main())
