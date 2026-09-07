#!/usr/bin/env bats

setup() {
    export REPO_ROOT
    REPO_ROOT="$(cd "$BATS_TEST_DIRNAME/.." && pwd)"
    export AIBOX="${REPO_ROOT}/aibox"

    mkdir -p "${REPO_ROOT}/.test-work"

    export TEST_ROOT
    TEST_ROOT="$(mktemp -d "${REPO_ROOT}/.test-work/integration.XXXXXX")"
    export TEST_HOME="${TEST_ROOT}/home"
    export TEST_PROJECT="${TEST_ROOT}/project"
    export TEST_PARENT="${TEST_ROOT}"
    export TEST_OUTSIDE="${TEST_PARENT}/outside-target"

    mkdir -p \
        "$TEST_HOME" \
        "$TEST_PROJECT"
}

teardown() {
    rm -rf "$TEST_ROOT"
}

run_aibox() {
    run bash -c 'cd "$1" && HOME="$2" SHELL=/bin/sh "$3" -- "${@:4}"' _ "$TEST_PROJECT" "$TEST_HOME" "$AIBOX" "$@"
}

@test "current directory is writable and preserved" {
    run_aibox bash -lc 'test "$PWD" = "$1" && echo ok > created-by-aibox' _ "$TEST_PROJECT"
    [ "$status" -eq 0 ]
    [ "$(cat "$TEST_PROJECT/created-by-aibox")" = "ok" ]
}

@test "hostname changes display identity but keeps detection and workspace" {
    run bash -c 'cd "$1" && HOME="$2" AIBOX=foreign "$3" --hostname=project-agent -- bash -c '\''test "$AIBOX" = 1 && test "$(cat /proc/sys/kernel/hostname)" = project-agent && test "$PWD" = "$1" && touch hostname-write'\'' _ "$1"' _ "$TEST_PROJECT" "$TEST_HOME" "$AIBOX"
    [ "$status" -eq 0 ]
    [ -f "$TEST_PROJECT/hostname-write" ]
}

@test "certificate paths are checked inside the sandbox without printing values" {
    local name path
    touch "$TEST_HOME/secret-certificate-path"
    for name in SSL_CERT_FILE NIX_SSL_CERT_FILE; do
        for path in "" "$TEST_HOME/secret-certificate-path" "$TEST_PROJECT/missing" "$TEST_PROJECT"; do
            export "$name=$path"
            run_aibox touch command-started
            [ "$status" -ne 0 ]
            [[ "$output" == *"$name is not a readable certificate file inside the sandbox"* ]]
            [[ "$output" != *"secret-certificate-path"* ]]
            [ ! -e "$TEST_PROJECT/command-started" ]
        done
        unset "$name"
    done
}

@test "distinct and relative certificate paths preserve command arguments and status" {
    touch "$TEST_PROJECT/first bundle" "$TEST_PROJECT/second"
    export SSL_CERT_FILE='first bundle' NIX_SSL_CERT_FILE="$TEST_PROJECT/second"
    run_aibox bash -c 'test "$1" = '\''a b; $(false)'\'' && test "$2" = "" && test "$SSL_CERT_FILE" = "first bundle" && exit 42' _ 'a b; $(false)' ''
    [ "$status" -eq 42 ]
}

@test "parent directory write is denied" {
    run_aibox bash -lc '! touch "$1/parent-write-denied" 2>/dev/null' _ "$TEST_PARENT"
    [ "$status" -eq 0 ]
    [ ! -e "$TEST_PARENT/parent-write-denied" ]
}

@test "symlink escape write is denied" {
    touch "$TEST_OUTSIDE"
    ln -s "$TEST_OUTSIDE" "$TEST_PROJECT/escape"

    run_aibox bash -lc '! sh -c "echo escaped > escape" 2>/dev/null'
    [ "$status" -eq 0 ]
    [ ! -s "$TEST_OUTSIDE" ]
}

@test "generic home cache/config/local writes do not persist" {
    run_aibox bash -lc 'touch "$HOME/.cache/cache-file"; touch "$HOME/.config/config-file"; touch "$HOME/.local/local-file"'
    [ "$status" -eq 0 ]
    [ ! -e "$TEST_HOME/.cache/cache-file" ]
    [ ! -e "$TEST_HOME/.config/config-file" ]
    [ ! -e "$TEST_HOME/.local/local-file" ]
}

@test "agent state writes persist" {
    run_aibox bash -lc 'echo state > "$HOME/.codex/state-file"'
    [ "$status" -eq 0 ]
    [ "$(cat "$TEST_HOME/.codex/state-file")" = "state" ]
}

@test "shared agent skills and plugin state writes persist" {
    run_aibox bash -lc 'echo skill > "$HOME/.agents/skills/state-file"; echo plugin > "$HOME/.agents/plugins/state-file"'
    [ "$status" -eq 0 ]
    [ "$(cat "$TEST_HOME/.agents/skills/state-file")" = "skill" ]
    [ "$(cat "$TEST_HOME/.agents/plugins/state-file")" = "plugin" ]
}

@test "Anthropic profile state writes persist" {
    run_aibox bash -lc 'echo profile > "$HOME/.config/anthropic/state-file"'
    [ "$status" -eq 0 ]
    [ "$(cat "$TEST_HOME/.config/anthropic/state-file")" = "profile" ]
}

@test "copilot state writes persist" {
    run_aibox bash -lc 'mkdir -p "$HOME/.copilot/session-state"; echo state > "$HOME/.copilot/session-state/session-file"'
    [ "$status" -eq 0 ]
    [ "$(cat "$TEST_HOME/.copilot/session-state/session-file")" = "state" ]
}

@test "copilot cache writes persist" {
    run_aibox bash -lc 'echo cache > "$HOME/.cache/copilot/cache-file"'
    [ "$status" -eq 0 ]
    [ "$(cat "$TEST_HOME/.cache/copilot/cache-file")" = "cache" ]
}

@test "OpenCode state and config writes persist" {
    run_aibox bash -lc 'echo cache > "$HOME/.cache/opencode/file"; echo config > "$HOME/.config/opencode/file"; echo data > "$HOME/.local/share/opencode/file"; echo state > "$HOME/.local/state/opencode/file"'
    [ "$status" -eq 0 ]
    [ "$(cat "$TEST_HOME/.cache/opencode/file")" = "cache" ]
    [ "$(cat "$TEST_HOME/.config/opencode/file")" = "config" ]
    [ "$(cat "$TEST_HOME/.local/share/opencode/file")" = "data" ]
    [ "$(cat "$TEST_HOME/.local/state/opencode/file")" = "state" ]
}

@test "Hermes, OMP, and Pi state writes persist" {
    run_aibox bash -lc 'echo hermes > "$HOME/.hermes/file"; echo omp > "$HOME/.omp/file"; echo pi > "$HOME/.pi/file"'
    [ "$status" -eq 0 ]
    [ "$(cat "$TEST_HOME/.hermes/file")" = "hermes" ]
    [ "$(cat "$TEST_HOME/.omp/file")" = "omp" ]
    [ "$(cat "$TEST_HOME/.pi/file")" = "pi" ]
}

@test "existing OMP XDG state writes persist" {
    mkdir -p "$TEST_HOME/.cache/omp" "$TEST_HOME/.local/share/omp" "$TEST_HOME/.local/state/omp"

    run_aibox bash -lc 'echo cache > "$HOME/.cache/omp/file"; echo data > "$HOME/.local/share/omp/file"; echo state > "$HOME/.local/state/omp/file"'
    [ "$status" -eq 0 ]
    [ "$(cat "$TEST_HOME/.cache/omp/file")" = "cache" ]
    [ "$(cat "$TEST_HOME/.local/share/omp/file")" = "data" ]
    [ "$(cat "$TEST_HOME/.local/state/omp/file")" = "state" ]
}

@test "old agent config paths stay private" {
    run_aibox bash -lc 'mkdir -p "$HOME/.config/claude" "$HOME/.config/claude-code" "$HOME/.config/github-copilot"; touch "$HOME/.config/claude/file" "$HOME/.config/claude-code/file" "$HOME/.config/github-copilot/file"'
    [ "$status" -eq 0 ]
    [ ! -e "$TEST_HOME/.config/claude/file" ]
    [ ! -e "$TEST_HOME/.config/claude-code/file" ]
    [ ! -e "$TEST_HOME/.config/github-copilot/file" ]
}

@test "ori global state writes persist" {
    run_aibox bash -lc 'echo state > "$HOME/.ori/state-file"'
    [ "$status" -eq 0 ]
    [ "$(cat "$TEST_HOME/.ori/state-file")" = "state" ]
}

@test "fresh claude json is writable and persists" {
    run_aibox bash -lc 'test "$(cat "$HOME/.claude.json")" = "{}" && printf "%s\n" "{\"ok\":true}" >"$HOME/.claude.json"'
    [ "$status" -eq 0 ]
    [ "$(cat "$TEST_HOME/.claude.json")" = '{"ok":true}' ]
}

@test "ordinary environment variables and the OpenRouter key pass through" {
    run env AIBOX_SENTINEL=visible OPENROUTER_API_KEY=test-key bash -c \
        'cd "$1" && HOME="$2" SHELL=/bin/sh "$3" -- bash -lc '\''test "$AIBOX_SENTINEL" = visible && test "$OPENROUTER_API_KEY" = test-key'\''' \
        _ "$TEST_PROJECT" "$TEST_HOME" "$AIBOX"
    [ "$status" -eq 0 ]
}

@test "agent API and profile environment variables pass through" {
    run env \
        OPENAI_API_KEY=openai-key \
        ANTHROPIC_API_KEY=anthropic-key \
        ANTHROPIC_PROFILE=work \
        COPILOT_GITHUB_TOKEN=copilot-token \
        HERMES_PROFILE=work \
        OMP_PROFILE=work \
        bash -c \
        'cd "$1" && HOME="$2" SHELL=/bin/sh "$3" -- bash -lc '\''test "$OPENAI_API_KEY" = openai-key && test "$ANTHROPIC_API_KEY" = anthropic-key && test "$ANTHROPIC_PROFILE" = work && test "$COPILOT_GITHUB_TOKEN" = copilot-token && test "$HERMES_PROFILE" = work && test "$OMP_PROFILE" = work'\''' \
        _ "$TEST_PROJECT" "$TEST_HOME" "$AIBOX"
    [ "$status" -eq 0 ]
}

@test "OpenCode config file path in the project passes through" {
    local config="$TEST_PROJECT/opencode-extra.json"
    printf '{}\n' >"$config"

    run env OPENCODE_CONFIG="$config" bash -c \
        'cd "$1" && HOME="$2" SHELL=/bin/sh "$3" -- bash -lc '\''test "$OPENCODE_CONFIG" = "$PWD/opencode-extra.json" && test -f "$OPENCODE_CONFIG"'\''' \
        _ "$TEST_PROJECT" "$TEST_HOME" "$AIBOX"
    [ "$status" -eq 0 ]
}

@test "custom agent state roots are removed" {
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
        bash -c \
        'cd "$1" && HOME="$2" SHELL=/bin/sh "$3" -- bash -lc '\''test -z "${CODEX_HOME+x}" && test -z "${CODEX_SQLITE_HOME+x}" && test -z "${CLAUDE_CONFIG_DIR+x}" && test -z "${ANTHROPIC_CONFIG_DIR+x}" && test -z "${COPILOT_HOME+x}" && test -z "${COPILOT_CACHE_HOME+x}" && test -z "${HERMES_HOME+x}" && test -z "${HERMES_MANAGED_DIR+x}" && test -z "${PI_CONFIG_DIR+x}" && test -z "${PI_CODING_AGENT_DIR+x}" && test -z "${PI_CODING_AGENT_SESSION_DIR+x}" && test -z "${PI_SERVER_DIR+x}" && test -z "${OPENCODE_CONFIG_DIR+x}"'\''' \
        _ "$TEST_PROJECT" "$TEST_HOME" "$AIBOX"
    [ "$status" -eq 0 ]
}

@test "aibox dump prompt is available inside sandbox" {
    run_aibox bash -lc 'prompt=$(aibox -p); [[ "$prompt" == *"https://github.com/ruifm/aibox"* ]] && [[ "$prompt" == *"minimal flake.nix devShell"* ]]'
    [ "$status" -eq 0 ]
}

@test "nix daemon works inside the sandbox when available" {
    command -v nix >/dev/null 2>&1 || skip "nix is not installed"
    nix store info >/dev/null 2>&1 || skip "nix daemon is not available"

    run_aibox nix store info
    [ "$status" -eq 0 ]
    [[ "$output" == *"Store URL: daemon"* ]]
}
