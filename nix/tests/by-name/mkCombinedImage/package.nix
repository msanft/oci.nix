{
  pullImage,
  mkCombinedImage,
  runCommandNoCC,
  mkSimpleImage,
  cowsay,
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

  combinedImg = mkCombinedImage {
    name = "combined-alpine";
    images = [
      alpineImg
      nixImg
    ];
  };
in
runCommandNoCC "test-mkCombinedImage"
  {
    nativeBuildInputs = [ combinedImg ];
  }
  ''
    cat ${combinedImg}/index.json
    mkdir -p $out
  ''
