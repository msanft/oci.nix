{
  pullImage,
  mkCombinedImage,
  runCommandNoCC,
  mkSimpleImage,
  cowsay,
  jq,
}:
let
  alpineImg = pullImage {
    url = "docker.io/library/alpine:3.22.1@sha256:4bcff63911fcb4448bd4fdacec207030997caf25e9bea4045fa6c8c44de311d1";
    hash = "sha256-nH3rohs65Y4ojVIdwIgaYVlNyYjiAw4oYEHwuGq9XmY=";
  };

  nixImg = mkSimpleImage {
    name = "test-nix-image";
    layers = [ cowsay ];
  };

  config = {
    Entrypoint = [ "/bin/cowsay" ];
  };

  combinedImg = mkCombinedImage {
    name = "combined-alpine";
    images = [
      alpineImg
      nixImg
    ];
    config = { inherit config; };
  };
in
runCommandNoCC "test-mkCombinedImage"
  {
    nativeBuildInputs = [
      combinedImg
      jq
    ];
  }
  ''
    digest="$(jq -r '.manifests[0].digest' ${combinedImg}/index.json)"
    digestPath="${combinedImg}/blobs/sha256/''${digest#sha256:}"
    configDigest="$(jq -r '.config.digest' "$digestPath")"
    entrypoint="$(jq -r '.config.Entrypoint[0]' "${combinedImg}/blobs/sha256/''${configDigest#sha256:}")"
    if [ "$entrypoint" != '${builtins.elemAt config.Entrypoint 0}' ]; then
      echo "Error: Entrypoint is not set correctly in combined image"
      echo "Expected: ${builtins.elemAt config.Entrypoint 0}"
      echo "Got: $entrypoint"
      exit 1
    fi
    mkdir -p $out
  ''
