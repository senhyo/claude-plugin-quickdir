# tests/test_merge.bats
load 'helpers'

setup() {
  setup_fake_home
  source "$BATS_TEST_DIRNAME/../shell/quickdir.sh"
}
teardown() { teardown_fake_home; }

@test "_qd_merged_paths deduplicates history and bookmarks" {
  mkdir -p "$FAKE_HOME/merge_a"
  make_fake_project "proj-a" "$FAKE_HOME/merge_a"
  _qd_bookmark_add "$FAKE_HOME/merge_a"
  run _qd_merged_paths
  count=$(echo "$output" | grep -c "merge_a")
  [[ "$count" -eq 1 ]]
}

@test "_qd_merged_paths puts history entries before bookmark-only entries" {
  mkdir -p "$FAKE_HOME/history_only" "$FAKE_HOME/bookmark_only"
  make_fake_project "hist" "$FAKE_HOME/history_only"
  _qd_bookmark_add "$FAKE_HOME/bookmark_only"
  run _qd_merged_paths
  hist_line=$(echo "$output" | grep -n "history_only" | cut -d: -f1)
  bm_line=$(echo "$output" | grep -n "bookmark_only" | cut -d: -f1)
  [[ -n "$hist_line" ]]
  [[ -n "$bm_line" ]]
  [[ "$hist_line" -lt "$bm_line" ]]
}

@test "qd list prints merged paths" {
  mkdir -p "$FAKE_HOME/list_test"
  make_fake_project "list-proj" "$FAKE_HOME/list_test"
  run qd list
  [[ "$output" == *"list_test"* ]]
}
