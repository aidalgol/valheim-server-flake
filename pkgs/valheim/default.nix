{
  lib,
  stdenv,
  fetchSteam,
  autoPatchelfHook,
  makeWrapper,
  steamworksSdkRedist,
  zlib,
  pulseaudio,
  # Pass ValheimPlus package to add the ValheimPlus mod.
  valheimPlus ? null
}:
stdenv.mkDerivation rec {
  name = "valheim-server";
  version = "0.215.2";
  src = fetchSteam {
    inherit name;
    appId = "896660";
    depotId = "896661";
    manifestId = "1755534777276869897";
    hash = "sha256-fyctiui0Ee57gFIqJvAVOeOQItydx9Fop5F4nz6RpUQ=";
  };

  # Skip phases that don't apply to prebuilt binaries.
  dontBuild = true;
  dontConfigure = true;

  nativeBuildInputs = [
    autoPatchelfHook
    makeWrapper
  ];

  buildInputs = [
    stdenv.cc
    zlib
    pulseaudio
    steamworksSdkRedist
  ];

  installPhase = ''
    runHook preInstall

    mkdir $out
    cp -r \
      $src/*.so \
      $src/*.debug \
      $src/valheim_server.x86_64 \
      $src/valheim_server_Data \
      $out

    chmod +x $out/valheim_server.x86_64

    # We may be able to replace LD_PRELOAD with a patchelf command once
    # https://github.com/NixOS/patchelf/pull/459
    # makes it into a release.
    makeWrapper $out/valheim_server.x86_64 $out/valheim_server \
      ${lib.optionalString (valheimPlus != null) '' \
        --set LD_PRELOAD ${valheimPlus}/doorstop_libs/libdoorstop_x64.so \
        --set DOORSTOP_INVOKE_DLL_PATH \"${valheimPlus}/BepInEx/core/BepInEx.Preloader.dll\" \
        --set DOORSTOP_CORLIB_OVERRIDE_PATH \"${valheimPlus}/unstripped_corlib\" \
      ''} \
      --set SteamAppId 892970

    runHook postInstall
  '';

  preFixup = lib.optionalString (valheimPlus != null) ''
    addAutoPatchelfSearchPath ${valheimPlus}/doorstop_libs/
  '';

  postFixup = ''
    patchelf --add-needed "steamclient.so" $out/valheim_server.x86_64
    ${lib.optionalString (valheimPlus != null)
      "patchelf --add-needed \"libdoorstop_x64.so\" $out/valheim_server.x86_64"}
  '';

  meta = with lib; {
    description = "Valheim dedicated server";
    homepage = "https://steamdb.info/app/896660/";
    changelog = "https://store.steampowered.com/news/app/892970?updates=true";
    # TODO: Figure out how to allow nonfree packages from flakes.
    # license = licenses.unfree;
    maintainers = with maintainers; [aidalgol];
    platforms = ["x86_64-linux"];
  };
}
