{
  lib,
  buildFHSUserEnv,
  writeScript,
  valheim-server-plus-unwrapped,
  steamworks-sdk-redist,
  zlib,
  pulseaudio,
}:
buildFHSUserEnv {
  name = "valheim-server";

  runScript = let
    libdoorstopFilename = "libdoorstop_x64.so";
  in
    writeScript "valheim-server-wrapper" ''
      # Whether or not to enable Doorstop. Valid values: TRUE or FALSE
      export DOORSTOP_ENABLE=TRUE

      # What .NET assembly to execute. Valid value is a path to a .NET DLL that mono can execute.
      export DOORSTOP_INVOKE_DLL_PATH="${valheim-server-plus-unwrapped}/BepInEx/core/BepInEx.Preloader.dll"

      # Which folder should be put in front of the Unity dll loading path
      export DOORSTOP_CORLIB_OVERRIDE_PATH="${valheim-server-plus-unwrapped}/unstripped_corlib"

      export LD_LIBRARY_PATH=${valheim-server-plus-unwrapped}/doorstop_libs/${libdoorstopFilename}:$LD_LIBRARY_PATH
      export LD_PRELOAD=${libdoorstopFilename}

      export LD_LIBRARY_PATH=${steamworks-sdk-redist}/lib:$LD_LIBRARY_PATH
      export SteamAppId=892970

      exec ${valheim-server-plus-unwrapped}/valheim_server.x86_64 "$@"
    '';

  targetPkgs = pkgs: [
    valheim-server-plus-unwrapped
    steamworks-sdk-redist
    zlib
    pulseaudio
  ];

  inherit (valheim-server-plus-unwrapped) meta;
}
