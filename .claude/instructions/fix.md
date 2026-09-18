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
- run the `## Verify Command` from `.task/PROJECT.md`

Do not read the whole verify log into context: redirect its output to a
temp file, then read back only the last ~50 lines plus any lines
matching an error/warning pattern (e.g. `{command} > /tmp/verify.log
2>&1; tail -n 50 /tmp/verify.log; grep -iE 'error|failed|warning'
/tmp/verify.log | head -40`). Record only the pass/fail verdict and the
essential error lines in the `## Follow-up N — Applied` section.

The Verify Command must pass before proceeding. If it fails, fix the code
and re-run it, up to 3 attempts total.

If `.task/PROJECT.md` has no Verify Command filled in, say so explicitly
in the Applied section instead of silently skipping this step.

### 4. Append to followups.md

Whether verify passed or failed after 3 attempts, append
`## Follow-up N — Applied` at the END of `.task/followups.md` (sections
stay in order: request N, applied N, request N+1, ...):

```
## Follow-up N — Applied
- `path/to/file`: what changed, 1 line

Verify: {command} → pass|fail

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

Keep it terse. **Budget: each `## Follow-up N — Applied` section must be
≤ 1,200 characters** (check with `wc -m`; compress if over), including
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
