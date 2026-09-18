#!/usr/bin/env bash
set -euo pipefail

usage() {
  cat <<'EOF'
Usage: save-followup.sh

Reads the clipboard (follow-up instructions from the AI web
conversation, or typed directly) and appends them to
.task/followups.md as a new "## Follow-up N" section. Creates
.task/followups.md from its template if missing.

Must be run from the root of a project that has a .task/ directory.
Warns (does not fail) if the previous follow-up has not yet been
marked "## Follow-up N — Applied".

Options:
  -h, --help    Show this help and exit
EOF
}

if [[ "${1:-}" == "-h" || "${1:-}" == "--help" ]]; then
  usage
  exit 0
fi

if [[ $# -gt 0 ]]; then
  echo "Error: save-followup.sh takes no arguments." >&2
  usage >&2
  exit 1
fi

if [[ ! -d .task ]]; then
  echo "Error: no .task/ directory found here. Run this from the project root." >&2
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
  echo "Error: clipboard is empty. Copy the follow-up instructions first." >&2
  exit 1
fi

FOLLOWUPS_FILE=.task/followups.md
if [[ ! -f "$FOLLOWUPS_FILE" ]]; then
  cat > "$FOLLOWUPS_FILE" <<'TEMPLATE'
# Follow-ups

<!-- One "## Follow-up N" section per follow-up request (bug fix or extra work), from the human or from AI web. -->
<!-- fix-agent appends "## Follow-up N — Applied" after handling it. -->
TEMPLATE
fi

LAST_N=$(grep -oE '^## Follow-up [0-9]+$' "$FOLLOWUPS_FILE" | awk '{print $3}' | sort -n | tail -1) || true
LAST_N=${LAST_N:-0}
N=$((LAST_N + 1))

if [[ "$LAST_N" -gt 0 ]] && ! grep -qF "## Follow-up $LAST_N — Applied" "$FOLLOWUPS_FILE"; then
  echo "Warning: '## Follow-up $LAST_N' has not been marked '— Applied' yet — appending anyway." >&2
fi

printf '\n## Follow-up %d\n\n%s\n' "$N" "$CLIPBOARD" >> "$FOLLOWUPS_FILE"

echo "Appended Follow-up $N to $FOLLOWUPS_FILE." >&2
echo "Now tell Claude: run fix" >&2
