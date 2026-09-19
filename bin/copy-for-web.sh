#!/usr/bin/env bash
set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
source "$SCRIPT_DIR/lib/copy-for-web-lib.sh"
source "$SCRIPT_DIR/lib/copy-for-web-design.sh"
source "$SCRIPT_DIR/lib/copy-for-web-modes.sh"
source "$SCRIPT_DIR/lib/copy-for-web-lean.sh"
source "$SCRIPT_DIR/lib/copy-for-web-handoff.sh"

LIMIT="${WEB_CHAR_LIMIT:-25000}"

usage() {
  cat <<'EOF'
Usage: copy-for-web.sh [result | --lean | handoff] [--split]

Every mode's payload starts with a one-line header ("[claude++ task
<id>-<name> — <project>]") so pasting into a stale web chat is obvious.

No argument: builds the planning payload from .task/PROJECT.md (if it
has real content), .task/overview.md, and .task/context.md, prefixed
with the planning prompt (bin/plan-prompt.md), and copies it to the
clipboard for pasting into a ChatGPT/Gemini web conversation. If
.task/design/ exists and has files, every file in it is also copied
into .task/web/ (same secret-filename guard and 200 KB size cap as
bin/attach.sh — the secret-filename guard exempts image files) and
listed under a "--- DESIGN REFERENCE (attached) ---" marker — attach
those too so the web planner can see the reference screenshots.

result: builds the result-review payload from .task/implementation.md
and .task/followups.md (if it has real content), prefixed with the
result prompt (bin/result-prompt.md).

--lean: builds a lean planning payload with no pre-built codebase
context — .task/PROJECT.md (if substantive), .task/overview.md, and a
FILE TREE of the project (git ls-files, or a pruned find outside a git
repo) in place of .task/context.md, prefixed with bin/plan-prompt.md
then bin/lean-note.md. The web planner replies with the files it wants
first; run bin/attach.sh <paths> to attach them, then ask for the plan.
Requires .task/overview.md (run `task (lean): ...` first) — does not
read .task/context.md.

handoff: builds a short payload for starting a FRESH web chat when the
current one has gotten too long — a fixed intro, an OVERVIEW SUMMARY
(## Goal + ## Acceptance Criteria from overview.md, or its first 800
chars if those headings are missing), the plan's CURRENT PLAN STEPS
(## Steps table), and LATEST STATUS (the newest Follow-up round, or
else implementation.md's Changes/Deviations), asking the web to confirm
it understands before continuing.

result, --lean, and handoff are mutually exclusive.

If .task/PROJECT.md's Language is vi, a line asking for a Vietnamese
response is appended after the prompt.

The web chat accepts at most WEB_CHAR_LIMIT characters per message
(default 25000). If the payload would exceed it, the largest sections
are written to files under .task/web/ instead (CONTEXT then PROJECT in
plan mode; FOLLOW-UPS then IMPLEMENTATION in result mode; in lean mode
the FILE TREE is filtered for noise, then collapsed to per-directory
counts, then attached in full, then PROJECT; OVERVIEW SUMMARY then
CURRENT PLAN STEPS in handoff mode) and the clipboard message
references them by name — attach those files in the web chat yourself.
.task/web/ is cleared and rebuilt on every run. --split forces the
above pairs to attachments regardless of size. Warns if the message
still exceeds 85% of the limit.

Must be run from the root of a project that has a .task/ directory.

Options:
  -h, --help    Show this help and exit
EOF
}

MODE="plan"
FORCE_SPLIT=0
for arg in "$@"; do
  case "$arg" in
    -h|--help) usage; exit 0 ;;
    result|handoff)
      if [[ "$MODE" != "plan" ]]; then
        echo "Error: 'result', '--lean', and 'handoff' cannot be used together." >&2
        exit 1
      fi
      MODE="$arg" ;;
    --lean)
      if [[ "$MODE" != "plan" ]]; then
        echo "Error: 'result', '--lean', and 'handoff' cannot be used together." >&2
        exit 1
      fi
      MODE="lean" ;;
    --split) FORCE_SPLIT=1 ;;
    *) echo "Error: unrecognized argument '$arg'." >&2; usage >&2; exit 1 ;;
  esac
done

if [[ ! -d .task ]]; then
  echo "Error: no .task/ directory found here. Run this from the project root." >&2
  exit 1
fi

# .task/web/ always mirrors just this run's attachments.
WEB_DIR=.task/web
rm -rf "$WEB_DIR"
mkdir -p "$WEB_DIR"
WEB_DIR_ABS="$(cd "$WEB_DIR" && pwd)"
WEB_FILES=()

case "$MODE" in
  handoff)
    PROMPT="$HANDOFF_INTRO"
    ;;
  result)
    PROMPT_FILE="$SCRIPT_DIR/result-prompt.md"
    [[ -f "$PROMPT_FILE" ]] || { echo "Error: $PROMPT_FILE not found." >&2; exit 1; }
    PROMPT="$(cat "$PROMPT_FILE")"
    ;;
  *)
    PROMPT_FILE="$SCRIPT_DIR/plan-prompt.md"
    [[ -f "$PROMPT_FILE" ]] || { echo "Error: $PROMPT_FILE not found." >&2; exit 1; }
    PROMPT="$(cat "$PROMPT_FILE")"
    ;;
esac
if [[ "$MODE" == "lean" ]]; then
  LEAN_NOTE_FILE="$SCRIPT_DIR/lean-note.md"
  [[ -f "$LEAN_NOTE_FILE" ]] || { echo "Error: $LEAN_NOTE_FILE not found." >&2; exit 1; }
  PROMPT="$PROMPT

$(cat "$LEAN_NOTE_FILE")"
fi
if [[ "$(get_language .task/PROJECT.md)" == "vi" ]]; then
  PROMPT="$PROMPT
Write your response in Vietnamese (keep the ## headings and file paths in English)."
fi

PROMPT="$(build_header_line)

$PROMPT"

case "$MODE" in
  plan) run_plan_mode ;;
  result) run_result_mode ;;
  lean) run_lean_mode ;;
  handoff) run_handoff_mode ;;
esac

WARN_AT=$((LIMIT * 85 / 100))
if [[ "$TOTAL_CHARS" -gt "$WARN_AT" ]]; then
  echo "Warning: payload is $TOTAL_CHARS chars, over 85% of the $LIMIT char limit." >&2
  echo "Section breakdown:" >&2
  print_breakdown
fi

copy_to_clipboard "$PAYLOAD"

LINES=$(printf '%s\n' "$PAYLOAD" | wc -l | tr -d ' ')
echo "Copied $LINES lines, $TOTAL_CHARS chars (limit $LIMIT)." >&2

if [[ ${#WEB_FILES[@]} -gt 0 ]]; then
  echo "Attach these files from .task/web/ ($WEB_DIR_ABS):" >&2
  for f in "${WEB_FILES[@]}"; do
    echo "  $f" >&2
  done
  if [[ "$(uname -s)" == "Darwin" ]]; then
    echo "  open .task/web" >&2
  fi
fi
