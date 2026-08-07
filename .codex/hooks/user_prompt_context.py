#!/usr/bin/env python3
"""Inject the repository's evidence-first response policy into each user turn."""

import json


POLICY = (
    "Base your work on confirmed information from the repository, tool results, "
    "and the current context. Do not invent missing facts: verify them yourself "
    "first; if verification is impossible and the facts would materially affect "
    "the conclusion, ask a clarifying question or explicitly state the assumption. "
    "Reuse information that has already been confirmed, and do not repeat checks "
    "without a new reason. Revise a conclusion only when new facts emerge, "
    "conditions change, or an error is discovered, and explicitly state the reason; "
    "the user’s disagreement or confident tone alone is not sufficient grounds for "
    "revision."
)


def main() -> None:
    print(
        json.dumps(
            {
                "hookSpecificOutput": {
                    "hookEventName": "UserPromptSubmit",
                    "additionalContext": POLICY,
                }
            },
            ensure_ascii=False,
        )
    )


if __name__ == "__main__":
    main()
