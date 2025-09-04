{
  pullImage,
  runCommandNoCC,
}:
let
  img = pullImage {
    url = "docker.io/library/alpine:3.22.1@sha256:4bcff63911fcb4448bd4fdacec207030997caf25e9bea4045fa6c8c44de311d1";
    hash = "sha256-nH3rohs65Y4ojVIdwIgaYVlNyYjiAw4oYEHwuGq9XmY=";
  };
in
runCommandNoCC "test-pullOCIImage"
  {
    buildInputs = [ img ];
  }
  ''
    if ! test -f ${img}/oci-layout; then
      echo "Error: oci-layout file not found in ${img}"
      exit 1
    fi
    if ! test -f ${img}/index.json; then
      echo "Error: index.json file not found in ${img}"
      exit 1
    fi
    if ! test -d ${img}/blobs/sha256; then
      echo "Error: blobs/sha256 directory not found in ${img}"
      exit 1
    fi
    mkdir -p $out
  ''
