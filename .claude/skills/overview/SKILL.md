---
name: overview
description: Normalize a user's development request into a clear, implementation-independent task specification.
---
# Overview

You are responsible for converting a raw development request into a concise,
unambiguous task specification.

Your job is NOT to design the implementation.
Do not write code.
Do not inspect the entire codebase unless absolutely necessary to understand
the wording of the request.

## Input

The prompt the human sent when invoking this skill.

The prompt may be rough, vague, or incomplete. That is expected.

**Guard:** If no prompt was provided in the conversation and `.task/request.md`
is empty or contains only placeholder text, stop and ask:

> What is the task? Please describe what you want to change or build.

After generating overview.md, also save the original prompt to:

    .task/request.md

(for archival — no need for the user to pre-fill this file)

## Pre-flight: validate git state

Run this before writing ANY file — overview.md, request.md, or index.md.

- If the target project is not a git repository, skip this entire
  pre-flight step and note it in the final report.
- Otherwise, read `Base branch` and `Task branch prefix` from
  `.task/PROJECT.md` `## Git`.
- Verify the working tree is clean:

      git status --porcelain

  No `.task/` exclusion pathspec is needed here — nothing has been written
  yet at this point, so a plain clean check is correct. (The old exclusion
  workaround, needed only because the guards used to run after the writes,
  is deliberately gone.) Empty output means clean — proceed. Non-empty
  output means the human has real uncommitted changes — STOP and ask them
  to commit or stash first.
- Verify HEAD is on the base branch:

      git rev-parse --abbrev-ref HEAD

  Compare its output to the `Base branch` value. If they differ, STOP and
  tell the human to switch to the base branch first.

**Output language.** Also read the `Language:` line in `.task/PROJECT.md` `## Language` (missing or unrecognized → `en`). Write all prose you put into `.task/*.md` files and your final report to the human in that language (`vi` = Vietnamese). Always keep in English regardless of setting: every markdown heading (e.g. `## Goal`, `## Acceptance Criteria`, `## Fix Notes — Round N`, `## Fixes Applied — Round N`, `## Round N`) — tooling and routing grep these exact strings; `Base branch:` / `Task branch prefix:` / `Language:` lines; `.task/index.md` table field names, status values (`in-progress`, `done`) and `—` placeholders; template labels such as `Result:` / `Issues found:`; file paths; git branch names and slugs; commit messages and tag names; code, identifiers, and code comments.

## Output

Create or update:

    .task/overview.md

Use this structure:

```
# Task Overview

## Goal
Describe the desired outcome in 1-3 sentences.

## Problem
Explain what problem currently exists.

## Scope
List what should be changed.

## Out of Scope
List things that should explicitly NOT be changed.

## Requirements
List concrete functional and technical requirements.

## Constraints
List known constraints such as:
- platform
- framework
- architecture constraints
- compatibility
- performance
- security
- existing conventions
- user requirements

## Acceptance Criteria
Define observable conditions that determine whether the task is complete.
Use checkboxes:
- [ ] ...
- [ ] ...

## Ambiguities
List unresolved questions or assumptions.
If there are no important ambiguities:
None.

## Notes
Additional useful information from the original request.
```

## Rules

1. Preserve the user's actual intent.
2. Do not invent requirements.
3. Do not make architectural decisions.
4. Do not propose implementation details unless necessary to clarify a requirement.
5. Separate requirements from implementation ideas.
6. Keep the document concise.
7. Prefer concrete language.
8. If something is unknown, explicitly mark it as unknown.
9. Never claim something about the codebase that you have not verified.

## Quality Check

Before proceeding, verify overview.md against this checklist.
If any item fails, revise the document before continuing.

- [ ] Goal is specific enough to verify when complete (not vague like "improve X")
- [ ] Scope names concrete areas, not "the whole app" or "everywhere"
- [ ] At least one Acceptance Criterion is directly observable
- [ ] Ambiguities section is explicit — no hidden assumptions baked into Requirements
- [ ] Requirements section contains no implementation decisions

## After writing overview.md

### 1. Update task index

In `.task/index.md`, update the Active Task section:
- Determine the new ID by scanning across sources, since an unmerged task
  branch carries an ID that neither `.task/done/` nor the History table
  can see yet on the base branch:
  - Read `Task branch prefix` from `.task/PROJECT.md` `## Git`.
  - If the target project is a git repository, list existing task branches:

        git for-each-ref --format='%(refname:short)' 'refs/heads/{prefix}*'

    For each branch name, strip the prefix, then take the part before the
    FIRST `-`. Keep only values that are all digits — ignore anything that
    doesn't parse, so a hand-made branch like `task/experiment` can't break
    the rule.
  - Also collect the IDs from the History table in `.task/index.md`.
  - The new ID is `max(all collected IDs) + 1`, zero-padded to 3 digits.
  - If the project is not a git repository, skip the branch scan and use
    the History IDs alone.
  - If both sources yield no IDs, fall back to counting subdirectories in
    `.task/done/` (excluding `README.md`) and adding 1, zero-padded to 3
    digits.
- Extract the Goal from overview.md. Create a slug: lowercase, hyphens, max 5 words.
- Set the Active Task fields:

| Field   | Value                      |
|---------|----------------------------|
| ID      | {id}                       |
| Name    | {slug}                     |
| Started | {today's date}             |
| Status  | in-progress                |
| Branch  | {branch name, once created} |

This ID is provisional until `save` finalizes it, and must be written bare
(no "(tentative)" suffix or other annotation) because the branch-creation
command below uses it verbatim in the branch name.

### 2. Create task branch

If the target project is not a git repository, skip this step and note
it in the report.

Otherwise:
- Create and switch to the task branch from the base branch:

      git checkout -b {prefix}{id}-{slug} {base}

- Record the branch name in the Active Task table's Branch field in
  `.task/index.md`.

### 3. Invoke context-agent

Immediately invoke the **context-agent** subagent to explore the codebase.
Do not explore the codebase yourself — delegate entirely to context-agent.
This keeps the main context clean.

Wait for context-agent to finish, then report to the user:
> overview.md and context.md are ready. Proceed to Step 2: copy both files to AI web.
