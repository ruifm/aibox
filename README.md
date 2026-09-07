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
aibox hermes
aibox omp
aibox opencode
aibox pi
aibox ori codex
aibox -- bash
```

Supported agent state/config policy is maintained for Codex, Claude Code,
GitHub Copilot CLI, [Hermes](https://github.com/NousResearch/hermes-agent),
[OMP](https://github.com/can1357/oh-my-pi),
[OpenCode](https://opencode.ai/docs/), and
[Pi](https://github.com/earendil-works/pi). OpenRouter support uses Ori. Other
commands can be useful for debugging, but they are best-effort and do not get
dedicated persistent state/config mounts.

## Install

Nix is the recommended installation method:

```sh
nix profile install github:ruifm/aibox/v0.2.0
```

Run without installing:

```sh
nix run github:ruifm/aibox/v0.2.0 -- codex
```

From a clone:

```sh
nix profile install .
```

Secondary direct-script install:

```sh
mkdir -p ~/.local/bin
curl -fsSL https://raw.githubusercontent.com/ruifm/aibox/v0.2.0/aibox -o ~/.local/bin/aibox
chmod +x ~/.local/bin/aibox
```

After installing, run an end-to-end smoke check:

```sh
aibox -- true && echo "aibox smoke check passed"
```

This also creates the known persistent agent state paths when they are missing.

### Updates

Select a tested version from [GitHub Releases](https://github.com/ruifm/aibox/releases).
Each release includes compatibility notes for mounts, environment handling, and
command-line changes. Published version tags are not moved.

For a host or project flake, pin the selected tag:

```nix
inputs.aibox.url = "github:ruifm/aibox/v0.2.0";
```

Commit the flake lock with its exact revision and NAR hash. To update, change the
tag, run `nix flake update aibox`, and test the locked result before deployment.
Release automation can select a GitHub release and retain that same exact lock.
`main` remains the development branch. Sandbox startup does not check for or
install updates. See the [0.2.0 compatibility notes](docs/releases/v0.2.0.md).

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

## Display Name and Detection

Use `aibox --hostname project-agent -- codex` to set a display name. The default
is `aibox`. Names contain 1-64 ASCII letters, digits, dots, or hyphens, with a
letter or digit at each end. `--hostname=project-agent` also works.

Scripts can use `[ "${AIBOX:-}" = 1 ]` to select sandbox behavior. The marker is
set inside every sandbox, including when the hostname changes. It does not prove
isolation or grant authority. Replace hostname checks with this marker and
remove source patches for `--hostname aibox`. The option changes no mounts or
credential policy.

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
(`codex`, `claude`, `copilot`, `hermes`, `omp`, `opencode`, `pi`, or `ori`)
somewhere the sandbox can see it: the project Nix devShell, a Nix profile, or
the host system paths mounted read-only at `/usr` and `/bin`. Ori also needs the
target agent command.

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
- `~/.hermes`
- `~/.omp`
- `~/.pi`
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

Hermes keeps its config, credentials, sessions, memories, skills, plugins, and
managed tools in `~/.hermes`. OMP keeps its config and default state in
`~/.omp`. Pi keeps its config, credentials, sessions, packages, skills, and
extensions in `~/.pi`.

OMP can move data, state, and cache to `~/.local/share/omp`,
`~/.local/state/omp`, and `~/.cache/omp`. `aibox` mounts these paths when they
already exist. It does not create them because OMP uses their existence to
decide if XDG migration is complete. Run `omp config init-xdg` outside `aibox`
if you want to migrate an existing OMP profile.

System agent config mounts are read-only and are added only when they exist:

- `/etc/codex`
- `/etc/claude-code`
- `/etc/github-copilot`
- `/etc/hermes`
- `/etc/opencode`

On NixOS, the matching `/etc/static` subdirectories are also mounted read-only.
This includes the existing Nix and certificate directories. The complete host
`/etc/static` directory is not mounted. Links to arbitrary host targets are not
followed to add mounts. Nix store contents remain readable through `/nix/store`.

To require system policy files before a command starts:

```sh
aibox --require-config /etc/codex/managed_config.toml \
  --require-config=/etc/codex/requirements.toml -- codex
```

Each path must be an absolute file path below one of the five system agent
directories above, without `.` or `..` components. The check runs inside the
sandbox and stops startup if a file is missing or unreadable. The option does
not add mounts or check whether the agent obeys the policy. Without the option,
missing system configuration remains optional. NixOS packages can remove their
source patches for `/etc/static/codex`.

`aibox` uses the default agent state paths. It removes `CODEX_HOME`,
`CODEX_SQLITE_HOME`, `CLAUDE_CONFIG_DIR`, `ANTHROPIC_CONFIG_DIR`,
`COPILOT_HOME`, `COPILOT_CACHE_HOME`, `HERMES_HOME`, `HERMES_MANAGED_DIR`,
`PI_CONFIG_DIR`, `PI_CODING_AGENT_DIR`, `PI_CODING_AGENT_SESSION_DIR`,
`PI_SERVER_DIR`, and `OPENCODE_CONFIG_DIR` inside the sandbox. It does not use
environment variables to add mounts. Profile variables such as
`ANTHROPIC_PROFILE`, `HERMES_PROFILE`, and `OMP_PROFILE` still pass through.

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

## State Lifetime

| Paths | Access and lifetime |
| --- | --- |
| Workspace, including `.direnv` | Read/write; persists on the host |
| Agent state/config paths listed above | Read/write; persists on the host |
| `~/.local/share/direnv`, `~/.cache/direnv` | Read/write; persists on the host |
| Other files below `~/.cache`, `~/.config`, `~/.local` | Private temporary storage, except listed read-only mounts |
| `/tmp`, `/var/tmp`, `/run/aibox/runtime` | Private temporary storage; each new sandbox starts empty |
| Home skeleton outside writable mounts | Read-only; not the host home contents |
| Nix store, system configuration, Nix profiles, direnv configuration | Read-only host mounts |

`XDG_RUNTIME_DIR` is `/run/aibox/runtime`, a separate tmpfs mount owned by the
invoking user with mode 0700. The inherited runtime path is replaced. Concurrent
sandboxes do not share it. Use it for sockets and active GPG state that must not
survive a restart. Storage is released when the sandbox processes end.

`aibox` removes `SSH_AUTH_SOCK`, `GPG_AGENT_INFO`, `GNUPGHOME`,
`DBUS_SESSION_BUS_ADDRESS`, `DOCKER_HOST`, and `KUBECONFIG`, plus the agent path
variables listed above. It replaces `HOME`, the XDG base directories, and
`TMPDIR`, and selects `NIX_REMOTE=daemon` when the daemon socket exists.
Other variables remain visible, including credentials. No host SSH or GPG agent
is forwarded automatically.

Persistent agent directories can contain credentials, live databases, locks,
and sockets. Do not synchronize complete live state directories without checking
the application's backup requirements. Exclude sockets, locks, temporary runtime
files, and credential bundles from ordinary source synchronization.

### Explicit Credentials

Use a dedicated credential bundle inside the workspace when a command needs it.
Create it outside the sandbox, restrict its directory to mode 0700 and private
files to mode 0600, and exclude it from Git and synchronization. Do not put secret
keys in Nix expressions or the Nix store.

For SSH, select the dedicated key and known-hosts file explicitly:

```sh
aibox -- ssh -F /dev/null -o IdentitiesOnly=yes -o StrictHostKeyChecking=yes \
  -o UserKnownHostsFile="$PWD/.credentials/known_hosts" \
  -i "$PWD/.credentials/id_ed25519" operator@server.example
```

For GPG and a dedicated password store, set paths after sandbox entry:

```sh
aibox -- bash -c '
  export GNUPGHOME="$XDG_RUNTIME_DIR/gnupg"
  export PASSWORD_STORE_DIR="$PWD/.credentials/password-store"
  install -d -m 0700 "$GNUPGHOME"
  gpg --batch --import "$PWD/.credentials/gpg-secret.asc" || exit
  exec pass show service/account
'
```

Install these commands in the project devShell. An authorized self-SSH key can
permit commands on the host through the shared network, outside the filesystem
boundary. Credential access is an explicit operator choice, not an ordinary
account default.

## Systemd Services

[The NixOS service example](examples/systemd.nix) runs a project command as the
dedicated `aibox` account. The VM test imports this same example. For a NixOS
flake with an `aibox` input, include it in the host configuration:

```nix
imports = [
  (import "${inputs.aibox}/examples/systemd.nix" {
    aibox = inputs.aibox.packages.${pkgs.stdenv.hostPlatform.system}.default;
    workspace = "/srv/project";
    command = [ "${pkgs.nix}/bin/nix" "develop" "--command" "project-task" ];
    hostname = "project-agent";
    requiredConfig = [
      "/etc/codex/managed_config.toml"
      "/etc/codex/requirements.toml"
    ];
  })
];
```

Provision the checkout and its devShell outside the sandbox. The `aibox` account
must own the workspace. Enable Nix flakes for this command, and provision the
required policy files through `environment.etc`. Omit `requiredConfig` for a
command that does not need these files. Start or inspect the service with
`systemctl start aibox` and `journalctl -u aibox`, outside the sandbox.

The service supplies explicit command paths and a clean environment, including
both certificate variables. Persistent agent state lives in `/var/lib/aibox`,
with mode 0700. `ProtectSystem=strict` restricts persistent filesystem writes,
with writable exceptions for the workspace and the systemd state directory.
`PrivateTmp` supplies separate temporary directories. Bubblewrap limits access within those
paths to its normal mount policy. The complete host state directory is not bound
into the sandbox.

The tested service uses `ProtectHostname=private`, `ProtectKernelLogs=no`, and
`ProtectKernelTunables=no`. It retains `ProtectKernelModules=yes`,
`PrivateTmp=yes`, `ProtectClock=yes`, `ProtectControlGroups=yes`, and
`ProtectProc=invisible`. These settings were tested together with the locked
nixpkgs. The service manages process lifetime; aibox does not manage sessions.

## Troubleshooting

### Service Restrictions

Bubblewrap prints its original startup error. Check the unit's journal and
restrictions before changing host-wide settings:

| Error | Check |
| --- | --- |
| `Can't set hostname` | `ProtectHostname=yes` prohibits the syscall; the example uses `private` |
| `Can't mount proc` | `ProtectKernelLogs` and `ProtectKernelTunables` each caused this failure in the VM test |
| `No permissions to create a new namespace` | Check `RestrictNamespaces`, syscall filters, and host user-namespace restrictions |
| Mount permission error | A filter such as `SystemCallFilter=~@mount` prevents Bubblewrap setup |
| Writable state creation fails | Check ownership, `StateDirectory`, `ReadWritePaths`, and any `ProtectHome` setting |

The same `EPERM` can have several causes. These messages do not identify one
specific unit setting on every host. A syscall filter can also terminate the
process with `SIGSYS` before Bubblewrap can print an error. Do not remove the
whole service restriction set to repair a single conflict. See the
[systemd execution reference](https://www.freedesktop.org/software/systemd/man/latest/systemd.exec.html)
for the scope of each setting.

### Certificate Bundles

`aibox` preserves `SSL_CERT_FILE` and `NIX_SSL_CERT_FILE`. When either is set,
it must name a readable regular file inside the sandbox. An empty value is an
error. Relative paths refer to the workspace. The variables can name different
files. Unset variables leave the client's default certificate selection intact.

For NixOS or a service with a minimal environment, set both variables to the
Nix store bundle:

```nix
SSL_CERT_FILE = "${pkgs.cacert}/etc/ssl/certs/ca-bundle.crt";
NIX_SSL_CERT_FILE = "${pkgs.cacert}/etc/ssl/certs/ca-bundle.crt";
```

The check runs before the command starts and names an invalid variable without
printing its value. It adds no mounts and does not parse certificates or prove
that a TLS connection will succeed. TLS verification remains the client's job.
Other client-specific certificate variables are inherited without this check.

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
