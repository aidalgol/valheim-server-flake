{
  lib,
  buildFHSUserEnv,
  writeScript,
  valheim-server-unwrapped,
  steamworks-sdk-redist,
  zlib,
  pulseaudio,
}:
buildFHSUserEnv {
  name = "valheim-server";

  runScript = writeScript "valheim-server-wrapper" ''
    export LD_LIBRARY_PATH=${steamworks-sdk-redist}/lib:$LD_LIBRARY_PATH
    export SteamAppId=892970
    exec ${valheim-server-unwrapped}/valheim_server.x86_64 "$@"
  '';

  targetPkgs = pkgs: [
    valheim-server-unwrapped
    steamworks-sdk-redist
    zlib
    pulseaudio
  ];

  inherit (valheim-server-unwrapped) meta;
}
