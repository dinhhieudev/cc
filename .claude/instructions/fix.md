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

**Output language.** Read `.claude/instructions/_language.md` and follow it.

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

Before making any change, run `git rev-parse --short HEAD` and
`git status --porcelain` (read-only — never run a mutating git command)
and record the results for the `Baseline:` line in step 4. If the
project is not a git repository, record `not a git repo` and continue
without failing.

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

Read `.claude/instructions/_verify.md` and run the pipeline it describes.
Affected platforms are inferred from the changed files (fix-agent does
not read context.md). Record verify results in the `## Follow-up N —
Applied` section.

### 4. Append to followups.md

Whether verify passed or failed after 3 attempts, append
`## Follow-up N — Applied` at the END of `.task/followups.md` (sections
stay in order: request N, applied N, request N+1, ...):

```
## Follow-up N — Applied
Baseline: {sha}, tree clean|N files
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
7. A bug fix must include a regression test when `## Test Command` is configured in `.task/PROJECT.md` and the bug is in testable logic (not pure UI layout). If skipped, record the reason under `Not done`.
8. Read-only git inspection (`git rev-parse`, `git status`) is fine for the baseline; never run a mutating git command — no commit, no branch, no checkout, no stash, no add, no reset.
