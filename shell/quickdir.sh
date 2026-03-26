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
