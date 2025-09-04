{
  mkLayer,
  mkManifest,
  mkImage,
  hello,
  cowsay,
  runCommandNoCC,
}:
let
  layer = mkLayer {
    files = [
      hello
      cowsay
    ];
  };
  image = mkImage {
    name = "test-image";
    manifests = [
      (mkManifest {
        name = "test-manifest";
        layers = [ layer ];
        config = {
          "cmd" = "/bin/hello";
        };
      })
    ];
    annotations = {
      "org.opencontainers.image.description" = "This is a test image";
    };
  };
in
runCommandNoCC "test-mkImage"
  {
    nativeBuildInputs = [ image ];
  }
  ''
    cat ${image}/index.json
    mkdir -p $out
  ''
