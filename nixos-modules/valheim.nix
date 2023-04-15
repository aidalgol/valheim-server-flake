{
  config,
  pkgs,
  lib,
  valheim-server,
  ...
}: let
  cfg = config.services.valheim;
in {
  options.services.valheim = {
    enable = lib.mkEnableOption (lib.mdDoc "Valheim Dedicated Server");

    serverName = lib.mkOption {
      type = lib.types.str;
      default = "";
      example = "Some Cozy Server";
      description = lib.mdDoc "The name listed in the server browser.";
    };

    worldName = lib.mkOption {
      type = with lib.types; nullOr str;
      default = null;
      example = "Midgard";
      description = lib.mdDoc ''
        The name of the world file to use, without the extension.
        If the world does not exist, then the server will generate a world from
        a random seed.
      '';
    };

    port = lib.mkOption {
      type = lib.types.port;
      default = 2456;
      description = lib.mdDoc ''
        The port on which to listen for incoming connections.

        Note that the port just above this one will be used for the Steam server browser service.
      '';
    };

    crossplay = lib.mkOption {
      type = lib.types.bool;
      default = false;
      description = lib.mdDoc ''
        Whether to enable cross-platform players.

        See the [announcement](https://steamcommunity.com/games/892970/announcements/detail/3308480236523722724)
        for details on this feature.

        This should be disabled when using a modded server that requires the
        client to be modded, as only PC versions can run mods.
      '';
    };

    openFirewall = lib.mkOption {
      type = lib.types.bool;
      default = false;
      description = lib.mdDoc "Whether to open ports in the firewall.";
    };

    password = lib.mkOption {
      type = lib.types.str;
      default = "";
      description = lib.mdDoc ''
        The server password.

        This can only be passed as a commandline argument to the server, so it
        can be viewed by any user on the system able to list processes.
      '';
    };

    valheimPlusCfg = lib.mkOption {
      type = with lib.types; nullOr str;
      description = lib.mdDoc ''
        Contents of the `valheim_plus.cfg` file.
      '';
    };
  };

  config = {
    users = {
      users.valheim = {
        isSystemUser = true;
        group = "valheim";
        home = "/var/lib/valheim";
      };
      groups.valheim = {};
    };

    systemd.services.valheim = let
      # We have to do this because ValheimPlus provides to way to specify an
      # altnerate config file path.
      valheim-server-final =
        if cfg.valheimPlusCfg != null
        then let
          valheimPlusConfigFilename = "vahleim_plus.cfg";
          valheim-plus-cfg = pkgs.writeText valheimPlusConfigFilename cfg.valheimPlusCfg;
        in
          valheim-server.overrideAttrs (final: prev: {
            postInstall = ''
              cp ${valheim-plus-cfg}/${valheimPlusConfigFilename};
              ${if prev ? postInstall then prev.postInstall else ""}
            '';
          })
        else valheim-server;
    in {
      description = "Valheim dedicated server";
      requires = ["network.target"];
      after = ["network.target"];
      wantedBy = ["multi-user.target"];

      serviceConfig = {
        Type = "exec";
        User = "valheim";
        ExecStart = lib.strings.concatStringsSep " " ([
            "${valheim-server-final}/bin/valheim-server"
            "-name \"${cfg.serverName}\""
          ]
          ++ (lib.lists.optional (cfg.worldName != null) "-world \"${cfg.worldName}\"")
          ++ [
            "-port \"${builtins.toString cfg.port}\""
            "-password \"${cfg.password}\""
          ]
          ++ (lib.lists.optional cfg.crossplay "-crossplay"));
      };
    };

    networking.firewall = lib.mkIf cfg.openFirewall {
      allowedUDPPorts = [
        cfg.port
        (cfg.port + 1) # Steam server browser
      ];
    };

    assertions = [
      {
        assertion = cfg.serverName != "";
        message = "The server name must not be empty.";
      }
      {
        assertion = cfg.worldName != "";
        message = "The world name must not be empty.";
      }
      {
        assertion = cfg.password != "";
        message = "The password must not be empty.";
      }
    ];
  };
}
