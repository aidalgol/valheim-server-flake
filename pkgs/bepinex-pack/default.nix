{
  lib,
  stdenv,
  fetchValheimThunderstoreMod,
  valheim-server,
}:
stdenv.mkDerivation {
  name = "BepInExPack-Valheim";
  version = "5.4.2105";

  # While BepInEx is open-source, there are no publicly available steps for
  # reproducing the BepInEx Valheim pack.
  src = fetchValheimThunderstoreMod {
    owner = "denikson";
    name = "BepInExPack_Valheim";
    version = "5.4.2105";
    hash = "sha256-V9xrjWmpKVmNIAAm4NlKOv8s9b6Tl3RsqDdLXyTYqDQ=";
  };

  # Skip phases that don't apply to prebuilt binaries.
  dontBuild = true;
  dontConfigure = true;
  dontFixup = true;

  installPhase = ''
    runHook preInstall

    mkdir $out
    cp -r \
      BepInExPack_Valheim/BepInEx \
      BepInExPack_Valheim/doorstop_config.ini \
      BepInExPack_Valheim/doorstop_libs \
      BepInExPack_Valheim/unstripped_corlib \
      BepInExPack_Valheim/winhttp.dll \
      $out

    runHook postInstall
  '';

  meta = with lib; {
    description = "BepInEx pack for Valheim";
    homepage = "https://valheim.thunderstore.io/package/denikson/BepInExPack_Valheim/";
    changelog = "https://valheim.thunderstore.io/package/denikson/BepInExPack_Valheim/";
    sourceProvenance = [sourceTypes.binaryBytecode];
    license = with licenses; [
      lgpl21Only # BepinEx, Doorstop, Il2CppInterop
      gpl3Only # Il2CppInterop
      mit # HarmonyX, MonoMod, cecil, Cpp2IL, .NET Runtime
    ];
    maintainers = with maintainers; [aidalgol];
    inherit (valheim-server.meta) platforms;
  };
}
