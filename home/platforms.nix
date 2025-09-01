{ config, pkgs, lib, ... }:

let
  # Base platform detection
  isLinux = pkgs.stdenv.isLinux;
  isDarwin = pkgs.stdenv.isDarwin;
  
  # WSL detection (independent of OS distribution)
  wslInteropExists = builtins.pathExists /proc/sys/fs/binfmt_misc/WSLInterop;
  kernelVersionContainsMicrosoft = 
    let
      versionFile = /proc/version;
    in
      if builtins.pathExists versionFile
      then builtins.match ".*microsoft.*" (builtins.readFile versionFile) != null
      else false;
  wslEnvExists = builtins.pathExists /run/WSL;
  
  isWSL = wslInteropExists || kernelVersionContainsMicrosoft || wslEnvExists;
  
  # NixOS detection (independent of WSL)
  isNixOS = builtins.pathExists /etc/nixos;
  
  # Granular system type detection
  systemType = if isDarwin then "darwin"
               else if isLinux && isWSL && isNixOS then "nixos-wsl"
               else if isLinux && isWSL then "linux-wsl"  
               else if isLinux && isNixOS then "nixos"
               else if isLinux then "linux"
               else "unknown";
               
in

{
  # Automatic font installation for macOS
  home.activation.installFonts = lib.mkIf isDarwin (config.lib.dag.entryAfter ["writeBoundary"] ''
    echo "🔤 Installing Nerd Fonts to macOS font directory..."
    
    # Create the font directory if it doesn't exist
    mkdir -p ~/Library/Fonts
    
    # Find and link all font files from Nix profile
    font_count=0
    if [ -d ~/.nix-profile/share/fonts ]; then
      find -L ~/.nix-profile/share/fonts \( -name "*.ttf" -o -name "*.otf" \) | while read font; do
        font_name=$(basename "$font")
        # Create symlink if it doesn't exist or points to a different file
        if [ ! -L ~/Library/Fonts/"$font_name" ] || [ "$(readlink ~/Library/Fonts/"$font_name")" != "$font" ]; then
          ln -sf "$font" ~/Library/Fonts/"$font_name"
          font_count=$((font_count + 1))
        fi
      done
    fi
    
    # Also check for fonts in the home-manager profile path
    if [ -d ~/.local/state/nix/profiles/home-manager/home-path/share/fonts ]; then
      find -L ~/.local/state/nix/profiles/home-manager/home-path/share/fonts \( -name "*.ttf" -o -name "*.otf" \) | while read font; do
        font_name=$(basename "$font")
        if [ ! -L ~/Library/Fonts/"$font_name" ] || [ "$(readlink ~/Library/Fonts/"$font_name")" != "$font" ]; then
          ln -sf "$font" ~/Library/Fonts/"$font_name"
          font_count=$((font_count + 1))
        fi
      done
    fi
    
    if [ $font_count -gt 0 ]; then
      echo "✅ Linked $font_count font files to ~/Library/Fonts"
      echo "ℹ️  You may need to restart your terminal for fonts to appear"
    else
      echo "ℹ️  Fonts already up to date in ~/Library/Fonts"
    fi
  '');

  # Platform-specific package sets
  home.packages = with pkgs; (
    # Common packages for all platforms
    [
      curl
      fish
      htop
      jq
      nodejs_22
      nodePackages.npm
      ollama
      vim
      
      # fonts
      nerd-fonts._0xproto
      nerd-fonts.droid-sans-mono
      nerd-fonts.fira-code
      nerd-fonts.jetbrains-mono
      nerd-fonts.hack
    ]
    # macOS-specific packages  
    ++ lib.optionals isDarwin [
      # Add macOS-specific packages here
    ]
    # NixOS-specific packages (handles NixOS quirks)
    ++ lib.optionals isNixOS [
      # Add NixOS-specific packages here
      # e.g., packages that work better on NixOS
      patchelf
      gcc
    ]
    # Traditional Linux packages (Ubuntu, Fedora, etc. + Nix)
    ++ lib.optionals (isLinux && !isNixOS) [
      # Add traditional Linux-specific packages here
      # e.g., packages that work better on traditional distros
    ]
    # WSL-specific packages (regardless of underlying distro)
    ++ lib.optionals isWSL [
      # Add WSL-specific packages here
      # e.g., wslu for WSL utilities
    ]
  );

  # Platform-specific environment variables
  # Note: WSL and SYSTEM_TYPE are set dynamically in shell init for Linux systems
  home.sessionVariables = {
    # Expose detection flags for scripts and applications
    IS_NIXOS = if isNixOS then "true" else "false";
  } // lib.optionalAttrs isDarwin {
    # Darwin-specific environment variables
    HOMEBREW_PREFIX = "/opt/homebrew";
    SYSTEM_TYPE = "darwin";
    IS_WSL = "false";
  } // lib.optionalAttrs isNixOS {
    # NixOS-specific environment variables
    # These help scripts know they're on NixOS with its unique filesystem
    NIXOS_SYSTEM = "true";
  } // lib.optionalAttrs (isLinux && !isNixOS) {
    # Traditional Linux environment variables
    NIXOS_SYSTEM = "false";
  };

  # Platform-specific configurations
  home.file = lib.mkMerge [
    # Common configurations
    {
      ".npmrc".text = ''
        prefix=~/.npm-global
        update-notifier=false
      '';
    }
    
    # macOS-specific configurations
    (lib.mkIf isDarwin {
      # Add macOS-specific file configurations here
    })
    
    # NixOS-specific configurations (handles NixOS filesystem quirks)
    (lib.mkIf (isNixOS && !isWSL) {
      # Add native NixOS-specific file configurations here
      # e.g., shell scripts with proper Nix store paths
    })
    
    # Traditional Linux-specific configurations 
    (lib.mkIf (isLinux && !isNixOS && !isWSL) {
      # Add native traditional Linux-specific file configurations here
      # e.g., shell scripts with traditional paths like /bin/bash
    })
    
    # WSL configurations (regardless of underlying distro)
    (lib.mkIf isWSL {
      # Add WSL-specific file configurations here
      # e.g., interop configurations, Windows path integrations
    })
    
    # NixOS on WSL specific configurations
    (lib.mkIf (isNixOS && isWSL) {
      # Add NixOS-WSL specific configurations here
      # Combination of NixOS quirks + WSL requirements
    })
    
    # Traditional Linux on WSL configurations
    (lib.mkIf (isLinux && !isNixOS && isWSL) {
      # Add traditional Linux-WSL specific configurations here
      # e.g., Ubuntu/Fedora on WSL with traditional paths
    })
  ];
}
