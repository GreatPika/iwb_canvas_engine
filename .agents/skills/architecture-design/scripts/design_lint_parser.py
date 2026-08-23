"""Public compatibility facade for architecture design parsing."""

from __future__ import annotations

from design_lint_parser_document import parse_design
from design_lint_parser_values import parse_reference_list, parse_vocabulary_list

__all__ = ["parse_design", "parse_reference_list", "parse_vocabulary_list"]
