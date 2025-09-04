{
  mkSimpleImage,
  hello,
  cowsay,
  runCommandNoCC,
}:
let
  image = mkSimpleImage {
    name = "test-simple-image";
    layers = [
      hello
      cowsay
    ];
    annotations = {
      "org.opencontainers.image.description" = "This is a test image";
    };
  };
in
runCommandNoCC "test-mkSimpleImage"
  {
    nativeBuildInputs = [ image ];
  }
  ''
    cat ${image}/index.json
    mkdir -p $out
  ''
