{ pkgs, aibox }:
pkgs.testers.runNixOSTest {
  name = "aibox";
  nodes.machine = { ... }: {
    users.users.agent = { isNormalUser = true; group = "agent"; };
    users.groups.agent = { };
    systemd.tmpfiles.rules = [ "d /srv/project 0700 agent agent -" ];
    environment.systemPackages = [ aibox pkgs.bash pkgs.util-linux ];
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
    };
  };
  testScript = ''
    import shlex

    start_all()
    machine.wait_for_unit("multi-user.target")

    def box(script, *options):
        command = ["env", "PATH=${pkgs.lib.makeBinPath [ pkgs.bash pkgs.coreutils pkgs.gnugrep pkgs.util-linux ]}",
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
    for path in ["/etc/codex/missing.toml", "/etc/codex", "/etc/codex/broken.toml"]:
        machine.succeed("ln -sfn /outside-missing /etc/codex/broken.toml")
        status, output = machine.execute(box("touch command-started", "--require-config=" + path) + " 2>&1")
        assert status != 0, output
        assert "config" in output, output
        machine.fail("test -e /srv/project/command-started")
  '';
}
