# Claude++ Workflow

A task workflow that pairs Claude Code (codebase exploration, implementation, fixes) with an external AI web conversation (planning, review). AI web plans and analyzes; Claude Code gathers compact context and executes precisely, minimizing its own token use. AI web messages are limited to 25,000 characters total, so every file that gets pasted into web (`overview.md`, `context.md`, `implementation.md`, `followups.md`) is character-budgeted — see each agent's instructions — and content that doesn't fit is split into attachments under `.task/web/` by `bin/copy-for-web.sh`.

## Agent Routing

| Human says | Main context does |
|---|---|
| `task: ...` / `skill overview + context: ...` (accepted alias) / any new-task request | Write the request verbatim into `.task/overview.md` `## Original Request` (see template below), then dispatch **context-agent** |
| `run execute` / `chạy execute` (plan saved via `bin/save-plan.sh`) | Dispatch **execute-agent**; do NOT read `.task/plan.md` |
| `implement this plan: ...` / `triển khai plan này: ...` | Write pasted plan to `.task/plan.md` FIRST, then dispatch **execute-agent** |
| `run fix` / `chạy fix` (follow-up saved via `bin/save-followup.sh`) | Dispatch **fix-agent**; do NOT read `.task/followups.md` |
| `fix: ...` / `add: ...` / `làm thêm: ...` / any follow-up request on the current task | Append `## Follow-up N` (request verbatim) to `.task/followups.md` FIRST, then dispatch **fix-agent** |
| `save task` / `lưu task` | Run `save` skill |

New-task template written to `.task/overview.md` before dispatching context-agent:

```
# Task Overview

## Original Request

<request text verbatim>
```

Equivalent phrasings in either language route the same row.

N = (count of lines in `.task/followups.md` matching `^## Follow-up [0-9]+$` — request headings only, not `— Applied`) + 1.

## Hard rules for main context

1. Subagents CANNOT see this conversation. Anything the human pastes must be written to a file BEFORE dispatching a subagent. This is not optional. This requirement is satisfied either by main context writing the file itself, or by the human having already written it via the clipboard route — but a subagent must never be dispatched expecting content that exists only in this conversation.
2. Main context never implements or fixes code directly — always dispatch execute-agent / fix-agent.
3. Main context runs only the `save` skill. `context`, `execute`, and `fix` are not skills at all — they are instruction files under `.claude/instructions/` that their respective subagents read. Main context must never read or act on those files itself.
4. Never write project-level context into `.task/context.md`; it belongs in `.task/PROJECT.md`.
5. `.task/PROJECT.md` is read explicitly by each `.claude/instructions/*.md` file rather than imported here, so it loads exactly once per agent.
