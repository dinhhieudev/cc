# Claude++ Workflow

A task workflow that pairs Claude Code (codebase exploration, implementation, fixes) with an external AI web conversation (planning, review).

## Agent Routing

| User says | Main context does |
|---|---|
| `skill overview + context: ...` | Run `overview` skill in main context → it invokes **context-agent** |
| `plan saved to .task/plan.md, run execute` (or equivalent) | Dispatch **execute-agent** directly — the human already wrote `.task/plan.md`; do NOT read or rewrite it. Do not read its contents into main context — only execute-agent reads the file |
| pastes an implementation plan ("implement this plan: ...") | **Write the pasted plan to `.task/plan.md` FIRST**, then dispatch **execute-agent** |
| `fix notes round N saved, run fix` (or equivalent) | Dispatch **fix-agent** directly — the human already appended the Fix Notes; do NOT read or rewrite `.task/review.md`. Do not read its contents into main context — only fix-agent reads the file |
| pastes a fix list ("fix this list: ...") | **Append the pasted list to `.task/review.md` as `## Fix Notes — Round N` FIRST**, then dispatch **fix-agent** |
| `save task` | Run `save` skill in main context |

Vietnamese phrasings of these triggers route identically to their English rows. Examples: `plan đã lưu vào .task/plan.md, chạy execute` → execute-agent row; `triển khai plan này: ...` → paste-plan row; `fix notes round N đã lưu, chạy fix` → fix-agent row; `sửa theo danh sách này: ...` → paste-fix-list row; `lưu task` → save row. `skill overview + context: ...` is unchanged (skill name). The appended heading is always `## Fix Notes — Round N` in English, even when the human writes Vietnamese.

N for `## Fix Notes — Round N` = (number of existing `## Fix Notes — Round`
headings in `.task/review.md`) + 1. If the computed N would be greater than
3, do not append — stop and apply hard rule 4 instead (loop is not
converging; the human decides: accept, re-plan, or descope).

## Hard rules for main context

1. Subagents CANNOT see this conversation. Anything the human pastes must be written to a file BEFORE dispatching a subagent. This is not optional. This requirement is satisfied either by main context writing the file itself, or by the human having already written it via the clipboard route — but a subagent must never be dispatched expecting content that exists only in this conversation.
2. Main context never implements or fixes code directly — always dispatch execute-agent / fix-agent.
3. Main context runs only the `overview` and `save` skills. `context`, `execute`, and `fix` are not skills at all — they are instruction files under `.claude/instructions/` that their respective subagents read. Main context must never read or act on those files itself.
4. Fix rounds are capped at 3. If a 4th round is requested, stop and tell the human the loop is not converging and needs a decision.
5. Never write project-level context into `.task/context.md`; it belongs in `.task/PROJECT.md`.
6. `.task/PROJECT.md` is read explicitly by each `.claude/instructions/*.md` file rather than imported here, so it loads exactly once per agent.
