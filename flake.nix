{
  description = "Nix flake for the official Claude Desktop Linux beta";

  inputs = {
    nixpkgs.url = "github:NixOS/nixpkgs/nixos-unstable";
  };

  outputs =
    { self, nixpkgs }:
    let
      lib = nixpkgs.lib;
      systems = [
        "x86_64-linux"
        "aarch64-linux"
      ];

      forAllSystems =
        f:
        lib.genAttrs systems (
          system:
          let
            pkgs = import nixpkgs {
              inherit system;
              config.allowUnfree = true;
            };
          in
          f system pkgs
        );
    in
    {
      packages = forAllSystems (
        _system: pkgs:
        rec {
          claude-desktop = pkgs.callPackage ./pkgs/claude-desktop { };
          default = claude-desktop;
        }
      );

      apps = forAllSystems (
        system: _pkgs:
        rec {
          claude-desktop = {
            type = "app";
            program = "${self.packages.${system}.claude-desktop}/bin/claude-desktop";
            meta.description = "Launch Claude Desktop";
          };
          default = claude-desktop;
        }
      );

      checks = forAllSystems (system: _pkgs: {
        claude-desktop = self.packages.${system}.claude-desktop;
      });

      overlays.default = final: prev: {
        claude-desktop = final.callPackage ./pkgs/claude-desktop { };
      };

      nixosModules.default = import ./modules/nixos;
      nixosModules.claude-desktop = self.nixosModules.default;
    };
}
