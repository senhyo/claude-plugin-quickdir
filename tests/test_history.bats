load 'helpers'

setup() { setup_fake_home; }
teardown() { teardown_fake_home; }

@test "fake home is created and writable" {
  [[ -d "$QD_CLAUDE_PROJECTS_DIR" ]]
  [[ "$FAKE_HOME" != "$HOME" ]]
}
