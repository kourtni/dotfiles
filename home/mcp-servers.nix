{ config, pkgs, lib, ... }:

let
  # Platform detection
  isLinux = pkgs.stdenv.isLinux;
  isDarwin = pkgs.stdenv.isDarwin;
  
  # Define the wrapper script that handles GitHub token loading
  shadcnUiMcpServerWrapper = pkgs.writeShellScriptBin "shadcn-ui-mcp-server" ''
    # Load GitHub token from sops if available
    if [ -f "${config.sops.secrets.github_mcp_token.path}" ]; then
      export GITHUB_PERSONAL_ACCESS_TOKEN="$(cat ${config.sops.secrets.github_mcp_token.path})"
      echo "✅ Using GitHub MCP token from sops"
    else
      echo "ℹ️  No GitHub MCP token found, running with default rate limits"
    fi
    
    # Run the MCP server
    exec ${pkgs.nodejs_22}/bin/npx @jpisnice/shadcn-ui-mcp-server "$@"
  '';
in
{
  # Install shadcn-ui-mcp-server via npm
  home.activation.shadcnUiMcpServer = config.lib.dag.entryAfter ["writeBoundary"] ''
    set -e  # Exit on any error
    
    echo "🔧 Setting up shadcn-ui-mcp-server..."
    
    # Create npm global directory in home
    export NPM_CONFIG_PREFIX="$HOME/.npm-global"
    mkdir -p "$HOME/.npm-global"
    
    # Add Node.js and npm to PATH for this activation script
    export PATH="${pkgs.nodejs_22}/bin:${pkgs.nodePackages.npm}/bin:$PATH"
    
    echo "✅ node found: $(which node)"
    echo "✅ npm found: $(which npm)"
    echo "📍 NPM prefix: $NPM_CONFIG_PREFIX"
    
    # Install or update shadcn-ui-mcp-server
    if ! npm list -g @jpisnice/shadcn-ui-mcp-server >/dev/null 2>&1; then
      echo "📦 Installing shadcn-ui-mcp-server..."
      npm install -g @jpisnice/shadcn-ui-mcp-server || {
        echo "❌ Failed to install shadcn-ui-mcp-server"
        exit 1
      }
      echo "✅ shadcn-ui-mcp-server installed successfully!"
    else
      echo "🔄 shadcn-ui-mcp-server already installed, checking for updates..."
      npm update -g @jpisnice/shadcn-ui-mcp-server || {
        echo "⚠️  Failed to update shadcn-ui-mcp-server, but continuing..."
      }
    fi
  '';

  # Create systemd user service for Linux/WSL
  systemd.user.services.shadcn-ui-mcp-server = lib.mkIf isLinux {
    Unit = {
      Description = "shadcn/ui MCP Server";
      Documentation = "https://github.com/Jpisnice/shadcn-ui-mcp-server";
    };

    Service = {
      Type = "simple";
      # Use the wrapper script for consistency with macOS
      ExecStart = "${shadcnUiMcpServerWrapper}/bin/shadcn-ui-mcp-server";
      
      # Set up environment
      Environment = [
        "NPM_CONFIG_PREFIX=%h/.npm-global"
        "PATH=${pkgs.nodejs_22}/bin:%h/.npm-global/bin:/usr/bin:/bin"
      ];
      
      # Restart on failure
      Restart = "on-failure";
      RestartSec = "5s";
      
      # Security hardening
      PrivateTmp = true;
      ProtectSystem = "strict";
      ProtectHome = "read-only";
      ReadWritePaths = [
        "%h/.npm-global"
        "%h/.npm"
      ];
      NoNewPrivileges = true;
    };

    Install = {
      WantedBy = [ "default.target" ];
    };
  };

  # For macOS, create a launchd configuration
  launchd.agents.shadcn-ui-mcp-server = lib.mkIf isDarwin {
    enable = true;
    config = {
      Label = "com.github.jpisnice.shadcn-ui-mcp-server";
      ProgramArguments = [
        "${shadcnUiMcpServerWrapper}/bin/shadcn-ui-mcp-server"
      ];
      
      # Set up environment
      EnvironmentVariables = {
        NPM_CONFIG_PREFIX = "%h/.npm-global";
        PATH = "${pkgs.nodejs_22}/bin:%h/.npm-global/bin:/usr/bin:/bin";
      };

      RunAtLoad = false;
      KeepAlive = false;
      
      # Logging
      StandardOutPath = "%h/Library/Logs/shadcn-ui-mcp-server.log";
      StandardErrorPath = "%h/Library/Logs/shadcn-ui-mcp-server.error.log";
    };
  };

  # Add the wrapper script to home packages
  home.packages = [
    shadcnUiMcpServerWrapper
  ];

  # Add information about the MCP server to the user's shell
  programs.fish.shellInit = lib.mkIf config.programs.fish.enable ''
    # shadcn-ui-mcp-server info
    function mcp-shadcn-status
      if command -v systemctl >/dev/null 2>&1
        systemctl --user status shadcn-ui-mcp-server
      else if test (uname) = "Darwin"
        launchctl list | grep shadcn-ui-mcp-server
      else
        echo "MCP server status not available on this platform"
      end
    end
    
    function mcp-shadcn-start
      if command -v systemctl >/dev/null 2>&1
        systemctl --user start shadcn-ui-mcp-server
      else if test (uname) = "Darwin"
        launchctl load ~/Library/LaunchAgents/com.github.jpisnice.shadcn-ui-mcp-server.plist
      else
        shadcn-ui-mcp-server
      end
    end
    
    function mcp-shadcn-stop
      if command -v systemctl >/dev/null 2>&1
        systemctl --user stop shadcn-ui-mcp-server
      else if test (uname) = "Darwin"
        launchctl unload ~/Library/LaunchAgents/com.github.jpisnice.shadcn-ui-mcp-server.plist
      else
        echo "Use Ctrl+C to stop the MCP server"
      end
    end
  '';
}