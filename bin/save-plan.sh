#!/usr/bin/env bash
set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
source "$SCRIPT_DIR/lib/save-plan-lib.sh"

usage() {
  cat <<'EOF'
Usage: save-plan.sh [--force]

Reads the clipboard (the plan pasted back from the AI web conversation)
and writes it to .task/plan.md as:

  # Implementation Plan

  <clipboard content>

Must be run from the root of a project that has a .task/ directory.
Refuses to overwrite .task/plan.md if it already has real content,
unless --force is given. Warns (does not fail) if the pasted plan has
no "## Steps" section, is missing other required headings, still has
open questions, or its Steps table references a File path that doesn't
exist and isn't marked as new.

Options:
  --force       Overwrite .task/plan.md even if it already has content
  -h, --help    Show this help and exit
EOF
}

FORCE=0
for arg in "$@"; do
  case "$arg" in
    -h|--help) usage; exit 0 ;;
    --force) FORCE=1 ;;
    *) echo "Error: unrecognized argument '$arg'." >&2; usage >&2; exit 1 ;;
  esac
done

if [[ ! -d .task ]]; then
  echo "Error: no .task/ directory found here. Run this from the project root." >&2
  exit 1
fi

# Placeholder files contain nothing but a heading and HTML comment(s); strip
# comments (including ones spanning multiple lines), heading lines, and
# blank lines, then check whether anything real is left.
strip_comments() {
  awk '
    BEGIN { incomment = 0 }
    {
      line = $0
      out = ""
      while (length(line) > 0) {
        if (incomment) {
          end = index(line, "-->")
          if (end == 0) { line = "" }
          else { line = substr(line, end + 3); incomment = 0 }
        } else {
          start = index(line, "<!--")
          if (start == 0) { out = out line; line = "" }
          else {
            out = out substr(line, 1, start - 1)
            line = substr(line, start + 4)
            incomment = 1
          }
        }
      }
      print out
    }
  ' "$1"
}

has_real_content() {
  strip_comments "$1" | awk '
    /^[[:space:]]*#/ { next }
    /^[[:space:]]*$/ { next }
    { found = 1 }
    END { exit(found ? 0 : 1) }
  '
}

PLAN_FILE=.task/plan.md
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

CLIPBOARD="$(read_clipboard)"
if [[ -z "$(printf '%s' "$CLIPBOARD" | tr -d '[:space:]')" ]]; then
  echo "Error: clipboard is empty. Copy the plan from the web conversation first." >&2
  exit 1
fi

printf '# Implementation Plan\n\n%s\n' "$CLIPBOARD" > "$PLAN_FILE"

if ! printf '%s\n' "$CLIPBOARD" | grep -q '^## Steps'; then
  echo "Warning: no '## Steps' section found in the pasted plan." >&2
fi

check_required_headings "$PLAN_FILE"
check_open_questions "$PLAN_FILE"
check_steps_paths "$PLAN_FILE"

LINES=$(wc -l < "$PLAN_FILE" | tr -d ' ')
echo "Wrote $LINES lines to $PLAN_FILE." >&2
echo "Now tell Claude: run execute" >&2
