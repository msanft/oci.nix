{
  mkLayer,
  hello,
  cowsay,
  runCommandNoCC,
}:
let
  sources = [
    hello
    cowsay
    ./someFile
  ];
  layer = mkLayer {
    files = sources;
  };
in
runCommandNoCC "test-pullOCIImage"
  {
    inherit sources;
    buildInputs = [ layer ];
  }
  ''
    sources=($sources)
    mkdir unpacked
    tar -xf ${layer}/layer.tar.gz -C unpacked
    for f in "''${sources[@]}"; do
      if ! test -e unpacked/$f; then
        echo "Error: file $f not found in layer"
        exit 1
      fi
    done
    mkdir -p $out
  ''
