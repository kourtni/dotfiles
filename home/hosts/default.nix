{ config, pkgs, lib, ... }:

let
  # Create a file with hostname detection
  hostnameFile = pkgs.runCommand "hostname" {} ''
    ${pkgs.hostname}/bin/hostname | cut -d. -f1 > $out
  '';
  hostname = builtins.readFile hostnameFile;
  isCxGawd = lib.strings.hasPrefix "CxGawd" hostname;
in
{
  # Host-specific packages
  home.packages = lib.optionals isCxGawd [
    pkgs.bazelisk
  ];
}
