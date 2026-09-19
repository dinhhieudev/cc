# Secret-file guard and .task/design/ (screenshot reference) attachment
# helpers, shared by bin/attach.sh and bin/copy-for-web.sh (plan mode).
# Sourced, not executed directly.

# Shared with bin/attach.sh — same 200 KB attachment cap.
MAX_BYTES=204800 # 200 KB

# True (exit 0) if $1's basename looks like a secret/credential file.
# Pattern-based only — does not inspect file contents. Shared by
# bin/attach.sh and copy_design_files() below so both refuse the same names.
# The secret/credential/password/apikey/api_key/token SUBSTRING checks are
# skipped for image files (png/jpg/jpeg/gif/webp/svg/bmp/ico) — a name like
# "design-tokens.png" is a normal design asset, not a credential leak. The
# extension and exact-name checks above still apply to every file type.
is_secret_file() {
  local base lower
  base="$(basename "$1")"
  lower="$(printf '%s' "$base" | tr '[:upper:]' '[:lower:]')"
  case "$lower" in
    .env|.env.*) return 0 ;;
    *.pem|*.key|*.p12|*.pfx|*.jks|*.keystore) return 0 ;;
    id_rsa|id_ed25519|id_dsa|id_ecdsa) return 0 ;;
    .npmrc|.netrc|.git-credentials|credentials) return 0 ;;
  esac
  case "$lower" in
    *.png|*.jpg|*.jpeg|*.gif|*.webp|*.svg|*.bmp|*.ico) return 1 ;;
  esac
  case "$lower" in
    *secret*|*credential*|*password*|*apikey*|*api_key*|*token*) return 0 ;;
  esac
  return 1
}

# Copies file $2 into web dir $1, naming it by flattening $3 ("/" -> "__"),
# tracks the flattened name in the global WEB_FILES array, and sets the
# global WEB_LINE to a "$flat — $4" listing line (label defaults to $3).
# Sets WEB_LINE rather than echoing it — callers must NOT invoke this via
# command substitution ($(...)), which would run it in a subshell and lose
# the WEB_FILES append. Shared single-file copy step for copy_attach_files()
# (copy-for-web-lib.sh) and copy_design_files() below.
copy_web_file() {
  local web_dir="$1" src="$2" flatten_key="$3" label="${4:-$3}" flat
  flat="${flatten_key//\//__}"
  cp "$src" "$web_dir/$flat"
  WEB_FILES+=("$flat")
  WEB_LINE="$flat — $label"
}

# Copies every file under .task/design/ (plan mode only — a human-populated
# folder of reference screenshots for the AI web planner; Claude Code never
# reads them), excluding .task/design/result/ (result-mode screenshots,
# forwarded separately by copy_result_screenshots() in
# copy-for-web-result.sh), into $1, flattening the path relative to
# .task/design/ ("/" -> "__"). Applies the same secret-filename guard and
# 200 KB size cap as bin/attach.sh. Appends flattened names to WEB_FILES
# and sets the global DESIGN_LIST to a "--- DESIGN REFERENCE (attached) ---"
# block (or "" if the folder is missing/empty/all-refused).
copy_design_files() {
  local web_dir="$1" path rel_key lines="" size
  DESIGN_LIST=""
  [[ -d .task/design ]] || return 0
  while IFS= read -r path; do
    [[ -z "$path" ]] && continue
    rel_key="${path#.task/design/}"
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
  done < <(find .task/design -type f -not -name '.*' -not -path '.task/design/result/*' | sort)
  if [[ -n "$lines" ]]; then
    DESIGN_LIST=$'--- DESIGN REFERENCE (attached) ---\n'"$lines"
  fi
}
