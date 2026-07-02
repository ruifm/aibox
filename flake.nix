{
  description = "Run AI coding agents in a lightweight Bubblewrap sandbox";

  inputs = {
    nixpkgs.url = "github:NixOS/nixpkgs/nixos-unstable";
  };

  outputs =
    { self, nixpkgs }:
    let
      systems = [
        "x86_64-linux"
        "aarch64-linux"
      ];
      forAllSystems = nixpkgs.lib.genAttrs systems;
    in
    {
      packages = forAllSystems (
        system:
        let
          pkgs = nixpkgs.legacyPackages.${system};
        in
        {
          default = pkgs.stdenvNoCC.mkDerivation {
            pname = "aibox";
            version = "0.1.0";
            src = ./.;

            nativeBuildInputs = [ pkgs.makeWrapper ];

            installPhase = ''
              runHook preInstall
              install -Dm755 aibox "$out/bin/aibox"
              patchShebangs "$out/bin/aibox"
              wrapProgram "$out/bin/aibox" \
                --prefix PATH : ${
                  pkgs.lib.makeBinPath [
                    pkgs.bubblewrap
                    pkgs.coreutils
                  ]
                }
              runHook postInstall
            '';

            meta = {
              description = "Run AI coding agents in a lightweight Bubblewrap sandbox";
              homepage = "https://github.com/ruifm/aibox";
              license = pkgs.lib.licenses.mit;
              mainProgram = "aibox";
              platforms = pkgs.lib.platforms.linux;
            };
          };
        }
      );

      apps = forAllSystems (system: {
        default = {
          type = "app";
          program = "${self.packages.${system}.default}/bin/aibox";
          meta.description = "Run AI coding agents in a lightweight Bubblewrap sandbox";
        };
      });

      devShells = forAllSystems (
        system:
        let
          pkgs = nixpkgs.legacyPackages.${system};
        in
        {
          default = pkgs.mkShell {
            packages = [
              pkgs.bash
              pkgs.bats
              pkgs.bubblewrap
              pkgs.coreutils
              pkgs.git
              pkgs.just
              pkgs.nix
              pkgs.shellcheck
              pkgs.shfmt
            ];
          };
        }
      );

      checks = forAllSystems (
        system:
        let
          pkgs = nixpkgs.legacyPackages.${system};
          src = pkgs.lib.cleanSource ./.;
        in
        {
          package = self.packages.${system}.default;

          shellcheck = pkgs.runCommand "aibox-shellcheck" { nativeBuildInputs = [ pkgs.shellcheck ]; } ''
            shellcheck ${./aibox}
            touch "$out"
          '';

          shfmt = pkgs.runCommand "aibox-shfmt" { nativeBuildInputs = [ pkgs.shfmt ]; } ''
            shfmt -d -i 4 -ci ${./aibox}
            touch "$out"
          '';

          unit = pkgs.runCommand "aibox-unit-tests" {
            nativeBuildInputs = [
              pkgs.bash
              pkgs.bats
              pkgs.coreutils
            ];
          } ''
            cp -R ${src} source
            cd source
            bats tests/unit.bats
            touch "$out"
          '';
        }
      );
    };
}
