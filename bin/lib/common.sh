# Shared helpers for the claude++ bin/ scripts. Sourced, not executed directly.

[[ -n "${CLAUDE_PP_COMMON_SOURCED:-}" ]] && return 0
CLAUDE_PP_COMMON_SOURCED=1

# Placeholder files contain nothing but a heading and HTML comment(s); strip
# comments (including ones spanning multiple lines), heading lines, and
# blank lines, then check whether anything real is left.
strip_comments() {
  awk '
    BEGIN { incomment = 0 }
    {
      line = $0
      out = ""
      while (length(line) > 0) {
        if (incomment) {
          end = index(line, "-->")
          if (end == 0) { line = "" }
          else { line = substr(line, end + 3); incomment = 0 }
        } else {
          start = index(line, "<!--")
          if (start == 0) { out = out line; line = "" }
          else {
            out = out substr(line, 1, start - 1)
            line = substr(line, start + 4)
            incomment = 1
          }
        }
      }
      print out
    }
  ' "$1"
}

has_real_content() {
  strip_comments "$1" | awk '
    /^[[:space:]]*#/ { next }
    /^[[:space:]]*$/ { next }
    { found = 1 }
    END { exit(found ? 0 : 1) }
  '
}

# True (exit 0) if $1 contains what looks like a credential: an AWS access
# key, a PEM private key header, a Bearer token, an OpenAI-style secret
# key, a Slack token, or a GitHub personal access token. Binary files
# (screenshots included) are skipped without grepping, so they never trip
# it.
has_secret_content() {
  local f="$1"
  if file --mime-encoding "$f" 2>/dev/null | grep -q 'binary$'; then
    return 1
  fi
  grep -qE 'AKIA[0-9A-Z]{16}|-----BEGIN [A-Z ]*PRIVATE KEY-----|Authorization:[[:space:]]*Bearer[[:space:]]+[A-Za-z0-9._-]{20,}|sk-[A-Za-z0-9]{20,}|xox[baprs]-[A-Za-z0-9-]{10,}|ghp_[A-Za-z0-9]{36}' "$f"
}

# Rewrites the "| Status | <value> |" row inside .task/index.md's
# "## Active Task" table (never the "## History" table below it) to $1,
# padding the value cell to match the header row's "Value" column width
# when the new value fits, or falling back to single-space padding
# without truncating it otherwise. Warns to stderr and returns 0 (never
# fails the run) if .task/index.md is missing or no Status row is found
# in that section.
set_active_status() {
  local status="$1" index_file=".task/index.md" tmp
  if [[ ! -f "$index_file" ]]; then
    echo "Warning: $index_file not found; skipping Active Task Status update." >&2
    return 0
  fi
  tmp="$(mktemp)"
  if awk -v newval="$status" '
    BEGIN { insection = 0; done = 0; width = 0 }
    /^## Active Task/ { insection = 1 }
    insection && /^## / && !/^## Active Task/ { insection = 0 }
    insection && width == 0 && $0 ~ /^\| *Field *\|/ {
      n = split($0, hp, "|")
      width = length(hp[3])
    }
    insection && $0 ~ /^\| *Status *\|/ && !done {
      n = split($0, parts, "|")
      if (width > 0 && length(newval) + 2 <= width) {
        pad = width - length(newval) - 1
        newcell = " " newval
        for (i = 0; i < pad; i++) newcell = newcell " "
      } else {
        newcell = " " newval " "
      }
      $0 = parts[1] "|" parts[2] "|" newcell "|" parts[4]
      done = 1
    }
    { print }
    END { exit(done ? 0 : 1) }
  ' "$index_file" > "$tmp"; then
    cat "$tmp" > "$index_file"
    rm -f "$tmp"
  else
    rm -f "$tmp"
    echo "Warning: no Status row found in $index_file's Active Task section; skipping status update." >&2
    return 0
  fi
}
