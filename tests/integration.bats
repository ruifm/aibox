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
        bash -c \
        'cd "$1" && HOME="$2" SHELL=/bin/sh "$3" -- bash -lc '\''test "$OPENAI_API_KEY" = openai-key && test "$ANTHROPIC_API_KEY" = anthropic-key && test "$ANTHROPIC_PROFILE" = work && test "$COPILOT_GITHUB_TOKEN" = copilot-token'\''' \
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
        bash -c \
        'cd "$1" && HOME="$2" SHELL=/bin/sh "$3" -- bash -lc '\''test -z "${CODEX_HOME+x}" && test -z "${CODEX_SQLITE_HOME+x}" && test -z "${CLAUDE_CONFIG_DIR+x}" && test -z "${ANTHROPIC_CONFIG_DIR+x}" && test -z "${COPILOT_HOME+x}" && test -z "${COPILOT_CACHE_HOME+x}"'\''' \
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
