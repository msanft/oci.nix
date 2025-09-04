{
  mkLayer,
  mkConfig,
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
  config = mkConfig {
    layers = [ layer ];
    config = {
      cmd = [ "/bin/hello" ];
    };
  };
in
runCommandNoCC "test-mkConfig"
  {
    nativeBuildInputs = [ config ];
  }
  ''
    cat ${config}/image-config.json
    exit 1
    mkdir -p $out
  ''
