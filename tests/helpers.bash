# tests/helpers.bash

# Create an isolated home dir for tests so we never touch real ~/.claude or ~/.config
setup_fake_home() {
  export FAKE_HOME="$(mktemp -d)"
  export QD_CLAUDE_PROJECTS_DIR="$FAKE_HOME/.claude/projects"
  export QD_BOOKMARKS_FILE="$FAKE_HOME/.config/quickdir/bookmarks.txt"
  mkdir -p "$QD_CLAUDE_PROJECTS_DIR"
  mkdir -p "$FAKE_HOME/.config/quickdir"
}

teardown_fake_home() {
  rm -rf "$FAKE_HOME"
}

# Create a fake Claude project directory with a JSONL file containing a given cwd
make_fake_project() {
  local name="$1"        # directory name under QD_CLAUDE_PROJECTS_DIR
  local cwd="$2"         # value for the "cwd" field (use forward slashes)
  local age_seconds="${3:-0}"  # how many seconds "old" the file should appear (via touch -d)

  local proj_dir="$QD_CLAUDE_PROJECTS_DIR/$name"
  mkdir -p "$proj_dir"
  local jsonl="$proj_dir/session.jsonl"
  # Write a minimal JSONL line with cwd
  printf '{"type":"start","cwd":"%s"}\n' "$cwd" > "$jsonl"

  if [[ "$age_seconds" -gt 0 ]]; then
    # Make the file appear older so recency sorting can be tested
    touch -d "-${age_seconds} seconds" "$jsonl"
  fi
}
