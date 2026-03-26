# tests/test_select.bats
load 'helpers'

setup() {
  setup_fake_home
  source "$BATS_TEST_DIRNAME/../shell/quickdir.sh"
  export QD_FORCE_LIST=1   # always use numbered list in tests
}
teardown() { teardown_fake_home; }

@test "_qd_select returns path matching user input '1'" {
  run bash -c "
    source '$BATS_TEST_DIRNAME/../shell/quickdir.sh'
    export QD_FORCE_LIST=1
    printf '/tmp/alpha\n/tmp/beta\n1\n' | _qd_select 2>/dev/null
  "
  [[ "$output" == "/tmp/alpha" ]]
}

@test "_qd_select returns path matching user input '2'" {
  run bash -c "
    source '$BATS_TEST_DIRNAME/../shell/quickdir.sh'
    export QD_FORCE_LIST=1
    printf '/tmp/alpha\n/tmp/beta\n2\n' | _qd_select 2>/dev/null
  "
  [[ "$output" == "/tmp/beta" ]]
}

@test "_qd_select exits 0 and prints nothing on empty input (cancel)" {
  run bash -c "
    source '$BATS_TEST_DIRNAME/../shell/quickdir.sh'
    export QD_FORCE_LIST=1
    printf '/tmp/alpha\n\n' | _qd_select 2>/dev/null
  "
  [[ "$status" -eq 0 ]]
  [[ -z "$output" ]]
}

@test "_qd_select exits 0 on out-of-range number" {
  run bash -c "
    source '$BATS_TEST_DIRNAME/../shell/quickdir.sh'
    export QD_FORCE_LIST=1
    printf '/tmp/alpha\n99\n' | _qd_select 2>/dev/null
  "
  [[ "$status" -eq 0 ]]
  [[ -z "$output" ]]
}
