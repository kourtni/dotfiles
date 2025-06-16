{ config, home-manager, pkgs, ... }:

let
  isWSL = builtins.pathExists /proc/sys/fs/binfmt_misc/WSLInterop;
in
{
  imports = [
    # Note: sops-nix is imported at the system level in flake.nix
    (import ./programs.nix { inherit config pkgs home-manager; })
    # ./dotfiles.nix
    ./hosts/default.nix
  ];

  # sops-nix configuration
  sops = {
    defaultSopsFile = ./secrets/secrets.enc.yaml;
    age.keyFile = "${config.home.homeDirectory}/.config/sops/age/keys.txt";
    secrets = {
      github_name = {
        key = "github/name";
      };
      github_email = {
        key = "github/email";
      };
      github_token = {
        key = "github/token";
      };
    };
  };

  home.username = "kourtni";
  home.homeDirectory = "/home/kourtni";
  home.stateVersion = "24.11";

  programs.home-manager.enable = true;

  home.sessionVariables = {
    WSL = if isWSL then "true" else "false";
  };

  # Optional WSL-specific settings could go here:
  # home.packages = if isWSL then [ pkgs.htop ] else [ pkgs.firefox ];

}
