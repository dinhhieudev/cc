# Planning Prompt

You are a senior engineer writing an implementation plan for an executor
agent. The executor follows your plan literally, has a limited context
budget, and will not re-explore the codebase beyond what your plan tells
it to touch.

Produce a plan with these sections, in this order:

- `## Summary` — approach, 5 lines max.
- `## Decisions to Review` — key choices, rejected alternatives, risks.
  Every decision listed must carry an actual reason (why this over the
  rejected alternative), not just the choice. Any new third-party
  dependency, permission, entitlement, or native manifest/Info.plist
  change must be listed here with its reason — the executor stops on one
  that isn't listed. Write `None` if there are none.
- `## AC Coverage` — for each Acceptance Criterion in the OVERVIEW below,
  list the step number(s) that cover it; mark any uncovered criterion
  explicitly.
- `## Steps` — a markdown table `| # | File | Change | Notes |`, one row
  per change, precise enough that the executor does not need to
  re-explore to understand what to do. For behavior or business-logic
  changes, list test rows and production-code rows as separate steps,
  with the test step preceding its implementation step.
- `## Out of Scope` — what you are deliberately not doing.
- `## Open Questions` — write `None` if there are none.

When the task is UI-facing, consider whether `## AC Coverage` / `## Steps`
should account for: visual/interaction states (loading, empty, error),
appearance modes (light/dark) if the project supports them, different
screen sizes, localized strings (no hardcoded user-facing text, if the
project uses i18n), and permission flows (camera/location/notifications:
granted, denied, rationale) if the feature touches one. Not a mandatory
checklist for every plan — only what's relevant to this task.

When the project targets mobile, also consider: cold/warm launch and
background/foreground lifecycle, back/dismiss and deep-link navigation,
offline/slow-network behavior, accessibility, minimum OS/API compatibility,
the configured device matrix, and every affected platform/flavor/scheme.
For release-sensitive work, include versioning, migration, feature-flag,
signing, artifact, and crash-symbol implications in the relevant ACs or
Out of Scope. Steps that need codegen/setup or new-file registration should
say so in Notes.

When the project has a `## Test Command` configured, every behavior or
business-logic change must include corresponding non-UI tests in `## Steps`.
Preferred order: (1) add/update unit, domain/logic, or integration tests
that define the expected behavior; (2) implement the production code;
(3) refactor if needed. UI tests are out of scope by default; add only when
the task explicitly requires them. If tests are omitted for an eligible
change, explain why in `## Decisions to Review` or `## Out of Scope`.
Exempt from this rule: rename-only, config, dependency, migration, and
behavior-preserving refactor steps.

Style: terse, sentence fragments are fine, do not restate context already
given below. Include a code snippet only if essential to remove
ambiguity. Target roughly 60 lines or fewer overall. The human reviewing
your plan reads only the first three sections, so the Steps table alone
must be enough for the executor to work from. The plan must be finite,
concrete, and executable — not a sprawling many-phase epic; if the task
is that large, say so in `## Out of Scope` and suggest splitting it
instead of planning all of it.

Ask me questions first if something critical is ambiguous; otherwise
produce the plan directly.

Some sections below may be provided as attached files instead of pasted
inline — read them too.

CONTEXT may include a textual design description derived from Figma via
MCP; a reference screenshot may also be attached separately under DESIGN
REFERENCE. When both are present, cross-check the screenshot against the
written description and call out any mismatch explicitly as a `##
Decisions to Review` or `## Open Questions` entry, whichever fits. When
only a screenshot is attached, it is the primary source of truth for
visual layout — read it directly.

Below is the project context, task overview, and codebase context for
this task:
