#!/usr/bin/env bash
set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
source "$SCRIPT_DIR/lib/copy-for-web-lib.sh"

MAX_BYTES=204800 # 200 KB

usage() {
  cat <<'EOF'
Usage: attach.sh <path> [<path>...]
       attach.sh -

Copies the named project files into .task/web/ (flattened: "/" becomes
"__"), so you can attach them in the web chat after the web planner
asks for specific files (see bin/copy-for-web.sh --lean).

Does NOT clear .task/web/ first — it belongs to the preceding
copy-for-web.sh run; attach.sh only adds to it.

Refuses absolute paths and any path containing "..". Warns and skips
paths that don't exist, are directories, or are over 200 KB. Prints
each "path -> flattened name" and the total character count of
everything now in .task/web/.

"-" reads newline-separated paths from stdin instead of argv.

Must be run from the root of a project that has a .task/ directory.

Options:
  -h, --help    Show this help and exit
EOF
}

if [[ "${1:-}" == "-h" || "${1:-}" == "--help" ]]; then
  usage
  exit 0
fi

if [[ $# -eq 0 ]]; then
  echo "Error: no paths given." >&2
  usage >&2
  exit 1
fi

if [[ ! -d .task ]]; then
  echo "Error: no .task/ directory found here. Run this from the project root." >&2
  exit 1
fi

PATHS=()
if [[ "$1" == "-" ]]; then
  while IFS= read -r line; do
    [[ -n "$line" ]] && PATHS+=("$line")
  done
else
  PATHS=("$@")
fi

WEB_DIR=.task/web
mkdir -p "$WEB_DIR"

for p in "${PATHS[@]}"; do
  if is_unsafe_path "$p"; then
    echo "Warning: refusing unsafe path '$p' (absolute or contains ..); skipping." >&2
    continue
  fi
  if [[ ! -e "$p" ]]; then
    echo "Warning: path '$p' not found; skipping." >&2
    continue
  fi
  if [[ -d "$p" ]]; then
    echo "Warning: '$p' is a directory; skipping." >&2
    continue
  fi
  SIZE=$(wc -c < "$p" | tr -d ' ')
  if [[ "$SIZE" -gt "$MAX_BYTES" ]]; then
    echo "Warning: '$p' is $SIZE bytes, over the 200 KB limit; skipping." >&2
    continue
  fi
  flat="${p//\//__}"
  cp "$p" "$WEB_DIR/$flat"
  echo "$p -> $flat"
done

TOTAL_CHARS=0
for f in "$WEB_DIR"/*; do
  [[ -f "$f" ]] || continue
  c=$(count_chars "$(cat "$f")")
  TOTAL_CHARS=$((TOTAL_CHARS + c))
done
echo "Total chars now in $WEB_DIR: $TOTAL_CHARS" >&2
