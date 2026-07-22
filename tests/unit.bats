#!/usr/bin/env bats

setup() {
    export REPO_ROOT
    REPO_ROOT="$(cd "$BATS_TEST_DIRNAME/.." && pwd)"
    export AIBOX="${REPO_ROOT}/aibox"

    export TEST_HOME="${BATS_TEST_TMPDIR}/home"
    export TEST_PROJECT="${BATS_TEST_TMPDIR}/project"
    export FAKE_BIN="${BATS_TEST_TMPDIR}/bin"
    export AIBOX_FAKE_BWRAP_LOG="${BATS_TEST_TMPDIR}/bwrap.argv"
    export AIBOX_FAKE_BWRAP_PARENT_LOG="${BATS_TEST_TMPDIR}/bwrap-parent.argv"

    mkdir -p \
        "$TEST_PROJECT" \
        "$FAKE_BIN" \
        "$TEST_HOME/.codex" \
        "$TEST_HOME/.claude" \
        "$TEST_HOME/.copilot" \
        "$TEST_HOME/.config/claude" \
        "$TEST_HOME/.config/claude-code" \
        "$TEST_HOME/.config/github-copilot" \
        "$TEST_HOME/.config/gh" \
        "$TEST_HOME/.config/git" \
        "$TEST_HOME/.config/direnv" \
        "$TEST_HOME/.local/share/direnv" \
        "$TEST_HOME/.cache/direnv"

    touch \
        "$TEST_HOME/.claude.json" \
        "$TEST_HOME/.gitconfig" \
        "$TEST_HOME/AGENTS.md" \
        "$TEST_HOME/CLAUDE.md"

    {
        printf '#!%s\n' "$(command -v bash)"
        cat <<'EOF'
printf '%s\n' "$@" >"${AIBOX_FAKE_BWRAP_LOG:?}"
while IFS= read -r -d '' arg; do
    printf '%s\n' "$arg"
done <"/proc/${PPID}/cmdline" >"${AIBOX_FAKE_BWRAP_PARENT_LOG:?}"
exit "${AIBOX_FAKE_BWRAP_STATUS:-0}"
EOF
    } >"$FAKE_BIN/bwrap"
    chmod +x "$FAKE_BIN/bwrap"

    export PATH="${FAKE_BIN}:${PATH}"
}

run_aibox() {
    run_aibox_with_home "$TEST_HOME" "$@"
}

run_aibox_with_home() {
    local home=$1
    shift
    run bash -c 'cd "$1" && HOME="$2" SHELL=/bin/sh bash "$3" -- "${@:4}"' _ "$TEST_PROJECT" "$home" "$AIBOX" "$@"
}

assert_arg() {
    grep -Fxq -- "$1" "$AIBOX_FAKE_BWRAP_LOG"
}

refute_arg() {
    ! grep -Fxq -- "$1" "$AIBOX_FAKE_BWRAP_LOG"
}

@test "--version prints version" {
    mkdir -p "${BATS_TEST_TMPDIR}/empty-path"

    run env PATH="${BATS_TEST_TMPDIR}/empty-path" "$BASH" "$AIBOX" --version
    [ "$status" -eq 0 ]
    [ "$output" = "aibox 0.1.0" ]
}

@test "--help does not require bwrap" {
    mkdir -p "${BATS_TEST_TMPDIR}/empty-path"

    run env PATH="${BATS_TEST_TMPDIR}/empty-path" "$BASH" "$AIBOX" --help
    [ "$status" -eq 0 ]
    [[ "$output" == *"Usage:"* ]]
    [[ "$output" == *"aibox -p|--dump-prompt"* ]]
    [[ "$output" == *"Run from a project directory"* ]]
}

@test "--dump-prompt does not require bwrap" {
    mkdir -p "${BATS_TEST_TMPDIR}/empty-path"

    run env PATH="${BATS_TEST_TMPDIR}/empty-path" "$BASH" "$AIBOX" --dump-prompt
    [ "$status" -eq 0 ]
    [[ "$output" == *"aibox sandbox"* ]]
    [[ "$output" == *"https://github.com/ruifm/aibox"* ]]
    [[ "$output" == *"Nix devShell"* ]]
    [[ "$output" == *"run direnv allow once before adding tools"* ]]
}

@test "-p dumps prompt" {
    mkdir -p "${BATS_TEST_TMPDIR}/empty-path"

    run env PATH="${BATS_TEST_TMPDIR}/empty-path" "$BASH" "$AIBOX" -p
    [ "$status" -eq 0 ]
    [[ "$output" == *"aibox public repo: https://github.com/ruifm/aibox"* ]]
    [[ "$output" == *"aibox -p"* ]]
}

@test "unknown option is rejected" {
    mkdir -p "${BATS_TEST_TMPDIR}/empty-path"

    run env PATH="${BATS_TEST_TMPDIR}/empty-path" "$BASH" "$AIBOX" --bogus
    [ "$status" -ne 0 ]
    [[ "$output" == *"unknown option: --bogus"* ]]
}

@test "prints bwrap command before running it" {
    run_aibox true
    [ "$status" -eq 0 ]
    [[ "$output" == *"aibox: bwrap "* ]]
    assert_arg "true"
}

@test "keeps aibox as the bwrap parent process" {
    run_aibox true
    [ "$status" -eq 0 ]
    sed -n '2p' "$AIBOX_FAKE_BWRAP_PARENT_LOG" | grep -Fxq "$AIBOX"
}

@test "returns the bwrap exit status" {
    export AIBOX_FAKE_BWRAP_STATUS=42

    run_aibox true
    [ "$status" -eq 42 ]
}

@test "binds current directory at the same absolute path" {
    run_aibox true
    [ "$status" -eq 0 ]
    assert_arg "--bind"
    assert_arg "$TEST_PROJECT"
    assert_arg "--chdir"
    assert_arg "$TEST_PROJECT"
}

@test "refusing HOME as workspace suggests project directory" {
    run bash -c 'cd "$1" && HOME="$1" SHELL=/bin/sh bash "$2" -- true' _ "$TEST_PROJECT" "$AIBOX"
    [ "$status" -ne 0 ]
    [[ "$output" == *"refusing to bind HOME as the writable workspace; cd into a project directory first"* ]]
}

@test "keeps root read-only and host network shared" {
    run_aibox true
    [ "$status" -eq 0 ]
    assert_arg "--share-net"
    assert_arg "--unshare-user"
    assert_arg "--disable-userns"
    assert_arg "--remount-ro"
}

@test "includes Nix store and daemon policy when available" {
    run_aibox true
    [ "$status" -eq 0 ]

    if [ -d /nix/store ]; then
        assert_arg "/nix/store"
    fi
    if [ -S /nix/var/nix/daemon-socket/socket ]; then
        assert_arg "/nix/var/nix/daemon-socket/socket"
        assert_arg "NIX_REMOTE"
        assert_arg "daemon"
    fi
}

@test "mounts only agent state, not Git or GitHub CLI config" {
    run_aibox true
    [ "$status" -eq 0 ]

    assert_arg "$TEST_HOME/.codex"
    assert_arg "$TEST_HOME/.claude"
    assert_arg "$TEST_HOME/.copilot"
    assert_arg "$TEST_HOME/.config/github-copilot"
    assert_arg "COPILOT_HOME"

    refute_arg "$TEST_HOME/.config/gh"
    refute_arg "$TEST_HOME/.gitconfig"
    refute_arg "$TEST_HOME/.config/git"
    refute_arg "$TEST_HOME/AGENTS.md"
    refute_arg "$TEST_HOME/CLAUDE.md"
}

@test "mounts aibox prompt command inside sandbox path" {
    run_aibox true
    [ "$status" -eq 0 ]

    assert_arg "$AIBOX"
    assert_arg "/run/aibox/bin/aibox"
    assert_arg "PATH"
    assert_arg "/run/aibox/bin:${PATH}"
}

@test "creates known writable state paths before mounting" {
    local fresh_home="${BATS_TEST_TMPDIR}/fresh-home"
    mkdir -p "$fresh_home"

    run_aibox_with_home "$fresh_home" true
    [ "$status" -eq 0 ]

    [ -d "$fresh_home/.codex" ]
    [ -d "$fresh_home/.claude" ]
    [ -d "$fresh_home/.copilot" ]
    [ -d "$fresh_home/.config/claude" ]
    [ -d "$fresh_home/.config/claude-code" ]
    [ -d "$fresh_home/.config/github-copilot" ]
    [ -d "$fresh_home/.local/share/direnv" ]
    [ -d "$fresh_home/.cache/direnv" ]
    [ "$(cat "$fresh_home/.claude.json")" = "{}" ]

    assert_arg "$fresh_home/.codex"
    assert_arg "$fresh_home/.claude.json"
}

@test "preserves existing claude json content" {
    printf '{"existing":true}\n' >"$TEST_HOME/.claude.json"

    run_aibox true
    [ "$status" -eq 0 ]
    [ "$(cat "$TEST_HOME/.claude.json")" = '{"existing":true}' ]
}

@test "invalid state directory type fails clearly" {
    rm -rf "$TEST_HOME/.codex"
    touch "$TEST_HOME/.codex"

    run_aibox true
    [ "$status" -ne 0 ]
    [[ "$output" == *"expected directory but found non-directory: $TEST_HOME/.codex; remove or rename the conflicting path"* ]]
}

@test "invalid claude json type fails clearly" {
    rm -f "$TEST_HOME/.claude.json"
    mkdir "$TEST_HOME/.claude.json"

    run_aibox true
    [ "$status" -ne 0 ]
    [[ "$output" == *"expected file but found non-file: $TEST_HOME/.claude.json; remove or rename the conflicting path"* ]]
}

@test "ignores removed AGENT_SANDBOX environment knobs" {
    local extra_path="${BATS_TEST_TMPDIR}/extra"
    mkdir -p "$extra_path"

    run env AGENT_SANDBOX_RW_PATHS="$extra_path" bash -c \
        'cd "$1" && HOME="$2" SHELL=/bin/sh bash "$3" -- true' \
        _ "$TEST_PROJECT" "$TEST_HOME" "$AIBOX"

    [ "$status" -eq 0 ]
    refute_arg "$extra_path"
}

@test "agent instruction aliases are symlinks" {
    [ -L "$REPO_ROOT/CLAUDE.md" ]
    [ "$(readlink "$REPO_ROOT/CLAUDE.md")" = "AGENTS.md" ]
    [ -L "$REPO_ROOT/.github/copilot-instructions.md" ]
    [ "$(readlink "$REPO_ROOT/.github/copilot-instructions.md")" = "../AGENTS.md" ]
}
