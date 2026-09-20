# Local-only ignore handling for bin/install-untracked.sh: writes the
# claude++ workflow block to the target's .git/info/exclude (never a
# tracked file) and strips any legacy block left in the target's
# .gitignore by older installs. Sourced, not executed directly.
#
# Uses globals set by the caller: TARGET, BIN_FILES, UPGRADE, COPIED,
# SKIPPED, and the write_marker_block/replace_marker_block helpers from
# install-untracked-lib.sh.

IGNORE_MARKER_BEGIN="# claude++ workflow: begin"
IGNORE_MARKER_END="# claude++ workflow: end"

# Resolves the target's local-only exclude file (EXCLUDE_FILE, absolute
# path) via `git rev-parse --git-path info/exclude` so linked worktrees
# resolve to the shared repo's info/exclude, not a per-worktree copy.
resolve_exclude_file() {
  local rel dir base
  rel="$(git -C "$TARGET" rev-parse --git-path info/exclude)"
  case "$rel" in
    /*)
      EXCLUDE_FILE="$rel"
      mkdir -p "$(dirname "$EXCLUDE_FILE")"
      ;;
    *)
      dir="$(dirname "$rel")"
      base="$(basename "$rel")"
      mkdir -p "$TARGET/$dir"
      EXCLUDE_FILE="$(cd "$TARGET/$dir" && pwd)/$base"
      ;;
  esac
}

# Builds IGNORE_BODY: the same installed-path list as before, each line
# root-anchored with the target's show-prefix (empty at repo root) so
# info/exclude patterns — always relative to the repo root — only match
# this install's own paths.
build_ignore_body() {
  local prefix f
  prefix="$(git -C "$TARGET" rev-parse --show-prefix)"
  IGNORE_BODY="/${prefix}CLAUDE.local.md
/${prefix}.claude/agents/context-agent.md
/${prefix}.claude/agents/execute-agent.md
/${prefix}.claude/agents/fix-agent.md
/${prefix}.claude/instructions/
/${prefix}.claude/skills/save/
/${prefix}.task/"
  for f in "${BIN_FILES[@]}"; do
    IGNORE_BODY="$IGNORE_BODY
/${prefix}bin/$f"
  done
}

# Removes the $2/$3 marker block (and one blank line directly preceding
# it) from $1. No-op if the file or the begin marker is absent. Leaves
# the file empty (not deleted) if nothing but the block remained.
remove_marker_block() {
  local file="$1" begin="$2" end="$3" tmp
  [[ -f "$file" ]] || return 0
  grep -qF "$begin" "$file" || return 0
  tmp="$file.tmp.$$"
  awk -v begin="$begin" -v end="$end" '
    {
      if ($0 == begin) {
        skip = 1
        if (have_prev && prev != "") print prev
        have_prev = 0
        next
      }
      if (skip) {
        if ($0 == end) skip = 0
        next
      }
      if (have_prev) print prev
      prev = $0
      have_prev = 1
    }
    END { if (have_prev) print prev }
  ' "$file" > "$tmp" && mv "$tmp" "$file"
}

# Writes/refreshes the claude++ block in EXCLUDE_FILE from IGNORE_BODY,
# then strips a legacy block from the target's .gitignore if present.
install_ignore_block() {
  if [[ -f "$EXCLUDE_FILE" ]] && grep -qF "$IGNORE_MARKER_BEGIN" "$EXCLUDE_FILE"; then
    replace_marker_block "$EXCLUDE_FILE" "$IGNORE_MARKER_BEGIN" "$IGNORE_MARKER_END" "$IGNORE_BODY"
    COPIED+=(".git/info/exclude (claude++ workflow block refreshed)")
  else
    write_marker_block "$EXCLUDE_FILE" "$IGNORE_MARKER_BEGIN" "$IGNORE_MARKER_END" "$IGNORE_BODY"
    COPIED+=(".git/info/exclude (claude++ workflow block)")
  fi

  if [[ -f "$TARGET/.gitignore" ]] && grep -qF "$IGNORE_MARKER_BEGIN" "$TARGET/.gitignore"; then
    remove_marker_block "$TARGET/.gitignore" "$IGNORE_MARKER_BEGIN" "$IGNORE_MARKER_END"
    COPIED+=(".gitignore (legacy claude++ block removed — commit this once if that block was ever committed)")
  fi
}
