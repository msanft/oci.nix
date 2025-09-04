{
  mkImage,
  mkManifest,
  mkLayer,
}:
{
  # Name of the image.
  name,
  # A list of closures to include in the image.
  layers ? [ ],
  # Annotations to add to the image.
  annotations ? { },
}:
mkImage {
  inherit name annotations;
  manifests = [
    (mkManifest {
      name = "${name}-manifest";
      layers = builtins.map (layer: mkLayer { files = [ layer ]; }) layers;
    })
  ];
}
