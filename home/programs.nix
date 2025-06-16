{ config, pkgs, lib, ... }:

let
  userConfig = import ../user-config.nix;
  
  # Platform detection
  isLinux = pkgs.stdenv.isLinux;
  isDarwin = pkgs.stdenv.isDarwin;
  isWSL = builtins.pathExists /proc/sys/fs/binfmt_misc/WSLInterop;
  
  # Platform-specific VS Code paths
  vscodeWSLPath = "/mnt/c/Users/${userConfig.windowsUsername}/AppData/Local/Programs/Microsoft VS Code/bin";
  vscodeDarwinPath = "/Applications/Visual Studio Code.app/Contents/Resources/app/bin";
  
  # Determine VS Code path based on platform
  vscodePath = if isWSL then vscodeWSLPath
               else if isDarwin then vscodeDarwinPath
               else null; # No default path for native Linux
in

{
  
  programs.git = {
    enable = true;
    # Fallback git config (can be overridden by sops secrets)
    userName = userConfig.git.name;
    userEmail = userConfig.git.email;
    extraConfig = {
      credential.helper = "store";
    };
  };

  # Set up git credentials and config via activation script that can read sops secrets
  home.activation.setupGitSecrets = config.lib.dag.entryAfter ["writeBoundary"] ''
    # Set git user name and email from sops secrets (overrides default config)
    if [ -f "${config.sops.secrets.github_name.path}" ] && [ -f "${config.sops.secrets.github_email.path}" ]; then
      ${pkgs.git}/bin/git config --global user.name "$(cat ${config.sops.secrets.github_name.path})"
      ${pkgs.git}/bin/git config --global user.email "$(cat ${config.sops.secrets.github_email.path})"
      echo "✅ Git user config updated from sops secrets"
    else
      echo "ℹ️  Using git config from user-config.nix (no sops secrets found)"
    fi
    
    # Set up git credentials from sops secrets
    if [ -f "${config.sops.secrets.github_token.path}" ]; then
      echo "https://$(cat ${config.sops.secrets.github_token.path}):x-oauth-basic@github.com" > ~/.git-credentials
      echo "✅ Git credentials updated from sops secrets"
    else
      echo "ℹ️  No GitHub token found in sops secrets"
    fi
  '';

  programs.fish = {
    enable = true;

    shellInit = ''
      direnv hook fish | source
      set -gx EDITOR nvim
      fish_vi_key_bindings

      # Runtime platform detection for Linux systems
      if test (uname) = "Linux"
        # Detect WSL environment
        if test -e /proc/sys/fs/binfmt_misc/WSLInterop; or test -e /run/WSL; or string match -q "*microsoft*" (uname -r)
          set -gx WSL "true"
          set -gx SYSTEM_TYPE "wsl"
        else
          set -gx WSL "false"
          set -gx SYSTEM_TYPE "linux"
        end
      end
    '' + lib.optionalString (vscodePath != null) ''

      # Add VS Code CLI to PATH (Platform-specific)
      set -l code_bin "${vscodePath}"
      if test -d "$code_bin"
        set -gx PATH $code_bin $PATH
      end
    '';

    functions = {
      ll = "ls -l";
      gs = "git status";
      hm-rebuild = "nix run ~/dotfiles#home-manager -- switch --flake ~/dotfiles --recreate-lock-file";
    };
  };

  programs.starship = {
    enable = true;
    enableFishIntegration = true;
    settings = import ./starship-settings-from-toml.nix;
  };

  fonts.fontconfig.enable = true;

  # Add npm global bin to PATH
  home.sessionPath = [
    "$HOME/.npm-global/bin"
  ];

  # REPRODUCIBLE: Auto-install Claude Code via Home Manager activation
  home.activation.claudeCode = config.lib.dag.entryAfter ["writeBoundary"] ''
    set -e  # Exit on any error
    
    echo "🔧 Setting up Claude Code (v6)..."
    
    # Create npm global directory in home
    export NPM_CONFIG_PREFIX="$HOME/.npm-global"
    mkdir -p "$HOME/.npm-global"
    
    # Add Node.js and npm to PATH for this activation script
    export PATH="${pkgs.nodejs_22}/bin:${pkgs.nodePackages.npm}/bin:$PATH"
    
    echo "✅ node found: $(which node)"
    echo "✅ npm found: $(which npm)"
    echo "📍 NPM prefix: $NPM_CONFIG_PREFIX"
    
    # Install or update Claude Code
    if [ ! -f "$HOME/.npm-global/bin/claude" ]; then
      echo "📦 Installing Claude Code..."
      npm install -g @anthropic-ai/claude-code || {
        echo "❌ Failed to install Claude Code"
        exit 1
      }
      echo "✅ Claude Code installed successfully!"
    else
      echo "🔄 Claude Code already installed, checking for updates..."
      npm update -g @anthropic-ai/claude-code || {
        echo "⚠️  Failed to update Claude Code, but continuing..."
      }
    fi
    
    echo "📋 Contents of ~/.npm-global/bin/:"
    ls -la "$HOME/.npm-global/bin/" || echo "Directory doesn't exist yet"
  '';

}
