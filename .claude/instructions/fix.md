# Fix

Apply a follow-up fix or extra work for the current task.

## Inputs

Find the latest `## Follow-up N` in `.task/followups.md` that has no
matching `## Follow-up N — Applied`. If none exists, STOP and report
exactly:

> No pending follow-up in `.task/followups.md`. Main context must append
> the request as `## Follow-up N` before dispatching fix-agent.

Read, in order:

    .task/PROJECT.md
    .task/overview.md
    .task/plan.md

Then read only the current `## Follow-up N` section of
`.task/followups.md`. Do not read the entire follow-up history — earlier
rounds are irrelevant to the current one.

Set `.task/index.md` Active Task Status to `fixing`, then inspect the actual codebase.

Follow-up requests may come from the human directly (a quick fix/add
request) or from AI web review; treat both the same way.

## Priority

1. Actual codebase
2. Approved implementation plan
3. Current `## Follow-up N` request
4. Task overview

**Output language.** Read the `Language:` line in `.task/PROJECT.md` `## Language` (missing or unrecognized → `en`). Write all prose you put into `.task/*.md` files and your final report to the human in that language (`vi` = Vietnamese). Always keep in English regardless of setting: every markdown heading (e.g. `## Goal`, `## Acceptance Criteria`, `## Follow-up N`, `## Follow-up N — Applied`) — tooling and routing grep these exact strings; the `Language:` line; `.task/index.md` table field names, status values (`spec`, `planned`, `executing`, `fixing`, `done`) and `—` placeholders; file paths; task slugs; code, identifiers, and code comments.

## Token Discipline

The `## Follow-up N` request is the source of instructions. Read only the
files it names plus what is strictly needed to apply the change
correctly — no broad re-exploration. Do not restate the request in your
report; keep the final report to ~10 lines pointing at `followups.md`.

## Objective

Resolve the request with the smallest safe change. The goal is NOT to
redesign the feature.

## Workflow

### 1. Validate

Verify the request against the actual codebase. If it came from AI web
review, it may be wrong — do not change code solely because it was
suggested; confirm the issue actually exists first.

### 2. Fix

Prefer the smallest change that:
- resolves the request
- preserves the approved architecture
- preserves existing behavior
- avoids scope expansion

If the request requires a significant architectural change, stop and
report it (see Escalation) instead of making a large assumption.

### 3. Re-check

After fixing:
- inspect changed code
- review the diff
- verify no obvious regressions
- run verify commands from `.task/PROJECT.md` in order:
  0. `## Codegen / Setup Command` — run first when the change touches
     models/serialization, dependencies, l10n strings, assets, or adds
     files needing registration; else record `skipped (not needed)`
  1. `## Type Check Command` — fast; required if present
  2. `## Build Command` — gated by its `Build policy:` line (absent =
     `native-only`): `always` runs it; `never` records
     `skipped (policy)`; `native-only` runs it only when the change
     touches native config, dependencies, codegen, platform folders, or
     build settings, else records `skipped (policy)`
  3. `## Test Command` — run after build when present
  4. `## Device Smoke Test Command` — run when present and relevant
  Backward compat: if only the old `## Verify Command` field is present,
  treat it as the type check step. Empty optional commands are skipped and
  must be recorded as skipped, never reported as passed.

**Per-platform commands.** Build/Test/Device Smoke slots may hold one line
per platform (`ios: <command>` / `android: <command>`) instead of a single
command. Run only the platforms the follow-up affects — inferred from the
files changed (fix-agent does not read context.md). iOS always runs
first; when both platforms are affected, run Android only if the change
touches Android-specific files/behavior, else record it
`skipped (ios-priority)`.

**Long-running commands.** Run codegen/build/test commands with the
maximum Bash timeout, or in the background and wait for them — mobile
builds routinely exceed the default 2-minute timeout. A tool timeout is
not a verify failure: rerun with more time and do not count it toward
the 3 attempts below.

Do not read the whole verify log into context: redirect its output to a
temp file, then read back only the last ~50 lines plus any lines
matching an error/warning pattern, errors before warnings (e.g.
`{command} > /tmp/verify.log 2>&1; tail -n 50 /tmp/verify.log; grep -iE
'error|failed' /tmp/verify.log | head -30; grep -i 'warning'
/tmp/verify.log | head -10`). Record only the pass/fail verdict and the
essential error lines in the `## Follow-up N — Applied` section.

Every configured verify command must pass before proceeding. Run
codegen/setup first, then type check, then build, then tests. If any
command fails, fix the code and rerun the pipeline from type check, up to
3 full attempts total (codegen/setup reruns only if its inputs changed
since the previous attempt).

If `.task/PROJECT.md` has no type check, build, test, or verify command filled in, say so explicitly
in the Applied section instead of silently skipping this step.

### 4. Append to followups.md

Whether verify passed or failed after 3 attempts, append
`## Follow-up N — Applied` at the END of `.task/followups.md` (sections
stay in order: request N, applied N, request N+1, ...):

```
## Follow-up N — Applied
- `path/to/file`: what changed, 1 line

Verify:
- Codegen/setup: {command} → pass|fail|skipped (reason)
- Type check: {command} → pass|fail|skipped
- Build: {command} → pass|fail|skipped (reason)
- Tests: {command} → pass|fail|skipped
- Device smoke: {command} → pass|fail|skipped

Manual test:
- [ ] ...

Not done: {only if something was skipped or impossible, with why}

- PROJECT.md candidate: {section}: {fact}
```

Add a `- PROJECT.md candidate: <PROJECT.md section name>: <fact>` line
only when this follow-up revealed a durable project-level fact NOT
already stated in `.task/PROJECT.md` (a convention, an architectural
constraint, an important file, a gotcha) — omit it entirely otherwise;
having none is the normal case.

If this follow-up used mock/placeholder data in place of an
unavailable real source, note it under `Not done` (what's mocked, what
the real source is) — same convention as `.task/implementation.md`'s
`## Deviations from Plan`.

Keep it terse. **Budget: each `## Follow-up N — Applied` section must be
≤ 1,400 characters** (check with `wc -m`; compress if over), including
any `PROJECT.md candidate` lines — it, plus `implementation.md` and
every other Applied section, is pasted into web in one message limited
to 25,000 characters total via `bin/copy-for-web.sh result`.

## Escalation

If the request requires:
- architectural ambiguity
- major conflict between the request and the codebase
- complex concurrency behavior
- large-scale refactoring
- security-sensitive behavior
- a problem that cannot be safely resolved from the request
- a new third-party dependency, permission, entitlement, or
  Info.plist/AndroidManifest permission change that the follow-up
  request does not explicitly list

DO NOT guess. Stop and report what you found, why it's insufficient, and
what decision is required — but still append `## Follow-up N — Applied`
noting what was and wasn't done, so the round doesn't silently vanish.

## Rules

1. Fix valid issues only.
2. Do not blindly trust AI web review.
3. Do not redesign the feature.
4. Do not expand scope or perform unrelated refactoring.
5. Preserve the approved plan unless a change is necessary.
6. Keep fixes minimal.
7. No commit — this workflow does not touch git.
