# Plan-mode and result-mode payload builders for bin/copy-for-web.sh.
# Sourced, not executed directly. Rely on globals set by the caller:
# PROMPT, LIMIT, WEB_DIR, FORCE_SPLIT, WEB_FILES (and set PAYLOAD/TOTAL_CHARS).

run_plan_mode() {
  build_project_section

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
}

run_result_mode() {
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
}
