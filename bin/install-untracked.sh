#!/usr/bin/env bash
set -euo pipefail

usage() {
  cat <<'EOF'
Usage: install-untracked.sh [--lang en|vi] <target-project-path>

Installs the claude++ workflow (agents, instructions, skills, .task/,
bin/ helper scripts) into <target-project-path>, and marks every
installed path as gitignored in the target so none of it pollutes the
target project's shared git history.

Also merges this repo's CLAUDE.md (Agent Routing table + hard rules)
into <target-project-path>/CLAUDE.local.md, between marker comments.

<target-project-path> must already exist and be a git repository — this
script only makes sense for a git-tracked project, since it relies on
.gitignore to keep the installed files out of git status.

If .claude/agents/{context,execute,fix}-agent.md or
.claude/skills/{overview,save}/ already exist in the target with
different content, the script aborts before copying anything (see this
repo's README.md, section "c) Merging when the target project already
has .claude/agents/ or .claude/skills/"). Re-running against a target
that already has an identical install is safe (idempotent).

Options:
  --lang <en|vi>  Set Language: in the installed .task/PROJECT.md; this
                   controls the language agents write .task prose and
                   reports in. Also accepts --lang=<en|vi>. Default: en.
  -h, --help      Show this help and exit
EOF
}

if [[ $# -eq 0 ]]; then
  usage
  exit 1
fi

LANG_ARG=""
LANG_SET=0
POSITIONAL=()

while [[ $# -gt 0 ]]; do
  case "$1" in
    -h|--help)
      usage
      exit 0
      ;;
    --lang)
      if [[ $# -lt 2 ]]; then
        echo "Error: --lang requires a value (en or vi)." >&2
        exit 1
      fi
      LANG_ARG="$2"
      LANG_SET=1
      shift 2
      ;;
    --lang=*)
      LANG_ARG="${1#--lang=}"
      LANG_SET=1
      shift
      ;;
    -*)
      echo "Error: unknown option '$1'." >&2
      usage >&2
      exit 1
      ;;
    *)
      POSITIONAL+=("$1")
      shift
      ;;
  esac
done

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

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
REPO_ROOT="$(cd "$SCRIPT_DIR/.." && pwd)"

# --- Collision check -------------------------------------------------------
# A path only counts as a real collision if it exists in the target with
# content different from ours. If it exists and is byte-for-byte identical,
# it's a previous install by this same script — safe to leave alone, so
# re-running against a target it already installed into is idempotent
# rather than a hard failure.
AGENT_FILES=(context-agent.md execute-agent.md fix-agent.md)
SKILL_DIRS=(overview save)

HARD_COLLISIONS=()

for f in "${AGENT_FILES[@]}"; do
  src="$REPO_ROOT/.claude/agents/$f"
  dst="$TARGET/.claude/agents/$f"
  if [[ -e "$dst" ]] && ! cmp -s "$src" "$dst"; then
    HARD_COLLISIONS+=(".claude/agents/$f")
  fi
done

for d in "${SKILL_DIRS[@]}"; do
  src="$REPO_ROOT/.claude/skills/$d"
  dst="$TARGET/.claude/skills/$d"
  if [[ -e "$dst" ]] && ! diff -rq "$src" "$dst" >/dev/null 2>&1; then
    HARD_COLLISIONS+=(".claude/skills/$d")
  fi
done

if [[ ${#HARD_COLLISIONS[@]} -gt 0 ]]; then
  echo "Error: the following already exist in '$TARGET' with different content:" >&2
  for c in "${HARD_COLLISIONS[@]}"; do
    echo "  $c" >&2
  done
  echo "Rename one side manually and update its references — see this repo's README.md, section \"c) Merging when the target project already has .claude/agents/ or .claude/skills/\"." >&2
  exit 1
fi

# --- Copy --------------------------------------------------------------
COPIED=()
SKIPPED=()

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
  # mkdir + trailing-slash cp (not `cp -R src dst`) so a rerun against an
  # existing identical dst overwrites in place instead of nesting src inside it.
  mkdir -p "$TARGET/.claude/skills/$d"
  cp -R "$REPO_ROOT/.claude/skills/$d/." "$TARGET/.claude/skills/$d/"
  COPIED+=(".claude/skills/$d/")
done

TASK_FRESH=0
if [[ -e "$TARGET/.task" ]]; then
  SKIPPED+=(".task/ (already exists — left untouched)")
  if [[ "$LANG_SET" -eq 1 ]]; then
    SKIPPED+=(".task/PROJECT.md language (existing .task/ left untouched — set \"Language: $LANG_ARG\" by hand)")
  fi
else
  cp -R "$REPO_ROOT/.task" "$TARGET/.task"
  COPIED+=(".task/")
  TASK_FRESH=1
fi

if [[ "$TASK_FRESH" -eq 1 && "$LANG_SET" -eq 1 ]]; then
  PROJECT_MD="$TARGET/.task/PROJECT.md"
  if grep -q '^Language:' "$PROJECT_MD"; then
    awk -v lang="$LANG_ARG" '/^Language:/ { print "Language: " lang; next } { print }' "$PROJECT_MD" > "$PROJECT_MD.tmp" && mv "$PROJECT_MD.tmp" "$PROJECT_MD"
  else
    printf '\n## Language\n\nLanguage: %s\n' "$LANG_ARG" >> "$PROJECT_MD"
  fi
  COPIED+=(".task/PROJECT.md language set to $LANG_ARG")
fi

mkdir -p "$TARGET/bin"
cp -p "$REPO_ROOT/bin/copy-for-web.sh" "$TARGET/bin/copy-for-web.sh"
cp -p "$REPO_ROOT/bin/diff-for-web.sh" "$TARGET/bin/diff-for-web.sh"
COPIED+=("bin/copy-for-web.sh" "bin/diff-for-web.sh")

# --- CLAUDE.local.md ----------------------------------------------------
CLAUDE_LOCAL="$TARGET/CLAUDE.local.md"
CLAUDE_MARKER_BEGIN="<!-- claude++ workflow: begin -->"
CLAUDE_MARKER_END="<!-- claude++ workflow: end -->"

if [[ -f "$CLAUDE_LOCAL" ]] && grep -qF "$CLAUDE_MARKER_BEGIN" "$CLAUDE_LOCAL"; then
  SKIPPED+=("CLAUDE.local.md (already has the claude++ workflow block)")
else
  CLAUDE_BLOCK="$CLAUDE_MARKER_BEGIN"$'\n'"$(cat "$REPO_ROOT/CLAUDE.md")"$'\n'"$CLAUDE_MARKER_END"
  if [[ -f "$CLAUDE_LOCAL" ]]; then
    printf '\n%s\n' "$CLAUDE_BLOCK" >> "$CLAUDE_LOCAL"
  else
    printf '%s\n' "$CLAUDE_BLOCK" > "$CLAUDE_LOCAL"
  fi
  COPIED+=("CLAUDE.local.md (claude++ workflow block)")
fi

# --- .gitignore ----------------------------------------------------------
GITIGNORE="$TARGET/.gitignore"
GITIGNORE_MARKER_BEGIN="# claude++ workflow: begin"
GITIGNORE_MARKER_END="# claude++ workflow: end"

if [[ -f "$GITIGNORE" ]] && grep -qF "$GITIGNORE_MARKER_BEGIN" "$GITIGNORE"; then
  SKIPPED+=(".gitignore (already has the claude++ workflow block)")
else
  GITIGNORE_BLOCK="$GITIGNORE_MARKER_BEGIN
CLAUDE.local.md
.claude/agents/context-agent.md
.claude/agents/execute-agent.md
.claude/agents/fix-agent.md
.claude/instructions/
.claude/skills/overview/
.claude/skills/save/
.task/
bin/copy-for-web.sh
bin/diff-for-web.sh
$GITIGNORE_MARKER_END"
  if [[ -f "$GITIGNORE" ]]; then
    printf '\n%s\n' "$GITIGNORE_BLOCK" >> "$GITIGNORE"
  else
    printf '%s\n' "$GITIGNORE_BLOCK" > "$GITIGNORE"
  fi
  COPIED+=(".gitignore (claude++ workflow block)")
fi

# --- Summary ---------------------------------------------------------------
echo "Installed claude++ workflow (untracked) into: $TARGET" >&2
echo >&2
echo "Copied:" >&2
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
