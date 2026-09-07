#!/usr/bin/env bats

setup() {
    export RELEASE_TEST_ROOT="$BATS_TEST_TMPDIR/release"
    mkdir -p "$RELEASE_TEST_ROOT/scripts" "$RELEASE_TEST_ROOT/docs/releases"
    cp "$BATS_TEST_DIRNAME/../aibox" "$RELEASE_TEST_ROOT/aibox"
    cp "$BATS_TEST_DIRNAME/../scripts/check-release.sh" "$RELEASE_TEST_ROOT/scripts/check-release.sh"
    RELEASE_TEST_VERSION=$(bash "$RELEASE_TEST_ROOT/aibox" --version)
    RELEASE_TEST_VERSION=${RELEASE_TEST_VERSION#aibox }
    printf 'Release notes\n' >"$RELEASE_TEST_ROOT/docs/releases/v$RELEASE_TEST_VERSION.md"
}

@test "release check accepts matching versions and notes" {
    run bash "$RELEASE_TEST_ROOT/scripts/check-release.sh" "v$RELEASE_TEST_VERSION" "$RELEASE_TEST_VERSION"
    [ "$status" -eq 0 ]
}

@test "release check rejects malformed tags and version mismatches" {
    local tag
    for tag in main v01.2.3 'v1.2.3;false' v1.2.3-rc1 v99.0.0; do
        run bash "$RELEASE_TEST_ROOT/scripts/check-release.sh" "$tag" "$RELEASE_TEST_VERSION"
        [ "$status" -ne 0 ]
    done
    run bash "$RELEASE_TEST_ROOT/scripts/check-release.sh" "v$RELEASE_TEST_VERSION" 99.0.0
    [ "$status" -ne 0 ]
    [[ "$output" == *"package version"* ]]
}

@test "release check requires nonempty release notes" {
    rm "$RELEASE_TEST_ROOT/docs/releases/v$RELEASE_TEST_VERSION.md"
    run bash "$RELEASE_TEST_ROOT/scripts/check-release.sh" "v$RELEASE_TEST_VERSION" "$RELEASE_TEST_VERSION"
    [ "$status" -ne 0 ]
    [[ "$output" == *"release notes"* ]]
    touch "$RELEASE_TEST_ROOT/docs/releases/v$RELEASE_TEST_VERSION.md"
    run bash "$RELEASE_TEST_ROOT/scripts/check-release.sh" "v$RELEASE_TEST_VERSION" "$RELEASE_TEST_VERSION"
    [ "$status" -ne 0 ]
}
