{
  mkLayer,
  mkManifest,
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
  manifest = mkManifest {
    name = "test-manifest";
    layers = [ layer ];
    config = {
      "cmd" = "/bin/hello";
    };
  };
in
runCommandNoCC "test-mkManifest"
  {
    nativeBuildInputs = [ manifest ];
  }
  ''
    cat ${manifest}/image-manifest.json
    mkdir -p $out
  ''
