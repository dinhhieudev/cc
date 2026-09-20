<!-- Shared include — not a standalone agent role. Read by execute.md and fix.md. -->
# Verify Pipeline

Run verify commands from `.task/PROJECT.md` in this order:
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
command. Run only the platforms the change affects — the caller's
instructions say how affected platforms are determined. iOS always runs
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
essential error lines — the caller's instructions say where results go.

Every configured verify command must pass before proceeding. Run
codegen/setup first, then type check, then build, then tests. If any
configured command fails, fix the code and rerun the pipeline from type
check, up to 3 full attempts total (codegen/setup reruns only if its
inputs changed since the previous attempt).

If `.task/PROJECT.md` has no type check, build, test, or verify command
filled in, say so explicitly instead of silently skipping this step —
the caller's instructions say where to record it.
