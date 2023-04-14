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
      eachDefaultSystem (system: let
        pkgs = import nixpkgs {inherit system;};

        linters = with pkgs; [
          alejandra
          statix
        ];
      in {
        packages = rec {
          valheimServer = pkgs.callPackage ./pkgs/valheim {
            inherit (steam-fetcher.lib.${system}) fetchSteam;
            inherit (steam-fetcher.packages.${system}) steamworksSdkRedist;
          };
          valheimPlus = pkgs.callPackage ./pkgs/valheim-plus {};
          valheimServerPlus = pkgs.callPackage ./pkgs/valheim {
            inherit (steam-fetcher.lib.${system}) fetchSteam;
            inherit (steam-fetcher.packages.${system}) steamworksSdkRedist;
            inherit valheimPlus;
          };
          default = valheimServer;
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
