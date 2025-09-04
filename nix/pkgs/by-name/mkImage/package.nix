{
  lib,
  runCommand,
  writers,
  nix,
}:
{
  # Name of the image.
  name,
  # A list of (`mkManifest`-produced) manifests to include in the image.
  manifests ? [ ],
  # Annotations to add to the index.
  annotations ? { },
}:
let
  # Media descriptors for each manifest
  manifestMediaDescriptors = lib.lists.map (
    manifest: builtins.fromJSON (builtins.readFile (manifest + "/media-descriptor.json"))
  ) manifests;

  # Index JSON
  index = writers.writeJSON "index.json" (
    {
      schemaVersion = 2;
      mediaType = "application/vnd.oci.image.index.v1+json";
    }
    // {
      annotations = {
        "org.opencontainers.image.title" = name;
      }
      // annotations;
      manifests = manifestMediaDescriptors;
    }
  );
in
runCommand name
  {
    inherit index;
    nativeBuildInputs = [ nix ];
    blobDirs = lib.lists.map (manifest: manifest + "/blobs/sha256") manifests;
  }
  ''
    srcs=($blobDirs)
    mkdir -p $out/blobs/sha256

    # Add the index
    cp $index $out/index.json

    # Add the image layout
    echo '{"imageLayoutVersion": "1.0.0"}' > $out/image-layout

    # Symlink all blobs from manifests and config into the image's blob directory
    for src in $srcs; do
      for blob in $(ls $src); do
        ln -s "$(realpath $src/$blob)" "$out/blobs/sha256/$blob"
      done
    done
  ''
