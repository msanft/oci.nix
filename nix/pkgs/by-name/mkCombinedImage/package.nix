{
  lib,
  combineimages,
  runCommandNoCC,
  writers,
}:
{
  # Name of the image.
  name,
  # A list of OCI images to include in the image.
  images ? [ ],
  # Full config for the combined image.
  config ? { },
}:
let
  configJSON = writers.writeJSON "config.json" config;
in
runCommandNoCC name
  {
    inherit images configJSON;
    nativeBuildInputs = [ combineimages ];
  }
  ''
    combineimages $configJSON ${lib.concatStringsSep " " images} $out
  ''
