#!/usr/bin/env bash
set -euo pipefail

[[ "$AIBOX" == 1 ]]
[[ $(cat /proc/sys/kernel/hostname) == project-agent ]]
[[ "$PWD" == /srv/service-project ]]
[[ "$SSL_CERT_FILE" == "$NIX_SSL_CERT_FILE" ]]
grep -q -- '-----BEGIN CERTIFICATE-----' "$SSL_CERT_FILE"
[[ $(stat -c %a "$XDG_RUNTIME_DIR") == 700 ]]
[[ $(stat -c %u "$XDG_RUNTIME_DIR") == "$(id -u)" ]]
[[ $(stat -f -c %T "$XDG_RUNTIME_DIR") == tmpfs ]]
[[ ! -e "$XDG_RUNTIME_DIR/previous-session" ]]
[[ ! -e "$HOME/.ssh" && ! -e "$HOME/.gnupg" && ! -e "$HOME/.password-store" ]]
[[ ! -e /etc/unrelated-host-config && ! -e /etc/static/unrelated-host-config ]]
[[ ! -e /srv/outside && ! -e /var/lib/host-file ]]
[[ ! ${SSH_AUTH_SOCK+x} && ! ${GPG_AGENT_INFO+x} && ! ${GNUPGHOME+x} ]]
[[ ! ${DBUS_SESSION_BUS_ADDRESS+x} && ! ${DOCKER_HOST+x} && ! ${KUBECONFIG+x} ]]
[[ ! ${AIBOX_HOST_SECRET+x} ]]
if touch /etc/aibox-write-denied 2>/dev/null; then exit 1; fi
if touch /srv/outside 2>/dev/null; then exit 1; fi
grep -q 'required = true' /etc/codex/requirements.toml
nix store info 2>&1 | grep 'Store URL: daemon' >/dev/null
curl --fail --silent --show-error https://localhost:8443/ >response
grep -q 's_server' response
touch "$XDG_RUNTIME_DIR/previous-session"
printf 'private\n' >"$XDG_RUNTIME_DIR/account-secret"
printf 'persistent\n' >"$HOME/.codex/service-state"
touch service-ready
exec sleep infinity
