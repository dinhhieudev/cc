# Execute

Implement the approved plan.

## Inputs

Read, in order:

    .task/PROJECT.md
    .task/overview.md
    .task/plan.md

`.task/plan.md` is the plan to implement. If it is empty or still the
placeholder template, STOP and report exactly:

> `.task/plan.md` is empty. Main context must write the approved plan to
> `.task/plan.md` (via `bin/save-plan.sh` or a pasted plan) before
> dispatching execute-agent.

The plan comes from AI web and uses these headings: `## Summary`,
`## Decisions to Review`, `## AC Coverage`, `## Steps` (table
`| # | File | Change | Notes |`), `## Out of Scope`, `## Open Questions`.

Set `.task/index.md` Active Task Status to `executing` (it stays `executing` through completion — `save` sets it to `done`), then inspect the actual codebase.

## Priority

1. Actual codebase
2. Approved implementation plan
3. Task overview

The actual codebase is the source of truth.

**Output language.** Read the `Language:` line in `.task/PROJECT.md` `## Language` (missing or unrecognized → `en`). Write all prose you put into `.task/*.md` files and your final report to the human in that language (`vi` = Vietnamese). Always keep in English regardless of setting: every markdown heading (e.g. `## Goal`, `## Acceptance Criteria`, `## Follow-up N`, `## Follow-up N — Applied`) — tooling and routing grep these exact strings; the `Language:` line; `.task/index.md` table field names, status values (`spec`, `planned`, `executing`, `fixing`, `done`) and `—` placeholders; file paths; task slugs; code, identifiers, and code comments.

## Token Discipline

The plan is the source of instructions. Read only the files it names plus
what is strictly needed to apply each change correctly — no broad
re-exploration of the codebase. Do not restate the plan in your report.

## Escalation

If you encounter:
- architectural ambiguity
- major conflict between plan and codebase
- complex concurrency behavior
- large-scale refactoring
- unclear API design
- difficult compiler/type-system problems
- security-sensitive behavior
- a blocking `## Open Questions` entry in the plan
- a problem that cannot be safely resolved from the plan

DO NOT guess or invent a solution.

Stop and report:
1. What you found
2. Why the plan is insufficient
3. What decision is required

For normal implementation work, proceed autonomously.

## Objective

Implement the approved plan accurately while minimizing:
- unnecessary files
- unnecessary abstractions
- unnecessary refactoring
- unrelated changes
- duplicated logic

## Workflow

### 1. Validate the Plan

Before changing code:
- read `## Steps` and identify the files it touches
- verify those files exist or should be created
- verify assumptions still match the current codebase
- use `## AC Coverage` to check the plan addresses every Acceptance
  Criterion in `.task/overview.md`
- read `## Open Questions`; if any entry blocks implementation, STOP
  before changing any code and report it (see Escalation) — do not
  guess on a real decision

If the plan conflicts with the actual codebase, do not blindly follow it. Determine whether the conflict is trivial and safely resolvable, architectural, or ambiguous. For architectural or ambiguous conflicts, stop and report the issue (see Escalation).

### 2. Inspect Existing Patterns

Before implementing:
- inspect nearby code
- follow existing naming conventions
- follow existing architecture
- reuse existing helpers where appropriate

Do not introduce a new pattern when an existing pattern already solves
the problem.

### 3. Implement

Implement `## Steps` in order, in small logical changes.

Prefer:
- simple code
- existing abstractions
- local changes
- explicit behavior
- maintainable implementation

Avoid:
- speculative abstractions
- unnecessary protocols
- unnecessary dependency injection
- unnecessary architecture layers
- unrelated cleanup

### 4. Verify

After implementation:
- inspect changed files
- check obvious integration issues
- review the diff
- confirm every Acceptance Criterion is addressed (cross-check against
  `## AC Coverage`)
- run verify commands from `.task/PROJECT.md` in this order:
  1. `## Type Check Command` — fast; required if present
  2. `## Build Command` — required when the task changes buildable code or platform config
  3. `## Test Command` — run after build when present
  4. `## Device Smoke Test Command` — run when present and relevant to the task
  Backward compat: if only the old `## Verify Command` field is present,
  treat it as the type check step. Empty optional commands are skipped and
  must be recorded as skipped, never reported as passed.

Do not read the whole verify log into context: redirect its output to a temp file, then read back only the last ~50 lines plus any lines matching an error/warning pattern (e.g. `{command} > /tmp/verify.log 2>&1; tail -n 50 /tmp/verify.log; grep -iE 'error|failed|warning' /tmp/verify.log | head -40`). Record only the pass/fail verdict and the essential error lines in `.task/implementation.md`.

Every configured verify command must pass before proceeding. Run type check
before build, and build before tests. If any configured command fails, fix the
code and rerun the pipeline from type check, up to 3 full attempts total. If
it still fails after the third attempt, write `.task/implementation.md` with
`## Verify` showing the failing command and output, then STOP and report exactly:

> The configured verify pipeline (`{failing command}`) still fails after 3 attempts.
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

If `.task/PROJECT.md` has no type check, build, test, or verify command filled in, say so explicitly
in `.task/implementation.md` instead of silently skipping this step.

### 5. Write implementation.md

Create `.task/implementation.md`:

```
# Implementation Summary

## Changes
- `path/to/file`: change, 1 line

## Deviations from Plan
Any Acceptance Criterion with no plan step, or any plan step not done,
with why. If none: None.

## Verify
- Type check: {command} → pass|fail|skipped
- Build: {command} → pass|fail|skipped
- Tests: {command} → pass|fail|skipped
- Device smoke: {command} → pass|fail|skipped

## Manual Test Checklist
- [ ] ...

## PROJECT.md Candidates
- <PROJECT.md section name>: <the fact>
```

`## Deviations from Plan`: if mock/dummy/placeholder data or a stub was used because a real data source (API, backend, service) wasn't available or in scope, note it explicitly here — what's mocked, where (file/function), and what a future task needs to do to replace it with the real source; this is discoverable later via `## Related Task` lookups on the same Screen tag.

`## Manual Test Checklist`: generate a checklist appropriate to what was changed:
- **UI changes**: include checks for light/dark mode, smallest and largest Dynamic Type, portrait/landscape (unless rotation-locked), loading/empty/error states, accessibility labels, and localization when applicable. If `## Platform` targets both iOS and Android, include a check for each platform.
- **Network-dependent features**: include offline and slow-network checks.
- **Persisted state**: include a fresh-launch/restart check.
- **Gestures, camera, location, permissions, or performance-sensitive lists/scrolling**: include a real-device check — simulators/emulators often hide real gesture, permission, and performance behavior.
- **OS version span**: if `## Known Constraints` lists a minimum OS version that spans a major release boundary (e.g. iOS 16 vs iOS 17+), include a check on the minimum supported version.
- **Lifecycle/navigation**: when relevant, include background/foreground, cold start, back/dismiss, deep link, and state restoration checks.
- **Release-sensitive changes**: include the affected environment/flavor and upgrade-from-previous-version check.

`## PROJECT.md Candidates`: at most 5 bullets, each a single line, each a durable project-level fact worth adding to `.task/PROJECT.md` that is NOT already stated there (a convention, architectural constraint, important file, or gotcha) — format `- <PROJECT.md section name>: <the fact>`. Write `None` when nothing qualifies — that is the normal case for a routine task; task-specific detail, restatements of PROJECT.md, and anything already in the code's own docs don't qualify. This file is pasted into the web chat later (alongside `.task/followups.md`, in one message limited to 25,000 characters total) — keep it terse. **Budget: `.task/implementation.md` must be ≤ 5,000 characters**, this section included (check with `wc -m .task/implementation.md`; compress if over).

### 6. Final Report

Report to the human in ≤ ~10 lines, pointing at `.task/implementation.md`
rather than restating its contents.

## Rules

1. Implement only the requested scope.
2. Treat the plan as the implementation contract.
3. Treat the actual codebase as the source of truth.
4. Never hide a plan/codebase conflict.
5. Do not expand scope.
6. Do not perform unrelated refactoring.
7. Keep implementation simple.
8. Add or update tests when the risk warrants them: business logic and bug fixes should have regression coverage when practical; document justified omissions in Deviations from Plan.
9. Do not expose secrets.
10. No commit — this workflow does not touch git.
