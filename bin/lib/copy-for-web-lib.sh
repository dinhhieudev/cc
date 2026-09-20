# Shared helpers for bin/copy-for-web.sh. Sourced, not executed directly.

source "$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)/common.sh"

# .task/PROJECT.md ships with its ## Language section pre-filled
# (Language: en); strip that pre-filled line too before checking for
# real content.
project_has_substance() {
  strip_comments "$1" | awk '
    /^[[:space:]]*#/ { next }
    /^[[:space:]]*$/ { next }
    /^Language:/ { next }
    { found = 1 }
    END { exit(found ? 0 : 1) }
  '
}

# Reads .task/PROJECT.md's Language: line; anything other than "vi" is "en".
get_language() {
  local project_md="$1" line val
  [[ -f "$project_md" ]] || { echo "en"; return; }
  line=$(awk '/^Language:/ { print; exit }' "$project_md")
  [[ -n "$line" ]] || { echo "en"; return; }
  val="${line#Language:}"
  val="$(printf '%s' "$val" | awk '{gsub(/^[ \t]+|[ \t]+$/, ""); print}')"
  if [[ "$val" == "vi" ]]; then echo "vi"; else echo "en"; fi
}

# Character count, not byte count — multibyte-safe for Vietnamese text.
count_chars() {
  printf '%s' "$1" | LC_ALL=en_US.UTF-8 wc -m | tr -d ' '
}

# Joins its arguments with a blank line between each, trailing newline.
join_blocks() {
  local out="" first=1 b
  for b in "$@"; do
    if [[ "$first" -eq 1 ]]; then out="$b"; first=0
    else out="$out

$b"
    fi
  done
  printf '%s\n' "$out"
}

# Builds the globals BLOCKS[] and LABELS[] from alternating label/content
# pairs, skipping any pair whose content is empty.
set_blocks() {
  BLOCKS=()
  LABELS=()
  local label content
  while [[ $# -gt 0 ]]; do
    label="$1"; content="$2"; shift 2
    if [[ -n "$content" ]]; then
      LABELS+=("$label")
      BLOCKS+=("$content")
    fi
  done
}

# Prints per-block char counts for the current BLOCKS[]/LABELS[].
print_breakdown() {
  local i
  for (( i = 0; i < ${#LABELS[@]}; i++ )); do
    echo "  ${LABELS[$i]}: $(count_chars "${BLOCKS[$i]}") chars" >&2
  done
}

# True (exit 0) if $1 is an absolute path, or contains a ".." segment.
is_unsafe_path() {
  case "$1" in
    /*|../*|*/..|*/../*|..) return 0 ;;
  esac
  return 1
}

# Extracts attach paths from the "## Files to Attach" section of $1: lines
# "- path" (optionally followed by " — reason"), one path per output line.
extract_attach_paths() {
  awk '
    /^## Files to Attach/ { infile = 1; next }
    /^## / { infile = 0 }
    infile && /^- / {
      line = $0
      sub(/^- /, "", line)
      idx = index(line, " — ")
      if (idx > 0) { line = substr(line, 1, idx - 1) }
      gsub(/^[ \t]+|[ \t]+$/, "", line)
      gsub(/^`+|`+$/, "", line)
      if (line != "") print line
    }
  ' "$1"
}

# Copies files listed in .task/context.md's "## Files to Attach" section
# into $1 (the web attachment dir), flattening "/" to "__". Appends
# flattened names to the global WEB_FILES array and sets the global
# ATTACH_LIST to a "--- ATTACHED FILES ---" block (or "" if none/none
# valid). Warns and skips missing or unsafe paths.
copy_attach_files() {
  local web_dir="$1" rel_path lines="" size
  while IFS= read -r rel_path; do
    [[ -z "$rel_path" ]] && continue
    if is_unsafe_path "$rel_path"; then
      echo "Warning: refusing unsafe attach path '$rel_path' (absolute or contains ..); skipping." >&2
      continue
    fi
    if [[ ! -f "$rel_path" ]]; then
      echo "Warning: attach path '$rel_path' not found; skipping." >&2
      continue
    fi
    if is_secret_file "$rel_path"; then
      echo "Warning: refusing likely secret file '$rel_path' (matches pattern); skipping." >&2
      continue
    fi
    if has_secret_content "$rel_path"; then
      echo "Warning: refusing '$rel_path' (contains what looks like a credential); skipping." >&2
      continue
    fi
    size=$(wc -c < "$rel_path" | tr -d ' ')
    if [[ "$size" -gt "$MAX_BYTES" ]]; then
      echo "Warning: '$rel_path' is $size bytes, over the 200 KB limit; skipping." >&2
      continue
    fi
    copy_web_file "$web_dir" "$rel_path" "$rel_path"
    if [[ -z "$lines" ]]; then lines="$WEB_LINE"
    else lines="$lines
$WEB_LINE"
    fi
  done < <(extract_attach_paths .task/context.md)
  ATTACH_LIST=""
  if [[ -n "$lines" ]]; then
    ATTACH_LIST=$'--- ATTACHED FILES ---\n'"$lines"
  fi
}

# Builds the PROJECT_SECTION global from .task/PROJECT.md if it has real
# content beyond the Language line; warns to stderr and leaves
# PROJECT_SECTION empty otherwise. Shared by plan mode and lean mode.
build_project_section() {
  PROJECT_SECTION=""
  if [[ ! -f .task/PROJECT.md ]]; then
    echo "Warning: .task/PROJECT.md is missing — the AI web planner will not receive project architecture/conventions." >&2
  elif ! project_has_substance .task/PROJECT.md; then
    echo "Warning: .task/PROJECT.md has no project context filled in (only the Language section) — the AI web planner will not receive project architecture/conventions." >&2
  else
    PROJECT_SECTION=$'--- PROJECT ---\n'"$(strip_comments .task/PROJECT.md)"
  fi
}

# Header line prepended to every payload; ID-Name from index.md, project name from PROJECT.md's ## Project (else cwd basename).
build_header_line() {
  local id="" name="" project_name=""
  read -r id name < <(awk -F'|' '/^## Active Task/{s=1;next} /^## /{s=0} s{f=$2;gsub(/^[ \t]+|[ \t]+$/,"",f);v=$3;gsub(/^[ \t]+|[ \t]+$/,"",v);if(f=="ID")id=v;if(f=="Name")name=v}END{print id,name}' .task/index.md 2>/dev/null) || true
  project_name=$(awk '/^## Project$/{s=1;next} /^## /{s=0} s' .task/PROJECT.md 2>/dev/null | strip_comments /dev/stdin | awk 'NF{print;exit}') || true
  [[ -n "$project_name" ]] || project_name="$(basename "$PWD")"; printf '[claude++ task %s-%s — %s]' "$id" "$name" "$project_name"
}

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
