#!/usr/bin/env bash
set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
source "$SCRIPT_DIR/lib/copy-for-web-lib.sh"

LIMIT="${WEB_CHAR_LIMIT:-25000}"

usage() {
  cat <<'EOF'
Usage: copy-for-web.sh [result] [--split]

No argument: builds the planning payload from .task/PROJECT.md (if it
has real content), .task/overview.md, and .task/context.md, prefixed
with the planning prompt (bin/plan-prompt.md), and copies it to the
clipboard for pasting into a ChatGPT/Gemini web conversation.

result: builds the result-review payload from .task/implementation.md
and .task/followups.md (if it has real content), prefixed with the
result prompt (bin/result-prompt.md).

If .task/PROJECT.md's Language is vi, a line asking for a Vietnamese
response is appended after the prompt.

The web chat accepts at most WEB_CHAR_LIMIT characters per message
(default 25000). If the payload would exceed it, the largest sections
are written to files under .task/web/ instead (CONTEXT then PROJECT in
plan mode; FOLLOW-UPS then IMPLEMENTATION in result mode) and the
clipboard message references them by name — attach those files in the
web chat yourself. .task/web/ is cleared and rebuilt on every run.
--split forces CONTEXT and PROJECT to attachments regardless of size
(plan mode only). Warns if the message still exceeds 85% of the limit.

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
    result) MODE="result" ;;
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

if [[ "$MODE" == "plan" ]]; then
  PROMPT_FILE="$SCRIPT_DIR/plan-prompt.md"
else
  PROMPT_FILE="$SCRIPT_DIR/result-prompt.md"
fi
[[ -f "$PROMPT_FILE" ]] || { echo "Error: $PROMPT_FILE not found." >&2; exit 1; }

PROMPT="$(cat "$PROMPT_FILE")"
if [[ "$(get_language .task/PROJECT.md)" == "vi" ]]; then
  PROMPT="$PROMPT
Write your response in Vietnamese (keep the ## headings and file paths in English)."
fi

if [[ "$MODE" == "plan" ]]; then
  PROJECT_SECTION=""
  if [[ ! -f .task/PROJECT.md ]]; then
    echo "Warning: .task/PROJECT.md is missing — the AI web planner will not receive project architecture/conventions." >&2
  elif ! project_has_substance .task/PROJECT.md; then
    echo "Warning: .task/PROJECT.md has no project context filled in (only the Language section) — the AI web planner will not receive project architecture/conventions." >&2
  else
    PROJECT_SECTION=$'--- PROJECT ---\n'"$(cat .task/PROJECT.md)"
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

  OVERVIEW_SECTION=$'--- OVERVIEW ---\n'"$(cat .task/overview.md)"
  CONTEXT_SECTION=$'--- CONTEXT ---\n'"$(cat .task/context.md)"
  CONTEXT_DISPLAY="$CONTEXT_SECTION"
  PROJECT_DISPLAY="$PROJECT_SECTION"

  copy_attach_files "$WEB_DIR"

  recompute() {
    set_blocks "prompt" "$PROMPT" "PROJECT" "$PROJECT_DISPLAY" "OVERVIEW" "$OVERVIEW_SECTION" \
      "CONTEXT" "$CONTEXT_DISPLAY" "ATTACHED FILES" "$ATTACH_LIST"
    PAYLOAD="$(join_blocks "${BLOCKS[@]}")"
    TOTAL_CHARS=$(count_chars "$PAYLOAD")
  }
  recompute

  if [[ "$FORCE_SPLIT" -eq 1 || "$TOTAL_CHARS" -gt "$LIMIT" ]]; then
    cat .task/context.md > "$WEB_DIR/context.md"
    WEB_FILES+=("context.md")
    CONTEXT_DISPLAY="--- CONTEXT --- (attached as context.md)"
    recompute

    if [[ -n "$PROJECT_DISPLAY" ]] && { [[ "$FORCE_SPLIT" -eq 1 ]] || [[ "$TOTAL_CHARS" -gt "$LIMIT" ]]; }; then
      cat .task/PROJECT.md > "$WEB_DIR/project.md"
      WEB_FILES+=("project.md")
      PROJECT_DISPLAY="--- PROJECT --- (attached as project.md)"
      recompute
    fi

    if [[ "$TOTAL_CHARS" -gt "$LIMIT" ]]; then
      echo "Error: even with CONTEXT/PROJECT attached, payload is $TOTAL_CHARS chars, over the $LIMIT char limit." >&2
      echo "Section breakdown:" >&2
      print_breakdown
      exit 1
    fi
  fi
else
  if [[ ! -f .task/implementation.md ]] || ! has_real_content .task/implementation.md; then
    echo "Error: .task/implementation.md not found or still a placeholder. Run execute first." >&2
    exit 1
  fi

  IMPLEMENTATION_SECTION=$'--- IMPLEMENTATION ---\n'"$(cat .task/implementation.md)"
  IMPLEMENTATION_DISPLAY="$IMPLEMENTATION_SECTION"
  FOLLOWUPS_DISPLAY=""
  if [[ -f .task/followups.md ]] && has_real_content .task/followups.md; then
    FOLLOWUPS_DISPLAY=$'--- FOLLOW-UPS ---\n'"$(cat .task/followups.md)"
  fi

  recompute() {
    set_blocks "prompt" "$PROMPT" "IMPLEMENTATION" "$IMPLEMENTATION_DISPLAY" "FOLLOW-UPS" "$FOLLOWUPS_DISPLAY"
    PAYLOAD="$(join_blocks "${BLOCKS[@]}")"
    TOTAL_CHARS=$(count_chars "$PAYLOAD")
  }
  recompute

  if [[ "$TOTAL_CHARS" -gt "$LIMIT" ]]; then
    if [[ -n "$FOLLOWUPS_DISPLAY" ]]; then
      cat .task/followups.md > "$WEB_DIR/followups.md"
      WEB_FILES+=("followups.md")
      FOLLOWUPS_DISPLAY="--- FOLLOW-UPS --- (attached as followups.md)"
      recompute
    fi

    if [[ "$TOTAL_CHARS" -gt "$LIMIT" ]]; then
      cat .task/implementation.md > "$WEB_DIR/implementation.md"
      WEB_FILES+=("implementation.md")
      IMPLEMENTATION_DISPLAY="--- IMPLEMENTATION --- (attached as implementation.md)"
      recompute
    fi

    if [[ "$TOTAL_CHARS" -gt "$LIMIT" ]]; then
      echo "Error: even with FOLLOW-UPS/IMPLEMENTATION attached, payload is $TOTAL_CHARS chars, over the $LIMIT char limit." >&2
      echo "Section breakdown:" >&2
      print_breakdown
      exit 1
    fi
  fi
fi

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
