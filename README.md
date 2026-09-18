# Claude++ Workflow

English | [Tiếng Việt](README.vi.md)

A task workflow that pairs an external AI web conversation (ChatGPT/Gemini — a
stronger model, its own quota) with Claude Code (codebase exploration,
implementation, fixes). The web chat does the thinking: planning and
reviewing results. Claude Code gathers compact context and executes
precisely, on cheap `sonnet` subagents, to keep Claude token spend low.

## Why this split

The web chat is the brain, with its own quota separate from Claude's — it
does the planning and the result review, the reasoning-heavy work. Claude
Code is the hands: it explores the codebase, writes tight technical context,
and executes plans literally through cheap subagents. No git diff is ever
sent to the web chat, and the workflow itself never touches git — branches
and commits stay entirely in the human's hands.

Everything that crosses into the web chat is character-budgeted (one web
message is capped at `WEB_CHAR_LIMIT`, 25,000 characters by default), and
whatever doesn't fit is split into attachment files under `.task/web/` that
you attach manually.

## Installing into a project

### Option A — automated, untracked

```
bash bin/install-untracked.sh [--lang en|vi] [--upgrade] /path/to/target
```

`<target-project-path>` must already exist and be a git repository — the
script relies on `.gitignore` to keep everything it installs out of the
target's git status. It copies:

- `.claude/agents/{context-agent.md,execute-agent.md,fix-agent.md}`
- `.claude/instructions/{context.md,execute.md,fix.md}`
- `.claude/skills/save/`
- `.task/` — only if the target has no `.task/` yet (a fresh install; an
  existing `.task/` is left untouched)
- `bin/{copy-for-web.sh,plan-prompt.md,result-prompt.md,save-plan.sh,save-followup.sh}`
  and `bin/lib/{copy-for-web-lib.sh,save-plan-lib.sh}`

It also merges this repo's `CLAUDE.md` (Agent Routing table + hard rules)
into the target's `CLAUDE.local.md` between marker comments, and adds a
matching block to the target's `.gitignore` so none of the above pollutes
the target's shared git history.

Flags:
- `--lang en|vi` (also accepts `--lang=en`) — on a fresh install, sets
  `Language:` in the new `.task/PROJECT.md` (default `en`); ignored if the
  target already has a `.task/`, except under `--upgrade`, which syncs the
  `Language:` line to it regardless.
- `--upgrade` — updates an existing untracked install to the current
  template: overwrites the agent/instruction/skill/bin files, removes
  retired paths from older installs (`bin/diff-for-web.sh`,
  `.claude/skills/overview/`) if present, and refreshes the
  `CLAUDE.local.md`/`.gitignore` marker blocks. Requires a previous install
  (checks for the marker in `CLAUDE.local.md`) and never touches `.task/`
  except syncing the `Language:` line.

If `.claude/agents/*` or `.claude/skills/save/` already exist in the target
with different content, the script aborts before copying anything unless
`--upgrade` is given — see Option B, section c) below.

### Option B — manual, tracked

Use this when you want the workflow files committed into the target repo
instead of gitignored.

#### a) What to copy

Same file set as Option A's copy list above, plus `.task/` (all of it:
`PROJECT.md`, `overview.md`, `context.md`, `plan.md`, `implementation.md`,
`followups.md`, `index.md`, `done/README.md`). Note that
`bin/install-untracked.sh` and `bin/lib/install-untracked-lib.sh` are the
installer itself and are not part of the workflow — don't copy them.

Commit the copied files into the target repo yourself; this workflow never
does it for you. Consider gitignoring `.task/web/` in the target — it's a
scratch directory that `bin/copy-for-web.sh` rebuilds on every run and
`save` deletes when a task is archived.

#### b) Merging when the target project already has a CLAUDE.md

Paste this repo's Agent Routing table and "Hard rules for main context"
section into the target's `CLAUDE.md` (or append them as a new section).

#### c) Merging when the target project already has `.claude/agents/` or `.claude/skills/`

Rename one side (this workflow's `context-agent`/`execute-agent`/`fix-agent`
or `save`, or the target's existing files) so the names don't collide, and
update whichever references point at the old name.

#### d) Verify the install

From the target project root: `bin/copy-for-web.sh --help` should print
usage, and `.task/PROJECT.md` should exist and be ready to fill in.

## Initial setup (one time only)

Fill in `.task/PROJECT.md`: `## Project`, `## Tech Stack`,
`## Architecture Overview`, `## Key Conventions`, `## Source Layout`,
`## Important Files`, `## Known Constraints`, and `## Verify Command` — the
exact shell command (`npm run typecheck`, `swift build`, ...) that
execute-agent and fix-agent must run before reporting done. `## Language`
ships pre-filled with `Language: en`; change it to `vi` for Vietnamese
output. This file is never modified by any agent or skill — you own it.

When `Language: vi`, `bin/copy-for-web.sh` also appends a line to the web
prompt (both planning and result-review payloads) asking the AI web to
answer in Vietnamese: "Write your response in Vietnamese (keep the ##
headings and file paths in English)."

## Step 1 — Claude Code: task overview + context

Say `task: <request>` (alias: `skill overview + context: <request>`, or any
new-task request in plain language). Main context writes your request
verbatim into `.task/overview.md` under `## Original Request`, then
dispatches **context-agent**.

context-agent reads `.task/PROJECT.md` and `.task/overview.md`, explores the
codebase (via CodeGraph if the target has `.codegraph/`), and writes:

- `.task/overview.md` — the full spec (`## Goal`, `## Problem`, `## Scope`,
  `## Out of Scope`, `## Requirements`, `## Constraints`,
  `## Acceptance Criteria`, `## Ambiguities`, `## Notes`), budget ≤ 4,000
  characters
- `.task/context.md` — technical context for the planner (`## Relevant
  Architecture`, `## Relevant Files`, `## Existing Patterns`,
  `## Data Flow`, `## Dependencies`, `## Current Behavior`,
  `## Important Constraints`, `## Potential Risk Areas`,
  `## Relevant Code Snippets`, `## Unknowns`, `## Files to Attach` — max 10
  paths), budget ≤ 12,000 characters
- `.task/index.md` — Active Task section (ID, Name, Started, Status =
  `in-progress`)

## Step 2 — AI web: planning

Run:

```
bin/copy-for-web.sh [--split]
```

With no argument it builds the planning payload — `.task/PROJECT.md` (if it
has real content beyond the Language line), `.task/overview.md`,
`.task/context.md`, prefixed with `bin/plan-prompt.md` — and copies it to
the clipboard. If the payload exceeds `WEB_CHAR_LIMIT` (25,000 by default,
overridable via the environment variable), CONTEXT is split to a
`.task/web/` attachment file first, then PROJECT if still over; `--split`
forces both to attachments regardless of size. A warning (with a per-section
size breakdown) prints at 85% of the limit.

Paste the clipboard content into a **new** web chat, and attach any files
`.task/web/` lists. `bin/plan-prompt.md` asks the web model to question you
first if something critical is ambiguous, otherwise produce a plan with six
fixed sections: `## Summary`, `## Decisions to Review`, `## AC Coverage`,
`## Steps` (a table `| # | File | Change | Notes |`), `## Out of Scope`,
`## Open Questions`. You only need to review the first three sections —
Summary, Decisions to Review, AC Coverage.

## Step 3 — Claude Code: execute

Copy the plan from the web chat, then run:

```
bin/save-plan.sh [--force]
```

It writes the clipboard to `.task/plan.md`, and warns (non-fatally) about
missing required headings, unresolved `## Open Questions`, or `## Steps`
file paths that don't exist and aren't marked as new. It refuses to
overwrite an already-filled `plan.md` unless `--force` is given.

Then tell Claude `run execute` (or `chạy execute`) — main context dispatches
**execute-agent** directly without reading `plan.md` itself. Fallback: paste
a plan straight into the conversation with `implement this plan: <plan>` (or
`triển khai plan này: ...`), and main context writes it to `.task/plan.md`
first.

execute-agent reads `PROJECT.md`, `overview.md`, `plan.md`, checks
`## AC Coverage` against every Acceptance Criterion, and escalates instead
of guessing on a blocking `## Open Questions` entry, an architectural
conflict, or anything security-sensitive. It implements `## Steps` in order,
runs the `## Verify Command` from `PROJECT.md` (up to 3 attempts), and
writes `.task/implementation.md` (`## Changes`, `## Deviations from Plan`,
`## Verify`, `## Manual Test Checklist`), budget ≤ 5,000 characters. No
commit — the workflow doesn't touch git.

## Step 4 — test and fix (loop, no round limit)

Test manually. Two routes, repeat as many times as needed:

**Small/obvious fix** — prompt Claude directly: `fix: ...` / `add: ...` /
`làm thêm: ...` (or any follow-up request). Main context appends
`## Follow-up N` (your request, verbatim) to `.task/followups.md`, then
dispatches **fix-agent**.

**Needs real thinking** — run `bin/copy-for-web.sh result` in the *same* web
chat. It builds a payload from `.task/implementation.md` and
`.task/followups.md` (if it has content), prefixed with
`bin/result-prompt.md`, which asks the web model to list gaps against the
plan/ACs and, if follow-up work is needed, output body-only follow-up
instructions ready to paste. You can add your own manual test findings below
the pasted report before sending. Oversized payloads split FOLLOW-UPS then
IMPLEMENTATION to `.task/web/` attachments. Then run `bin/save-followup.sh`
(no arguments) to append the clipboard as the next `## Follow-up N` — it
warns if the previous one isn't yet marked Applied. Then tell Claude
`run fix` (or `chạy fix`) — main context dispatches **fix-agent** without
reading `followups.md` itself.

fix-agent reads only the current `## Follow-up N` section (not earlier
rounds), applies the smallest safe change, re-runs the Verify Command (up to
3 attempts), and appends `## Follow-up N — Applied` — budget ≤ 1,200
characters per section.

## Step 5 — Claude Code: save the task

Say `save task` (or `lưu task`). The `save` skill:

- blocks if any `## Follow-up N` has no matching `## Follow-up N — Applied`,
  unless you explicitly confirm archiving anyway
- determines the task id/slug from `.task/index.md`'s Active Task (or
  derives one from the Goal in `overview.md` plus a count of
  `.task/done/` subdirectories)
- resumes a matching interrupted archive if `.task/done/{id}-{slug}/`
  already exists for the same Goal
- copies `overview.md`, `context.md`, `plan.md`, `implementation.md`,
  `followups.md` into `.task/done/{id}-{slug}/`
- resets those five files to their blank templates and deletes `.task/web/`
- never touches `.task/PROJECT.md`
- clears the Active Task section in `index.md` and adds a History row

No commit — you own git; the workflow never stages or commits anything.

## Character budget

One web message is capped at `WEB_CHAR_LIMIT` (25,000 characters, override
via the environment variable):

| File / section | Budget |
|---|---|
| `.task/overview.md` | ≤ 4,000 chars |
| `.task/context.md` | ≤ 12,000 chars |
| `.task/implementation.md` | ≤ 5,000 chars |
| each `## Follow-up N — Applied` section | ≤ 1,200 chars |
| `.task/PROJECT.md` (typical) | ~5,000 chars |
| planning prompt (`bin/plan-prompt.md`) | ~2,500 chars |
| **Total per web message** | **25,000 chars** |

Whatever doesn't fit is split into attachment files under `.task/web/` by
`bin/copy-for-web.sh` — attach them in the web chat yourself.

## Directory structure

```
.
├── CLAUDE.md
├── README.md
├── README.vi.md
├── bin/
│   ├── copy-for-web.sh
│   ├── install-untracked.sh
│   ├── plan-prompt.md
│   ├── result-prompt.md
│   ├── save-followup.sh
│   ├── save-plan.sh
│   └── lib/
│       ├── copy-for-web-lib.sh
│       ├── install-untracked-lib.sh
│       └── save-plan-lib.sh
├── .claude/
│   ├── agents/
│   │   ├── context-agent.md
│   │   ├── execute-agent.md
│   │   └── fix-agent.md
│   ├── instructions/
│   │   ├── context.md
│   │   ├── execute.md
│   │   └── fix.md
│   └── skills/
│       └── save/
│           └── SKILL.md
└── .task/
    ├── PROJECT.md
    ├── overview.md
    ├── context.md
    ├── plan.md
    ├── implementation.md
    ├── followups.md
    ├── index.md
    ├── web/            (scratch — rebuilt per copy-for-web.sh run, deleted by save)
    └── done/
        ├── README.md
        └── {id}-{slug}/
```
