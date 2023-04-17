# Valheim Server Flake
A Nix flake for the Valheim dedicated server, providing both a package and a NixOS module.

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
    pkgs = import nixpkgs {inherit system;};
    system = "x86_64-linux";
  in {
    nixosConfigurations.my-server= nixpkgs.lib.nixosSystem {
      inherit system;
      modules = [
        ./configuration.nix
        valheim-server.nixosModules.${system}.default
      ];
      specialArgs = {
        valheim-server-flake = valheim-server;
        inherit system;
      };
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
  services.valheim = {
    enable = true;
    serverName = "Some cozy server";
    worldName = "Midgard";
    openFirewall = true;
    password = "sekkritpasswd";
    # If you want ValheimPlus.
    usePlus = true;
    valheimPlusConfig = builtins.readFile ./valheim_plus.cfg;
  # ...
}
```

## Notes on using ValheimPlus
Because BepInEx (the mod framework ValheimPlus uses) must both be installed in-tree with Valheim, and to be able to write to various files in the directory tree, we cannot run the modded Valheim server from the Nix store.  To work around this without completely giving up on immutability, we copy the files out of the Nix store to a directory under `/var/lib/valheim` and run from there, but wipe and rebuild this directory on each launch.
