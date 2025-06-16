{ config, pkgs, ... }:

{
  
  # programs.git = {
  #   enable = true;
  #   userName = builtins.readFile config.sops.secrets.github_name.path;
  #   userEmail = builtins.readFile config.sops.secrets.github_email.path;
  #
  #   extraConfig = {
  #     credential.helper = "store";
  #   };
  # };

  # home.file.".git-credentials".text =
  #   "https://${builtins.readFile config.sops.secrets.github_token.path}:x-oauth-basic@github.com";

  programs.fish = {
    enable = true;

    shellInit = ''
      direnv hook fish | source
      set -gx EDITOR nvim
      fish_vi_key_bindings

      # Add VS Code CLI to PATH (Fish requires extra care with paths that have spaces)
      set -l code_bin "/mnt/c/Users/klact/AppData/Local/Programs/Microsoft VS Code/bin"
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

  home.packages = with pkgs; [
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
  ];

  # Add npm global bin to PATH
  home.sessionPath = [
    "$HOME/.npm-global/bin"
  ];

  # Set up npm configuration
  home.file.".npmrc".text = ''
    prefix=~/.npm-global
    update-notifier=false
  '';

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
