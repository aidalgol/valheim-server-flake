# Valheim Server Flake
A Nix flake for the Valheim dedicated server, providing both a package and a NixOS module.

## Usage
(Your NixOS system configuration must already be a flake.)

Add this flake as an input, add add the NixOS module.  Your config should look something like this.
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
      # Only required if you want to use the ValheimPlus mod.
      specialArgs = {
        inherit (valheim-server.lib.${system}) mkValheimServerPlus;
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
  mkValheimServerPlus, # Only if using ValheimPlus.
  ...  
}: {
  # ...
  services.valheim = {
    enable = true;
    serverName = "Some cozy server";
    worldName = "Midgard";
    openFirewall = true;
    password = "sekkritpasswd";
    # If using ValheimPlus, you also need to provide a config file.
    package = mkValheimServerPlus {valheimPlusConfig = builtins.readFile ./valheim_plus.cfg;};
  # ...
}
```

The mechanism for passing the ValheimPlus config file is like this because the config file must be in-tree at a certain location; there is unfortunately no mechanism for providing a configuration file at an alternate location.