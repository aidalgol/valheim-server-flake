{
  lib,
  runCommandLocal,
}: {
  valheim-server-unwrapped,
  valheim-plus,
  valheimPlusConfig,
}:
runCommandLocal "valheim-server-plus" {
  passAsFile = ["valheimPlusConfig"];
} ''
  mkdir -p $out

  cp -r \
    ${valheim-server-unwrapped}/* \
    ${valheim-plus}/* \
    $out

  chmod +w $out/BepInEx/config
  cp ${valheimPlusConfig} $out/BepInEx/config/valheim_plus.cfg
''
