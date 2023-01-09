{ pkgs ? import <nixpkgs> {} }:

pkgs.mkShell {
  buildInputs = [
    pkgs.bashInteractive
    pkgs.curl
    pkgs.docker-compose
    pkgs.gnumake
  ];
}
