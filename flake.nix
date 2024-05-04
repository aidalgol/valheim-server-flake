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
        overlays = [
          steam-fetcher.overlays.default
          self.overlays.default
        ];
      };
    lintersFor = system: let
      pkgs = pkgsFor system;
    in
      with pkgs; [
        alejandra
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
    in {
      fmt = pkgs.runCommandLocal "alejandra" {} ''
        ${pkgs.alejandra}/bin/alejandra --check ${./.} > "$out"
      '';
    });

    formatter = forAllSystems (system: (pkgsFor system).alejandra);

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
    packages = forAllSystems (system: let
      pkgs = pkgsFor system;
    in {
      valheim-server = pkgs.valheim-server;
    });
  };
}
