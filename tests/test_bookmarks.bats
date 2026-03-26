# tests/test_bookmarks.bats
load 'helpers'

setup() {
  setup_fake_home
  source "$BATS_TEST_DIRNAME/../shell/quickdir.sh"
}
teardown() { teardown_fake_home; }

@test "_qd_bookmark_list returns empty when no bookmarks file" {
  run _qd_bookmark_list
  [[ -z "$output" ]]
}

@test "_qd_bookmark_add writes path to bookmarks file" {
  mkdir -p "$FAKE_HOME/bm_test"
  _qd_bookmark_add "$FAKE_HOME/bm_test"
  run _qd_bookmark_list
  [[ "$output" == *"$FAKE_HOME/bm_test"* ]]
}

@test "_qd_bookmark_add does not duplicate an existing bookmark" {
  mkdir -p "$FAKE_HOME/bm_dup"
  _qd_bookmark_add "$FAKE_HOME/bm_dup"
  _qd_bookmark_add "$FAKE_HOME/bm_dup"
  run _qd_bookmark_list
  count=$(echo "$output" | grep -c "$FAKE_HOME/bm_dup")
  [[ "$count" -eq 1 ]]
}

@test "_qd_bookmark_add exits 1 for non-existent path" {
  run _qd_bookmark_add "/path/that/does/not/exist"
  [[ "$status" -eq 1 ]]
}

@test "_qd_bookmark_remove removes the given path" {
  mkdir -p "$FAKE_HOME/bm_rm"
  _qd_bookmark_add "$FAKE_HOME/bm_rm"
  _qd_bookmark_remove "$FAKE_HOME/bm_rm"
  run _qd_bookmark_list
  [[ "$output" != *"$FAKE_HOME/bm_rm"* ]]
}
