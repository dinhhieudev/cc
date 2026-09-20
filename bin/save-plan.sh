#!/usr/bin/env bash
set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
source "$SCRIPT_DIR/lib/save-plan-lib.sh"
source "$SCRIPT_DIR/lib/common.sh"

usage() {
  cat <<'EOF'
Usage: save-plan.sh [--force]
       save-plan.sh --stdin [--force]
       save-plan.sh --check

Reads the clipboard (the plan pasted back from the AI web conversation)
and writes it to .task/plan.md as:

  # Implementation Plan

  <clipboard content>

Must be run from the root of a project that has a .task/ directory.
Refuses to overwrite .task/plan.md if it already has real content,
unless --force is given. Warns (does not fail) if the pasted plan has
no "## Steps" section, is missing other required headings, still has
open questions, its Decisions to Review section looks thin, or its
Steps table references a File path that doesn't exist and isn't marked
as new.

Options:
  --force       Overwrite .task/plan.md even if it already has content
  --stdin       Read the plan from stdin instead of the clipboard;
                otherwise behaves exactly like the clipboard route
  --check       Validate the existing .task/plan.md in place (no
                clipboard read, no write); exits non-zero only if
                .task/plan.md is missing or still a placeholder
  -h, --help    Show this help and exit
EOF
}

FORCE=0
CHECK=0
STDIN=0
for arg in "$@"; do
  case "$arg" in
    -h|--help) usage; exit 0 ;;
    --force) FORCE=1 ;;
    --check) CHECK=1 ;;
    --stdin) STDIN=1 ;;
    *) echo "Error: unrecognized argument '$arg'." >&2; usage >&2; exit 1 ;;
  esac
done

if [[ "$CHECK" -eq 1 && "$STDIN" -eq 1 ]]; then
  echo "Error: --check and --stdin cannot be used together." >&2
  exit 1
fi

if [[ ! -d .task ]]; then
  echo "Error: no .task/ directory found here. Run this from the project root." >&2
  exit 1
fi

PLAN_FILE=.task/plan.md

if [[ "$CHECK" -eq 1 ]]; then
  if [[ ! -f "$PLAN_FILE" ]] || ! has_real_content "$PLAN_FILE"; then
    echo "Error: $PLAN_FILE is missing or still a placeholder." >&2
    exit 1
  fi
  check_required_headings "$PLAN_FILE"
  check_open_questions "$PLAN_FILE"
  check_thin_decisions "$PLAN_FILE"
  check_steps_paths "$PLAN_FILE"
  exit 0
fi

if [[ -f "$PLAN_FILE" ]] && has_real_content "$PLAN_FILE" && [[ "$FORCE" -eq 0 ]]; then
  echo "Error: $PLAN_FILE already has content. Use --force to overwrite." >&2
  exit 1
fi

read_clipboard() {
  if command -v pbpaste >/dev/null 2>&1; then
    pbpaste
  elif command -v xclip >/dev/null 2>&1; then
    xclip -selection clipboard -o
  elif command -v xsel >/dev/null 2>&1; then
    xsel --clipboard --output
  else
    echo "Error: no clipboard tool found (pbpaste/xclip/xsel)." >&2
    exit 1
  fi
}

if [[ "$STDIN" -eq 1 ]]; then
  CONTENT="$(cat)"
else
  CONTENT="$(read_clipboard)"
fi

if [[ -z "$(printf '%s' "$CONTENT" | tr -d '[:space:]')" ]]; then
  if [[ "$STDIN" -eq 1 ]]; then
    echo "Error: stdin is empty. Pipe the plan text in." >&2
  else
    echo "Error: clipboard is empty. Copy the plan from the web conversation first." >&2
  fi
  exit 1
fi

printf '# Implementation Plan\n\n%s\n' "$CONTENT" > "$PLAN_FILE"
set_active_status planned

if ! printf '%s\n' "$CONTENT" | grep -q '^## Steps'; then
  echo "Warning: no '## Steps' section found in the pasted plan." >&2
fi

check_required_headings "$PLAN_FILE"
check_open_questions "$PLAN_FILE"
check_thin_decisions "$PLAN_FILE"
check_steps_paths "$PLAN_FILE"

LINES=$(wc -l < "$PLAN_FILE" | tr -d ' ')
echo "Wrote $LINES lines to $PLAN_FILE." >&2
echo "Set .task/index.md Active Task Status to planned." >&2
echo "Now tell Claude: run execute" >&2
