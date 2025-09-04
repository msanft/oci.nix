{
  lib,
  combineimages,
  runCommandNoCC,
}:
{
  # Name of the image.
  name,
  # A list of OCI images to include in the image.
  images ? [ ],
}:
runCommandNoCC name
  {
    inherit images;
    nativeBuildInputs = [ combineimages ];
  }
  ''
    combineimages ${lib.concatStringsSep " " images} $out
  ''
