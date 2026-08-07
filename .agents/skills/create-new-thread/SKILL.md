---
name: create-new-thread
description: Use when the user explicitly asks to start or run repository work in a new thread.
---

# Create New Thread

Create a repository-scoped thread only when the user explicitly asks for a new
thread.

## Steps

1. Discover `list_projects`, `create_thread`, `set_thread_title`, and
   `send_message_to_thread` if they are not already callable.
2. Run `echo "$CODEX_THREAD_ID"` from the current repository root; this is the
   parent thread ID. Stop if it is empty.
3. Use `list_projects` and choose the project whose path matches the current
   repository root.
4. Use the `local` environment by default. Use `worktree` only if the user
   explicitly asks for an isolated worktree.
5. Build the created thread prompt from the `Prompt` template below.
6. Create the thread with `create_thread`.
7. Rename the created thread with `set_thread_title`.
   - Use the `threadId` returned by `create_thread`.
   - Set `title` to the required prefix plus the concrete topic, for example
     `research canvas persistence`.
   - If `set_thread_title` is unavailable, start the created thread prompt with
     `Thread title: <required prefix> - <topic>` as a fallback.
8. In the final response, emit the created-thread directive returned by
   `create_thread`.

## Special Cases

If the topic is unclear from the current conversation, ask the user before
creating the thread.

Do not read, summarize, or paste the target skill text into the created thread
prompt.

Thread prompts must not ask the created thread to do work outside the selected
skill's responsibility. Give the thread the parent goal and any source artifact
required by the selected thread type, but do not override the skill workflow,
report-back instruction, or rules for when it must stop and report a problem.

Use `model: "gpt-5.6-sol"` and `thinking: "xhigh"` for Research, Plan and Design threads:

- Research: title starts with `research`; prompt says to use
  `$research-codebase`. Research threads provide facts only. Do not ask them
  for recommendations, implementation choices, or next-step decisions. Tell
  them why the research is needed, so they can search the relevant code, docs,
  and tests efficiently.
- Design: title starts with `design`; prompt says to use
  `$architecture-design`. Pass the research artifact link or path the
  design must use. Design threads develop a concrete architecture solution from
  the problem, research facts, repository evidence, and required source inputs.
  Do not ask them to implement code, write the plan contract, or continue past
  unresolved contradictions in the source inputs.
- Plan contract: title starts with `plan`; prompt says to use
  `$change-contract` in create-or-update mode.
  Pass the design artifact link or path the plan must use. Plan threads turn an
  accepted design into a contract-backed active plan under
  `docs/planning/plans/`. Do not ask them to redesign the solution or implement
  the planned change.
- Implementation: title starts with `implement`; prompt says to
  use `$lead-unit-by-unit`. Pass the active-plan link or path the
  implementation must use. Implementation threads execute the accepted
  contract-backed scope they are given. Do not ask them to redefine scope,
  redesign architecture, or invent missing contract decisions.

Source artifact values by thread type:

- Research: use `none` unless the user explicitly provides an existing source
  artifact to inspect.
- Design: pass the `docs/history/research/...md` research artifact link or path.
- Plan contract: pass the `docs/planning/designs/...md` design artifact link or path.
- Implementation: pass the `docs/planning/plans/...md` active-plan link or path.

## Prompt

```text
Thread title: <required title prefix> - <topic>
Parent thread ID: <CODEX_THREAD_ID>
Environment: <selected environment>
Use skill: <skill name>
Source artifact: <value from Source artifact values by thread type>

Purpose:
<why the parent thread needs this work>

Task:
<exact task within the selected skill's responsibility>

Report back:
When complete or blocked, use `send_message_to_thread` to report back to the
parent thread ID above. Follow the selected skill's output contract exactly. If
blocked, report only the blocker required by that skill.
```
