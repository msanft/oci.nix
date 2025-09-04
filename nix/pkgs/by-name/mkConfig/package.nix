{
  lib,
  runCommand,
  writers,
  nix,
}:
{
  # Layers is the list of (`mkLayer`-produced) layers to include in the config.
  layers ? [ ],
  # Config is the set of configuration options for the image.
  config ? { },
}:

let
  diffIDs = lib.lists.map (layer: builtins.readFile (layer + "/DiffID")) layers;
  ociConfig = {
    inherit config;
    architecture = "amd64";
    os = "linux";
  }
  // {
    rootfs = {
      type = "layers";
      diff_ids = diffIDs;
    };
  };
  configJSON = writers.writeJSON "image-config.json" ociConfig;
in

runCommand "oci-image-config"
  {
    nativeBuildInputs = [ nix ];
    platformJSON = builtins.toJSON {
      inherit (ociConfig) architecture os;
    };
    inherit configJSON;
  }
  ''
    # Write the config to a file under blobs/sha256
    sha256=$(nix-hash --type sha256 --flat $configJSON)
    mkdir -p $out/blobs/sha256
    cp $configJSON "$out/blobs/sha256/$sha256"

    # Create a symlink to the image config
    ln -s "$out/blobs/sha256/$sha256" "$out/image-config.json"

    # Write the platform.json
    echo "$platformJSON" > "$out/platform.json"

    # Write the media descriptor
    echo -n "{\"mediaType\": \"application/vnd.oci.image.config.v1+json\", \"size\": $(stat -c %s $configJSON), \"digest\": \"sha256:$sha256\"}" > $out/media-descriptor.json
  ''
