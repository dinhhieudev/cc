#!/usr/bin/env bash
set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
REPO_ROOT="$(cd "$SCRIPT_DIR/.." && pwd)"
source "$SCRIPT_DIR/lib/install-untracked-lib.sh"

if [[ $# -eq 0 ]]; then
  usage
  exit 1
fi

parse_args "$@"

if [[ "$LANG_SET" -eq 1 && "$LANG_ARG" != "en" && "$LANG_ARG" != "vi" ]]; then
  echo "Error: --lang must be 'en' or 'vi' (got '$LANG_ARG')." >&2
  exit 1
fi

if [[ ${#POSITIONAL[@]} -eq 0 ]]; then
  usage
  exit 1
fi

if [[ ${#POSITIONAL[@]} -gt 1 ]]; then
  echo "Error: install-untracked.sh takes exactly one positional argument (the target project path)." >&2
  usage >&2
  exit 1
fi

TARGET_ARG="${POSITIONAL[0]}"

if [[ ! -e "$TARGET_ARG" ]]; then
  echo "Error: target path '$TARGET_ARG' does not exist." >&2
  exit 1
fi

if [[ ! -d "$TARGET_ARG" ]]; then
  echo "Error: target path '$TARGET_ARG' is not a directory." >&2
  exit 1
fi

TARGET="$(cd "$TARGET_ARG" && pwd)"

if ! git -C "$TARGET" rev-parse --is-inside-work-tree >/dev/null 2>&1; then
  echo "Error: '$TARGET' is not a git repository. This script only makes sense for a git-tracked project — it relies on .gitignore to keep the installed files out of git status." >&2
  exit 1
fi

CLAUDE_LOCAL="$TARGET/CLAUDE.local.md"
CLAUDE_MARKER_BEGIN="<!-- claude++ workflow: begin -->"
CLAUDE_MARKER_END="<!-- claude++ workflow: end -->"

if [[ "$UPGRADE" -eq 1 ]]; then
  check_upgrade_preflight "$CLAUDE_LOCAL" "$CLAUDE_MARKER_BEGIN" "$CLAUDE_MARKER_END"
fi

AGENT_FILES=(context-agent.md execute-agent.md fix-agent.md)
SKILL_DIRS=(save)
BIN_FILES=(copy-for-web.sh plan-prompt.md result-prompt.md save-plan.sh save-followup.sh attach.sh lean-note.md lib/copy-for-web-lib.sh lib/copy-for-web-design.sh lib/copy-for-web-modes.sh lib/copy-for-web-lean.sh lib/copy-for-web-handoff.sh lib/save-plan-lib.sh)

# --- Collision check -------------------------------------------------------
# A path only counts as a real collision if it exists in the target with
# content different from ours (see check_collisions in the lib). Skipped
# entirely under --upgrade: the preflight check above already proved the
# target is our own prior install, so differing agent/skill files there
# are ours to overwrite.
if [[ "$UPGRADE" -eq 0 ]]; then
  check_collisions
fi

# --- Copy --------------------------------------------------------------
COPIED=()
SKIPPED=()
TASK_FRESH=0

mkdir -p "$TARGET/.claude/agents"
for f in "${AGENT_FILES[@]}"; do
  cp "$REPO_ROOT/.claude/agents/$f" "$TARGET/.claude/agents/$f"
  COPIED+=(".claude/agents/$f")
done

mkdir -p "$TARGET/.claude/instructions"
cp -R "$REPO_ROOT/.claude/instructions/." "$TARGET/.claude/instructions/"
COPIED+=(".claude/instructions/")

mkdir -p "$TARGET/.claude/skills"
for d in "${SKILL_DIRS[@]}"; do
  # --upgrade: remove the target dir first so the copy mirrors the
  # template exactly (deleted template files don't linger).
  # Non-upgrade: mkdir + trailing-slash cp (not `cp -R src dst`) so a
  # rerun against an existing identical dst overwrites in place instead
  # of nesting src inside it.
  [[ "$UPGRADE" -eq 1 ]] && rm -rf "$TARGET/.claude/skills/$d"
  mkdir -p "$TARGET/.claude/skills/$d"
  cp -R "$REPO_ROOT/.claude/skills/$d/." "$TARGET/.claude/skills/$d/"
  COPIED+=(".claude/skills/$d/")
done

# --- .task/ --------------------------------------------------------------
if [[ "$UPGRADE" -eq 1 ]]; then
  # .task/ is never copied/overwritten on upgrade. The only exception is
  # the Language section in .task/PROJECT.md, kept in sync like a fresh
  # install keeps it in sync at creation time.
  upgrade_project_language "$TARGET/.task/PROJECT.md" "$LANG_SET" "$LANG_ARG"
elif [[ -e "$TARGET/.task" ]]; then
  SKIPPED+=(".task/ (already exists — left untouched)")
  if [[ "$LANG_SET" -eq 1 ]]; then
    SKIPPED+=(".task/PROJECT.md language (existing .task/ left untouched — set \"Language: $LANG_ARG\" by hand)")
  fi
else
  cp -R "$REPO_ROOT/.task" "$TARGET/.task"
  COPIED+=(".task/")
  TASK_FRESH=1
  if [[ "$LANG_SET" -eq 1 ]]; then
    set_project_language "$TARGET/.task/PROJECT.md" "$LANG_ARG"
    COPIED+=(".task/PROJECT.md language set to $LANG_ARG")
  fi
fi

mkdir -p "$TARGET/bin/lib"
for f in "${BIN_FILES[@]}"; do
  cp -p "$REPO_ROOT/bin/$f" "$TARGET/bin/$f"
  COPIED+=("bin/$f")
done

# --upgrade only: drop retired paths from prior installs.
if [[ "$UPGRADE" -eq 1 && -f "$TARGET/bin/diff-for-web.sh" ]]; then
  rm -f "$TARGET/bin/diff-for-web.sh"
  COPIED+=("bin/diff-for-web.sh (removed)")
fi
if [[ "$UPGRADE" -eq 1 && -d "$TARGET/.claude/skills/overview" ]]; then
  rm -rf "$TARGET/.claude/skills/overview"; COPIED+=(".claude/skills/overview/ (removed)")
fi

# --- CLAUDE.local.md ----------------------------------------------------
if [[ "$UPGRADE" -eq 1 ]]; then
  replace_marker_block "$CLAUDE_LOCAL" "$CLAUDE_MARKER_BEGIN" "$CLAUDE_MARKER_END" "$(cat "$REPO_ROOT/CLAUDE.md")"
  COPIED+=("CLAUDE.local.md (claude++ workflow block refreshed)")
elif write_marker_block "$CLAUDE_LOCAL" "$CLAUDE_MARKER_BEGIN" "$CLAUDE_MARKER_END" "$(cat "$REPO_ROOT/CLAUDE.md")"; then
  COPIED+=("CLAUDE.local.md (claude++ workflow block)")
else
  SKIPPED+=("CLAUDE.local.md (already has the claude++ workflow block)")
fi

# --- .gitignore ----------------------------------------------------------
GITIGNORE="$TARGET/.gitignore"
GITIGNORE_MARKER_BEGIN="# claude++ workflow: begin"
GITIGNORE_MARKER_END="# claude++ workflow: end"
GITIGNORE_BODY="CLAUDE.local.md
.claude/agents/context-agent.md
.claude/agents/execute-agent.md
.claude/agents/fix-agent.md
.claude/instructions/
.claude/skills/save/
.task/"
for f in "${BIN_FILES[@]}"; do
  GITIGNORE_BODY="$GITIGNORE_BODY
bin/$f"
done

if [[ "$UPGRADE" -eq 1 ]]; then
  if [[ -f "$GITIGNORE" ]] && grep -qF "$GITIGNORE_MARKER_BEGIN" "$GITIGNORE"; then
    replace_marker_block "$GITIGNORE" "$GITIGNORE_MARKER_BEGIN" "$GITIGNORE_MARKER_END" "$GITIGNORE_BODY"
    COPIED+=(".gitignore (claude++ workflow block refreshed)")
  else
    write_marker_block "$GITIGNORE" "$GITIGNORE_MARKER_BEGIN" "$GITIGNORE_MARKER_END" "$GITIGNORE_BODY"
    COPIED+=(".gitignore (claude++ workflow block)")
  fi
elif write_marker_block "$GITIGNORE" "$GITIGNORE_MARKER_BEGIN" "$GITIGNORE_MARKER_END" "$GITIGNORE_BODY"; then
  COPIED+=(".gitignore (claude++ workflow block)")
else
  SKIPPED+=(".gitignore (already has the claude++ workflow block)")
fi

# --- Summary ---------------------------------------------------------------
SUMMARY_HEADING="Copied:"
if [[ "$UPGRADE" -eq 1 ]]; then
  echo "Upgraded claude++ workflow (untracked) in: $TARGET" >&2
  SUMMARY_HEADING="Updated:"
else
  echo "Installed claude++ workflow (untracked) into: $TARGET" >&2
fi
echo >&2
echo "$SUMMARY_HEADING" >&2
for c in "${COPIED[@]}"; do
  echo "  $c" >&2
done
if [[ ${#SKIPPED[@]} -gt 0 ]]; then
  echo >&2
  echo "Skipped:" >&2
  for s in "${SKIPPED[@]}"; do
    echo "  $s" >&2
  done
fi
if [[ "$TASK_FRESH" -eq 1 ]]; then
  echo >&2
  echo "Reminder: fill in $TARGET/.task/PROJECT.md before starting a task." >&2
fi
