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
        "$TEST_HOME/.agents/skills" \
        "$TEST_HOME/.agents/plugins" \
        "$TEST_HOME/.opencode/bin" \
        "$TEST_HOME/.codex" \
        "$TEST_HOME/.claude" \
        "$TEST_HOME/.copilot" \
        "$TEST_HOME/.hermes" \
        "$TEST_HOME/.omp" \
        "$TEST_HOME/.ori" \
        "$TEST_HOME/.pi" \
        "$TEST_HOME/.cache/copilot" \
        "$TEST_HOME/.cache/omp" \
        "$TEST_HOME/.cache/opencode" \
        "$TEST_HOME/.config/anthropic" \
        "$TEST_HOME/.config/opencode" \
        "$TEST_HOME/.config/claude" \
        "$TEST_HOME/.config/claude-code" \
        "$TEST_HOME/.config/github-copilot" \
        "$TEST_HOME/.config/gh" \
        "$TEST_HOME/.config/git" \
        "$TEST_HOME/.config/direnv" \
        "$TEST_HOME/.local/share/direnv" \
        "$TEST_HOME/.local/share/omp" \
        "$TEST_HOME/.local/share/opencode" \
        "$TEST_HOME/.local/state/omp" \
        "$TEST_HOME/.local/state/opencode" \
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

assert_arg_sequence() {
    local -a expected=("$@")
    local -a actual
    local start offset

    mapfile -t actual <"$AIBOX_FAKE_BWRAP_LOG"
    for ((start = 0; start + ${#expected[@]} <= ${#actual[@]}; start++)); do
        for ((offset = 0; offset < ${#expected[@]}; offset++)); do
            [[ "${actual[start + offset]}" == "${expected[offset]}" ]] || break
        done
        ((offset == ${#expected[@]})) && return 0
    done

    printf 'missing argument sequence: %s\n' "${expected[*]}" >&2
    return 1
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
    [[ "$output" == *"Run from the repository root"* ]]
    [[ "$output" == *"aibox hermes"* ]]
    [[ "$output" == *"aibox omp"* ]]
    [[ "$output" == *"aibox pi"* ]]
    [[ "$output" == *"aibox opencode"* ]]
}

@test "--dump-prompt does not require bwrap" {
    mkdir -p "${BATS_TEST_TMPDIR}/empty-path"

    run env PATH="${BATS_TEST_TMPDIR}/empty-path" "$BASH" "$AIBOX" --dump-prompt
    [ "$status" -eq 0 ]
    [[ "$output" == *"aibox sandbox"* ]]
    [[ "$output" == *"https://github.com/ruifm/aibox"* ]]
    [[ "$output" == *"Nix devShell"* ]]
    [[ "$output" == *"run direnv allow once before adding tools"* ]]
    [[ "$output" == *"Project files above it are not visible"* ]]
    [[ "$output" == *"Custom agent state path environment variables are removed"* ]]
    [[ "$output" == *"Hermes, OMP, OpenCode, and Pi paths"* ]]
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

@test "required config options preserve paths and command arguments" {
    run bash -c 'cd "$1" && HOME="$2" bash "$3" --require-config /etc/codex/requirements.toml --require-config="/etc/claude-code/policy file.json" -- printf "%s" "a b"' _ "$TEST_PROJECT" "$TEST_HOME" "$AIBOX"
    [ "$status" -eq 0 ]
    assert_arg_sequence /etc/codex/requirements.toml "/etc/claude-code/policy file.json" printf "%s" "a b"
}

@test "required config rejects paths outside the fixed directories" {
    local path
    for path in relative /etc/codex-other/file /etc/codex/../shadow /etc/codex/./file /etc/static/codex/file /etc/codex ""; do
        run bash "$AIBOX" --require-config="$path" -- true
        [ "$status" -ne 0 ]
        [[ "$output" == *"invalid required config path"* ]]
    done
    run bash "$AIBOX" --require-config
    [ "$status" -ne 0 ]
    [[ "$output" == *"missing value for --require-config"* ]]
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

@test "refusing HOME as workspace suggests repository root" {
    run bash -c 'cd "$1" && HOME="$1" SHELL=/bin/sh bash "$2" -- true' _ "$TEST_PROJECT" "$AIBOX"
    [ "$status" -ne 0 ]
    [[ "$output" == *"refusing to bind HOME as the writable workspace; cd into a repository root first"* ]]
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

@test "mounts supported agent state, not Git or GitHub CLI config" {
    run_aibox true
    [ "$status" -eq 0 ]

    assert_arg "$TEST_HOME/.agents/skills"
    assert_arg "$TEST_HOME/.agents/plugins"
    assert_arg "$TEST_HOME/.codex"
    assert_arg "$TEST_HOME/.claude"
    assert_arg "$TEST_HOME/.copilot"
    assert_arg "$TEST_HOME/.hermes"
    assert_arg "$TEST_HOME/.omp"
    assert_arg "$TEST_HOME/.ori"
    assert_arg "$TEST_HOME/.pi"
    assert_arg "$TEST_HOME/.cache/copilot"
    assert_arg "$TEST_HOME/.cache/omp"
    assert_arg "$TEST_HOME/.cache/opencode"
    assert_arg "$TEST_HOME/.config/anthropic"
    assert_arg "$TEST_HOME/.config/opencode"
    assert_arg "$TEST_HOME/.local/share/omp"
    assert_arg "$TEST_HOME/.local/share/opencode"
    assert_arg "$TEST_HOME/.local/state/omp"
    assert_arg "$TEST_HOME/.local/state/opencode"

    refute_arg "$TEST_HOME/.config/claude"
    refute_arg "$TEST_HOME/.config/claude-code"
    refute_arg "$TEST_HOME/.config/github-copilot"
    refute_arg "$TEST_HOME/.opencode"
    refute_arg "$TEST_HOME/.opencode/bin"
    refute_arg "$TEST_HOME/.config/gh"
    refute_arg "$TEST_HOME/.gitconfig"
    refute_arg "$TEST_HOME/.config/git"
    refute_arg "$TEST_HOME/AGENTS.md"
    refute_arg "$TEST_HOME/CLAUDE.md"
}

@test "mounts system agent config read-only when present" {
    run_aibox true
    [ "$status" -eq 0 ]

    assert_arg_sequence --ro-bind-try /etc/codex /etc/codex
    assert_arg_sequence --ro-bind-try /etc/claude-code /etc/claude-code
    assert_arg_sequence --ro-bind-try /etc/github-copilot /etc/github-copilot
    assert_arg_sequence --ro-bind-try /etc/hermes /etc/hermes
    assert_arg_sequence --ro-bind-try /etc/opencode /etc/opencode
}

@test "uses fixed default agent state paths" {
    run env \
        CODEX_HOME=/host/codex \
        CODEX_SQLITE_HOME=/host/codex-sqlite \
        CLAUDE_CONFIG_DIR=/host/claude \
        ANTHROPIC_CONFIG_DIR=/host/anthropic \
        COPILOT_HOME=/host/copilot \
        COPILOT_CACHE_HOME=/host/copilot-cache \
        HERMES_HOME=/host/hermes \
        HERMES_MANAGED_DIR=/host/hermes-managed \
        PI_CONFIG_DIR=foreign-omp \
        PI_CODING_AGENT_DIR=/host/pi-agent \
        PI_CODING_AGENT_SESSION_DIR=/host/pi-session \
        PI_SERVER_DIR=/host/pi-server \
        OPENCODE_CONFIG_DIR=/host/opencode \
        bash -c 'cd "$1" && HOME="$2" SHELL=/bin/sh bash "$3" -- true' \
        _ "$TEST_PROJECT" "$TEST_HOME" "$AIBOX"
    [ "$status" -eq 0 ]

    assert_arg_sequence --unsetenv CODEX_HOME
    assert_arg_sequence --unsetenv CODEX_SQLITE_HOME
    assert_arg_sequence --unsetenv CLAUDE_CONFIG_DIR
    assert_arg_sequence --unsetenv ANTHROPIC_CONFIG_DIR
    assert_arg_sequence --unsetenv COPILOT_HOME
    assert_arg_sequence --unsetenv COPILOT_CACHE_HOME
    assert_arg_sequence --unsetenv HERMES_HOME
    assert_arg_sequence --unsetenv HERMES_MANAGED_DIR
    assert_arg_sequence --unsetenv PI_CONFIG_DIR
    assert_arg_sequence --unsetenv PI_CODING_AGENT_DIR
    assert_arg_sequence --unsetenv PI_CODING_AGENT_SESSION_DIR
    assert_arg_sequence --unsetenv PI_SERVER_DIR
    assert_arg_sequence --unsetenv OPENCODE_CONFIG_DIR

    refute_arg /host/codex
    refute_arg /host/codex-sqlite
    refute_arg /host/claude
    refute_arg /host/anthropic
    refute_arg /host/copilot
    refute_arg /host/copilot-cache
    refute_arg /host/hermes
    refute_arg /host/hermes-managed
    refute_arg /host/pi-agent
    refute_arg /host/pi-session
    refute_arg /host/pi-server
    refute_arg /host/opencode
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

    [ -d "$fresh_home/.agents/skills" ]
    [ -d "$fresh_home/.agents/plugins" ]
    [ -d "$fresh_home/.codex" ]
    [ -d "$fresh_home/.claude" ]
    [ -d "$fresh_home/.copilot" ]
    [ -d "$fresh_home/.hermes" ]
    [ -d "$fresh_home/.omp" ]
    [ -d "$fresh_home/.ori" ]
    [ -d "$fresh_home/.pi" ]
    [ -d "$fresh_home/.cache/copilot" ]
    [ -d "$fresh_home/.cache/opencode" ]
    [ ! -e "$fresh_home/.cache/omp" ]
    [ -d "$fresh_home/.config/anthropic" ]
    [ -d "$fresh_home/.config/opencode" ]
    [ -d "$fresh_home/.local/share/direnv" ]
    [ -d "$fresh_home/.local/share/opencode" ]
    [ ! -e "$fresh_home/.local/share/omp" ]
    [ -d "$fresh_home/.local/state/opencode" ]
    [ ! -e "$fresh_home/.local/state/omp" ]
    [ -d "$fresh_home/.cache/direnv" ]
    [ "$(cat "$fresh_home/.claude.json")" = "{}" ]

    assert_arg "$fresh_home/.agents/skills"
    assert_arg "$fresh_home/.agents/plugins"
    assert_arg "$fresh_home/.codex"
    assert_arg "$fresh_home/.claude.json"
    assert_arg "$fresh_home/.hermes"
    assert_arg "$fresh_home/.omp"
    assert_arg "$fresh_home/.ori"
    assert_arg "$fresh_home/.pi"
    assert_arg "$fresh_home/.cache/copilot"
    assert_arg "$fresh_home/.cache/opencode"
    assert_arg "$fresh_home/.config/anthropic"
    assert_arg "$fresh_home/.config/opencode"
    assert_arg "$fresh_home/.local/share/opencode"
    assert_arg "$fresh_home/.local/state/opencode"
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
