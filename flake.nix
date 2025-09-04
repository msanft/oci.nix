{
  inputs = {
    nixpkgs.url = "github:NixOS/nixpkgs/nixos-unstable";
    flake-utils.url = "github:numtide/flake-utils";
  };

  outputs =
    {
      nixpkgs,
      flake-utils,
      ...
    }:
    flake-utils.lib.eachDefaultSystem (
      system:
      let
        pkgs = import nixpkgs {
          inherit system;
          config = {
            allowUnfree = true;
            permittedInsecurePackages = [ "libsoup-2.74.3" ];
          };

          overlays = [
            (_final: prev: (import ./nix/pkgs { inherit (prev) lib callPackage; }))
            (_final: prev: { tests = (import ./nix/tests { inherit (prev) lib callPackage; }); })
          ];
        };
      in
      {
        legacyPackages = pkgs;

        devShells = {
          default = pkgs.callPackage ./nix/shell.nix { };
        };
      }
    );
}
