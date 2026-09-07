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
- nixfmt
- actionlint
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

The VM runs the packaged launcher through the service example, including
NixOS policy links, two accounts, restart behavior, and TLS. Certificate keys
in the test fixture are test data. The TLS tests need no external endpoint.

## Releases

Set the same version in the launcher and Nix package, and add
`docs/releases/vX.Y.Z.md`. Describe mount, environment, and CLI compatibility
changes with the required migration steps. Run:

```sh
nix develop -c just check check-release v0.2.0
nix develop -c just test-integration
nix flake check -L
```

The maintainer creates and pushes the corresponding `vX.Y.Z` tag after review.
CI tests the tagged commit, checks its versions and release notes, then publishes
the GitHub release. Publication uses the existing tag and its checked-in notes.
It does not replace existing releases. Do not move published version tags.

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
