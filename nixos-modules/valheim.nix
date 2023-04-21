{
  self,
  steam-fetcher,
}: {
  config,
  pkgs,
  lib,
  ...
}: let
  cfg = config.services.valheim;
  stateDir = "/var/lib/valheim";
in {
  config.nixpkgs.overlays = [self.overlays.default steam-fetcher.overlays.default];

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

    usePlus = lib.mkOption {
      type = lib.types.bool;
      default = false;
      description = lib.mdDoc "Whether to use the ValheimPlus mod.";
    };

    valheimPlusConfig = lib.mkOption {
      type = with lib.types; nullOr str;
      description = lib.mdDoc "Contents of the `valheim_plus.cfg` file.";
    };
  };

  config = {
    users = {
      users.valheim = {
        isSystemUser = true;
        group = "valheim";
        home = stateDir;
      };
      groups.valheim = {};
    };

    systemd.services = let
      installDir = "${stateDir}/valheim-server-plus";
    in {
      valheim = {
        description = "Valheim dedicated server";
        requires = ["network.target"];
        after = ["network.target"];
        wantedBy = ["multi-user.target"];

        preStart = lib.optionalString cfg.usePlus ''
          rm -rf ${installDir}
          mkdir ${installDir}
          cp -r \
            ${pkgs.valheim-server-unwrapped}/* \
            ${pkgs.valheim-plus}/* \
            ${installDir}
          # BepInEx doesn't like read-only files.
          chmod -R u+w ${installDir}
          echo "${cfg.valheimPlusConfig}" > ${installDir}/BepInEx/config/valheim_plus.cfg
        '';

        serviceConfig = let
          valheimPlusFHSEnvWrapper = pkgs.buildFHSUserEnv {
            name = "valheim-server";
            runScript = let
              libdoorstopFilename = "libdoorstop_x64.so";
            in
              pkgs.writeScript "valheim-server-plus-wrapper" ''
                # Whether or not to enable Doorstop. Valid values: TRUE or FALSE
                export DOORSTOP_ENABLE=TRUE

                # What .NET assembly to execute. Valid value is a path to a .NET DLL that mono can execute.
                export DOORSTOP_INVOKE_DLL_PATH="${installDir}/BepInEx/core/BepInEx.Preloader.dll"

                # Which folder should be put in front of the Unity dll loading path
                export DOORSTOP_CORLIB_OVERRIDE_PATH="${installDir}/unstripped_corlib"

                export LD_LIBRARY_PATH=${installDir}/doorstop_libs:$LD_LIBRARY_PATH
                export LD_PRELOAD=${libdoorstopFilename}

                export LD_LIBRARY_PATH=${pkgs.steamworks-sdk-redist}/lib:$LD_LIBRARY_PATH
                export SteamAppId=892970

                exec ${installDir}/valheim_server.x86_64 "$@"
              '';

            targetPkgs = with pkgs;
              pkgs: [
                pkgs.steamworks-sdk-redist
                zlib
                pulseaudio
              ];
          };
        in {
          Type = "exec";
          User = "valheim";
          ExecStart = let
            valheimServerPkg =
              if cfg.usePlus
              then valheimPlusFHSEnvWrapper
              else pkgs.valheim-server;
          in
            lib.strings.concatStringsSep " " ([
                "${valheimServerPkg}/bin/valheim-server"
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
      {
        assertion = cfg.usePlus -> cfg.valheimPlusConfig != "";
        message = "You must specify a ValheimPlus config file when using this mod.";
      }
    ];
  };
}
