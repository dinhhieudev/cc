#!/usr/bin/env bash
set -euo pipefail

usage() {
  cat <<'EOF'
Usage: copy-for-web.sh

Concatenates .task/PROJECT.md, .task/overview.md, and .task/context.md
(with separator headers) and copies the result to the clipboard, for
pasting into a ChatGPT/Gemini web conversation. If .task/PROJECT.md is
missing or empty, it is skipped with a warning instead of failing —
unlike overview.md and context.md, which are required.

Must be run from the root of a project that has a .task/ directory.

Options:
  -h, --help    Show this help and exit
EOF
}

if [[ "${1:-}" == "-h" || "${1:-}" == "--help" ]]; then
  usage
  exit 0
fi

if [[ $# -gt 0 ]]; then
  echo "Error: copy-for-web.sh takes no arguments." >&2
  usage >&2
  exit 1
fi

if [[ ! -d .task ]]; then
  echo "Error: no .task/ directory found here. Run this from the project root." >&2
  exit 1
fi

# Placeholder files contain nothing but a heading and HTML comment(s); strip
# comments (including ones spanning multiple lines), heading lines, and blank
# lines, then check whether anything real is left.
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

# .task/PROJECT.md ships with its ## Git section pre-filled (Base branch /
# Task branch prefix) and its ## Language section pre-filled (Language: en),
# so has_real_content alone would never flag a PROJECT.md whose substantive
# sections are all still blank. Strip those pre-filled lines too before
# checking for real content.
project_has_substance() {
  strip_comments "$1" | awk '
    /^[[:space:]]*#/ { next }
    /^[[:space:]]*$/ { next }
    /^Base branch:/ { next }
    /^Task branch prefix:/ { next }
    /^Language:/ { next }
    { found = 1 }
    END { exit(found ? 0 : 1) }
  '
}

# .task/PROJECT.md is filled in once by the human, not generated per task —
# missing or empty is a warning, not a hard failure.
PROJECT_SECTION=""
if [[ ! -f .task/PROJECT.md ]]; then
  echo "Warning: .task/PROJECT.md is missing — the AI web planner will not receive project architecture/conventions." >&2
elif ! project_has_substance .task/PROJECT.md; then
  echo "Warning: .task/PROJECT.md has no project context filled in (only the Git/Language sections) — the AI web planner will not receive project architecture/conventions." >&2
else
  PROJECT_SECTION=$(printf '%s\n%s' "--- PROJECT ---" "$(cat .task/PROJECT.md)")
fi

for f in .task/overview.md .task/context.md; do
  if [[ ! -f "$f" ]]; then
    echo "Error: $f not found. Run the overview step first." >&2
    exit 1
  fi
  if ! has_real_content "$f"; then
    echo "Error: $f still contains only its placeholder comment. Run the overview step first." >&2
    exit 1
  fi
done

copy_to_clipboard() {
  local payload="$1"
  if command -v pbcopy >/dev/null 2>&1; then
    printf '%s' "$payload" | pbcopy
    echo "Copied to clipboard (pbcopy)." >&2
  elif command -v xclip >/dev/null 2>&1; then
    printf '%s' "$payload" | xclip -selection clipboard
    echo "Copied to clipboard (xclip)." >&2
  elif command -v xsel >/dev/null 2>&1; then
    printf '%s' "$payload" | xsel --clipboard --input
    echo "Copied to clipboard (xsel)." >&2
  else
    echo "No clipboard tool found (pbcopy/xclip/xsel); printing payload to stdout instead." >&2
    printf '%s\n' "$payload"
  fi
}

PROJECT_SEP=""
if [[ -n "$PROJECT_SECTION" ]]; then
  PROJECT_SEP=$'\n\n'
fi

PAYLOAD=$(printf '%s%s%s\n%s\n\n%s\n%s\n' \
  "$PROJECT_SECTION" "$PROJECT_SEP" \
  "--- OVERVIEW ---" "$(cat .task/overview.md)" \
  "--- CONTEXT ---" "$(cat .task/context.md)")

copy_to_clipboard "$PAYLOAD"

LINES=$(printf '%s\n' "$PAYLOAD" | wc -l | tr -d ' ')
CHARS=$(printf '%s' "$PAYLOAD" | wc -c | tr -d ' ')
TOKENS=$((CHARS / 4))
echo "Copied $LINES lines (~$TOKENS tokens estimated) to clipboard." >&2
