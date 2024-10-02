{
  description = "A simple ruby app demo";

  nixConfig = {
    extra-substituters = "https://nixpkgs-ruby.cachix.org";
    extra-trusted-public-keys = "nixpkgs-ruby.cachix.org-1:vrcdi50fTolOxWCZZkw0jakOnUI1T19oYJ+PRYdK4SM=";
  };

  inputs = {
    nixpkgs.url = "nixpkgs";
    ruby-nix = {
      url = "github:inscapist/ruby-nix";
      inputs.nixpkgs.follows = "nixpkgs";
    };
    # a fork that supports platform dependant gem
    bundix = {
      url = "github:inscapist/bundix/main";
      inputs.nixpkgs.follows = "nixpkgs";
    };
    bob-ruby = {
      url = "github:bobvanderlinden/nixpkgs-ruby";
      inputs.nixpkgs.follows = "nixpkgs";
    };
  };

  outputs =
    {
      self,
      nixpkgs,
      ruby-nix,
      bundix,
      bob-ruby,
    }:
    let
      supportedSystems = [ "x86_64-linux" ];
      forEachSystem =
        f:
        nixpkgs.lib.genAttrs supportedSystems (
          system:
          f rec {
            pkgs = import nixpkgs {
              inherit system;
              overlays = [ bob-ruby.overlays.default ];
            };
            # See available versions here: https://github.com/bobvanderlinden/nixpkgs-ruby/blob/master/ruby/versions.json
            ruby = pkgs."ruby-3.3.1";
            rubyNix = ruby-nix.lib pkgs;
            rubyEnv =
              (rubyNix {
                inherit gemset ruby;
                name = "bmob_server";
                gemConfig = pkgs.defaultGemConfig // gemConfig;
              }).env;
            inherit system;
          }
        );

      # TODO generate gemset.nix with bundix
      gemset = if builtins.pathExists ./gemset.nix then import ./gemset.nix else { };

      # If you want to override gem build config, see
      #   https://github.com/NixOS/nixpkgs/blob/master/pkgs/development/ruby-modules/gem-config/default.nix
      gemConfig = { };
    in
    rec {

      packages = forEachSystem (
        {
          pkgs,
          ruby,
          rubyEnv,
          ...
        }:
        rec {
          default = bmob-server;
          bmob-server = pkgs.callPackage ./. {
            inherit ruby;
            rubyEnv = rubyEnv;
          };
        }
      );

      nixosModules = rec {
        default = bmob-server;
        bmob-server = import ./nixos-module.nix packages.bmob-server;
      };

      devShells = forEachSystem (
        {
          pkgs,
          system,
          rubyEnv,
          ...
        }:
        rec {
          default = dev;
          dev = pkgs.mkShell {
            buildInputs =
              let
                # Run `bundix` to generate `gemset.nix`
                bundixcli = bundix.packages.${system}.default;

                # Use these instead of the original `bundle <mutate>` commands
                bundleLock = pkgs.writeShellScriptBin "bundle-lock" ''
                  export BUNDLE_PATH=vendor/bundle
                  bundle lock
                '';
                bundleUpdate = pkgs.writeShellScriptBin "bundle-update" ''
                  export BUNDLE_PATH=vendor/bundle
                  bundle lock --update
                '';
              in
              [
                rubyEnv
                bundixcli
                bundleLock
                bundleUpdate
              ]
              ++ (with pkgs; [
                yarn
                rufo
                # more packages here
              ]);
          };
        }
      );
    };
}
