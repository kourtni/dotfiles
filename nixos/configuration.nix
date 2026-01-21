# Edit this configuration file to define what should be installed on
# your system. Help is available in the configuration.nix(5) man page, on
# https://search.nixos.org/options and in the NixOS manual (`nixos-help`).

# NixOS-WSL specific options are documented on the NixOS-WSL repository:
# https://github.com/nix-community/NixOS-WSL

{ config, lib, pkgs, ... }:

let
  userConfig = import ../user-config.nix;
in

{
  imports = [
    /etc/nixos/hardware-configuration.nix
  ];

  wsl.enable = true;
  wsl.defaultUser = userConfig.username;

  # Override problematic auto-generated mounts with nofail option
  fileSystems."/usr/lib/wsl/drivers" = lib.mkForce {
    device = "none";
    fsType = "none";
    options = [ "nofail" ];
  };

  # Nix configuration
  nix.package = pkgs.nixVersions.latest;
  nix.settings.experimental-features = [ "nix-command" "flakes" ];
  
  networking.hostName = "wsl"; # <- must match the flake output key

  users.users.${userConfig.username} = {
    isNormalUser = true;
    shell = pkgs.fish;
    extraGroups = [ "wheel" ];
  };

  time.timeZone = "America/Chicago";
  i18n.defaultLocale = "en_US.UTF-8";

  # Add some some basic system packages
  environment.systemPackages = with pkgs; [
    age
    direnv
    gh
    git
    neovim
    nix-direnv
    sops
    wget
  ];

  programs.fish.enable = true;
  programs.command-not-found.enable = true;

  # Enable nix-ld to run unpatched dynamic binaries on NixOS
  programs.nix-ld.enable = true;

  # This value determines the NixOS release from which the default
  # settings for stateful data, like file locations and database versions
  # on your system were taken. It's perfectly fine and recommended to leave
  # this value at the release version of the first install of this system.
  # Before changing this value read the documentation for this option
  # (e.g. man configuration.nix or on https://nixos.org/nixos/options.html).
  system.stateVersion = "24.11"; # Did you read the comment?
}
