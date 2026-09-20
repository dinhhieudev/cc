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

**Normal vs `--lean` (Step 1):**

| Codebase | Path |
|---|---|
| Large or unfamiliar | Normal (`task: ...`) — richer `context.md` for the planner |
| Small, or you already know the area | `--lean` (`task (lean): ...`) — saves Claude tokens, costs one extra round trip |

**Direct fix vs web round-trip (Step 4 follow-ups):**

| Follow-up | Path |
|---|---|
| Obvious small fix you already know how to describe | Prompt Claude directly: `fix: ...` |
| Unclear bug, or a gap in the plan that needs judgment | Route through web: `bin/copy-for-web.sh result` |

## Installing into a project

### Option A — automated, untracked

```
bash bin/install-untracked.sh [--lang en|vi] [--upgrade] /path/to/target
```

`<target-project-path>` must already exist and be a git repository — the
script relies on the target's local-only `.git/info/exclude` to keep
everything it installs out of the target's git status. It copies:

- `.claude/agents/{context-agent.md,execute-agent.md,fix-agent.md}`
- `.claude/instructions/{context.md,execute.md,fix.md}`
- `.claude/skills/save/`
- `.task/` — only if the target has no `.task/` yet (a fresh install; an
  existing `.task/` is left untouched)
- `bin/{copy-for-web.sh,plan-prompt.md,result-prompt.md,save-plan.sh,save-followup.sh,attach.sh,lean-note.md}`
  and `bin/lib/{copy-for-web-lib.sh,copy-for-web-design.sh,copy-for-web-result.sh,copy-for-web-modes.sh,copy-for-web-lean.sh,copy-for-web-handoff.sh,save-plan-lib.sh}`

It also merges this repo's `CLAUDE.md` (Agent Routing table + hard rules)
into the target's `CLAUDE.local.md` between marker comments, and adds a
matching block to the target's `.git/info/exclude` — never the tracked
`.gitignore` — so none of the above pollutes the target's shared git
history. `.git/info/exclude` is per-clone (not versioned), so re-run the
installer after cloning the target on another machine. If an earlier
install left a claude++ block in the target's `.gitignore`, every run
removes it (rest of the file untouched) and tells you to commit that
removal once if the block was ever committed.

Flags:
- `--lang en|vi` (also accepts `--lang=en`) — on a fresh install, sets
  `Language:` in the new `.task/PROJECT.md` (default `en`); ignored if the
  target already has a `.task/`, except under `--upgrade`, which syncs the
  `Language:` line to it regardless.
- `--upgrade` — updates an existing untracked install to the current
  template: overwrites the agent/instruction/skill/bin files, removes
  retired paths from older installs (`bin/diff-for-web.sh`,
  `.claude/skills/overview/`) if present, and refreshes the
  `CLAUDE.local.md`/`.git/info/exclude` marker blocks. Requires a
  previous install (checks for the marker in `CLAUDE.local.md`) and
  never touches `.task/` except syncing the `Language:` line.

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
`## Important Files`, `## Known Constraints`, and the verify commands —
`## Codegen / Setup Command` (regenerates code or fetches dependencies,
run before type check when the change touches models, dependencies, l10n
strings, or assets — e.g. `dart run build_runner build`, `pod install`),
`## Type Check Command` (fast, required), `## Build Command` (gated by an
optional `Build policy: native-only|always|never` line, default
`native-only` — builds only when native config, dependencies, codegen,
platform files, or build settings changed), `## Test Command`, and
`## Device Smoke Test Command`. The last three accept either one command
or one line per platform (`ios: ...` / `android: ...`); when a task
affects both, iOS runs first and Android runs only if the change is
Android-specific. `## Language` ships pre-filled with `Language: en`;
change it to `vi` for Vietnamese output. This file is never modified by
any agent or skill except the `save` skill, which may append bullets you
approve in Step 5 — otherwise you own it.

When `Language: vi`, `bin/copy-for-web.sh` also appends a line to the web
prompt (both planning and result-review payloads) asking the AI web to
answer in Vietnamese: "Write your response in Vietnamese (keep the ##
headings and file paths in English)."

### Human-runs profile (no automated build/run)

When the human owns build/run/manual test — Claude agents never run
builds or launch the app; the human builds, runs, and manually tests,
then reports problems — configure `Build policy: never`, leave
`## Device Smoke Test Command` empty, and keep `## Codegen / Setup
Command` and `## Type Check Command` filled in. Codegen still runs
(`build_runner`, `pod install`, `gen-l10n`) because the type check
depends on generated files — it is not skippable.

| Project | Type Check Command | Test Command | Build policy |
|---|---|---|---|
| Flutter | `dart analyze` | `flutter test` | `never` |
| Android native | `./gradlew compileDebugKotlin` | `./gradlew testDebugUnitTest` | `never` |
| Android KMP | `./gradlew compileKotlinJvm` | `./gradlew jvmTest` | `never` |
| iOS native | `xcodebuild build -scheme <Scheme> -destination 'generic/platform=iOS' -quiet` | `swift test` for SPM logic packages, else empty | `never` |

Pick test commands that do NOT boot a simulator or emulator. For KMP,
avoid `./gradlew allTests` — it pulls in iOS targets and boots a
simulator.

- `generic/platform=iOS` builds for device architecture and never boots a
  simulator. It is a full compile, so the first cold run takes minutes,
  but incremental warm runs are roughly 20-60s because of the
  derived-data cache.
- Only `xcodebuild test` against an iOS-only test target needs a booted
  simulator. Logic that lives in a platform-agnostic SwiftPM package can
  be tested with `swift test` on the macOS host instead — seconds, no
  simulator.

iOS native has no *cheap* type check — the cheapest correct one is a full
incremental build, unlike `dart analyze` or `compileDebugKotlin`. If that
cost is acceptable, put the `generic/platform=iOS` build in the Type
Check slot and iOS native is covered like the other three. If it is not,
leave Type Check empty and accept zero automated verification:
execute-agent must then state explicitly in `.task/implementation.md`
that no verify command is configured rather than silently skipping, and
the only remaining automated guard is the escalation rule (a new
dependency, permission, entitlement, or Info.plist/AndroidManifest change
not listed in the plan stops the agent). Also note: sharing the default
DerivedData with an open Xcode can cause lock contention — pass
`-derivedDataPath` to a separate directory if that becomes a problem.

## Step 1 — Claude Code: task overview + context

Say `task: <request>` (alias: `skill overview + context: <request>`, or any
new-task request in plain language). Main context writes your request
verbatim into `.task/overview.md` under `## Original Request`, then
dispatches **context-agent**.

Example: `task: add a dark-mode toggle to the settings screen`. (This
example carries through Steps 1-5 below.)

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
  `spec`). Status then advances: `planned` when `bin/save-plan.sh` saves a
  plan, `executing` when execute-agent starts, `fixing` when a follow-up
  round starts, `done` when the task is saved.

**Lean alternative** — for a small project, or when you already know the area: say
`task (lean): <request>` (alias: `task lean: <request>`) instead. context-agent writes
only `.task/overview.md` (same spec, same budget) from `.task/PROJECT.md`, your request,
and at most 3 files you name explicitly — it does not otherwise explore the codebase, and
leaves `.task/context.md` as its blank template. This saves Claude tokens at the cost of
one extra round trip with the web planner; for a large, unfamiliar codebase the normal
path's `context.md` gives the planner better context, so prefer that instead. Continue at
Step 2 with `bin/copy-for-web.sh --lean` rather than the plain form.

**Design reference (optional)** — drop reference screenshots for a UI task into
`.task/design/` any time before Step 2; plan-mode `bin/copy-for-web.sh` auto-attaches them
(see Step 2). Claude Code never opens these images itself, only forwards them — the AI web
planner reads them directly. If you give context-agent a Figma link and this project has
Figma MCP configured, it extracts a text description into `.task/context.md`'s CONTEXT
section as usual (Figma MCP is optional; skipped gracefully when not available).

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

If `.task/design/` has reference screenshots, they're auto-attached the same way
(listed under `--- DESIGN REFERENCE (attached) ---`) — attach those too.
`bin/plan-prompt.md` asks the web planner to cross-check each screenshot against any
Figma-derived description in CONTEXT and flag mismatches as a Decision to Review or Open
Question; with no such description, the screenshot alone is the source of truth for layout.

Paste the clipboard content into a **new** web chat, and attach any files
`.task/web/` lists. `bin/plan-prompt.md` asks the web model to question you
first if something critical is ambiguous, otherwise produce a plan with six
fixed sections: `## Summary`, `## Decisions to Review`, `## AC Coverage`,
`## Steps` (a table `| # | File | Change | Notes |`), `## Out of Scope`,
`## Open Questions`. You only need to review the first three sections —
Summary, Decisions to Review, AC Coverage.

For the dark-mode example, a plausible (illustrative, not literal-format)
excerpt of what comes back:

```
## Decisions to Review
- Persist the toggle via SharedPreferences, not a new state-management
  provider — avoids adding a dependency for a single boolean.

## AC Coverage
- AC1 (toggle visible in Settings): Step 1
- AC2 (persists across restarts): Step 1

## Steps
| # | File | Change | Notes |
|---|---|---|---|
| 1 | lib/settings/settings_screen.dart | Add dark-mode Switch, wire to ThemeProvider | persists via SharedPreferences |
```

**Lean alternative** — after `bin/copy-for-web.sh --lean` (see Step 1), the payload swaps
`.task/context.md` for a FILE TREE of the project (`git ls-files`, or a pruned `find`
outside a git repo) and adds `bin/lean-note.md` to the prompt, asking the web planner to
first reply with the files it wants (at most 15 paths from the tree) before producing a
plan. Run `bin/attach.sh <path> [<path>...]` to copy those files into `.task/web/`
(flattened, with the mapping and a running character count printed; also accepts `-` to
read paths from stdin), attach them in the same web chat, and ask for the plan — then
continue at Step 3 unchanged. An oversized FILE TREE degrades: noisy files (lockfiles,
images, `*.min.*`, `.task/**`) drop first, then it collapses to per-directory
`dir/ (N files)` counts, then the full tree is attached as `.task/web/file-tree.txt`;
`--split` forces the FILE TREE and PROJECT straight to attachments.

Worked round-trip: `task (lean): add a dark-mode toggle to the settings
screen`, then `bin/copy-for-web.sh --lean`. The web might reply with an
illustrative (fake) list like:

```
1. lib/settings/settings_screen.dart
2. lib/theme/theme_provider.dart
```

Then `bin/attach.sh lib/settings/settings_screen.dart lib/theme/theme_provider.dart`
prints:

```
lib/settings/settings_screen.dart -> lib__settings__settings_screen.dart
lib/theme/theme_provider.dart -> lib__theme__theme_provider.dart
Total chars now in .task/web: 3214
```

Attach both files in the web UI, ask for the plan, and continue at Step 3.

## Step 3 — Claude Code: execute

Default: copy the plan from the web chat and paste it straight into the
conversation with `implement this plan: <plan>` (or `triển khai plan này:
...`, or just the plan text itself). Claude writes it verbatim to
`.task/plan.md` (overwriting whatever was there), runs `bin/save-plan.sh
--check` to validate it, reports any warnings in a line or two, and
dispatches **execute-agent** anyway — warnings are informational, not
blocking.

Cheaper alternative, if you'd rather the plan never enter the Claude
conversation: copy the plan from the web chat, then run:

```
bin/save-plan.sh [--force] | --stdin [--force] | --check
```

With no flags it reads the clipboard and writes it to `.task/plan.md`,
running the same validation, and warns (non-fatally) about missing required
headings, unresolved `## Open Questions`, a `## Decisions to Review` section
that looks thin (short bullets with no visible reasoning), or `## Steps`
file paths that don't exist and aren't marked as new. It refuses to overwrite an
already-filled `plan.md` unless `--force` is given. `--stdin` reads the plan
from stdin instead of the clipboard (e.g. `cat plan.txt | bin/save-plan.sh
--stdin`) and otherwise behaves exactly like the clipboard route. `--check`
validates the existing `.task/plan.md` in place — no clipboard read, no
write — and errors only if the file is missing or still a placeholder.

Then tell Claude `run execute` (or `chạy execute`) — main context dispatches
**execute-agent** directly without reading `plan.md` itself.

execute-agent reads `PROJECT.md`, `overview.md`, `plan.md`, checks
`## AC Coverage` against every Acceptance Criterion, and escalates instead
of guessing on a blocking `## Open Questions` entry, an architectural
conflict, anything security-sensitive, or a new dependency/permission/
entitlement/manifest change the plan doesn't list. It implements `## Steps`
in order, then runs codegen/setup (when relevant), type check, build
(gated by `Build policy:`), and tests/device smoke — one command per
platform when configured, iOS first — up to 3 attempts, and writes
`.task/implementation.md` (`## Changes`, `## Deviations from Plan`,
`## Verify`, `## Manual Test Checklist`, `## PROJECT.md Candidates`), budget
≤ 6,000 characters. For UI tasks, the Manual Test Checklist asks you to
save result screenshots into `.task/design/result/`. No commit — the
workflow doesn't touch git.

For the dark-mode example, an illustrative `## Changes` line:
`- lib/settings/settings_screen.dart: added dark-mode toggle, persists via SharedPreferences`

## Step 4 — test and fix (loop, no round limit)

Test manually. Two routes, repeat as many times as needed:

**Small/obvious fix** — prompt Claude directly: `fix: ...` / `add: ...` /
`làm thêm: ...` (or any follow-up request). Main context appends
`## Follow-up N` (your request, verbatim) to `.task/followups.md`, then
dispatches **fix-agent**.

For the dark-mode example, say testing turns up a bug: `fix: toggling
twice re-triggers the API call`. fix-agent patches it and appends
`## Follow-up 1 — Applied` to `.task/followups.md`.

If manual testing produced a crash, capture the log yourself —
`xcrun simctl spawn booted log show --last 2m` for iOS, `adb logcat -d`
for Android — then either paste the top ~30 frames into the `fix: ...`
request (direct route), or write it to a file and run
`bin/attach.sh <file>` to send it along with the web round-trip below.

**Needs real thinking** — run `bin/copy-for-web.sh result` in the *same* web
chat. It builds a payload from `.task/implementation.md` and
`.task/followups.md` (if it has content), prefixed with
`bin/result-prompt.md`, which asks the web model to list gaps against the
plan/ACs and, if follow-up work is needed, output body-only follow-up
instructions ready to paste. You can add your own manual test findings below
the pasted report before sending. If you saved screenshots to
`.task/design/result/`, they're attached automatically (listed under
`--- RESULT SCREENSHOTS (attached) ---`) and compared against the design
reference by `bin/result-prompt.md`. Add `--diff` to also attach a
filtered `git diff` (tracked + untracked changes, excluding `.task/`,
lockfiles, `.pbxproj`, and generated files) as `.task/web/changes.diff.txt`,
capped at `WEB_DIFF_MAX_BYTES` (100,000 bytes by default) — off by default
since diffs are often too long; it warns instead of failing outside a git
repo or when there's nothing to diff. Oversized payloads split FOLLOW-UPS then
IMPLEMENTATION to `.task/web/` attachments. Then run `bin/save-followup.sh`
(no arguments) to append the clipboard as the next `## Follow-up N` — it
warns if the previous one isn't yet marked Applied. Then tell Claude
`run fix` (or `chạy fix`) — main context dispatches **fix-agent** without
reading `followups.md` itself.

fix-agent reads only the current `## Follow-up N` section (not earlier
rounds), applies the smallest safe change, re-runs the Verify Command (up to
3 attempts), and appends `## Follow-up N — Applied` — budget ≤ 1,400
characters per section.

**Fresh chat** — if the *same* web chat above has gotten too long or lost
context, run `bin/copy-for-web.sh handoff` instead of `result` and paste it
into a **new** web chat. It sends a short intro plus an OVERVIEW SUMMARY
(`## Goal` + `## Acceptance Criteria`), the plan's `## Steps` table, and the
latest Follow-up round (or `implementation.md`'s Changes/Deviations),
asking the web to confirm it understands before continuing — no need to
retype the original context. Oversized payloads split OVERVIEW SUMMARY then
CURRENT PLAN STEPS to `.task/web/` attachments. Continue the loop above in
that new chat.

Concrete cue: after 4-5 follow-up rounds in the same web chat, replies
start getting slower or losing earlier details — that's when to run
`bin/copy-for-web.sh handoff`.

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
- shows you any `## PROJECT.md Candidates` bullets from `implementation.md`
  and `PROJECT.md candidate` lines from `followups.md`, and appends only
  the ones you approve to the matching section of `.task/PROJECT.md` — its
  one exception to never touching that file
- resets those five files to their blank templates and deletes `.task/web/`
- clears the Active Task section in `index.md` and adds a History row

For the dark-mode example, a candidate might read: "Key Conventions:
dark-mode state persists via SharedPreferences, not a global provider" —
you reply `add it` to approve, or `skip` to decline.

No commit — you own git; the workflow never stages or commits anything.

## Character budget

One web message is capped at `WEB_CHAR_LIMIT` (25,000 characters, override
via the environment variable):

| File / section | Budget |
|---|---|
| `.task/overview.md` | ≤ 4,000 chars |
| `.task/context.md` | ≤ 12,000 chars |
| `.task/implementation.md` | ≤ 6,000 chars |
| each `## Follow-up N — Applied` section | ≤ 1,400 chars |
| `.task/PROJECT.md` (typical) | ~5,000 chars |
| planning prompt (`bin/plan-prompt.md`) | ~3,500 chars |
| **Total per web message** | **25,000 chars** |

Whatever doesn't fit is split into attachment files under `.task/web/` by
`bin/copy-for-web.sh` — attach them in the web chat yourself.

Every `bin/copy-for-web.sh` run also writes the exact payload to
`.task/web/_message.md` — paste it by hand when driving the session
remotely without clipboard access.

## Directory structure

```
.
├── CLAUDE.md
├── README.md
├── README.vi.md
├── bin/
│   ├── attach.sh
│   ├── copy-for-web.sh
│   ├── install-untracked.sh
│   ├── lean-note.md
│   ├── plan-prompt.md
│   ├── result-prompt.md
│   ├── save-followup.sh
│   ├── save-plan.sh
│   └── lib/
│       ├── copy-for-web-design.sh
│       ├── copy-for-web-handoff.sh
│       ├── copy-for-web-lean.sh
│       ├── copy-for-web-lib.sh
│       ├── copy-for-web-modes.sh
│       ├── copy-for-web-result.sh
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
