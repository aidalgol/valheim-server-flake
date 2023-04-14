{
  lib,
  stdenv,
  fetchSteam,
  fetchzip,
}:
# While ValheimPlus is open-source, upstream, like most mods, does not support
# building from source except for development purposes and does not provide
# clear and complete instructions for building from source.  Coupled with the
# fact that they also bundle third-party dependencies in their binary release
# bundles, and that mods are so inherently fragile even at the best of times,
# there is little benefit in building from source, so we simply use the binary
# release.
stdenv.mkDerivation {
  name = "valheim-server-plus";
  version = "0.215.2-0.9.9.11";
  srcs = [
    (fetchSteam {
      name = "valheim-server";
      appId = "896660";
      depotId = "896661";
      manifestId = "1755534777276869897";
      hash = "sha256-fyctiui0Ee57gFIqJvAVOeOQItydx9Fop5F4nz6RpUQ=";
    })
    (fetchzip {
      url = "https://github.com/valheimPlus/ValheimPlus/releases/download/0.9.9.11/UnixServer.tar.gz";
      stripRoot = false;
      hash = "sha256-UlhGb1vxsFbtAkK1p2DMJuffRN26OHnrDB1poPH76JQ=";
    })
  ];

  # Skip phases that don't apply to prebuilt binaries.
  dontBuild = true;
  dontConfigure = true;
  dontFixup = true;

  unpackPhase = ''
    runHook preUnpack

    mkdir $out
    for _src in $srcs; do
      if [ $(stripHash "$_src") == valheim-server-depot ]; then
        echo "Unpacking Valheim server depot"
        cp -r "$_src" $(stripHash "$_src")
      else
        echo "Unpacking ValheimPlus"
        cp -r "$_src" valheim-plus
      fi
    done

    runHook postUnpack
  '';

  installPhase = ''
    runHook preInstall

    cp -r \
      valheim-server-depot/*.so \
      valheim-server-depot/*.debug \
      valheim-server-depot/valheim_server.x86_64 \
      valheim-server-depot/valheim_server_Data \
      $out
    chmod +x $out/valheim_server.x86_64

    cp -r \
      valheim-plus/BepInEx \
      valheim-plus/doorstop_config.ini \
      valheim-plus/doorstop_libs \
      valheim-plus/unstripped_corlib \
      valheim-plus/winhttp.dll \
      $out

    runHook postInstall
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
