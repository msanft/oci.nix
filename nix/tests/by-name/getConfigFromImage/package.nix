{
  pullImage,
  getConfigFromImage,
  runCommandNoCC,
  jq,
}:
let
  img = pullImage {
    url = "docker.io/library/alpine:3.22.1@sha256:4bcff63911fcb4448bd4fdacec207030997caf25e9bea4045fa6c8c44de311d1";
    hash = "sha256-J4CKwplJk4XKXquLUVjkRYWZBVsvyRtFbPAQWDbS04g=";
    platform = "linux/amd64";
  };

  config = getConfigFromImage img;
in
runCommandNoCC "test-getConfigFromImage"
  {
    buildInputs = [ jq ];
  }
  ''
    jq . ${config}
    mkdir -p $out
  ''
