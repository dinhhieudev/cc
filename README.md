# Claude++ Workflow

A feature-development workflow that pairs **Claude Code** with an **AI web** conversation (ChatGPT / Gemini).

Claude Code handles the codebase (exploration, implementation, fixes, git). The AI web handles planning and review.
You review at each checkpoint and are the only one who moves content back and forth between the two sides.

---

## Subagents — why and where each step runs

Steps that are heavy on codebase work run in a **dedicated subagent** so the main context doesn't fill up:

| Step | Runs in | Why |
|---|---|---|
| 1 — Overview + create branch | Main context | Light — just reads the prompt, writes a file, creates a git branch |
| 1 — Context | **context-agent** | Reads many codebase files → split out |
| 3 — Execute | **execute-agent** | Implements many changes → split out |
| 6 — Fix | **fix-agent** | Reads files + applies fixes → split out |
| 7 — Save | Main context | Light — just copies files, commits, and resets |

You don't need to do anything extra — Claude routes to the right subagent automatically per the table in `CLAUDE.md`.

Subagents **cannot see** the main conversation. Anything you paste
(plan, fix list) is written to a file by main context first, then the subagent is dispatched.

---

## Installing into a project

This is a template repo — copy it into your target project before use.
Two ways to do that:

- **Option A — automated, untracked** (recommended when the target
  project's team hasn't agreed to use this workflow, or you just don't
  want the workflow's files showing up in `git status`/history).
- **Option B — manual, tracked** (the workflow's files, including
  `.task/`, are committed into the target repo like any other project
  file — see the Directory Structure section at the end of this README).

### Option A — automated, untracked

From this template repo:

```bash
bash bin/install-untracked.sh /path/to/target-project
```

Requires the target to already be a git repository. The script:
- copies `.claude/agents/`, `.claude/instructions/`, `.claude/skills/{overview,save}/`,
  `.task/` (skipped if the target already has one — never overwrites existing task history),
  and `bin/{copy,diff}-for-web.sh` into the target
- merges the Agent Routing table + hard rules from this repo's `CLAUDE.md`
  into `<target>/CLAUDE.local.md` instead of touching the target's own `CLAUDE.md`
- appends a marker-delimited block to `<target>/.gitignore` covering every
  file it just copied, so none of it is ever staged

It aborts before copying anything if `.claude/agents/{context,execute,fix}-agent.md`
or `.claude/skills/{overview,save}/` already exist in the target with
different content (see Option B, part c below, for how to resolve that by
hand). Safe to re-run — an install identical to what's already there is a
no-op, not an error.

After it finishes, skip straight to filling in `.task/PROJECT.md`
(see "Initial setup" below) — parts a-e below don't apply to this path.

### Option B — manual, tracked

#### a) What to copy

From this template repo into the root of the target project:

```
.claude/agents/
.claude/instructions/
.claude/skills/overview/
.claude/skills/save/
.task/
bin/
CLAUDE.md
```

Example:
```
cp -R .claude/agents .claude/instructions <target>/.claude/
cp -R .claude/skills/overview .claude/skills/save <target>/.claude/skills/
cp -R .task bin CLAUDE.md <target>/
```

`.task/done/` must be copied too (it comes with its own `README.md`). The
other `.task/*.md` files arrive as empty templates — that's expected; only
`.task/PROJECT.md` needs to be filled in by hand.

#### b) Merging when the target project already has a CLAUDE.md

Don't overwrite it. Merge the template's CLAUDE.md content into the
project's existing CLAUDE.md, keeping in full:
- the `## Agent Routing` table (every row)
- the `N for ## Fix Notes — Round N` paragraph right below the table
- the `## Hard rules for main context` list (all 6 rules)

Note: this template's CLAUDE.md does **not** use an `@.task/PROJECT.md`
style import — PROJECT.md is read explicitly by each
`.claude/instructions/*.md` file, so it loads exactly once per agent.
Don't add that kind of import when merging.

#### c) Merging when the target project already has `.claude/agents/` or `.claude/skills/`

Names must not collide: `context-agent`, `execute-agent`, `fix-agent`,
`overview`, `save`. If any name already exists in the target project,
rename one side and update every reference (the `Agent Routing` table in
CLAUDE.md, and the pointer to `.claude/instructions/*.md` in the
corresponding agent file).

#### d) Commit `.task/` into the target project

`.task/` should be committed into the target project's repo — see the
Directory Structure section at the end of this README for details.

#### e) Verify the install

From the root of the target project:
- `bash bin/copy-for-web.sh --help` must print usage.
- `bash bin/copy-for-web.sh` (with no task yet) must fail cleanly, reporting
  that `.task/overview.md` is still a placeholder — this proves the script
  is pointed at the target project's own `.task/`.

---

## Initial setup (one time only)

Fill in `.task/PROJECT.md` — project-level context that no agent or skill overwrites:

- `Tech Stack`, `Architecture Overview`, `Key Conventions`, `Source Layout`,
  `Important Files`, `Known Constraints` — as usual.
- `## Verify Command` — a shell command that proves the build/typecheck is
  clean (e.g. `npm run typecheck`, `swift build`). execute-agent and
  fix-agent **must** run this command before reporting done.
- `## Git` — `Base branch` (default `main`) and `Task branch prefix`
  (default `task/`).

`.task/context.md` is **auto-generated per task** (written by context-agent
each time) — **never hand-edit this file**, any changes will be overwritten
on the next task.

---

## Step 1 — Claude Code: analyze the request + create branch

**Prompt:**
```
skill overview + context: [describe the request, can include file names or pasted code]
```

**Example:**
```
skill overview + context: fix the login feature, need to save token and
refresh token to keychain after the login API call succeeds @login.dart
```

Claude runs overview in main context → creates a task branch (`{prefix}{id}-{slug}`
from the base branch in `.task/PROJECT.md`) → invokes the **context-agent**
subagent itself to explore the codebase. If the working tree is dirty,
Claude stops and asks you to commit/stash first. The task must also start
from the base branch configured in `.task/PROJECT.md` — if HEAD is on a
different branch, Claude stops and asks you to switch to the base branch first.

**Output:** `.task/overview.md` + `.task/context.md`, task branch created, `.task/index.md` updated with the branch.

**Verify before moving to Step 2:**
- overview.md: after reading the Goal, can you tell when the task is "done"?
- context.md: does the data flow match the real architecture? Is there an Unknowns section?

---

## Step 2 — AI web: planning

Open a **new AI web conversation**. Keep this conversation open for the whole task.

Run `bin/copy-for-web.sh` (no arguments) — it copies the contents of
`PROJECT.md` + `overview.md` + `context.md` to the clipboard. Paste into the AI web along with:

```
Below is the project context, task overview, and technical context of a codebase.

[paste clipboard]

Produce a detailed, step-by-step implementation plan.
Specify exactly which files need to change and what the change is.
No code yet — just the plan.
```

Review and refine in the AI web until you're satisfied. Copy the final plan.

**Verify the plan before moving to Step 3:**
- Does the plan name a concrete file for every step?
- Does it address every Acceptance Criterion in overview.md?

---

## Step 3 — Claude Code: implement

**Recommended (saves tokens):** copy the plan from the AI web, then from the
project root run:
```
pbpaste > .task/plan.md
```
(`pbpaste` is macOS; on Linux use `xclip -o > .task/plan.md` or
`xsel -b > .task/plan.md`)

Then just tell Claude:
```
plan saved to .task/plan.md, run execute
```

Main context doesn't need to load the full plan into the conversation —
only execute-agent reads the file, saving tokens.

**Fallback** (when the clipboard route isn't convenient) — paste directly,
and main context writes it to `.task/plan.md` for you:
```
implement this plan:
[paste plan from AI web]
```

Either way, once `.task/plan.md` has a plan, Claude calls the
**execute-agent** subagent to implement it. execute-agent runs the Verify
Command from `.task/PROJECT.md`, which must pass before review.md is
written — if it doesn't pass, it retries fixes, or stops and reports the
failure if it can't fix it.

**Output:** code changes + `.task/review.md` (self-review) + `.task/testlog.md`
(Round 0 scaffold) + a `round-0` commit (tagged `round-0`) on the task branch.

**If execute-agent stops and escalates:** instead of implementing, the agent
may stop and report "what it found / why the plan is insufficient / what
decision is needed" (e.g. an architectural conflict, or the plan conflicting
with the real codebase). Paste that report into the same open AI web
conversation, ask it to revise the plan to resolve the decision, then
re-run Step 3 with the revised plan.

---

## Step 4 — Manual test

Build the app and test it for real. Record the results in `.task/testlog.md`
(the `## Round 0` scaffold is already there — check off the checklist and
note any issues found).

---

## Step 5 — AI web: review

Go back to the **open AI web conversation** (which already has the plan from Step 2).

Run `bin/diff-for-web.sh` (no arguments) to copy the full diff of the task
branch against the base branch to the clipboard.
Paste into the AI web along with `.task/review.md`:

```
Here is the actual diff and Claude's self-review after implementation.

--- DIFF ---
[paste clipboard from bin/diff-for-web.sh]

--- REVIEW ---
[paste the full contents of .task/review.md]

--- MANUAL TEST RESULTS (if any) ---
[paste the relevant part of .task/testlog.md, or describe the issue found]

Compare the diff against the plan we agreed on above: is the implementation
correct, complete, and within scope? List what needs to be fixed. If
everything looks good, say explicitly that no fixes are needed.
```

The plan is already in this conversation from Step 2, so the AI web uses
the diff to check plan-vs-code — something a self-review alone can't prove.
The diff is the **evidence**, review.md is the **map** — use both.

**If the AI web says no fixes are needed → Step 7.**
**If the AI web returns a fix list → Step 6.**

---

## Step 6 — Claude Code: fix (repeat up to 3 rounds)

**Recommended (saves tokens):** copy the fix list from the AI web, then from
the project root run (replace `N` with the actual round number):
```
printf '\n## Fix Notes — Round N\n\n' >> .task/review.md && pbpaste >> .task/review.md
```
`N` = (number of `## Fix Notes — Round` headings already in
`.task/review.md`) + 1 — the same rule main context uses.

Then just tell Claude (replace `N` with the actual round number):
```
fix notes round N saved, run fix
```

**Fallback** (when the clipboard route isn't convenient) — paste directly,
and main context appends it to `.task/review.md` for you:
```
fix this list:
[paste fix list from AI web]
```

Either way, once `## Fix Notes — Round N` exists in `.task/review.md`,
Claude calls the **fix-agent** subagent to apply the fixes. fix-agent also
runs the Verify Command before recording the result.

**Output:** code fixes + `## Fixes Applied — Round N` in review.md +
a new `## Round N` scaffold in testlog.md + a `round-N` commit/tag +
a **delta summary** at the end of the response.

**Loop:**
1. Test manually again (Step 4), recording the corresponding round in `.task/testlog.md`.
2. Run `bin/diff-for-web.sh N` — copies the delta diff for round N (`round-{N-1}..round-N`).
   If the delta diff is too large, narrow it with `bin/diff-for-web.sh N --files path/to/File.swift`.
3. Go back to the AI web (same conversation) and paste the **delta summary** + **delta diff** instead of the full review.md.
4. Repeat Step 6 → 4 → 5 until the AI web confirms no more fixes are needed.

**When to stop:** the fix loop is capped at **3 rounds max**. If a 4th round
is requested, Claude stops and asks you to decide: accept as-is, go back to
planning, or narrow scope.

---

## Step 7 — Claude Code: save the task

Only do this once the AI web confirms no more fixes are needed.

**Prompt:**
```
save task
```

Claude commits any remaining changes, archives all task files into
`.task/done/`, resets the workspace (except `.task/PROJECT.md` — never
touched), and updates `.task/index.md`.

Save **does not auto-squash or auto-merge** — that's your call. Claude
reports the branch name and a suggested command:

```
git checkout {base} && git merge --squash {branch} && git commit
```

You should merge this branch back into the base branch **before starting
the next task** — Step 1 of the next task only runs when HEAD is on the
base branch (overview will stop otherwise).

IDs no longer collide, since `overview` scans existing task branches too
(including unmerged ones), not just `.task/done/`.

---

## Directory structure

```
CLAUDE.md              Agent routing table + hard rules for main context

bin/
  install-untracked.sh Installs this workflow into another project, gitignored (Option A)
  copy-for-web.sh       Copies PROJECT.md + overview.md + context.md to the clipboard (Step 2)
  diff-for-web.sh       Copies the git diff to the clipboard (Step 5/6)

.claude/
  agents/
    context-agent.md   Codebase exploration (subagent)
    execute-agent.md   Code implementation (subagent)
    fix-agent.md       Bug fixing (subagent)
  instructions/
    context.md         Instructions for context-agent (not a skill)
    execute.md         Instructions for execute-agent (not a skill)
    fix.md             Instructions for fix-agent (not a skill)
  skills/
    overview/          Request analysis + branch creation (main context)
    save/              Task archiving (main context)

.task/
  PROJECT.md            Project context + Verify Command + Git config (filled in once, never overwritten by any agent)
  index.md              List of all tasks
  request.md            Original request (created by the overview skill)
  overview.md           Task spec (created by the overview skill)
  context.md            Per-task technical context (created by context-agent, regenerated each task)
  plan.md               Implementation plan (from the AI web)
  implementation.md     Implementation summary
  review.md             Self-review + per-round fix history
  testlog.md            Manual test results per round
  done/                 Archive of completed tasks
```

`.task/` **should be committed** into the project's repo if installed via Option B — it's
the task's record. If installed via Option A, `.task/` is gitignored on purpose instead.
`bin/diff-for-web.sh` automatically excludes `.task/` from the diff so the AI web only sees real code.
