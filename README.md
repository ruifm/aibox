# aibox

[![CI](https://github.com/ruifm/aibox/actions/workflows/ci.yml/badge.svg)](https://github.com/ruifm/aibox/actions/workflows/ci.yml)
[![License: MIT](https://img.shields.io/badge/license-MIT-blue.svg)](LICENSE)
[![Bash](https://img.shields.io/badge/language-bash-green.svg)](aibox)

Run AI coding agents in a lightweight Bubblewrap sandbox, with project tooling
managed by `direnv` and Nix devShells.

`aibox` is the lightweight successor to
[`aidock`](https://github.com/ruifm/aidock): no container image, no image commits
on exit, no per-session agent binary drift, and no runtime configuration file.

```sh
aibox codex
aibox claude
aibox copilot
aibox opencode
aibox ori codex
aibox -- bash
```

Supported agent state/config policy is maintained for Codex, Claude Code,
GitHub Copilot CLI, and [OpenCode](https://opencode.ai/docs/). OpenRouter
support uses Ori. Other commands can be useful for debugging, but they are
best-effort and do not get dedicated persistent state/config mounts.

## Install

Nix is the recommended installation method:

```sh
nix profile install github:ruifm/aibox
```

Run without installing:

```sh
nix run github:ruifm/aibox -- codex
```

From a clone:

```sh
nix profile install .
```

Secondary direct-script install:

```sh
mkdir -p ~/.local/bin
curl -fsSL https://raw.githubusercontent.com/ruifm/aibox/main/aibox -o ~/.local/bin/aibox
chmod +x ~/.local/bin/aibox
```

After installing, run an end-to-end smoke check:

```sh
aibox -- true && echo "aibox smoke check passed"
```

This also creates the known persistent agent state paths when they are missing.

## Quick Start

Use `direnv` and a Nix devShell per project. The agent can edit `flake.nix`,
refresh the devShell, and install project-specific tools declaratively.

Example `.envrc`:

```sh
use flake
```

If the project has no `.envrc` and no Nix devShell yet, start by adding a
minimal `flake.nix` devShell plus the `.envrc` above, then run `direnv allow`.

Then launch the agent from the repository root:

```sh
cd my-project
aibox codex
```

`aibox` mounts the current directory, not its parent directories. If you start
it from a directory below the repository root, parent files such as `.git`,
`AGENTS.md`, `CLAUDE.md`, and agent settings are not visible.

## OpenRouter

Install [Ori](https://openrouter.ai/ori/harness) and the agent in a project
devShell or Nix profile. Sign in without trying to start a host browser from
the sandbox, then run the agent through Ori:

```sh
aibox ori login --no-browser
aibox ori codex
```

You can also set `OPENROUTER_API_KEY` before you start `aibox`. The sandbox
keeps inherited environment variables.

Ori keeps shared login and settings in `~/.ori`, which `aibox` mounts
read/write. Ori also writes logs and session transcripts to `.ori/` in the
project. Add `.ori/` to the project `.gitignore` because these files can contain
repository content and prompts.

## Agent Prompt

Before starting a session, paste the generated prompt into the agent. Inside an
active agent session, `aibox` is available on `PATH`, so you can also run
`!aibox -p` and ask the agent to follow it.

```sh
aibox -p
```

## Prerequisites

- Linux.
- Bash 4+.
- [Bubblewrap](https://github.com/containers/bubblewrap).
- Unprivileged user namespaces available to Bubblewrap.
- [Nix](https://nixos.org/) multi-user daemon. `nix store info` must work.
- [direnv](https://direnv.net/) and Nix devShells for the recommended workflow.

For an agent session, install the supported agent command you intend to run
(`codex`, `claude`, `copilot`, `opencode`, or `ori`) somewhere the sandbox can
see it: the project Nix devShell, a Nix profile, or the host system paths
mounted read-only at `/usr` and `/bin`. Ori also needs the target agent command.

## How It Works

`aibox` builds a Bubblewrap command that:

- binds the current directory read/write at the same absolute path;
- keeps host networking available;
- starts `$HOME` as a private tmpfs skeleton at the same absolute path;
- mounts selected real agent state/config directories back into that home;
- exposes `/nix/store` read-only;
- binds the Nix daemon socket so `nix develop`, `nix build`, and `direnv reload`
  can work;
- mounts `aibox` itself read-only at `/run/aibox/bin/aibox` and prepends that
  directory to `PATH`;
- leaves the inherited `PATH` visible, but does not discover or bind-mount
  arbitrary agent binaries from host-only paths such as `~/.local/bin` or
  `~/.opencode/bin`;
- remounts the synthetic root read-only after setup;
- prints the final `bwrap` command to stderr before execution.

`aibox` does not try to bind a single resolved agent executable into the
sandbox. Many agent commands are scripts or wrappers that need interpreters,
dynamic libraries, Node package trees, plugin files, or a Nix closure. Keeping
agent CLIs in a project devShell or Nix profile makes the executable and its
runtime closure available through the already-mounted Nix paths without adding
an arbitrary host-path mount interface.

Persistent agent state/config mounts:

- `~/.agents/skills`
- `~/.agents/plugins`
- `~/.codex`
- `~/.claude`
- `~/.claude.json`
- `~/.config/anthropic`
- `~/.copilot`
- `~/.cache/copilot`
- `~/.cache/opencode`
- `~/.config/opencode`
- `~/.local/share/opencode`
- `~/.local/state/opencode`
- `~/.ori`

These writable state paths are created on the host before launch when missing.
`~/.claude.json` is initialized as `{}`. If one of the expected directories is
a file, or `~/.claude.json` is not a file, `aibox` fails before starting the
sandbox.

`~/.agents/skills` is shared by Codex and Copilot CLI. Codex uses
`~/.agents/plugins` for personal plugin records. Claude Code can use Anthropic
CLI profiles and credentials from `~/.config/anthropic`. A selected Anthropic
API profile can use API billing instead of Claude subscription billing.
`~/.cache/copilot` is persistent to prevent repeated downloads.

OpenCode uses `~/.config/opencode` for user settings, instructions, agents,
commands, skills, and plugins. It uses `~/.local/share/opencode` for login,
MCP, session, and log data. It uses `~/.local/state/opencode` for state and
`~/.cache/opencode` for downloaded tools and plugin packages. Project
`.opencode` files are available through the project mount.

System agent config mounts are read-only and are added only when they exist:

- `/etc/codex`
- `/etc/claude-code`
- `/etc/github-copilot`
- `/etc/opencode`

`aibox` uses the default agent state paths. It removes `CODEX_HOME`,
`CODEX_SQLITE_HOME`, `CLAUDE_CONFIG_DIR`, `ANTHROPIC_CONFIG_DIR`,
`COPILOT_HOME`, `COPILOT_CACHE_HOME`, and `OPENCODE_CONFIG_DIR` inside the
sandbox. It does not use environment variables to add mounts. Profile
selectors such as `ANTHROPIC_PROFILE` still pass through.

`OPENCODE_CONFIG` and `OPENCODE_TUI_CONFIG` also pass through. The file must be
in the project or another path that the sandbox can read.

Other inherited agent variables also pass through. This includes API tokens,
model settings, provider settings, and profile selectors. A new variable does
not need a change in `aibox` unless it contains a file path that must be visible
inside the sandbox.

`aibox` intentionally does not mount GitHub CLI config, Git config, SSH agent,
GPG agent, D-Bus, Docker, Kubernetes config, browser profiles, or arbitrary
extra paths.

Linux keyrings that need D-Bus are not available. Use sign-in data in the
mounted agent state paths or use inherited token environment variables.

## Security Model

This is an accident-safety tool, not hostile-code containment.

The sandbox is intended to prevent routine agent/tool mistakes from writing
outside the project or reading broad host state. It still gives the agent full
network access, and it mounts real agent auth/session/config directories. Any
readable mounted data can be exfiltrated by code running in the sandbox.

`aibox` does not clear the ordinary process environment. API keys, cloud
credentials, package tokens, and other variables inherited by `aibox` are
visible to processes inside the sandbox. The printed `bwrap` command also
contains the command arguments you passed to `aibox`, so do not pass secrets as
CLI arguments.

Nix builds are performed by the host Nix daemon, outside Bubblewrap. Use host
Nix sandboxing if build isolation matters.

## Troubleshooting

### Ubuntu AppArmor User Namespaces

On Ubuntu 24.04+, AppArmor may restrict unprivileged user namespaces. If
`aibox -- true` fails with a Bubblewrap namespace permission error, add a
targeted profile for Bubblewrap instead of disabling the restriction globally:

```sh
cat <<'EOF' | sudo tee /etc/apparmor.d/local-aibox-bwrap >/dev/null
abi <abi/4.0>,
include <tunables/global>

profile local-aibox-bwrap /usr/bin/bwrap flags=(unconfined) {
  userns,

  include if exists <local/aibox-bwrap>
}

profile local-aibox-bwrap-nix /nix/store/*-bubblewrap-*/bin/bwrap flags=(unconfined) {
  userns,

  include if exists <local/aibox-bwrap-nix>
}
EOF

sudo apparmor_parser -r /etc/apparmor.d/local-aibox-bwrap
aibox -- true
```

If `bwrap` is installed somewhere else, add another profile stanza for the
absolute path printed by `readlink -f "$(command -v bwrap)"`.

## Contributing

Development setup and test commands live in [CONTRIBUTING.md](CONTRIBUTING.md).

## License

[MIT](LICENSE)
