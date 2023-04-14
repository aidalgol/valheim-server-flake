{ lib,
stdenv,
fetchzip,
autoPatchelfHook
}:
stdenv.mkDerivation {
  name = "ValheimPlus";
  version = "0.9.9.11";

  # While ValheimPlus is open-source, upstream, like most mods, does not support
  # building from source except for development purposes and does not provide
  # clear and complete instructions for building from source.  Coupled with the
  # fact that they also bundle third-party dependencies in their binary release
  # bundles, and that mods are so inherently fragile even at the best of times,
  # there is little benefit in building from source, so we simply use the binary
  # release.
  src = fetchzip {
    url = "https://github.com/valheimPlus/ValheimPlus/releases/download/0.9.9.11/UnixServer.tar.gz";
    stripRoot = false;
    hash = "sha256-UlhGb1vxsFbtAkK1p2DMJuffRN26OHnrDB1poPH76JQ=";
  };

  # Skip phases that don't apply to prebuilt binaries.
  dontBuild = true;
  dontConfigure = true;

  nativeBuildInputs = [
    autoPatchelfHook
  ];

  buildInputs = [
    stdenv.cc
  ];

  installPhase = ''
    runHook preInstall

    mkdir $out
    cp -r \
      BepInEx \
      doorstop_config.ini \
      doorstop_libs \
      unstripped_corlib \
      winhttp.dll \
      $out

    runHook postInstall
  '';

  postFixup = ''
  '';

  meta = with lib; {
    description = "A large quality-of-life mod for Valheim";
    homepage = "https://github.com/valheimPlus/ValheimPlus";
    changelog = "https://github.com/valheimPlus/ValheimPlus/releases";
    sourceProvenance = [sourceTypes.binaryBytecode];
    license = with licenses; [
      agpl3Only # ValheimPlus (does not clearly specify whether "only" or "plus")
      mit # HarmonyX
      lgpl21Plus # BepinEx
    ];
    maintainers = with maintainers; [aidalgol];
    platforms = ["x86_64-linux"]; # Same as Valheim
  };
}
