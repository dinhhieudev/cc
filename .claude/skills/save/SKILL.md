---
name: save
description: Archive the current task to .task/done/ and reset the workspace for the next task.
---
# Save Task

Archive the current task and reset the workspace.
The human does not need to fill in any fields manually.

## Steps

### 0. Check for an unfinished fix round

Read `.task/review.md`. Collect every `## Fix Notes — Round N` heading and
every `## Fixes Applied — Round N` heading.

If any Fix Notes round has no matching Fixes Applied round, STOP. Do not
archive, do not reset anything, do not touch git. Report which round(s)
are outstanding and tell the human their options:
- dispatch fix-agent to finish that round, or
- explicitly confirm they want to archive the unfinished state anyway.

Only proceed past this step when every Fix Notes round has a matching
Fixes Applied round, or the human has explicitly confirmed archiving
anyway.

### 1. Determine task ID and slug

Determine the id and slug together, from a single source, in this
priority order:

1. **From `.task/index.md`:** if the Active Task `ID` and `Name` are
   both present and not `—`, use them — `Name` is the slug. These are
   the same values already embedded in the task branch name.

2. **From the task branch name:** otherwise, if the project is a git
   repository and HEAD is on a task branch (its name starts with the
   `Task branch prefix` from `.task/PROJECT.md`), recover both by
   parsing it: run `git rev-parse --abbrev-ref HEAD`, remove the
   prefix, then split the remainder at the FIRST `-` — the part before
   it is the id, everything after it is the slug.

   Example: branch `task/001-add-logout-invalidate-session` with
   prefix `task/` → id `001`, slug `add-logout-invalidate-session`.

   This covers a re-run after a partial failure, where the Active Task
   row was already cleared but the branch still carries both values.

3. **Derive:** otherwise (not a git repo, or HEAD is not on a task
   branch), derive the slug from `.task/overview.md`'s Goal (first
   section): lowercase, hyphens, max 5 words.

   Before falling back to `max + 1`, first try to recover this task's
   own id from its own branch, matched by slug — at save time, the
   branch for the task being saved usually already exists and already
   carries this task's id, so `max + 1` would otherwise mint a brand-new
   id for a task that already has one:
   - Read `Task branch prefix` from `.task/PROJECT.md` `## Git`.
   - If the project is a git repository, list existing task branches:

         git for-each-ref --format='%(refname:short)' 'refs/heads/{prefix}*'

     For each branch name, strip the prefix, then split the remainder at
     the FIRST `-` — the part before it is that branch's id, everything
     after it is that branch's slug.
   - If exactly one branch's slug equals the derived slug, and its id is
     all digits, use that id as-is — this is the task being saved, and it
     already has an id. Do not add 1.

   Otherwise, compute the id by scanning across sources, since an
   unmerged task branch carries an ID that neither `.task/done/` nor the
   History table can see yet on the base branch:
   - From the same branch scan above, keep only the id part of each
     branch name, filtering to values that are all digits — ignore
     anything that doesn't parse, so a hand-made branch like
     `task/experiment` can't break the rule.
   - Also collect the IDs from the History table in `.task/index.md`.
   - The id is `max(all collected IDs) + 1`, zero-padded to 3 digits.
   - If the project is not a git repository, skip the branch scan and use
     the History IDs alone.
   - If both sources yield no IDs, fall back to counting existing
     subdirectories in `.task/done/` (excluding README.md) and adding 1,
     zero-padded to 3 digits.

   Example: "Add dark mode toggle" → derived slug `add-dark-mode`.
   Existing task branches: `task/003-add-dark-mode` (this task's own
   unmerged branch) and `task/002-something-else`. Exactly one branch's
   slug matches (`add-dark-mode`, id `003`) → id `003` is reused, not
   bumped to `004`. If no branch slug had matched, the fallback would
   apply instead: existing branches topping out at `task/002-...` and a
   History table high of `001` would give id `003` via max + 1.

### 2. Resume a pre-existing archive folder

If `.task/done/{id}-{slug}/` already exists for the id and slug
chosen in step 1, treat it as this same task's archive from an
earlier `save` that was interrupted partway through — an exact
match on the full folder name means the same id and the same slug,
and two different tasks always get different slugs, so they can
never collide on the full name.

Before proceeding, compare the Goal in the existing folder's
`overview.md` against the Goal in the current `.task/overview.md`.
If they clearly describe different tasks, STOP. Do not archive, do
not reset anything, do not touch git. Report:

> `.task/done/{id}-{slug}/` already exists, but its Goal doesn't
> match the current task's Goal. Tell me how to proceed before I
> overwrite it.

Otherwise, keep the id and slug from step 1 — do not bump the id,
since this is the same task, not a collision — and continue to
steps 3 and 4, where step 4's copy overwrites the files already in
the folder. Say so explicitly in the step 7 report, so the human
knows an earlier interrupted archive was completed rather than a
fresh one created.

### 3. Create archive folder

Create:

    .task/done/{id}-{slug}/

Example: `.task/done/003-add-dark-mode/`

### 4. Copy task files

Copy these files into the archive folder (skip any that don't exist):

- `request.md`
- `overview.md`
- `context.md`
- `plan.md`
- `implementation.md`
- `review.md`
- `testlog.md`

### 5. Reset workspace

Overwrite each active workspace file with its blank template:

**request.md:**
```
# Request

<!-- Paste the original user request below this line -->
```

**overview.md:**
```
# Task Overview

<!-- Generated by overview skill -->
```

**context.md:**
```
# Technical Context

<!-- Generated by context-agent. Overwritten on every task. -->
<!-- Project-level context lives in .task/PROJECT.md — never put it here. -->
```

**plan.md:**
```
# Implementation Plan

<!-- Written by main context from the plan the human pasted (produced by AI web). -->
```

**implementation.md:**
```
# Implementation Summary

<!-- Generated by execute-agent / fix-agent -->
```

**review.md:**
```
# Review

<!-- execute-agent writes the initial self-review. -->
<!-- Fix rounds are appended below as "Fix Notes — Round N" / "Fixes Applied — Round N". -->
```

**testlog.md:**
```
# Manual Test Log

<!-- The human records manual test results here, one section per round. -->
<!-- Paste the relevant findings into the AI web conversation at Step 5. -->

## Round 0 — initial implementation

Result:
- [ ]

Issues found:
-
```

Never archive, reset, or otherwise modify `.task/PROJECT.md` — it is
project-level and persists across tasks.

**Output language.** Read the `Language:` line in `.task/PROJECT.md` `## Language` (missing or unrecognized → `en`). Write all prose you put into `.task/*.md` files and your final report to the human in that language (`vi` = Vietnamese). Always keep in English regardless of setting: every markdown heading (e.g. `## Goal`, `## Acceptance Criteria`, `## Fix Notes — Round N`, `## Fixes Applied — Round N`, `## Round N`) — tooling and routing grep these exact strings; `Base branch:` / `Task branch prefix:` / `Language:` lines; `.task/index.md` table field names, status values (`in-progress`, `done`) and `—` placeholders; template labels such as `Result:` / `Issues found:`; file paths; git branch names and slugs; commit messages and tag names; code, identifiers, and code comments. The blank templates written in this step stay in English regardless of setting — they are structural placeholders, not prose.

### 6. Update index.md and commit

Read the branch name from the Active Task table's Branch field in
`.task/index.md` before clearing it.

In `.task/index.md`:
- Clear the Active Task section (set all fields, including Branch, to `—`)
- Add a row to the History table:
  `| {id} | {slug} | {branch} | {today's date} | done |`

If the target project is not a git repository, skip the commit and note
it in the report.

Otherwise, commit any remaining changes (including the index.md update):

```
git add -A && git commit -m "wip(task): save — {slug}"
```

Then delete this task's round tags so they don't leak into the next task
(round tags are always local to the current task, never pushed or shared):

```
if [ -n "$(git tag -l 'round-*')" ]; then git tag -l 'round-*' | xargs git tag -d; fi
```

Do NOT auto-squash and do NOT auto-merge — history rewriting is the
human's call. Instead, report the branch name and the suggested command
to squash-merge it into the base branch:

```
git checkout {base} && git merge --squash {branch} && git commit
```

### 7. Report

Output:

> Task archived: `.task/done/{id}-{slug}/`
> Workspace reset. Ready for the next task.

If step 2 overwrote a pre-existing archive folder (completing an
earlier interrupted save), say so explicitly here.

If step 0 required the human to confirm archiving an unfinished fix
round, say so explicitly here.

If the project is a git repository, also output the branch name and the
suggested squash-merge command from step 6, along with a warning that
this branch should be merged back into the base branch **before starting
the next task** — the overview skill refuses to start a task unless HEAD
is on the base branch, and the base branch won't contain this task's
archive until the merge happens, so the next task's step 1 will compute
the same ID.

## Rules

- Do not modify production source files.
- Do not modify `.task/PROJECT.md`.
- Do not delete files from `.task/done/`.
- If `.task/index.md` doesn't exist, create it with the History table before updating.
- Never archive an unfinished fix round without the human's explicit confirmation.
