{
  lib,
  runCommandNoCC,
  nix,
  gzip,
  zstd,
  rsync,
}:
{
  # Files are the closures of files to be included in this layer.
  files ? [ ],
  # Compression algorithm to use for the layer tarball.
  # One of "gzip", "zstd", or "uncompressed" (i.e. uncompressed).
  compression ? "gzip",
}:
let
  mediaType =
    if compression != "uncompressed" then
      "application/vnd.oci.image.layer.v1.tar+${compression}"
    else
      "application/vnd.oci.image.layer.v1.tar";
  outPath =
    if compression == "gzip" then
      "layer.tar.gz"
    else if compression == "zstd" then
      "layer.tar.zst"
    else
      "layer.tar";
in
runCommandNoCC "oci-layer"
  {
    inherit
      files
      compression
      mediaType
      outPath
      ;
    nativeBuildInputs = [
      nix
      rsync
    ]
    ++ lib.optional (compression == "gzip") gzip
    ++ lib.optional (compression == "zstd") zstd;
  }
  ''
    set -o pipefail
    srcs=($files)
    mkdir -p ./root $out

    # Copy all specified files into the root directory
    for f in "''${srcs[@]}"; do
      cp --parents -r "$f" ./root/
    done

    # Create the layer tarball
    tar --sort=name --owner=root:0 --group=root:0 --mode=544 --mtime='UTC 1970-01-01' -cC ./root -f $out/layer.tar .

    # Calculate the layer tarball's diffID (hash of the uncompressed tarball)
    diffID=$(nix-hash --type sha256 --flat $out/layer.tar)

    # Compress the layer tarball
    if [[ "$compression" = "gzip" ]]; then
      gzip -c $out/layer.tar > $out/$outPath
    elif [[ "$compression" = "zstd" ]]; then
      zstd -T0 -q -c $out/layer.tar > $out/$outPath
    else
      mv $out/layer.tar $out/$outPath
    fi
    rm -f $out/layer.tar

    # Calculate the blob's sha256 hash and write the media descriptor
    sha256=$(nix-hash --type sha256 --flat $out/$outPath)
    echo -n "{\"mediaType\": \"$mediaType\", \"size\": $(stat -c %s $out/$outPath), \"digest\": \"sha256:$sha256\"}" > $out/media-descriptor.json
    echo -n "sha256:$diffID" > $out/DiffID

    # Move the compressed layer tarball to the blobs directory and create a symlink
    mkdir -p $out/blobs/sha256
    mv $out/$outPath $out/blobs/sha256/$sha256
    ln -s $out/blobs/sha256/$sha256 $out/$outPath
  ''
