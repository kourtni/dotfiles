{ config, pkgs, ... }:

let
  isWSL = builtins.pathExists /proc/sys/fs/binfmt_misc/WSLInterop;
in
{
  imports = [
    ./programs.nix
    ./dotfiles.nix
    ./hosts/default.nix
  ];

  home.username = "kourtni";
  home.homeDirectory = "/home/kourtni";
  home.stateVersion = "23.11";

  programs.home-manager.enable = true;

  home.sessionVariables = {
    WSL = if isWSL then "true" else "false";
  };

  # Optional WSL-specific settings could go here:
  # home.packages = if isWSL then [ pkgs.htop ] else [ pkgs.firefox ];

}
