{ config, pkgs, lib, ... }:

let
  userConfig = import ../user-config.nix;
  npmUtils = import ./npm-utils.nix { inherit pkgs; };
  
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
        set -l is_wsl "false"
        if test -e /proc/sys/fs/binfmt_misc/WSLInterop; or test -e /run/WSL; or string match -q "*microsoft*" (uname -r)
          set is_wsl "true"
        end
        
        # Detect NixOS
        set -l is_nixos "false"
        if test -d /etc/nixos
          set is_nixos "true"
        end
        
        # Set granular system type
        if test "$is_wsl" = "true"; and test "$is_nixos" = "true"
          set -gx SYSTEM_TYPE "nixos-wsl"
        else if test "$is_wsl" = "true"
          set -gx SYSTEM_TYPE "linux-wsl"
        else if test "$is_nixos" = "true"
          set -gx SYSTEM_TYPE "nixos"
        else
          set -gx SYSTEM_TYPE "linux"
        end
        
        # Set detection variables
        set -gx IS_WSL "$is_wsl"
        set -gx IS_NIXOS "$is_nixos"
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
      hm-rebuild = "nix run ~/dotfiles#home-manager -- switch --flake ~/dotfiles";
      # Portable VS Code launcher that works on any WSL system
      code = ''
        # Check if we're in WSL first
        if not test -f /proc/sys/fs/binfmt_misc/WSLInterop
            # Not in WSL, try native code command
            command code $argv
            return
        end
        
        # Try to find VS Code in common Windows locations
        set -l vscode_paths \
            "/mnt/c/Program Files/Microsoft VS Code/bin/code" \
            "/mnt/c/Program Files (x86)/Microsoft VS Code/bin/code" \
            "/mnt/c/Users/$USER/AppData/Local/Programs/Microsoft VS Code/bin/code"
        
        # Also check with Windows username from Nix config
        set -l win_user "${userConfig.windowsUsername}"
        if test -n "$win_user"
            set vscode_paths $vscode_paths "/mnt/c/Users/$win_user/AppData/Local/Programs/Microsoft VS Code/bin/code"
        end
        
        # Try each path until we find one that exists
        for vscode_path in $vscode_paths
            if test -f "$vscode_path"
                # Check if it starts with a shebang (shell script)
                if head -n 1 "$vscode_path" 2>/dev/null | grep -q "^#!"
                    "$vscode_path" $argv
                    return
                end
            end
        end
        
        echo "VS Code not found. Please ensure it's installed on Windows." >&2
        return 1
      '';
    };
  };

  programs.starship = {
    enable = true;
    enableFishIntegration = true;
    settings = if isDarwin then {
      # Minimal Darwin config without Nerd Font symbols to avoid fontconfig dependencies
      format = "$all$character";
      character = {
        success_symbol = "[>](bold green)";
        error_symbol = "[>](bold red)";
      };
      directory = {
        truncation_length = 3;
        truncate_to_repo = true;
      };
      git_branch = {
        symbol = "";
        format = "[$symbol$branch]($style) ";
      };
      git_status = {
        format = "[$all_status$ahead_behind]($style) ";
      };
      # Add other essential modules without Nerd Font icons
    } else import ./starship-settings-from-toml.nix;
  };

  fonts.fontconfig.enable = pkgs.stdenv.isLinux;

  # Add npm global bin to PATH
  home.sessionPath = [
    "$HOME/.npm-global/bin"
  ];

  # REPRODUCIBLE: Auto-install Claude Code via Home Manager activation
  home.activation.claudeCode = config.lib.dag.entryAfter ["writeBoundary"] (
    npmUtils.mkNpmPackageActivation {
      packageName = "@anthropic-ai/claude-code";
      binaryName = "claude";
      displayName = "Claude Code";
    }
  );

  # REPRODUCIBLE: Auto-install Google Gemini CLI via Home Manager activation
  home.activation.geminiCLI = config.lib.dag.entryAfter ["writeBoundary"] (
    npmUtils.mkNpmPackageActivation {
      packageName = "@google/gemini-cli";
      binaryName = "gemini";
      displayName = "Google Gemini CLI";
    }
  );

}
