{ pkgs, aibox }:
let
  certificates = import ./tls.nix { inherit pkgs; };
  serviceCheck = pkgs.writeShellApplication {
    name = "aibox-service-check";
    runtimeInputs = [
      pkgs.coreutils
      pkgs.gnugrep
      pkgs.curl
      pkgs.nix
    ];
    text = builtins.readFile ./service-check.sh;
  };
in
pkgs.testers.runNixOSTest {
  name = "aibox";
  nodes.machine = { config, lib, ... }: {
    imports = [
      (import ../examples/systemd.nix {
        inherit aibox;
        workspace = "/srv/service-project";
        command = [ "${serviceCheck}/bin/aibox-service-check" ];
        requiredConfig = [
          "/etc/codex/managed_config.toml"
          "/etc/codex/requirements.toml"
        ];
      })
    ];
    users.users.agent = {
      isNormalUser = true;
      group = "agent";
    };
    users.groups.agent = { };
    nix.settings.experimental-features = [
      "nix-command"
      "flakes"
    ];
    systemd.tmpfiles.rules = [
      "d /srv/project 0700 agent agent -"
      "d /srv/service-project 0700 aibox aibox -"
      "f /srv/outside 0644 root root - outside"
      "f /var/lib/host-file 0644 root root - outside"
    ];
    systemd.services = {
      aibox = {
        wantedBy = lib.mkForce [ ];
        environment = {
          SSL_CERT_FILE = lib.mkForce "${certificates}/ca.pem";
          NIX_SSL_CERT_FILE = lib.mkForce "${certificates}/ca.pem";
          AIBOX_HOST_SECRET = "must-not-pass";
        };
      };
      tls.serviceConfig = {
        ExecStart = "${pkgs.openssl}/bin/openssl s_server -accept 8443 -cert ${certificates}/server.pem -key ${certificates}/server.key -www";
        DynamicUser = true;
      };
      invalid-certificate = {
        inherit (config.systemd.services.aibox) script path;
        environment = builtins.removeAttrs config.systemd.services.aibox.environment [ "PATH" ] // {
          SSL_CERT_FILE = "/host-inaccessible-ca";
        };
        serviceConfig = builtins.removeAttrs config.systemd.services.aibox.serviceConfig [ "ExecStart" ];
      };
    }
    //
      lib.mapAttrs
        (name: restriction: {
          inherit (config.systemd.services.aibox) script path;
          environment = builtins.removeAttrs config.systemd.services.aibox.environment [ "PATH" ];
          serviceConfig =
            builtins.removeAttrs config.systemd.services.aibox.serviceConfig [ "ExecStart" ] // restriction;
        })
        {
          blocked-hostname.ProtectHostname = true;
          blocked-logs.ProtectKernelLogs = true;
          blocked-tunables.ProtectKernelTunables = true;
          blocked-namespaces.RestrictNamespaces = true;
          blocked-mounts = {
            SystemCallFilter = [ "~@mount" ];
            SystemCallErrorNumber = "EPERM";
          };
        };
    environment.systemPackages = [
      aibox
      pkgs.bash
      pkgs.util-linux
    ];
    environment.etc = {
      "codex/managed_config.toml".text = "managed = true\n";
      "codex/requirements.toml".text = "required = true\n";
      "codex/writable.toml" = {
        text = "original\n";
        mode = "0600";
        user = "agent";
        group = "agent";
      };
      "unrelated-host-config".text = "unrelated\n";
      "codex/unreadable.toml" = {
        text = "private";
        mode = "0000";
      };
    };
  };
  testScript = ''
    import shlex

    start_all()
    machine.wait_for_unit("multi-user.target")

    def box(script, *options):
        command = ["env", "PATH=${
          pkgs.lib.makeBinPath [
            pkgs.bash
            pkgs.coreutils
            pkgs.gnugrep
            pkgs.util-linux
            pkgs.curl
          ]
        }",
                   "${aibox}/bin/aibox", *options, "--", "bash", "-c", script]
        return "runuser -u agent -- bash -c " + shlex.quote("cd /srv/project && " + shlex.join(command))

    required = ["--require-config", "/etc/codex/managed_config.toml",
                "--require-config=/etc/codex/requirements.toml"]
    machine.succeed("test $(readlink /etc/codex/requirements.toml) = /etc/static/codex/requirements.toml")
    machine.succeed(box("grep -q 'required = true' /etc/codex/requirements.toml", *required))
    machine.succeed(box("test ! -e /etc/unrelated-host-config && test ! -e /etc/static/unrelated-host-config"))
    machine.succeed(box("! echo changed > /etc/codex/writable.toml"))
    machine.succeed("grep -qx original /etc/codex/writable.toml")
    machine.succeed(box("findmnt -n -o VFS-OPTIONS -M /etc/static/codex | grep -qw ro"))
    machine.succeed("mkdir /etc/codex/directory")
    for path in ["/etc/codex/missing.toml", "/etc/codex/directory", "/etc/codex/broken.toml", "/etc/codex/unreadable.toml"]:
        machine.succeed("ln -sfn /outside-missing /etc/codex/broken.toml")
        status, output = machine.execute(box("touch command-started", "--require-config=" + path) + " 2>&1")
        assert status != 0, output
        assert "aibox: required config is not a readable regular file: " + path in output, output
        machine.fail("test -e /srv/project/command-started")

    machine.succeed("systemctl start tls.service")
    machine.wait_for_open_port(8443, timeout=30)
    machine.succeed(box("SSL_CERT_FILE=${certificates}/ca.pem curl --fail --silent --show-error https://localhost:8443/ > response"))
    machine.fail(box("SSL_CERT_FILE=${certificates}/untrusted.pem curl --fail --silent --show-error https://localhost:8443/"))
    machine.succeed("mkdir -p /var/lib/aibox/.ssh /var/lib/aibox/.gnupg /var/lib/aibox/.password-store")
    machine.succeed("touch /var/lib/aibox/.ssh/key /var/lib/aibox/.gnupg/key /var/lib/aibox/.password-store/key")
    machine.succeed("systemctl start aibox.service")
    machine.wait_until_succeeds("test -e /srv/service-project/service-ready", timeout=30)
    machine.succeed(box("test ! -e /run/aibox/runtime/account-secret"))
    pid = machine.succeed("pgrep -u aibox -x sleep").strip()
    machine.fail("runuser -u agent -- cat /proc/" + pid + "/root/run/aibox/runtime/account-secret")
    machine.succeed("systemctl stop aibox.service")
    machine.succeed("grep -qx persistent /var/lib/aibox/.codex/service-state")
    machine.succeed("rm /srv/service-project/service-ready")
    machine.succeed("systemctl start aibox.service")
    machine.wait_until_succeeds("test -e /srv/service-project/service-ready", timeout=30)
    machine.succeed("systemctl stop aibox.service")
    machine.succeed("rm /srv/service-project/service-ready")

    for unit, diagnostic in [
        ("blocked-hostname", "Can't set hostname"),
        ("blocked-logs", "Can't mount proc"),
        ("blocked-tunables", "Can't mount proc"),
        ("blocked-namespaces", "No permissions to create a new namespace"),
        ("blocked-mounts", "bwrap:"),
        ("invalid-certificate", "SSL_CERT_FILE is not a readable certificate file inside the sandbox"),
    ]:
        machine.execute("systemctl start " + unit + ".service")
        machine.wait_until_succeeds("test $(systemctl show -p ActiveState --value " + unit + ".service) = failed", timeout=30)
        journal = machine.succeed("journalctl -u " + unit + ".service --no-pager -o cat")
        assert diagnostic in journal, journal
        machine.fail("test -e /srv/service-project/service-ready")
  '';
}
