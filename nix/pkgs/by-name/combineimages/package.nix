{
  lib,
  buildGoModule,
}:
buildGoModule (finalAttrs: {
  pname = "combineimages";
  version = "0.0.1";

  src =
    let
      root = ../../../../.;
    in
    lib.fileset.toSource {
      inherit root;
      fileset = lib.fileset.unions [
        (lib.path.append root "go.mod")
        (lib.path.append root "go.sum")
        (lib.path.append root "cmd/combineimages")
      ];
    };

  vendorHash = "sha256-PqLOsO7wNuch6VbvC7f3PmgCdXTWlT9kML/WmEoYUFM=";

  subPackages = [ "cmd/combineimages" ];

  env.CGO_ENABLED = 0;

  meta.mainProgram = "combineimages";
})
