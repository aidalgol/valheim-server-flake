{
  lib,
  stdenv,
  fetchSteam,
  autoPatchelfHook,
  makeWrapper,
  steamworksSdkRedist,
  zlib,
  pulseaudio,
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

    makeWrapper $out/valheim_server.x86_64 $out/valheim_server \
      --set SteamAppId 892970

    runHook postInstall
  '';

  postFixup = ''
    patchelf --add-needed "steamclient.so" $out/valheim_server.x86_64
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
