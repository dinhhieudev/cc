# Handoff-mode payload builder for bin/copy-for-web.sh. Sourced, not
# executed directly. Relies on globals set by the caller: PROMPT, LIMIT,
# WEB_DIR, FORCE_SPLIT, WEB_FILES (and sets PAYLOAD/TOTAL_CHARS).

# Fixed intro for a fresh web chat continuing an existing task — assigned
# to PROMPT by bin/copy-for-web.sh's mode dispatch, the same slot plan/
# result mode fill from their prompt files.
HANDOFF_INTRO="Continuing an existing task in a fresh conversation.

Below is where things stand — no need to restate the original context
back to me. The summaries below cover the task so far; please read them
before replying."

# Extracts the section under an exact "## Heading" line from $1 up to
# (not including) the next "## " line, heading included. Empty if absent.
extract_section() {
  awk -v h="$2" '$0==h{s=1;print;next} /^## /{s=0} s' "$1"
}

# ## Goal + ## Acceptance Criteria from overview.md; falls back to the
# first 800 characters if neither heading is present.
build_overview_summary() {
  local goal="" ac=""
  if grep -q '^## Goal$' .task/overview.md; then
    goal="$(extract_section .task/overview.md '## Goal')"
  fi
  if grep -q '^## Acceptance Criteria$' .task/overview.md; then
    ac="$(extract_section .task/overview.md '## Acceptance Criteria')"
  fi
  if [[ -z "$goal" && -z "$ac" ]]; then
    printf '%s\n(truncated)' "$(LC_ALL=en_US.UTF-8 cut -c1-800 .task/overview.md)"
  elif [[ -n "$goal" && -n "$ac" ]]; then
    printf '%s\n\n%s' "$goal" "$ac"
  else
    printf '%s' "${goal}${ac}"
  fi
}

# ## Steps table from plan.md; "(no plan saved yet)" if unsaved/empty.
build_plan_steps() {
  if [[ ! -f .task/plan.md ]] || ! has_real_content .task/plan.md; then
    printf '(no plan saved yet)'
    return
  fi
  local steps
  steps="$(extract_section .task/plan.md '## Steps')"
  if [[ -n "$steps" ]]; then printf '%s' "$steps"; else printf '(no plan saved yet)'; fi
}

# Last "## Follow-up N" (+ its "— Applied" section if present) from
# followups.md; else "## Changes" + "## Deviations from Plan" from
# implementation.md; else "(no execution yet)".
build_latest_status() {
  local n="" req="" applied="" changes="" deviations=""
  if [[ -f .task/followups.md ]] && has_real_content .task/followups.md; then
    n="$(grep -oE '^## Follow-up [0-9]+$' .task/followups.md | grep -oE '[0-9]+' | sort -n | tail -1)" || true
    if [[ -n "$n" ]]; then
      req="$(extract_section .task/followups.md "## Follow-up $n")"
      applied="$(extract_section .task/followups.md "## Follow-up $n — Applied")"
      if [[ -n "$applied" ]]; then printf '%s\n\n%s' "$req" "$applied"; else printf '%s' "$req"; fi
      return
    fi
  fi
  if [[ -f .task/implementation.md ]] && has_real_content .task/implementation.md; then
    changes="$(extract_section .task/implementation.md '## Changes')"
    deviations="$(extract_section .task/implementation.md '## Deviations from Plan')"
    if [[ -n "$changes" || -n "$deviations" ]]; then
      printf '%s\n\n%s' "$changes" "$deviations"
      return
    fi
  fi
  printf '(no execution yet)'
}

run_handoff_mode() {
  if [[ ! -f .task/overview.md ]] || ! has_real_content .task/overview.md; then
    echo "Error: .task/overview.md not found or still a placeholder. Nothing to hand off yet." >&2
    exit 1
  fi

  OVERVIEW_SUMMARY="$(build_overview_summary)"
  PLAN_STEPS="$(build_plan_steps)"
  LATEST_STATUS="$(build_latest_status)"
  CONFIRM_ASK="Before continuing, briefly confirm you understand where this task stands, then proceed."

  OVERVIEW_DISPLAY=$'--- OVERVIEW SUMMARY ---\n'"$OVERVIEW_SUMMARY"
  STEPS_DISPLAY=$'--- CURRENT PLAN STEPS ---\n'"$PLAN_STEPS"
  STATUS_DISPLAY=$'--- LATEST STATUS ---\n'"$LATEST_STATUS"

  recompute() {
    set_blocks "prompt" "$PROMPT" "OVERVIEW SUMMARY" "$OVERVIEW_DISPLAY" \
      "CURRENT PLAN STEPS" "$STEPS_DISPLAY" "LATEST STATUS" "$STATUS_DISPLAY" \
      "confirm" "$CONFIRM_ASK"
    PAYLOAD="$(join_blocks "${BLOCKS[@]}")"
    TOTAL_CHARS=$(count_chars "$PAYLOAD")
  }
  recompute

  if [[ "$FORCE_SPLIT" -eq 1 || "$TOTAL_CHARS" -gt "$LIMIT" ]]; then
    printf '%s\n' "$OVERVIEW_SUMMARY" > "$WEB_DIR/overview-summary.md"
    WEB_FILES+=("overview-summary.md")
    OVERVIEW_DISPLAY="--- OVERVIEW SUMMARY --- (attached as overview-summary.md)"
    recompute

    if [[ "$FORCE_SPLIT" -eq 1 || "$TOTAL_CHARS" -gt "$LIMIT" ]]; then
      printf '%s\n' "$PLAN_STEPS" > "$WEB_DIR/plan-steps.md"
      WEB_FILES+=("plan-steps.md")
      STEPS_DISPLAY="--- CURRENT PLAN STEPS --- (attached as plan-steps.md)"
      recompute
    fi

    if [[ "$TOTAL_CHARS" -gt "$LIMIT" ]]; then
      echo "Error: even with OVERVIEW SUMMARY/CURRENT PLAN STEPS attached, payload is $TOTAL_CHARS chars, over the $LIMIT char limit." >&2
      echo "Section breakdown:" >&2
      print_breakdown
      exit 1
    fi
  fi
}
