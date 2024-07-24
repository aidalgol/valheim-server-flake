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

    public = lib.mkOption {
      type = lib.types.bool;
      default = true;
      description = lib.mdDoc ''
        Toggles visibility on the Steam server & community lists.
        When not set, defaults to true (visible).
        Set to false to make the server private.
      '';
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

    bepinexMods = lib.mkOption {
      type = with lib; types.listOf types.package;
      default = [];
      description = "BepInEx mods to install.";
      example = lib.types.literalExpression ''
        [
          (pkgs.fetchValheimThunderstoreMod {
            owner = "Somebody";
            name = "SomeMod";
            version = "x.y.z";
            hash = "sha256-AAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAA=";
          })
        ]
      '';
    };

    bepinexConfigs = lib.mkOption {
      type = with lib; types.listOf types.path;
      default = [];
      description = ''
        Config files for BepInEx mods.

        The filename must be what the given mod is expecting, otherwise it will
        not be loaded.
      '';
      example = lib.types.literalExpression ''
        [
          ./some_mod.cfg
        ]
      '';
    };
  };

  config = lib.mkIf cfg.enable {
    nixpkgs.overlays = [self.overlays.default steam-fetcher.overlays.default];

    users = {
      users.valheim = {
        isSystemUser = true;
        group = "valheim";
        home = stateDir;
        createHome = true;
      };
      groups.valheim = {};
    };

    systemd.services = let
      installDir = "${stateDir}/valheim-server-modded";
    in {
      valheim = {
        description = "Valheim dedicated server";
        requires = ["network.target"];
        after = ["network.target"];
        wantedBy = ["multi-user.target"];

        preStart = let
          mods = pkgs.symlinkJoin {
            name = "valheim-bepinex-mods";
            paths = cfg.bepinexMods;
            postBuild = ''
              rm -f \
                "$out"/*.md \
                "$out"/icon.png \
                "$out"/manifest.json
            '';
          };
          modConfigs =
            pkgs.runCommandLocal "valheim-bepinex-configs" {
              configs = cfg.bepinexConfigs;
            } ''
              mkdir "$out"
              for cfg in $configs; do
                cp $cfg $out/$(stripHash $cfg)
              done
            '';
        in
          lib.optionalString (cfg.bepinexMods != []) ''
            if [ -e ${installDir} ]; then
              chmod -R +w ${installDir}
              rm -rf ${installDir}
            fi
            mkdir ${installDir}
            cp -r \
              ${pkgs.valheim-server-unwrapped}/* \
              ${pkgs.valheim-bepinex-pack}/* \
              ${installDir}

            # BepInEx doesn't like read-only files.
            chmod -R u+w ${installDir}
          ''
          + lib.optionalString (cfg.bepinexMods != []) ''
            # Install extra mods.
            cp -rL "${mods}"/. ${installDir}/BepInEx/plugins/

            # BepInEx *really* doesn't like *any* read-only files.
            chmod -R u+w ${installDir}/BepInEx/plugins/
          ''
          + lib.optionalString (cfg.bepinexConfigs != []) ''
            # Install extra mod configs.
            cp -r ${modConfigs}/. ${installDir}/BepInEx/config/

            # BepInEx *really* doesn't like *any* read-only files.
            chmod -R u+w ${installDir}/BepInEx/config/
          '';

        serviceConfig = let
          valheimBepInExFHSEnvWrapper = pkgs.buildFHSUserEnv {
            name = "valheim-server";
            runScript = pkgs.writeScript "valheim-server-bepinex-wrapper" ''
              # Whether or not to enable Doorstop. Valid values: TRUE or FALSE
              export DOORSTOP_ENABLE=TRUE

              # What .NET assembly to execute. Valid value is a path to a .NET DLL that mono can execute.
              export DOORSTOP_INVOKE_DLL_PATH="${installDir}/BepInEx/core/BepInEx.Preloader.dll"

              # Which folder should be put in front of the Unity dll loading path
              export DOORSTOP_CORLIB_OVERRIDE_PATH="${installDir}/unstripped_corlib"

              export LD_LIBRARY_PATH=${installDir}/doorstop_libs:$LD_LIBRARY_PATH
              export LD_PRELOAD="libdoorstop_x64.so"

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
              if (cfg.bepinexMods != [])
              then valheimBepInExFHSEnvWrapper
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
                "-public ${if cfg.public then "1" else "0"}"
              ]
              ++ (lib.lists.optional cfg.crossplay "-crossplay")
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
    ];
  };
}
