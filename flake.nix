{
  description = "Some flake-based project";

  inputs = {
    nixpkgs.url = "github:nixos/nixpkgs/nixos-22.11";
    flake-utils.url = "github:numtide/flake-utils";
    steam-fetcher = {
      url = "github:aidalgol/nix-steam-fetcher";
      inputs.nixpkgs.follows = "nixpkgs";
    };
  };

  outputs = {
    self,
    nixpkgs,
    flake-utils,
    steam-fetcher,
  }:
    with flake-utils.lib;
      eachSystem ["x86_64-linux"] (system: let
        pkgs = import nixpkgs {inherit system;};

        linters = with pkgs; [
          alejandra
          statix
        ];

        mkValheimServerPlusUnwrapped = pkgs.callPackage ./pkgs/builders/make-valheim-server-plus.nix {};
      in rec {
        lib = {
          mkValheimServerPlus = {valheimPlusConfig}:
            pkgs.callPackage ./pkgs/valheim-server/fhsenv-plus.nix {
              valheim-server-plus-unwrapped = mkValheimServerPlusUnwrapped {
                inherit (packages) valheim-server-unwrapped valheim-plus;
                valheimPlusConfig = pkgs.writeText "valheim-plus-config" valheimPlusConfig;
              };
              inherit (steam-fetcher.packages.${system}) steamworks-sdk-redist;
            };
        };

        packages = rec {
          default = valheim-server;

          valheim-server-unwrapped = pkgs.callPackage ./pkgs/valheim-server {
            inherit (steam-fetcher.lib.${system}) fetchSteam;
          };

          valheim-server = pkgs.callPackage ./pkgs/valheim-server/fhsenv.nix {
            inherit valheim-server-unwrapped;
            inherit (steam-fetcher.packages.${system}) steamworks-sdk-redist;
          };

          valheim-plus = pkgs.callPackage ./pkgs/valheim-plus {};
        };

        nixosModules = rec {
          valheim = ./nixos-modules/valheim.nix;
          default = valheim;
        };

        devShells = {
          default = pkgs.mkShell {
            packages = with pkgs;
              [
                nil # Nix LS
              ]
              ++ linters;
          };
        };

        checks = builtins.mapAttrs (name: pkgs.runCommandLocal name {nativeBuildInputs = linters;}) {
          alejandra = "alejandra --check ${./.} > $out";
          statix = "statix check ${./.} > $out";
        };

        formatter = pkgs.writeShellApplication {
          name = "fmt";
          runtimeInputs = linters;
          text = ''
            alejandra --quiet .
            statix fix .
          '';
        };
      });
}
