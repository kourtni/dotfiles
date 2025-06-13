{ config, home-manager, pkgs, ... }:

let
  isWSL = builtins.pathExists /proc/sys/fs/binfmt_misc/WSLInterop;
in
{
  imports = [
    (import ./programs.nix { inherit pkgs home-manager; })
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
