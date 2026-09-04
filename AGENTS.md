# Agent Instructions

## Project Overview

`aibox` is a lightweight Bash launcher that runs AI coding agents inside a
Bubblewrap sandbox. It is the Nix/devShell-oriented successor to `aidock`: no
container image, no session image commits, and no runtime configuration file.

The public contract is intentionally small:

- bind the current project read/write at the same absolute path;
- keep host networking available;
- expose Nix store and the Nix daemon socket;
- mount only explicit agent state/config paths from `$HOME`;
- mount fixed system agent config directories read-only when present;
- do not mount Git/GitHub config, SSH agent, GPG agent, D-Bus, Docker, or
  Kubernetes state;
- print the final `bwrap` command to stderr before executing it.

## Development Rules

- Edit `aibox` directly; there is no generated launcher.
- Keep the runtime interface small. Do not add env-var configurability, config
  files, or arbitrary extra mount flags unless the project explicitly changes
  direction.
- Keep Bash formatted with `shfmt -i 4 -ci` and ShellCheck-clean.
- Use Nix as the primary development path: `nix develop -c just check`.
- Add tests for any mount-policy or CLI behavior change.

## Testing

- `just check` formats, lints, and runs unit tests.
- `just test-unit` uses a fake `bwrap` and should not need kernel namespace
  support.
- `just test-integration` uses real Bubblewrap and requires Linux user
  namespaces.

## Documentation

When behavior changes, update `README.md` in the same change. The README should
be explicit about prerequisites and the accident-safety threat model.
