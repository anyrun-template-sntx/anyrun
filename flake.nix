{
  description = "A wayland native, highly customizable runner.";

  inputs = {
    nixpkgs.url = "github:NixOS/nixpkgs/nixpkgs-unstable";

    crane = {
      url = "github:ipetkov/crane";
      inputs.nixpkgs.follows = "nixpkgs";
    };

    flake-utils.url = "github:numtide/flake-utils";

    advisory-db = {
      url = "github:rustsec/advisory-db";
      flake = false;
    };
  };

  outputs = { self, nixpkgs, crane, flake-utils, advisory-db, ... }:
    flake-utils.lib.eachDefaultSystem (system:
      let
        pkgs = import nixpkgs {
          inherit system;
        };

        inherit (pkgs) lib;

        craneLib = crane.lib.${system};
        src = lib.cleanSourceWith {
          src = ./.;
          filter = path: type:
            # (lib.hasSuffix "\.css" path) ||
            (lib.hasInfix "/rsc/" path) ||
            (craneLib.filterCargoSources path type)
          ;
        };

        commonArgs = {
          inherit src;
          buildInputs = with pkgs; [
            pkg-config
            glib
            atk
            gtk3
            librsvg
            gtk-layer-shell
          ] ++ lib.optionals pkgs.stdenv.isDarwin [ ];
        };

        cargoArtifacts = craneLib.buildDepsOnly commonArgs;

        anyrun = craneLib.buildPackage (commonArgs // {
          inherit cargoArtifacts;
        });
      in
      {
        checks = {
          inherit anyrun;

          anyrun-clippy = craneLib.cargoClippy (commonArgs // {
            inherit cargoArtifacts;
            cargoClippyExtraArgs = "--all-targets -- --deny warnings";
          });

          anyrun-doc = craneLib.cargoDoc (commonArgs // {
            inherit cargoArtifacts;
          });

          anyrun-fmt = craneLib.cargoFmt {
            inherit src;
          };

          anyrun-audit = craneLib.cargoAudit {
            inherit src advisory-db;
          };
        };

        packages.default = anyrun;

        apps.default = flake-utils.lib.mkApp {
          name = "anyrun";
          drv = anyrun;
        };

        homeManagerModules = {
          anyrun = import ./hm-module.nix self;
          default = anyrun;
        };

        devShells.default = pkgs.mkShell {
          inputsFrom = builtins.attrValues self.checks.${system};

          nativeBuildInputs = with pkgs; [
            alejandra # nix formatter
            rustfmt # rust formatter
            statix # lints and suggestions
            deadnix # clean up unused nix code
            rustc # rust compiler
            gcc # GNU Compiler Collection
            cargo # rust package manager
            clippy # opinionated rust formatter

            rust-analyzer # rust analyzer
            lldb # software debugger
          ];
        };
      });
}
