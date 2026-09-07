#!/usr/bin/env bash
set -euo pipefail

die() {
    printf 'aibox release: %s\n' "$*" >&2
    exit 1
}

[[ $# == 2 ]] || die "usage: check-release.sh TAG PACKAGE_VERSION"
tag=$1
package_version=$2
[[ $tag =~ ^v(0|[1-9][0-9]*)\.(0|[1-9][0-9]*)\.(0|[1-9][0-9]*)$ ]] || die "invalid version tag"

cd "$(dirname "${BASH_SOURCE[0]}")/.."
[[ $(bash ./aibox --version) == "aibox ${tag#v}" ]] || die "tag does not match script version"
[[ $package_version == "${tag#v}" ]] || die "tag does not match package version"
[[ -f "docs/releases/$tag.md" && -s "docs/releases/$tag.md" ]] || die "missing or empty release notes"
