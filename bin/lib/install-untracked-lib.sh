usage() {
  cat <<'EOF'
Usage: install-untracked.sh [--lang en|vi] [--upgrade] <target-project-path>

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
that already has an identical install is safe (idempotent). With
--upgrade this check is skipped instead — see below.

Options:
  --lang <en|vi>  Set Language: in the installed .task/PROJECT.md; this
                   controls the language agents write .task prose and
                   reports in. Also accepts --lang=<en|vi>. Default: en.
  --upgrade       Update an existing untracked install to the current
                   template version: overwrites the workflow agent,
                   instruction, and skill files plus bin/copy-for-web.sh
                   and bin/diff-for-web.sh, and refreshes the
                   CLAUDE.local.md block. Requires a previous install —
                   refuses unless the target's CLAUDE.local.md already
                   has the claude++ workflow marker. Never touches
                   .task/, except adding a missing Language section to
                   .task/PROJECT.md.
  -h, --help      Show this help and exit
EOF
}

parse_args() {
  LANG_ARG=""
  LANG_SET=0
  UPGRADE=0
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
      --upgrade)
        UPGRADE=1
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
}

# Rewrites the `Language:` line in $1 to $2, or appends a Language section.
set_project_language() {
  local project_md="$1" lang="$2"
  if grep -q '^Language:' "$project_md"; then
    awk -v lang="$lang" '/^Language:/ { print "Language: " lang; next } { print }' "$project_md" > "$project_md.tmp" && mv "$project_md.tmp" "$project_md"
  else
    printf '\n## Language\n\nLanguage: %s\n' "$lang" >> "$project_md"
  fi
}

# begin+body+end, no trailing newline. Shared by write/replace_marker_block
# so both produce byte-identical blocks.
build_marker_block() {
  local begin="$1" end="$2" body="$3"
  printf '%s\n%s\n%s' "$begin" "$body" "$end"
}

# Appends a marker block to $1 (creating it if needed) unless it already
# contains begin marker $2, in which case it returns 1 untouched.
write_marker_block() {
  local file="$1" begin="$2" end="$3" body="$4"
  if [[ -f "$file" ]] && grep -qF "$begin" "$file"; then
    return 1
  fi
  local block
  block="$(build_marker_block "$begin" "$end" "$body")"
  if [[ -f "$file" ]]; then
    printf '\n%s\n' "$block" >> "$file"
  else
    printf '%s\n' "$block" > "$file"
  fi
  return 0
}

# Exits 1 (target untouched) unless $1 exists and contains both markers.
check_upgrade_preflight() {
  local claude_local="$1" begin="$2" end="$3"
  if [[ ! -f "$claude_local" ]] || ! grep -qF "$begin" "$claude_local"; then
    echo "Error: no previous claude++ install found (missing the claude++ workflow marker in $claude_local) — run without --upgrade." >&2
    exit 1
  fi
  if ! grep -qF "$end" "$claude_local"; then
    echo "Error: $claude_local has a claude++ workflow begin marker but no matching end marker — refusing to modify it." >&2
    exit 1
  fi
}

# Exits 1 without copying anything if any target agent/skill file (see
# globals REPO_ROOT, TARGET, AGENT_FILES, SKILL_DIRS) differs from the
# template's. Byte-identical is not a collision — a prior install by us.
check_collisions() {
  local f d src dst
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
}

# Syncs the Language section of .task/PROJECT.md on --upgrade (.task/ is
# otherwise untouched); appends to caller's COPIED/SKIPPED globals.
upgrade_project_language() {
  local project_md="$1" lang_set="$2" lang_arg="$3" lang_to_use
  if [[ ! -f "$project_md" ]]; then
    SKIPPED+=(".task/PROJECT.md (missing — language not updated)")
  elif grep -q '^Language:' "$project_md"; then
    if [[ "$lang_set" -eq 1 ]]; then
      set_project_language "$project_md" "$lang_arg"
      COPIED+=(".task/PROJECT.md language set to $lang_arg")
    fi
  else
    lang_to_use="en"
    [[ "$lang_set" -eq 1 ]] && lang_to_use="$lang_arg"
    set_project_language "$project_md" "$lang_to_use"
    COPIED+=(".task/PROJECT.md language section added ($lang_to_use)")
  fi
}

# Replaces the begin/end marker block in $1 with one built from $4.
# Assumes both markers are present (call check_upgrade_preflight first).
replace_marker_block() {
  local file="$1" begin="$2" end="$3" body="$4"
  local begin_line end_line tmp
  begin_line="$(awk -v m="$begin" '$0==m{print NR; exit}' "$file")"
  end_line="$(awk -v m="$end" '$0==m{print NR; exit}' "$file")"
  tmp="$file.tmp.$$"
  {
    if [[ "$begin_line" -gt 1 ]]; then
      sed -n "1,$((begin_line - 1))p" "$file"
    fi
    printf '%s\n' "$(build_marker_block "$begin" "$end" "$body")"
    tail -n +"$((end_line + 1))" "$file"
  } > "$tmp" && mv "$tmp" "$file"
}
