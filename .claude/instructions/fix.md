# Fix

Resolve issues for the current fix round.

## Inputs

Find the latest `## Fix Notes — Round N` in `.task/review.md` that has no
matching `## Fixes Applied — Round N`. If none exists, STOP and report
exactly:

> No pending Fix Notes in `.task/review.md`. Main context must append the
> fix list as `## Fix Notes — Round N` before dispatching fix-agent.

If N > 3, STOP and report that the fix loop is not converging. List what
is still outstanding from the Round N fix notes and ask the human to
decide: accept as-is, re-plan, or descope. Do not fix anything.

Read, in order:

    .task/PROJECT.md
    .task/overview.md
    .task/plan.md

Then read only:
- the current round's `## Fix Notes — Round N` section of `.task/review.md`
- the previous round's `## Fixes Applied — Round N-1` section, if it exists

Do not read the entire review.md history — earlier rounds are irrelevant
to the current fix.

Then inspect the actual codebase.

Fix notes may combine AI-reviewer findings and the human's manual test
findings; treat both as findings to address, not just the AI's.

## Priority

1. Actual codebase
2. Approved implementation plan
3. Fix Notes (current round)
4. Task overview

## Objective

Fix valid issues with the smallest safe changes.
The goal is NOT to redesign the feature.

## Workflow

### 1. Classify Fix Notes

For every finding, classify it as:
- Critical / Bug / Requirement violation
- Plan violation / Architecture issue
- Edge case / Code quality
- Optional suggestion (do NOT auto-implement these)

### 2. Validate Findings

Verify every issue against the actual codebase.
The external AI may be wrong. Do not change code solely because it was suggested.

### 3. Fix

Fix valid issues.

Prefer the smallest change that:
- resolves the issue
- preserves the approved architecture
- preserves existing behavior
- avoids scope expansion

### 4. Re-check

After fixing:
- inspect changed code
- review the diff
- verify no obvious regressions
- run the `## Verify Command` from `.task/PROJECT.md`

The Verify Command must pass before proceeding. If it fails, fix the code
and re-run it, up to 3 attempts total. If it still fails after the third
attempt, STOP and report exactly:

> The Verify Command (`{verify command}`) still fails after 3 attempts.
>
> Final failing output:
> ```
> {final failing output}
> ```
>
> What was changed across attempts:
> - {summary of attempt 1}
> - {summary of attempt 2}
> - {summary of attempt 3}

Do not write `review.md` or `implementation.md`, do not commit, and do
not tag when stopping this way. If `.task/PROJECT.md` has no Verify
Command filled in, say so explicitly in the report instead of silently
skipping this step.

### 5. Append to review.md

```
## Fixes Applied — Round N
- Finding: ...
  Resolution: ...

## Skipped / Disagreed — Round N
- Finding: ...
  Reason: ...
```

### 6. Update Test Log

Append a new round section to `.task/testlog.md`, seeded from any new
manual tests raised in this round's fixes:

```
## Round N — fix round N

Result:
- [ ]

Issues found:
-
```

### 7. Commit

If the target project is not a git repository, skip this step and note
it in the report.

Otherwise, after the verify gate passes and review.md is appended:

```
git add -A && git commit -m "wip(task): round N — {slug}"
git tag -f round-N
```

`{slug}` is the task slug recorded in `.task/index.md`.

### 8. Output Delta Summary

After updating review.md, output a compact delta block in your response.
The user will copy this and paste it into their ongoing AI web conversation.

Format:

```
─── Paste to AI web (Round N) ───────────────────────────
Fixes applied in Round N:
- [brief description of each fix]

Skipped:
- [any skipped findings and why]

New manual tests needed:
- [ ] ...
─────────────────────────────────────────────────────────
```

Remind the human, in your response, to run `bin/diff-for-web.sh N` and paste
its clipboard contents (the round-{N-1}..round-N delta diff) into the AI web
conversation alongside this delta summary.

Also include:

```
Manual verification (do these before next AI web review):
- [ ] ...
```

## Rules

1. Fix valid issues only.
2. Do not blindly trust the external AI.
3. Do not redesign the feature.
4. Do not expand scope or perform unrelated refactoring.
5. Preserve the approved plan unless a change is necessary.
6. If a finding requires a significant architectural change,
   stop and report it instead of making a large assumption.
7. Keep fixes minimal.
