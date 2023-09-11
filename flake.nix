{
  description = "NixOS module for the Valheim dedicated server";

  inputs = {
    nixpkgs.url = "github:nixos/nixpkgs/nixos-23.05";
    steam-fetcher = {
      url = "github:nix-community/steam-fetcher";
      inputs.nixpkgs.follows = "nixpkgs";
    };
  };

  outputs = {
    self,
    nixpkgs,
    steam-fetcher,
  }: let
    # The Steam Nix fetcher only supports x86_64 Linux.
    supportedSystems = ["x86_64-linux"];
    forAllSystems = nixpkgs.lib.genAttrs supportedSystems;
    pkgsFor = system:
      import nixpkgs {
        inherit system;
        overlays = [steam-fetcher.overlays.default];
      };
    lintersFor = system: let
      pkgs = pkgsFor system;
    in
      with pkgs; [
        alejandra
        statix
      ];
  in {
    devShells = forAllSystems (system: let
      pkgs = pkgsFor system;
    in {
      default = pkgs.mkShell {
        packages = with pkgs;
          [
            nil # Nix LS
          ]
          ++ lintersFor system;
      };
    });

    checks = forAllSystems (system: let
      pkgs = pkgsFor system;
    in
      builtins.mapAttrs (name: pkgs.runCommandLocal name {nativeBuildInputs = lintersFor system;}) {
        alejandra = "alejandra --check ${./.} > $out";
        statix = "statix check ${./.} > $out";
      });

    formatter = forAllSystems (system: let
      pkgs = pkgsFor system;
    in
      pkgs.writeShellApplication {
        name = "fmt";
        runtimeInputs = lintersFor system;
        text = ''
          alejandra --quiet .
          statix fix .
        '';
      });

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
