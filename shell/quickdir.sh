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
  printf '%s\n' "$p" | tr '[:upper:]' '[:lower:]'
}

# Merge history + bookmarks, deduplicated, history first then bookmark-only entries.
# Deduplication key: lowercase path with trailing slash stripped.
# Compatible with bash 3.2+ (macOS system bash).
_qd_merged_paths() {
  local seen=''
  local path key

  _qd_emit_if_new() {
    local p="$1"
    local k
    k=$(_qd_normalize_path_key "$p")
    # Use newline-delimited string instead of associative array (bash 3.2 safe)
    if ! printf '%s\n' "$seen" | grep -qxF "$k" 2>/dev/null; then
      seen="${seen}"$'\n'"${k}"
      echo "$p"
    fi
  }

  while IFS= read -r path; do
    [[ -z "$path" ]] && continue
    _qd_emit_if_new "$path"
  done < <(_qd_history_paths)

  while IFS= read -r path; do
    [[ -z "$path" ]] && continue
    _qd_emit_if_new "$path"
  done < <(_qd_bookmark_list)
}

# Read paths from stdin, present a picker, print the chosen path to stdout.
# Set QD_FORCE_LIST=1 to bypass fzf (used in tests).
#
# In QD_FORCE_LIST mode (tests): all input comes from one pipe — paths first,
# then the choice as the final line. We read everything, split at the last line.
# In interactive mode: paths come from pipe; choice is read from /dev/tty.
_qd_select() {
  # Use fzf if available and not suppressed (paths from stdin, TTY for interaction)
  if [[ -z "${QD_FORCE_LIST:-}" ]] && command -v fzf &>/dev/null; then
    printf '%s\n' "${paths[@]}" | fzf --prompt="Select project> " --height=40%
    local fzf_exit=$?
    [[ "$fzf_exit" -eq 130 ]] && return 0
    return "$fzf_exit"
  fi

  # Numbered list fallback — read ALL stdin lines into an array
  local -a all_lines=()
  while IFS= read -r line; do
    all_lines+=("$line")
  done

  # In QD_FORCE_LIST mode the last line is the choice; the rest are paths.
  # In interactive mode every line is a path (choice is read from /dev/tty below).
  local -a paths=()
  local choice=""

  if [[ -n "${QD_FORCE_LIST:-}" ]]; then
    # Split: all but last line are paths; last line is the choice
    local total="${#all_lines[@]}"
    local path_count=$(( total > 0 ? total - 1 : 0 ))
    local idx=0
    while [[ "$idx" -lt "$path_count" ]]; do
      [[ -n "${all_lines[$idx]}" ]] && paths+=("${all_lines[$idx]}")
      idx=$(( idx + 1 ))
    done
    choice="${all_lines[$((total - 1))]}"
  else
    for line in "${all_lines[@]}"; do
      [[ -n "$line" ]] && paths+=("$line")
    done
  fi

  if [[ "${#paths[@]}" -eq 0 ]]; then
    echo "No recent projects found. Use 'qd add' to add a bookmark." >&2
    return 1
  fi

  # Print numbered list to stderr
  local i=1
  for p in "${paths[@]}"; do
    printf '%3d) %s\n' "$i" "$p" >&2
    ((i++))
  done

  # Read choice interactively if not already supplied (QD_FORCE_LIST supplies it above)
  if [[ -z "${QD_FORCE_LIST:-}" ]]; then
    printf 'Enter number (or empty to cancel): ' >&2
    if [[ ! -c /dev/tty ]]; then
      echo "No terminal available for interactive selection." >&2
      return 1
    fi
    read -r choice < /dev/tty
  fi

  [[ -z "$choice" ]] && return 0

  if [[ "$choice" =~ ^[0-9]+$ ]] && [[ "$choice" -ge 1 ]] && [[ "$choice" -le "${#paths[@]}" ]]; then
    echo "${paths[$((choice - 1))]}"
  fi
  return 0
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
