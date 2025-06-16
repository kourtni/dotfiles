{ config, pkgs, lib, ... }:

let
  # Platform detection
  isLinux = pkgs.stdenv.isLinux;
  isDarwin = pkgs.stdenv.isDarwin;
  isWSL = builtins.pathExists /proc/sys/fs/binfmt_misc/WSLInterop;
  
  systemType = if isWSL then "wsl" 
               else if isDarwin then "darwin"
               else if isLinux then "linux"  
               else "unknown";
in

{
  # Platform-specific package sets
  home.packages = with pkgs; (
    # Common packages for all platforms
    [
      curl
      fish
      htop
      nodejs_22
      nodePackages.npm
      vim
      
      # fonts
      nerd-fonts._0xproto
      nerd-fonts.droid-sans-mono
      nerd-fonts.fira-code
      nerd-fonts.jetbrains-mono
      nerd-fonts.hack
    ]
    # Linux-specific packages
    ++ lib.optionals isLinux [
      # Add Linux-specific packages here
    ]
    # macOS-specific packages  
    ++ lib.optionals isDarwin [
      # Add macOS-specific packages here
    ]
    # WSL-specific packages
    ++ lib.optionals isWSL [
      # Add WSL-specific packages here
    ]
  );

  # Platform-specific environment variables
  home.sessionVariables = {
    SYSTEM_TYPE = systemType;
    WSL = if isWSL then "true" else "false";
  } // lib.optionalAttrs isDarwin {
    # Darwin-specific environment variables
    HOMEBREW_PREFIX = "/opt/homebrew";
  } // lib.optionalAttrs isLinux {
    # Linux-specific environment variables
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
    
    # Linux-specific configurations
    (lib.mkIf (isLinux && !isWSL) {
      # Add native Linux-specific file configurations here
    })
    
    # WSL-specific configurations
    (lib.mkIf isWSL {
      # Add WSL-specific file configurations here
    })
  ];
}