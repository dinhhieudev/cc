# Context

You are responsible for investigating the existing codebase and producing
focused technical context for an external reasoning model.

The goal is NOT to solve the task.
The goal is to answer:

> "What does the external planner need to know about this codebase
> to produce a reliable implementation plan?"

## Input

Read, in order:

    .task/PROJECT.md
    .task/overview.md

Architecture, conventions, and source layout are already documented in
`.task/PROJECT.md` — do not re-derive them. Explore only the gaps
specific to this task, and in context.md note where you are confirming
vs. extending what PROJECT.md already states.

If the target project has a `.codegraph/` directory, use the codegraph
MCP tools (`codegraph_context` first, then one `codegraph_explore` for
the symbols it surfaces) instead of a grep+read loop. Fall back to
Read/Grep only when there is no index or codegraph did not cover a
needed detail.

Then inspect the actual codebase.

## Priority

1. Actual codebase
2. Task overview (to know what is relevant)
3. `.task/PROJECT.md` (already-documented architecture/conventions — confirm, don't re-derive)

## Output

Create or update:

    .task/context.md

Use this structure:

```
# Technical Context

## Relevant Architecture
Describe only the architecture relevant to this task.

## Relevant Files
For each relevant file:

### `path/to/file`
- Purpose:
- Relevant symbols:
- Why relevant:
- Important behavior:

Do NOT include irrelevant files.

## Existing Patterns
Describe existing patterns that the implementation should follow.
Examples:
- state management
- navigation
- dependency injection
- networking
- persistence
- UI composition
- error handling
- concurrency
- naming conventions

## Data Flow
Describe the relevant flow:

    User/Input
    →
    View
    →
    ViewModel
    →
    Service/Repository/etc.
    →
    Data

Only include layers that actually exist.

## Dependencies
List relevant dependencies/frameworks/packages.

## Current Behavior
Describe how the relevant feature currently works.

## Important Constraints
List technical constraints discovered from the codebase.

## Potential Risk Areas
List areas that the planner should pay attention to.

## Relevant Code Snippets
Include only small, highly relevant snippets when necessary.
Do NOT dump entire files.

## Unknowns
Clearly list anything that could not be determined.
```

## Rules

1. Read the actual codebase.
2. Follow existing architecture instead of inventing a new one.
3. Search before assuming.
4. Prefer the smallest relevant set of files.
5. Do not inspect unrelated parts of the repository.
6. Do not design the final solution.
7. Do not write implementation code.
8. Do not modify production source code.
9. Never include secrets.
10. Never include:
    - API keys
    - passwords
    - tokens
    - certificates
    - private keys
    - .env contents
    - customer/user data
11. If a file contains sensitive information, describe its role without exposing
    the sensitive content.
12. Write context.md and stop — do not implement anything.

## Token Optimization

Optimize for information density.

Prefer:
- file paths
- symbol names
- short explanations
- relevant snippets

Avoid:
- repeating the same information
- full file contents
- unrelated implementation details
- generated files
- dependency internals
- obvious boilerplate

The external planner should receive enough information to make architectural
decisions without receiving the entire repository.

## Quality Check

Before reporting done, verify context.md against this checklist.
If any item fails, revise the document before finishing.

- [ ] Only files directly relevant to the task are included
- [ ] Data flow reflects actual codebase layers (not invented architecture)
- [ ] Patterns section describes patterns found in the actual code, not invented ones
- [ ] No full file contents — only targeted snippets
- [ ] No secrets, tokens, passwords, or sensitive data
- [ ] Unknowns section exists, even if empty
- [ ] A developer with no codebase access could make sound architectural decisions from this document

## Final Report

After writing context.md, report:
> context.md generated. Ready for AI web planning (Step 2).
