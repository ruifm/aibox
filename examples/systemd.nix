{
  aibox,
  workspace,
  command,
  hostname ? "project-agent",
  requiredConfig ? [ ],
}:
{ pkgs, lib, ... }:
{
  users.users.aibox = {
    isSystemUser = true;
    group = "aibox";
    home = "/var/lib/aibox";
  };
  users.groups.aibox = { };

  systemd.services.aibox = {
    description = "Aibox project command";
    wantedBy = [ "multi-user.target" ];
    wants = [ "network-online.target" ];
    after = [
      "network-online.target"
      "nix-daemon.socket"
    ];
    requires = [ "nix-daemon.socket" ];
    environment = {
      HOME = "/var/lib/aibox";
      SSL_CERT_FILE = "${pkgs.cacert}/etc/ssl/certs/ca-bundle.crt";
      NIX_SSL_CERT_FILE = "${pkgs.cacert}/etc/ssl/certs/ca-bundle.crt";
    };
    path = [
      pkgs.bash
      pkgs.coreutils
      pkgs.nix
      pkgs.direnv
    ];
    script = ''
      exec ${pkgs.coreutils}/bin/env -i \
        HOME="$HOME" PATH="$PATH" \
        SSL_CERT_FILE="$SSL_CERT_FILE" NIX_SSL_CERT_FILE="$NIX_SSL_CERT_FILE" \
        ${lib.escapeShellArgs (
          [
            "${aibox}/bin/aibox"
            "--hostname"
            hostname
          ]
          ++ lib.concatMap (path: [
            "--require-config"
            path
          ]) requiredConfig
          ++ [ "--" ]
          ++ command
        )}
    '';
    serviceConfig = {
      Type = "exec";
      User = "aibox";
      Group = "aibox";
      StateDirectory = "aibox";
      StateDirectoryMode = "0700";
      WorkingDirectory = workspace;
      ReadWritePaths = [ workspace ];
      UMask = "0077";
      ProtectSystem = "strict";
      ProtectHostname = "private";
      ProtectKernelLogs = false;
      ProtectKernelTunables = false;
      ProtectKernelModules = true;
      PrivateTmp = true;
      ProtectClock = true;
      ProtectControlGroups = true;
      ProtectProc = "invisible";
    };
  };
}
