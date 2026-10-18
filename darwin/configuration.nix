{ config, pkgs, lib, ... }:

let
  userConfig = import ../user-config.nix;
in

{
  # Set hostname (optional but recommended)
  networking.hostName = "CxGawd";
  networking.computerName = "CxGawd";

  # Nix configuration
  nix.package = pkgs.nixVersions.latest;
  nix.settings = {
    experimental-features = [ "nix-command" "flakes" ];
    # Use binary caches to avoid building from source
    substituters = [
      "https://cache.nixos.org"
    ];
    trusted-public-keys = [
      "cache.nixos.org-1:6NCHdD59X431o0gWypbMrAURkbJ16ZPMQFGspcDShjY="
    ];
    # Allow building from source as fallback, but prefer binaries
    fallback = true;
  };

  # Automatic store maintenance (launchd). Daily, matching the NixOS module
  # defaults: 03:15 collect garbage and drop generations older than 14 days,
  # 03:45 dedupe the store. (nix-darwin's own default is weekly.)
  nix.gc = {
    automatic = true;
    interval = { Hour = 3; Minute = 15; };
    options = "--delete-older-than 14d";
  };
  nix.optimise = {
    automatic = true;
    interval = { Hour = 3; Minute = 45; };
  };

  # Allow unfree packages
  nixpkgs.config.allowUnfree = true;

  # Keep existing UID/GID ranges (existing Nix installation)
  ids.uids.nixbld = 300;
  ids.gids.nixbld = 30000;

  # System packages available to all users
  environment.systemPackages = with pkgs; [
    bazelisk
    gh
    git
  ];

  # User configuration
  users.users.${userConfig.username} = {
    home = userConfig.homeDirectory;
    shell = pkgs.fish;
  } // lib.optionalAttrs (userConfig.uid or null != null) {
    uid = userConfig.uid;
  };

  # nix-darwin only applies `shell` (and other properties) to users it
  # manages, so the login shell stays whatever macOS set until the user is
  # listed here. That requires the uid, which lives in the untracked
  # user-config.nix; without it the user is left alone.
  users.knownUsers = lib.optional (userConfig.uid or null != null) userConfig.username;

  # Enable fish shell
  programs.fish.enable = true;

  # Home Manager integration
  # This is configured in the flake.nix

  # Used for backwards compatibility, please read the changelog before changing.
  # $ darwin-rebuild changelog
  system.stateVersion = 5;
}
