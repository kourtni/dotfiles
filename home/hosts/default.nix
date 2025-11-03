{ config, pkgs, lib, ... }:

let
  # Create a file with hostname detection
  hostnameFile = pkgs.runCommand "hostname" {} ''
    ${pkgs.hostname}/bin/hostname | cut -d. -f1 > $out
  '';
  hostname = builtins.readFile hostnameFile;
  isCxGawd = lib.strings.hasPrefix "CxGawd" hostname;
  isDarwin = pkgs.stdenv.isDarwin;
in
{
  # Host-specific packages
  # Note: bazelisk is installed system-wide via nix-darwin on macOS
  home.packages = lib.optionals (isCxGawd && !isDarwin) [
    pkgs.bazelisk
  ];
}
