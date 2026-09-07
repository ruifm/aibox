# aibox task runner

set shell := ["bash", "-euo", "pipefail", "-c"]

project := "aibox"
bash_files := "aibox tests/service-check.sh scripts/check-release.sh"
nix_files := "flake.nix tests/nixos.nix tests/tls.nix examples/systemd.nix"

fmt:
    shfmt -w -i 4 -ci {{bash_files}}
    nixfmt {{nix_files}}

lint:
    shellcheck {{bash_files}}
    shfmt -d -i 4 -ci {{bash_files}}
    nixfmt --check {{nix_files}}
    actionlint

test-unit:
    bats tests/unit.bats tests/release.bats

test-release:
    bats tests/release.bats

check-release tag:
    bash scripts/check-release.sh {{quote(tag)}} "$(nix eval --raw ".#packages.$(nix eval --impure --raw --expr builtins.currentSystem).default.version")"

test-integration:
    bats tests/integration.bats

test-nixos:
    nix build --no-link -L '.#checks.'$(nix eval --impure --raw --expr builtins.currentSystem)'.nixos'

check: fmt lint test-unit

install:
    mkdir -p "${HOME}/.local/bin"
    install -m 0755 {{project}} "${HOME}/.local/bin/{{project}}"
    @echo "Installed: ${HOME}/.local/bin/{{project}}"

clean-test-artifacts:
    rm -rf .test-work
