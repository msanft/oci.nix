{
  lib,
  mkConfig,
  runCommand,
  writers,
  nix,
}:
{
  # Name of the manifest.
  name,
  # List of (`mkLayer`-produced) layers to include in the config.
  layers ? [ ],
  # Configuration options for the image. (i.e. `config` key of the OCI config)
  config ? { },
  # Annotations to add to the manifest.
  annotations ? { },
}:
let
  # Config for the image
  ociConfig = mkConfig { inherit layers config; };

  # Media descriptor and platform JSON for the image
  configMediaDescriptor = builtins.fromJSON (
    builtins.readFile (ociConfig + "/media-descriptor.json")
  );
  configPlatform = builtins.fromJSON (builtins.readFile (ociConfig + "/platform.json"));

  # List of media descriptors for each layer
  layerMediaDescriptors = lib.lists.map (
    layer: builtins.fromJSON (builtins.readFile (layer + "/media-descriptor.json"))
  ) layers;

  # Manifest JSON
  manifest = writers.writeJSON "image-manifest.json" (
    {
      schemaVersion = 2;
      mediaType = "application/vnd.oci.image.manifest.v1+json";
    }
    // {
      annotations = {
        "org.opencontainers.image.title" = name;
      }
      // annotations;
      config = configMediaDescriptor;
      layers = layerMediaDescriptors;
    }
  );
in

runCommand name
  {
    inherit manifest;
    blobDirs = lib.lists.map (layer: layer + "/blobs/sha256") (layers ++ [ ociConfig ]);
    platformJSON = builtins.toJSON configPlatform;
    nativeBuildInputs = [ nix ];
  }
  ''
    mkdir -p $out/blobs/sha256

    # Write the manifest JSON to a file under blobs/sha256
    sha256=$(nix-hash --type sha256 --flat $manifest)
    cp $manifest "$out/blobs/sha256/$sha256"
    ln -s "$out/blobs/sha256/$sha256" "$out/image-manifest.json"

    # Write the media descriptor
    echo -n "{\"mediaType\": \"application/vnd.oci.image.manifest.v1+json\", \"size\": $(stat -c %s $manifest), \"digest\": \"sha256:$sha256\", \"platform\": $platformJSON}" > $out/media-descriptor.json

    # Link all blobs from the layers and config into this image's blobs directory
    for src in $blobDirs; do
      for blob in $(ls $src); do
        ln -s "$src/$blob" "$out/blobs/sha256/$blob"
      done
    done
  ''
