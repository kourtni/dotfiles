{ config, home-manager, pkgs, lib, ... }:

let
  # Platform detection
  isLinux = pkgs.stdenv.isLinux;
  isDarwin = pkgs.stdenv.isDarwin;
  isWSL = builtins.pathExists /proc/sys/fs/binfmt_misc/WSLInterop;
  
  # System-specific settings
  systemType = if isWSL then "wsl" 
               else if isDarwin then "darwin"
               else if isLinux then "linux"  
               else "unknown";
in
{
  imports = [
    # Note: sops-nix is imported at the system level in flake.nix
    (import ./programs.nix { inherit config pkgs lib; })
    ./platforms.nix
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

  # Platform-specific configurations are handled in platforms.nix

}
