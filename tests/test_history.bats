load 'helpers'

setup() {
  setup_fake_home
  source "$BATS_TEST_DIRNAME/../shell/quickdir.sh"
}
teardown() { teardown_fake_home; }

@test "fake home is created and writable" {
  [[ -d "$QD_CLAUDE_PROJECTS_DIR" ]]
  [[ "$FAKE_HOME" != "$HOME" ]]
}

@test "_qd_history_paths returns a known cwd" {
  mkdir -p "/tmp/qd_test_known_cwd"
  make_fake_project "proj-a" "/tmp/qd_test_known_cwd"
  run _qd_history_paths
  [[ "$output" == *"qd_test_known_cwd"* ]]
  rm -rf /tmp/qd_test_known_cwd
}

@test "_qd_history_paths skips non-existent paths" {
  make_fake_project "proj-ghost" "/does/not/exist/ever"
  run _qd_history_paths
  [[ "$output" != *"/does/not/exist/ever"* ]]
}

@test "_qd_history_paths returns newest project first" {
  mkdir -p "/tmp/qd_test_alpha" "/tmp/qd_test_beta"
  make_fake_project "old-proj"  "/tmp/qd_test_beta"  60   # 60 seconds old
  make_fake_project "new-proj"  "/tmp/qd_test_alpha"  0    # just created
  run _qd_history_paths
  # alpha (newer) should appear before beta (older)
  alpha_line=$(echo "$output" | grep -n "alpha" | cut -d: -f1)
  beta_line=$(echo "$output" | grep -n "beta" | cut -d: -f1)
  [[ "$alpha_line" -lt "$beta_line" ]]
  rm -rf /tmp/qd_test_alpha /tmp/qd_test_beta
}

@test "_qd_history_paths returns empty output when no projects exist" {
  run _qd_history_paths
  [[ -z "$output" ]]
}
