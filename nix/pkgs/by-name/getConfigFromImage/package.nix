{
  lib,
  runCommandNoCC,
  jq,
}:
# Image to get the config from
image:
runCommandNoCC
  (lib.concatStringsSep "-" [
    image.name
    "config"
  ])
  {
    nativeBuildInputs = [
      image
      jq
    ];
  }
  ''
    digest="$(jq -r '.manifests[0].digest' ${image}/index.json)"
    digestPath="${image}/blobs/sha256/''${digest#sha256:}"
    configDigest="$(jq -r '.config.digest' "$digestPath")"
    cp "${image}/blobs/sha256/''${configDigest#sha256:}" $out
  ''
