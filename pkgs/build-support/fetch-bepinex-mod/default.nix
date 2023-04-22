{
  stdenv,
  fetchzip,
  ...
}: {
  name,
  url,
  hash,
}:
fetchzip {
  inherit url hash;

  name = "valheim-mod-${name}";

  # Some mod repositories, such as Thunderstore, use URLs that end in just the
  # version number.
  extension = "zip";

  # All files are in the top level, with no containing directory.
  stripRoot = false;
}
