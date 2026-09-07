# Contributing to aibox

## Setup

The recommended development environment is Nix:

```sh
nix develop
just check
```

Host prerequisites for development without `nix develop`:

- Bash 4+
- Bubblewrap
- ShellCheck
- shfmt
- Bats
- just
- Nix with the daemon running

## Workflow

The launcher is the `aibox` file at the repository root. There is no build step
for the script itself.

```sh
just fmt
just lint
just test-unit
just test-integration
just test-nixos
just check
```

`just check` is the default CI gate. Run it before opening a pull request.

`just test-nixos` and `nix flake check` also run a NixOS VM. The Nix builder must
have access to `/dev/kvm` and advertise the `kvm` and `nixos-test` system features.
The VM uses the repository's locked nixpkgs. No host `/etc` changes are needed.

## Code Style

- Bash uses 4-space indentation and case indentation: `shfmt -i 4 -ci`.
- Keep ShellCheck clean.
- Prefer explicit allowlists over runtime configurability.
- Keep mount policy changes small and covered by tests.

## Commits

Use conventional commit prefixes:

- `feat:` new feature
- `fix:` bug fix
- `docs:` documentation only
- `test:` tests only
- `refactor:` behavior-preserving code change
- `chore:` tooling, packaging, CI
