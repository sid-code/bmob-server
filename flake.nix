{
  description = "A very basic flake";

  inputs = {
    nixpkgs.url = "github:nixos/nixpkgs?ref=nixos-unstable";
  };

  outputs =
    { self, nixpkgs }:

    let
      supportedSystems = [ "x86_64-linux" ];
      forEachSystem =
        f:
        nixpkgs.lib.genAttrs supportedSystems (
          system:
          f {
            inherit system;
            pkgs = import nixpkgs { inherit system; };
          }
        );

    in
    {
      devShells = forEachSystem (
        { system, pkgs }:
        {
          default = pkgs.mkShell {
            buildInputs =
              let
                gems = self.packages.${system}.gems;
              in
              [
                gems
                gems.wrappedRuby
              ];
          };
        }
      );
      packages = forEachSystem (
        { system, pkgs }:
        rec {
          gems = pkgs.bundlerEnv {
            name = "gems-bmob-server";
            gemdir = ./.;
          };
        }
      );
    };
}
