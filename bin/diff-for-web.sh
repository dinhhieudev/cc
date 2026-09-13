#!/usr/bin/env bash
set -euo pipefail
usage() {
  cat <<'EOF'
Usage:
  diff-for-web.sh                    # full diff: {base}...HEAD
  diff-for-web.sh N                  # round N delta: round-{N-1}..round-N
  diff-for-web.sh --files a b        # full diff restricted to given paths
  diff-for-web.sh N --files a b      # round N delta restricted to given paths
  diff-for-web.sh -w ...              # -w may be added to any of the above
-w is opt-in only, never default: whitespace is semantically significant
in some languages (Python, YAML), so it is not ignored unless asked.
Produces a filtered git diff (excludes .task/, lockfiles, and other
generated noise) for pasting into an AI web review conversation. Must run
from a project root with a .task/ directory, inside a git work tree. If
the diff exceeds 1500 lines, a --stat summary is copied instead.
  -h, --help    Show this help and exit
EOF
}
WS_FLAG=""; POSITIONAL=()
while [[ $# -gt 0 ]]; do
  case "$1" in
    -h|--help) usage; exit 0 ;;
    -w) WS_FLAG="-w"; shift ;;
    *) POSITIONAL+=("$1"); shift ;;
  esac
done
[[ -d .task ]] || { echo "Error: no .task/ directory found here. Run this from the project root." >&2; exit 1; }
git rev-parse --is-inside-work-tree >/dev/null 2>&1 || { echo "Error: not inside a git work tree." >&2; exit 1; }
EXCLUDES=(
  ':(exclude).task/' ':(exclude)*.lock' ':(exclude)Package.resolved'
  ':(exclude)*.pbxproj' ':(exclude)*.xcassets/*' ':(exclude)package-lock.json'
  ':(exclude)yarn.lock' ':(exclude)pnpm-lock.yaml'
)
get_base_branch() {
  local candidate=""
  if [[ -f .task/PROJECT.md ]]; then
    candidate=$(grep -m1 -E '^[[:space:]]*[-*][[:space:]]*Base branch:|^[[:space:]]*Base branch:' .task/PROJECT.md | sed -E 's/^[[:space:]]*([-*][[:space:]]*)?Base branch:[[:space:]]*//') || true
  fi
  if [[ -z "$candidate" ]]; then
    if git rev-parse --verify --quiet main >/dev/null 2>&1; then candidate="main"
    elif git rev-parse --verify --quiet master >/dev/null 2>&1; then candidate="master"
    else echo "Error: no Base branch in .task/PROJECT.md and neither 'main' nor 'master' exists." >&2; exit 1
    fi
  fi
  git rev-parse --verify --quiet "$candidate" >/dev/null 2>&1 || { echo "Error: base branch '$candidate' (from .task/PROJECT.md) does not exist." >&2; exit 1; }
  echo "$candidate"
}
RANGE=""; PATHSPEC=(); ROUND_ARG=""; IDX=0
if [[ ${#POSITIONAL[@]} -gt "$IDX" && "${POSITIONAL[$IDX]}" =~ ^[0-9]+$ ]]; then
  N="${POSITIONAL[$IDX]}"
  [[ "$N" -ge 1 ]] || { echo "Error: round number must be >= 1." >&2; exit 1; }
  PREV_TAG="round-$((N - 1))"; CUR_TAG="round-$N"
  for t in "$PREV_TAG" "$CUR_TAG"; do
    git rev-parse --verify --quiet "refs/tags/$t" >/dev/null 2>&1 || { echo "Error: tag '$t' does not exist." >&2; exit 1; }
  done
  RANGE="${PREV_TAG}..${CUR_TAG}"
  ROUND_ARG="$N"
  IDX=$((IDX + 1))
fi
if [[ ${#POSITIONAL[@]} -gt "$IDX" ]]; then
  if [[ "${POSITIONAL[$IDX]}" == "--files" ]]; then
    REST_COUNT=$(( ${#POSITIONAL[@]} - IDX - 1 ))
    [[ "$REST_COUNT" -ge 1 ]] || { echo "Error: --files requires at least one path." >&2; exit 1; }
    PATHSPEC=("${POSITIONAL[@]:$((IDX + 1))}")
  else
    echo "Error: unrecognized argument '${POSITIONAL[$IDX]}'." >&2
    usage >&2
    exit 1
  fi
fi
if [[ -z "$RANGE" ]]; then
  RANGE="$(get_base_branch)...HEAD"
fi
# EXCLUDES is always non-empty, so this stays non-empty too - expanding an
# empty array under `set -u` errors on bash 3.2 (macOS's default /bin/bash).
PATHSPEC_FULL=()
[[ ${#PATHSPEC[@]} -gt 0 ]] && PATHSPEC_FULL+=("${PATHSPEC[@]}")
PATHSPEC_FULL+=("${EXCLUDES[@]}")
run_diff() {
  local mode="$1" # "" | --numstat | --stat
  local cmd=(git diff)
  [[ -n "$WS_FLAG" ]] && cmd+=("-w")
  [[ -n "$mode" ]] && cmd+=("$mode")
  cmd+=("$RANGE" "--")
  cmd+=("${PATHSPEC_FULL[@]}")
  "${cmd[@]}"
}
copy_to_clipboard() {
  local payload="$1"
  if command -v pbcopy >/dev/null 2>&1; then
    printf '%s' "$payload" | pbcopy; echo "Copied to clipboard (pbcopy)." >&2
  elif command -v xclip >/dev/null 2>&1; then
    printf '%s' "$payload" | xclip -selection clipboard; echo "Copied to clipboard (xclip)." >&2
  elif command -v xsel >/dev/null 2>&1; then
    printf '%s' "$payload" | xsel --clipboard --input; echo "Copied to clipboard (xsel)." >&2
  else
    echo "No clipboard tool found (pbcopy/xclip/xsel); printing payload to stdout instead." >&2
    printf '%s\n' "$payload"
  fi
}
DIFF_OUTPUT=$(run_diff "")
if [[ -z "$DIFF_OUTPUT" ]]; then
  echo "No changes in range $RANGE (after exclusions)." >&2
  exit 0
fi
LINE_COUNT=$(printf '%s\n' "$DIFF_OUTPUT" | wc -l | tr -d ' ')
FILE_COUNT=$(run_diff "--numstat" | wc -l | tr -d ' ')
if [[ "$LINE_COUNT" -gt 1500 ]]; then
  echo "Warning: diff is $LINE_COUNT lines (>1500); copying --stat instead." >&2
  echo "Newly added files show whole-file diffs, which is the usual cause of bloat." >&2
  if [[ -n "$ROUND_ARG" ]]; then
    echo "Narrow the range instead, e.g.: diff-for-web.sh $ROUND_ARG --files path/to/File.swift" >&2
  else
    echo "Narrow the range instead, e.g.: diff-for-web.sh --files path/to/File.swift" >&2
  fi
  echo "Per-file line counts (added+deleted), descending:" >&2
  run_diff "--numstat" | awk '{a=($1=="-"?0:$1); d=($2=="-"?0:$2); print a+d, $3}' | sort -rn >&2
  STAT_OUTPUT=$(run_diff "--stat")
  copy_to_clipboard "$STAT_OUTPUT"
  STAT_LINES=$(printf '%s\n' "$STAT_OUTPUT" | wc -l | tr -d ' ')
  STAT_CHARS=$(printf '%s' "$STAT_OUTPUT" | wc -c | tr -d ' ')
  echo "Range: $RANGE | files: $FILE_COUNT | stat lines: $STAT_LINES (~$((STAT_CHARS / 4)) tokens estimated)" >&2
  exit 0
fi
copy_to_clipboard "$DIFF_OUTPUT"
DIFF_CHARS=$(printf '%s' "$DIFF_OUTPUT" | wc -c | tr -d ' ')
echo "Range: $RANGE | files: $FILE_COUNT | lines: $LINE_COUNT (~$((DIFF_CHARS / 4)) tokens estimated)" >&2
