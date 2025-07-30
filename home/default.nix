{ config, home-manager, pkgs, lib, ... }:

let
  userConfig = import ../user-config.nix;
in
{
  imports = [
    # Note: sops-nix is imported at the system level in flake.nix
    (import ./programs.nix { inherit config pkgs lib; })
    ./platforms.nix
    ./hosts/default.nix
    ./mcp-servers.nix
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
      github_mcp_token = {
        key = "github/mcp_token";
      };
    };
  };

  home.username = userConfig.username;
  home.homeDirectory = userConfig.homeDirectory;
  home.stateVersion = userConfig.stateVersion;

  programs.home-manager.enable = true;

  # Platform-specific configurations are handled in platforms.nix

  # Ensure sops-nix service waits for home directory to be ready
  systemd.user.services.sops-nix = {
    Unit = {
      After = [ "graphical-session.target" ];
      # Ensure the service starts after the file system is ready
      RequiresMountsFor = [ config.home.homeDirectory ];
    };
  };

}
