{
  description = "NixOS module for the Valheim dedicated server";

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
      eachDefaultSystem (system: let
        pkgs = import nixpkgs {
          inherit system;
          overlays = [steam-fetcher.overlays.default];
        };

        linters = with pkgs; [
          alejandra
          statix
        ];
      in {
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
      })
      // {
        nixosModules = rec {
          valheim = import ./nixos-modules/valheim.nix {inherit self steam-fetcher;};
          default = valheim;
        };
        overlays.default = final: prev: {
          valheim-server-unwrapped = final.callPackage ./pkgs/valheim-server {};
          valheim-server = final.callPackage ./pkgs/valheim-server/fhsenv.nix {};
          valheim-bepinex-pack = final.callPackage ./pkgs/bepinex-pack {};
          fetchValheimThunderstoreMod = final.callPackage ./pkgs/build-support/fetch-thunderstore-mod {};
        };
      };
}
