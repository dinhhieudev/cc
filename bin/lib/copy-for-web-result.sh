# Result-mode helpers for bin/copy-for-web.sh: result screenshots and the
# optional --diff attachment. Sourced, not executed directly. Rely on
# globals set by the caller: WEB_DIR, WEB_FILES (and MAX_BYTES,
# is_secret_file, copy_web_file, WEB_LINE from copy-for-web-design.sh).

# Cap for the optional diff attachment, separate from MAX_BYTES (the 200 KB
# image/design cap) — a text diff this size is already ~25k tokens.
WEB_DIFF_MAX_BYTES="${WEB_DIFF_MAX_BYTES:-100000}"

# Copies every file under .task/design/result/ (result mode only — human-
# captured screenshots of the built feature) into $1, flattening the path
# relative to .task/design/result/ with a "result__" prefix ("/" -> "__").
# Same secret-filename guard and 200 KB size cap as copy_design_files().
# Appends flattened names to WEB_FILES and sets the global
# RESULT_SHOTS_LIST to a "--- RESULT SCREENSHOTS (attached) ---" block (or
# "" if the folder is missing/empty/all-refused).
copy_result_screenshots() {
  local web_dir="$1" path rel_key lines="" size
  RESULT_SHOTS_LIST=""
  [[ -d .task/design/result ]] || return 0
  while IFS= read -r path; do
    [[ -z "$path" ]] && continue
    rel_key="result/${path#.task/design/result/}"
    if is_secret_file "$path"; then
      echo "Warning: refusing likely secret file '$path' (matches pattern); skipping." >&2
      continue
    fi
    size=$(wc -c < "$path" | tr -d ' ')
    if [[ "$size" -gt "$MAX_BYTES" ]]; then
      echo "Warning: '$path' is $size bytes, over the 200 KB limit; skipping." >&2
      continue
    fi
    copy_web_file "$web_dir" "$path" "$rel_key"
    if [[ -z "$lines" ]]; then lines="$WEB_LINE"
    else lines="$lines
$WEB_LINE"
    fi
  done < <(find .task/design/result -type f -not -name '.*' | sort)
  if [[ -n "$lines" ]]; then
    RESULT_SHOTS_LIST=$'--- RESULT SCREENSHOTS (attached) ---\n'"$lines"
  fi
}

# True (exit 0) if diff path $1 matches one of the diff excludes: .task/,
# lockfiles, .pbxproj, generated Dart/Flutter files, Pods/build/node_modules.
# Mirrors the pathspecs write_diff_attachment() passes to `git diff`, for
# filtering untracked files (which git diff --no-index can't pathspec-filter).
_diff_path_excluded() {
  case "$1" in
    .task|.task/*) return 0 ;;
    *.lock|*-lock.json|*.lockb) return 0 ;;
    *.pbxproj|*.g.dart|*.freezed.dart|*.generated.*) return 0 ;;
    Pods|Pods/*|*/Pods|*/Pods/*) return 0 ;;
    build|build/*|*/build|*/build/*) return 0 ;;
    node_modules|node_modules/*|*/node_modules|*/node_modules/*) return 0 ;;
  esac
  return 1
}

# Builds a filtered, size-capped git diff (tracked changes vs HEAD, plus
# untracked files) as an attachment for result mode's --diff flag. Not a
# git repo, or nothing left to diff after filtering, are warnings
# (DIFF_LIST=""), never a hard failure. Writes $1/changes.diff.txt and
# appends it to WEB_FILES only when there is content.
write_diff_attachment() {
  local web_dir="$1" diff_out="" excludes=() e path one size
  DIFF_LIST=""
  if ! git rev-parse --is-inside-work-tree >/dev/null 2>&1; then
    echo "Warning: not a git repository; --diff produces no attachment." >&2
    return 0
  fi

  for e in '.task/' '*.lock' '*-lock.json' '*.lockb' 'Podfile.lock' 'pubspec.lock' \
           '*.pbxproj' '*.g.dart' '*.freezed.dart' '*.generated.*' 'Pods/' 'build/' 'node_modules/'; do
    excludes+=(":(exclude)$e")
  done

  if git rev-parse HEAD >/dev/null 2>&1; then
    diff_out="$(git diff HEAD -- . "${excludes[@]}" 2>/dev/null)" || true
  else
    diff_out="$(git diff -- . "${excludes[@]}" 2>/dev/null)" || true
  fi

  while IFS= read -r path; do
    [[ -z "$path" ]] && continue
    _diff_path_excluded "$path" && continue
    if is_secret_file "$path"; then
      echo "Warning: refusing likely secret file '$path' in diff (matches pattern); skipping." >&2
      continue
    fi
    one="$(git diff --no-index /dev/null "$path" 2>/dev/null)" || true
    [[ -n "$one" ]] || continue
    if [[ -n "$diff_out" ]]; then diff_out="$diff_out
$one"
    else diff_out="$one"
    fi
  done < <(git ls-files --others --exclude-standard)

  if [[ -z "$diff_out" ]]; then
    echo "Warning: no diff to attach (working tree matches HEAD, or everything was excluded)." >&2
    return 0
  fi

  size=$(printf '%s' "$diff_out" | wc -c | tr -d ' ')
  if [[ "$size" -gt "$WEB_DIFF_MAX_BYTES" ]]; then
    echo "Warning: diff is $size bytes, over the $WEB_DIFF_MAX_BYTES byte cap (WEB_DIFF_MAX_BYTES); truncating." >&2
    printf '%s' "$diff_out" | head -c "$WEB_DIFF_MAX_BYTES" > "$web_dir/changes.diff.txt"
    printf '\n[truncated at %s bytes]\n' "$WEB_DIFF_MAX_BYTES" >> "$web_dir/changes.diff.txt"
  else
    printf '%s\n' "$diff_out" > "$web_dir/changes.diff.txt"
  fi

  WEB_FILES+=("changes.diff.txt")
  DIFF_LIST=$'--- CODE DIFF (attached) ---\nchanges.diff.txt'
  if [[ "$size" -gt "$WEB_DIFF_MAX_BYTES" ]]; then
    DIFF_LIST="$DIFF_LIST (truncated at $WEB_DIFF_MAX_BYTES bytes)"
  fi
}
