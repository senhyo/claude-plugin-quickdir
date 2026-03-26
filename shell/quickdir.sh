# shell/quickdir.sh

# Override-able paths (tests set these via env vars)
: "${QD_CLAUDE_PROJECTS_DIR:=$HOME/.claude/projects}"
: "${QD_BOOKMARKS_FILE:=$HOME/.config/quickdir/bookmarks.txt}"

# Resolve the correct Python 3 interpreter (cross-platform).
# On Windows Git Bash, python3 is a broken App Installer stub; python works.
# On macOS/Linux, python3 is the correct command.
_qd_python() {
  if python3 -c "" 2>/dev/null; then
    python3 "$@"
  else
    python "$@"
  fi
}

# Convert a Unix path to a form Python can use (handles Windows Git Bash)
_qd_py_path() {
  cygpath -w "$1" 2>/dev/null || echo "$1"
}

# Print absolute paths from Claude project history, sorted newest-first.
# Only paths that currently exist on disk are printed.
_qd_history_paths() {
  [[ -d "$QD_CLAUDE_PROJECTS_DIR" ]] || return 0

  # Collect: "mtime_epoch jsonl_path" for the first .jsonl in each project dir
  local entries=()
  local proj_dir jsonl cwd
  for proj_dir in "$QD_CLAUDE_PROJECTS_DIR"/*/; do
    [[ -d "$proj_dir" ]] || continue
    jsonl=$(find "$proj_dir" -maxdepth 1 -name "*.jsonl" | head -1)
    [[ -f "$jsonl" ]] || continue
    # Get mtime as epoch seconds; convert path for Windows Python compatibility
    local mtime win_jsonl
    win_jsonl=$(_qd_py_path "$jsonl")
    mtime=$(_qd_python -c "import os,sys; print(int(os.path.getmtime(sys.argv[1])))" "$win_jsonl" 2>/dev/null) || continue
    entries+=("$mtime $jsonl")
  done

  [[ ${#entries[@]} -eq 0 ]] && return 0

  # Sort by mtime descending
  local sorted
  sorted=$(printf '%s\n' "${entries[@]}" | sort -rn)

  # Extract cwd from each jsonl, filter to existing paths
  while IFS= read -r entry; do
    [[ -z "$entry" ]] && continue
    jsonl="${entry#* }"
    local win_jsonl2
    win_jsonl2=$(_qd_py_path "$jsonl")
    cwd=$(_qd_python -c "
import json, sys
try:
    line = open(sys.argv[1]).readline()
    d = json.loads(line)
    print(d.get('cwd', ''))
except Exception:
    pass
" "$win_jsonl2" 2>/dev/null)
    [[ -z "$cwd" ]] && continue
    [[ -e "$cwd" ]] && echo "$cwd"
  done <<< "$sorted"
}

# Print bookmarks, one per line (skips non-existent paths)
_qd_bookmark_list() {
  [[ -f "$QD_BOOKMARKS_FILE" ]] || return 0
  while IFS= read -r path; do
    [[ -z "$path" ]] && continue
    [[ -e "$path" ]] && echo "$path"
  done < "$QD_BOOKMARKS_FILE"
}

# Add a path to bookmarks
_qd_bookmark_add() {
  local path="${1:-$PWD}"
  if [[ ! -e "$path" ]]; then
    echo "Path does not exist: $path" >&2
    return 1
  fi
  # Deduplicate: skip if already present (no trailing slash)
  local normalized="${path%/}"
  if [[ -f "$QD_BOOKMARKS_FILE" ]] && grep -q "^${normalized}/*$" "$QD_BOOKMARKS_FILE" 2>/dev/null; then
    echo "Already bookmarked." >&2
    return 0
  fi
  mkdir -p "$(dirname "$QD_BOOKMARKS_FILE")"
  echo "$normalized" >> "$QD_BOOKMARKS_FILE"
}

# Remove a path from bookmarks
_qd_bookmark_remove() {
  local path="$1"
  [[ -z "$path" ]] && return 0
  [[ -f "$QD_BOOKMARKS_FILE" ]] || return 0
  # Remove matching line using Python for safe exact-match without regex escaping
  _qd_python - "$QD_BOOKMARKS_FILE" "${path%/}" << 'PYEOF'
import sys
bm_file, remove_path = sys.argv[1], sys.argv[2]
try:
    with open(bm_file) as f:
        lines = f.readlines()
    with open(bm_file, 'w') as f:
        for line in lines:
            if line.rstrip('/\n') != remove_path.rstrip('/'):
                f.write(line)
except FileNotFoundError:
    pass
PYEOF
}

# Normalize a path to a canonical Unix-style form for deduplication key comparison.
# On Windows Git Bash, converts "C:/foo" -> "/c/foo" via cygpath -u.
# On other platforms, passes the path through unchanged.
_qd_normalize_path_key() {
  local p="${1%/}"   # strip trailing slash
  if command -v cygpath &>/dev/null; then
    p=$(cygpath -u "$p" 2>/dev/null || echo "$p")
  fi
  echo "${p,,}"  # lowercase (bash 4+)
}

# Merge history + bookmarks, deduplicated, history first then bookmark-only entries.
# Deduplication key: lowercase Unix-normalized path with trailing slash stripped.
_qd_merged_paths() {
  local -A seen=()
  local path key

  # History entries (already sorted by recency)
  while IFS= read -r path; do
    [[ -z "$path" ]] && continue
    key=$(_qd_normalize_path_key "$path")
    if [[ -z "${seen[$key]+x}" ]]; then
      seen["$key"]=1
      echo "$path"
    fi
  done < <(_qd_history_paths)

  # Bookmark-only entries (not already seen from history)
  while IFS= read -r path; do
    [[ -z "$path" ]] && continue
    key=$(_qd_normalize_path_key "$path")
    if [[ -z "${seen[$key]+x}" ]]; then
      seen["$key"]=1
      echo "$path"
    fi
  done < <(_qd_bookmark_list)
}

# Public entrypoint
qd() {
  case "${1:-}" in
    list)   _qd_merged_paths ;;
    add)    _qd_bookmark_add "${2:-$PWD}" ;;
    rm)     _qd_pick_and_remove ;;
    *)      _qd_run ;;
  esac
}
