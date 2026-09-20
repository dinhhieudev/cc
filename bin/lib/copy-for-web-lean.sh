# Lean-mode payload builder for bin/copy-for-web.sh. Sourced, not executed
# directly. Relies on globals set by the caller: PROMPT, LIMIT, WEB_DIR,
# FORCE_SPLIT, WEB_FILES (and sets PAYLOAD/TOTAL_CHARS).

# Noise dropped from the file tree during degradation: lockfiles, images,
# minified files, and .task/** (attachments/scratch, never source).
LEAN_NOISE_RE='(^|/)(package-lock\.json|yarn\.lock|pnpm-lock\.yaml|composer\.lock|Gemfile\.lock|Cargo\.lock|poetry\.lock)$|\.(png|jpe?g|gif|svg|ico|webp|bmp)$|\.min\.[^/]+$|^\.task/'

# Prints the project's file tree, one relative path per line, sorted.
build_file_tree() {
  if git rev-parse --is-inside-work-tree >/dev/null 2>&1; then
    git ls-files -co --exclude-standard | LC_ALL=C sort -u
  else
    find . \( -name .git -o -name node_modules -o -name .build -o -name dist -o -name build -o -path ./.task/web \) -prune -o -type f -print \
      | sed 's|^\./||' | LC_ALL=C sort
  fi
}

# Collapses the path list on stdin to "dir/ (N files)" lines for every path
# with at least $1 "/"-separated directory components; shallower paths are
# left literal.
collapse_at_depth() {
  local depth="$1"
  awk -v D="$depth" '
    {
      n = split($0, parts, "/")
      if (n - 1 >= D) {
        key = parts[1]
        for (i = 2; i <= D; i++) key = key "/" parts[i]
        count[key]++
      } else {
        print $0
      }
    }
    END {
      for (k in count) print k "/ (" count[k] " files)"
    }
  ' | LC_ALL=C sort
}

# Prints the max directory depth (number of "/") across the path list on stdin.
max_depth() {
  awk -F/ '{ if (NF - 1 > m) m = NF - 1 } END { print m + 0 }'
}

run_lean_mode() {
  build_project_section

  if [[ ! -f .task/overview.md ]] || ! has_real_content .task/overview.md; then
    echo "Error: .task/overview.md not found or still a placeholder. Run 'task (lean): ...' first." >&2
    exit 1
  fi
  OVERVIEW_SECTION=$'--- OVERVIEW ---\n'"$(cat .task/overview.md)"
  PROJECT_DISPLAY="$PROJECT_SECTION"
  [[ -n "$PROJECT_DISPLAY" ]] && PROJECT_DISPLAY="$(printf '%s' "$PROJECT_DISPLAY" | strip_comments /dev/stdin)"

  FULL_TREE="$(build_file_tree)"
  TREE_TEXT="$FULL_TREE"
  TREE_DISPLAY=$'--- FILE TREE ---\n'"$TREE_TEXT"

  recompute() {
    set_blocks "prompt" "$PROMPT" "PROJECT" "$PROJECT_DISPLAY" "OVERVIEW" "$OVERVIEW_SECTION" \
      "FILE TREE" "$TREE_DISPLAY"
    PAYLOAD="$(join_blocks "${BLOCKS[@]}")"
    TOTAL_CHARS=$(count_chars "$PAYLOAD")
  }
  recompute

  if [[ "$FORCE_SPLIT" -eq 1 ]]; then
    printf '%s\n' "$FULL_TREE" > "$WEB_DIR/file-tree.txt"
    WEB_FILES+=("file-tree.txt")
    TREE_DISPLAY="--- FILE TREE --- (attached as file-tree.txt)"
    recompute
  elif [[ "$TOTAL_CHARS" -gt "$LIMIT" ]]; then
    # Step 1: drop common noise.
    FILTERED_TREE="$(printf '%s\n' "$FULL_TREE" | grep -vE "$LEAN_NOISE_RE" || true)"
    TREE_TEXT="$FILTERED_TREE"
    TREE_DISPLAY=$'--- FILE TREE ---\n'"$TREE_TEXT"
    recompute

    # Step 2: collapse to directory-level counts, deepest-first.
    if [[ "$TOTAL_CHARS" -gt "$LIMIT" ]]; then
      local d maxd
      maxd=$(printf '%s\n' "$FILTERED_TREE" | max_depth)
      for (( d = maxd; d >= 1; d-- )); do
        TREE_TEXT="$(printf '%s\n' "$FILTERED_TREE" | collapse_at_depth "$d")"
        TREE_DISPLAY=$'--- FILE TREE ---\n'"$TREE_TEXT"
        recompute
        [[ "$TOTAL_CHARS" -le "$LIMIT" ]] && break
      done
    fi

    # Step 3: give up collapsing, attach the full original tree instead.
    if [[ "$TOTAL_CHARS" -gt "$LIMIT" ]]; then
      printf '%s\n' "$FULL_TREE" > "$WEB_DIR/file-tree.txt"
      WEB_FILES+=("file-tree.txt")
      TREE_DISPLAY="--- FILE TREE --- (attached as file-tree.txt)"
      recompute
    fi
  fi

  if [[ -n "$PROJECT_DISPLAY" ]] && { [[ "$FORCE_SPLIT" -eq 1 ]] || [[ "$TOTAL_CHARS" -gt "$LIMIT" ]]; }; then
    strip_comments .task/PROJECT.md > "$WEB_DIR/project.md"
    WEB_FILES+=("project.md")
    PROJECT_DISPLAY="--- PROJECT --- (attached as project.md)"
    recompute
  fi

  if [[ "$TOTAL_CHARS" -gt "$LIMIT" ]]; then
    echo "Error: even with FILE TREE/PROJECT attached, payload is $TOTAL_CHARS chars, over the $LIMIT char limit." >&2
    echo "Section breakdown:" >&2
    print_breakdown
    exit 1
  fi
}
