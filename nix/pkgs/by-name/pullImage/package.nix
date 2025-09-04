{
  runCommandNoCC,
  go-containerregistry,
  lib,
}:
{
  # URL of the image to pull.
  # Of form `<image>:<tag>`.
  url,
  # Output hash for the FOD.
  hash,
  # Whether to allow insecure connections. (i.e. non-TLS)
  insecure ? false,
  # Platform to pull.
  # Of form `<os>/<arch>`.
  # `null` means all, which is the default.
  platform ? null,
}:
let
  # Brittle parsing, but should work for everyone not using weird tag names
  name = lib.concatStrings [
    (builtins.replaceStrings [ ":" ] [ "-" ] (
      lib.lists.last (lib.strings.splitString "/" (builtins.head (lib.strings.splitString "@" url)))
    ))
    "-image"
  ];
in
runCommandNoCC name
  {
    nativeBuildInputs = [ go-containerregistry ];
    outputHashAlgo = "sha256";
    outputHashMode = "recursive";
    outputHash = hash;
  }
  ''
    mkdir -p $out
    crane pull ${url} $out --format oci ${if insecure then "--insecure" else ""} ${
      if platform != null then "--platform " + platform else ""
    }
  ''
