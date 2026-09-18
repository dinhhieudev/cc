# Shared helpers for bin/save-plan.sh. Sourced, not executed directly.
# All checks here are non-fatal (stderr warnings only) — no Claude tokens.

# Warns about any of the plan's required headings that are missing.
check_required_headings() {
  local plan_file="$1"
  local required=("## Summary" "## Decisions to Review" "## AC Coverage" "## Steps" "## Out of Scope" "## Open Questions")
  local missing=() h
  for h in "${required[@]}"; do
    grep -qF "$h" "$plan_file" || missing+=("$h")
  done
  if [[ ${#missing[@]} -gt 0 ]]; then
    echo "Warning: plan is missing headings: ${missing[*]}" >&2
  fi
}

# Prints the body lines of the named "## <heading>" section (stops at the
# next "## " heading).
section_body() {
  local plan_file="$1" heading="$2"
  awk -v h="^## $heading[[:space:]]*\$" '
    $0 ~ h { found = 1; next }
    /^## / { if (found) exit }
    found { print }
  ' "$plan_file"
}

# Warns if "## Open Questions" has real content (not empty, not "None").
check_open_questions() {
  local plan_file="$1" body trimmed
  body="$(section_body "$plan_file" "Open Questions")"
  trimmed="$(printf '%s' "$body" | tr -d '[:space:]' | tr '[:upper:]' '[:lower:]')"
  if [[ -n "$trimmed" && "$trimmed" != "none" ]]; then
    echo "Warning: plan still has open questions; answer them in the web chat before running execute" >&2
  fi
}

# Warns if "## Decisions to Review" is present (not empty, not "None") but
# every non-empty line in it is short — a heuristic for a bullet with no
# visible reasoning.
check_thin_decisions() {
  local plan_file="$1" body trimmed long_count
  body="$(section_body "$plan_file" "Decisions to Review")"
  trimmed="$(printf '%s' "$body" | tr -d '[:space:]' | tr '[:upper:]' '[:lower:]')"
  [[ -z "$trimmed" || "$trimmed" == "none" ]] && return
  long_count="$(printf '%s\n' "$body" | awk '
    { gsub(/^[[:space:]]+|[[:space:]]+$/, "") }
    length($0) == 0 { next }
    length($0) >= 40 { n++ }
    END { print n + 0 }
  ')"
  if [[ "$long_count" -eq 0 ]]; then
    echo "Warning: Decisions to Review looks thin (no visible reasoning) — consider asking the web planner to expand it." >&2
  fi
}

# Prints "<file-cell>\t<change-and-notes-text>" for each data row of the
# "## Steps" table.
extract_step_rows() {
  awk '
    /^## Steps[[:space:]]*$/ { in_steps = 1; next }
    /^## / { in_steps = 0 }
    in_steps && /^\|/ {
      line = $0
      sub(/^\|/, "", line)
      sub(/\|[[:space:]]*$/, "", line)
      n = split(line, cols, "|")
      for (i = 1; i <= n; i++) { gsub(/^[[:space:]]+|[[:space:]]+$/, "", cols[i]) }
      if (n < 4 || cols[2] == "File") next
      sep = 1
      for (i = 1; i <= n; i++) { if (cols[i] !~ /^[-: ]*$/) sep = 0 }
      if (sep) next
      printf "%s\t%s %s\n", cols[2], cols[3], cols[4]
    }
  ' "$1"
}

# Warns about File-column paths that don't exist and aren't flagged as new.
check_steps_paths() {
  local plan_file="$1" file_cell notes_text cell raw path bad=()
  while IFS=$'\t' read -r file_cell notes_text; do
    [[ -z "$file_cell" ]] && continue
    cell="${file_cell//,/ }"
    for raw in $cell; do
      path="${raw//\`/}"
      [[ -z "$path" ]] && continue
      [[ "$path" == *"/"* || "$path" == *"."* ]] || continue
      [[ -e "$path" ]] && continue
      printf '%s' "$notes_text" | grep -qiE 'new|create|add' && continue
      bad+=("$path")
    done
  done < <(extract_step_rows "$plan_file")
  if [[ ${#bad[@]} -gt 0 ]]; then
    echo "Paths in ## Steps that don't exist (and aren't marked as new): ${bad[*]}" >&2
  fi
}
