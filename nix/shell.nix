{ pkgs }:
pkgs.mkShell {
  buildInputs = with pkgs; [
    go
    go-containerregistry
  ];
}
