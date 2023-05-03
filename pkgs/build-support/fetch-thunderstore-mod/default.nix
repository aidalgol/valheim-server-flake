{
  stdenv,
  fetchzip,
  ...
}: {
  owner,
  name,
  version,
  hash,
}: let
  depString = "${owner}-${name}";
in
  fetchzip {
    inherit version hash;
    name = "valheim-thunderstore-${depString}";
    url = "https://thunderstore.io/package/download/${owner}/${name}/${version}/";
    extension = "zip";
    # All files are in the top level, with no containing directory.
    stripRoot = false;
  }
