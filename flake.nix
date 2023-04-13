{
  description = "Some flake-based project";

  inputs = {
    nixpkgs.url = "github:nixos/nixpkgs/nixos-22.11";
    flake-utils.url = "github:numtide/flake-utils";
    steam-fetcher.url = "github:aidalgol/nix-steam-fetcher";
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

        # Generate a user-friendly version number.
        version = builtins.substring 0 8 self.lastModifiedDate;

        linters = with pkgs; [
          alejandra
          statix
        ];
      in {
        packages = with pkgs; with steam-fetcher.lib.${system}; rec {
          valheimServer = stdenvNoCC.mkDerivation rec {
            name = "valheim-server";
            version = "0.215.2";
            src = fetchSteam {
              inherit name;
              appId = "896660";
              depotId = "896661";
              manifestId = "1096250207355556362";
              hash = "sha256-oOHBv//sgpvowiXmongc49t6hjZt1vRQKl+or20oi+o=";
            };

            # Skip phases that don't apply to prebuilt binaries.
            dontBuild = true;
            dontConfigure = true;

            installPhase = ''
              runHook preInstall

              mkdir $out
              cp -r \
                $src/*.so \
                $src/*.debug \
                $src/valheim_server.x86_64 \
                $src/valheim_server_Data \
                $out

              runHook postInstall
            '';
          };

          default = valheimServer;
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
