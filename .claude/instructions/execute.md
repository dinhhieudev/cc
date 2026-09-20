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

**Output language.** Read `.claude/instructions/_language.md` and follow it.

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
- a new third-party dependency, permission, entitlement, or
  Info.plist/AndroidManifest permission change that the plan does not
  explicitly list

DO NOT guess or invent a solution.

Before stopping, write `.task/implementation.md` using the step 5
template: `## Changes` listing what was applied so far (or
`None — stopped before changing code`), and `## Deviations from Plan`
stating which step you stopped at and what decision is required — so
partial work isn't lost. `.task/index.md` Status stays `executing` so
the human can resume.

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

Before any code changes, run `git rev-parse --short HEAD` and
`git status --porcelain` (read-only — never run a mutating git command)
and record the results for the `## Baseline` section below. If the
project is not a git repository, record `not a git repo` and continue
without failing.

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

Read `.claude/instructions/_verify.md` and run the pipeline it describes.
Affected platforms come from context.md's `## Platform & Build Context`
when available, otherwise inferred from the changed files. Record verify
results in `.task/implementation.md`'s `## Verify`.

If the pipeline still fails after the third attempt, write
`.task/implementation.md` with `## Verify` showing the failing command and
output, then STOP and report exactly:

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

### 5. Write implementation.md

Create `.task/implementation.md`:

```
# Implementation Summary

## Baseline
- HEAD before changes: {short sha}
- Working tree before changes: clean | {N} pre-existing modified/untracked files

## Changes
- `path/to/file`: change, 1 line

## Deviations from Plan
Any Acceptance Criterion with no plan step, or any plan step not done,
with why. If none: None.

## Verify
- Codegen/setup: {command} → pass|fail|skipped (reason)
- Type check: {command} → pass|fail|skipped
- Build: {command} → pass|fail|skipped (reason)
- Tests: {command} → pass|fail|skipped
- Device smoke: {command} → pass|fail|skipped

One line per platform when a slot has per-platform commands, e.g.
`- Build (ios): {command} → pass`, `- Build (android): skipped (ios-priority)`.

## Manual Test Checklist
- [ ] <action> → <expected result>

## PROJECT.md Candidates
- <PROJECT.md section name>: <the fact>
```

`## Deviations from Plan`: if mock/dummy/placeholder data or a stub was used because a real data source (API, backend, service) wasn't available or in scope, note it explicitly here — what's mocked, where (file/function), and what a future task needs to do to replace it with the real source; this is discoverable later via `## Related Task` lookups on the same Screen tag.

`## Manual Test Checklist`: generate a checklist appropriate to what was changed. Under a human-runs setup this checklist is the primary verification artifact, and a 40-item checklist does not get run, so:
- Each item uses the format `- [ ] <concrete action> → <expected result>` — never a vague bullet.
- At most 12 items, ordered by risk: happy path first, then state coverage (loading / empty / error), then edge cases (dark mode, Dynamic Type, rotation), then platform-specific items last.
- Mark items that require a physical device with `(real device)`.
- When `## Platform` in `.task/PROJECT.md` targets both iOS and Android, group the items under a per-platform heading.
- **UI changes**: first item asks the human to save result screenshots into `.task/design/result/` (iOS: `xcrun simctl io booted screenshot <name>.png`; Android: `adb exec-out screencap -p > <name>.png`) so `bin/copy-for-web.sh result` forwards them for review. Then include checks for light/dark mode, smallest and largest Dynamic Type, portrait/landscape (unless rotation-locked), loading/empty/error states, accessibility labels, and localization when applicable. If `## Platform` targets both iOS and Android, include a check for each platform.
- **Network-dependent features**: include offline and slow-network checks.
- **Persisted state**: include a fresh-launch/restart check.
- **Gestures, camera, location, permissions, or performance-sensitive lists/scrolling**: include a real-device check — simulators/emulators often hide real gesture, permission, and performance behavior.
- **OS version span**: if `## Known Constraints` lists a minimum OS version that spans a major release boundary (e.g. iOS 16 vs iOS 17+), include a check on the minimum supported version.
- **Lifecycle/navigation**: when relevant, include background/foreground, cold start, back/dismiss, deep link, and state restoration checks.
- **Release-sensitive changes**: include the affected environment/flavor and upgrade-from-previous-version check.

`## PROJECT.md Candidates`: at most 5 bullets, each a single line, each a durable project-level fact worth adding to `.task/PROJECT.md` that is NOT already stated there (a convention, architectural constraint, important file, or gotcha) — format `- <PROJECT.md section name>: <the fact>`. Write `None` when nothing qualifies — that is the normal case for a routine task; task-specific detail, restatements of PROJECT.md, and anything already in the code's own docs don't qualify. This file is pasted into the web chat later (alongside `.task/followups.md`, in one message limited to 25,000 characters total) — keep it terse. **Budget: `.task/implementation.md` must be ≤ 6,000 characters**, this section included (check with `wc -m .task/implementation.md`; compress if over).

### 6. Final Report

Report to the human in ≤ ~10 lines, pointing at `.task/implementation.md`
rather than restating its contents. Mention `review` (optional local
`/code-review` pass) as an available next step alongside
`bin/copy-for-web.sh result`.

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
10. Read-only git inspection (`git rev-parse`, `git status`) is fine for the baseline; never run a mutating git command — no commit, no branch, no checkout, no stash, no add, no reset.
