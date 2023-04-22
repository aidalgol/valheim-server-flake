# Valheim Server Flake
A Nix flake for the Valheim dedicated server, providing both an overlay and a NixOS module.

## Usage
(Your NixOS system configuration must already be a flake.)

Add this flake as an input, and add the NixOS module.  Your config should look something like this.
```nix
{
  inputs = {
    nixpkgs.url = "github:NixOS/nixpkgs/nixos-22.11";
    valheim-server = {
      url = "git+file:/home/aidan/src/valheim-server-flake";
      inputs.nixpkgs.follows = "nixpkgs";
    };
  };
  outputs = {
    self,
    nixpkgs,
    valheim-server,
  }: let
    system = "x86_64-linux";
    pkgs = import nixpkgs {inherit system;};
  in {
    nixosConfigurations.my-server= nixpkgs.lib.nixosSystem {
      inherit system;
      modules = [
        ./configuration.nix
        valheim-server.nixosModules.default
      ];
    };
  };
}
```

Then in your `configuration.nix`,
```nix
{
  config,
  pkgs,
  ...  
}: {
  # ...
  nixpkgs.config.allowUnfreePredicate = pkg:
    builtins.elem (lib.getName pkg) [
      "valheim-server"
      "steamworks-sdk-redist"
    ];
  # ...
  services.valheim = {
    enable = true;
    serverName = "Some cozy server";
    worldName = "Midgard";
    openFirewall = true;
    password = "sekkritpasswd";
    # If you want ValheimPlus.
    usePlus = true;
    valheimPlusConfig = ./valheim_plus.cfg;
    # If you want to use additional BepInEx mods
    # (not currently supported without ValheimPlus).
    bepinexMods = [
      (pkgs.fetchValheimBepInExMod {
        name = "some-mod";
        url = "https://thunderstore.io/package/download/SomeModAuthor/SomeMod/x.y.z/";
        hash = "sha256-AAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAA=";
      })
      # ...
    ];
    bepinexConfigs = [
      ./some_mod.cfg
      # ...
    ];
  };
  # ...
}
```

## Notes on using ValheimPlus
Because BepInEx (the mod framework ValheimPlus uses) must both be installed in-tree with Valheim, and to be able to write to various files in the directory tree, we cannot run the modded Valheim server from the Nix store.  To work around this without completely giving up on immutability, we copy the files out of the Nix store to a directory under `/var/lib/valheim` and run from there, but wipe and rebuild this directory on each launch.
