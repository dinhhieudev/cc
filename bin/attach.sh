#!/usr/bin/env bash
set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
source "$SCRIPT_DIR/lib/copy-for-web-lib.sh"
source "$SCRIPT_DIR/lib/copy-for-web-design.sh"
# MAX_BYTES (200 KB) comes from copy-for-web-design.sh, shared with
# copy_design_files() there.

usage() {
  cat <<'EOF'
Usage: attach.sh [--force-secret] <path> [<path>...]
       attach.sh [--force-secret] -

Copies the named project files into .task/web/ (flattened: "/" becomes
"__"), so you can attach them in the web chat after the web planner
asks for specific files (see bin/copy-for-web.sh --lean).

Does NOT clear .task/web/ first — it belongs to the preceding
copy-for-web.sh run; attach.sh only adds to it.

Refuses absolute paths and any path containing "..". Warns and skips
paths that don't exist, are directories, or are over 200 KB. Also
warns and skips paths whose basename looks like a secret/credential
file (.env*, *.pem/*.key/*.p12/*.pfx/*.jks/*.keystore, private SSH
keys, .npmrc/.netrc/.git-credentials, or names containing
secret/credential/password/apikey/api_key/token — except that last
group of name checks does not apply to image files: png/jpg/jpeg/
gif/webp/svg/bmp/ico) — this is a filename pattern check, not a
content scanner; pass --force-secret to copy such files anyway.
Prints each "path -> flattened name" and the total character count of
everything now in .task/web/.

"-" reads newline-separated paths from stdin instead of argv.

Must be run from the root of a project that has a .task/ directory.

Options:
  --force-secret  Copy files that match the secret-file pattern
                   instead of refusing them
  -h, --help      Show this help and exit
EOF
}

FORCE_SECRET=0
if [[ "${1:-}" == "--force-secret" ]]; then
  FORCE_SECRET=1
  shift
fi

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
  if is_secret_file "$p"; then
    if [[ "$FORCE_SECRET" -eq 1 ]]; then
      echo "Copying likely secret file '$p' (--force-secret given)." >&2
    else
      echo "Warning: refusing likely secret file '$p' (matches pattern); skipping. Use --force-secret to override if you're sure." >&2
      continue
    fi
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
