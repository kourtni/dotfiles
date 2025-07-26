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
  
  # Define the wrapper script for context7
  context7McpServerWrapper = pkgs.writeShellScriptBin "context7-mcp-server" ''
    # Run the context7 MCP server
    exec ${pkgs.nodejs_22}/bin/npx -y @upstash/context7-mcp "$@"
  '';
  
  # Define the mcp-testing-sensei binary
  mcpTestingSenseiBinary = pkgs.fetchurl {
    url = "https://github.com/kourtni/mcp-testing-sensei/releases/download/v0.2.1/mcp-testing-sensei-${if pkgs.stdenv.isDarwin then "macos" else "linux"}";
    sha256 = if pkgs.stdenv.isDarwin 
      then "1yrqmgyzf7zffl9vzdjz7v6ipdxrjvyw21i57gdhdwdis7y8f0qp"  # Need to update this for macOS with executable=true
      else "sha256-aguZR8/wFlM3aChWIIRXzpu/QvYgDrRkaq3rrESscNs=";
    executable = true;
  };
  
  # For Linux, use buildFHSEnv to provide a standard Linux environment
  mcpTestingSenseiFHS = if isLinux then pkgs.buildFHSEnv {
    name = "mcp-testing-sensei-fhs";
    targetPkgs = pkgs: with pkgs; [
      glibc
      gcc-unwrapped.lib
      zlib
      # Common Python dependencies
      expat
      libffi
      openssl
      ncurses6
      readline
      bzip2
      sqlite
      xz
    ];
    runScript = "${mcpTestingSenseiBinary}";
  } else null;
  
  # Create the final package
  mcpTestingSensei = if isLinux then 
    pkgs.writeShellScriptBin "mcp-testing-sensei" ''
      exec ${mcpTestingSenseiFHS}/bin/mcp-testing-sensei-fhs "$@"
    ''
  else if isDarwin then
    # For macOS, the binary should work directly
    pkgs.runCommand "mcp-testing-sensei" {} ''
      mkdir -p $out/bin
      cp ${mcpTestingSenseiBinary} $out/bin/mcp-testing-sensei
      chmod +x $out/bin/mcp-testing-sensei
    ''
  else throw "Unsupported platform";
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

  # Install context7-mcp-server via npm
  home.activation.context7McpServer = config.lib.dag.entryAfter ["writeBoundary"] ''
    set -e  # Exit on any error
    
    echo "🔧 Setting up context7-mcp-server..."
    
    # Create npm global directory in home
    export NPM_CONFIG_PREFIX="$HOME/.npm-global"
    mkdir -p "$HOME/.npm-global"
    
    # Add Node.js and npm to PATH for this activation script
    export PATH="${pkgs.nodejs_22}/bin:${pkgs.nodePackages.npm}/bin:$PATH"
    
    echo "✅ node found: $(which node)"
    echo "✅ npm found: $(which npm)"
    echo "📍 NPM prefix: $NPM_CONFIG_PREFIX"
    
    # Install or update context7-mcp-server
    if ! npm list -g @upstash/context7-mcp >/dev/null 2>&1; then
      echo "📦 Installing context7-mcp-server..."
      npm install -g @upstash/context7-mcp || {
        echo "❌ Failed to install context7-mcp-server"
        exit 1
      }
      echo "✅ context7-mcp-server installed successfully!"
    else
      echo "🔄 context7-mcp-server already installed, checking for updates..."
      npm update -g @upstash/context7-mcp || {
        echo "⚠️  Failed to update context7-mcp-server, but continuing..."
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

  systemd.user.services.context7-mcp-server = lib.mkIf isLinux {
    Unit = {
      Description = "Context7 MCP Server";
      Documentation = "https://github.com/upstash/context7";
    };

    Service = {
      Type = "simple";
      # Use the wrapper script
      ExecStart = "${context7McpServerWrapper}/bin/context7-mcp-server";
      
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

  systemd.user.services.mcp-testing-sensei = lib.mkIf isLinux {
    Unit = {
      Description = "MCP Testing Sensei Server";
      Documentation = "https://github.com/kourtni/mcp-testing-sensei";
    };

    Service = {
      Type = "simple";
      # Use the standalone binary directly
      ExecStart = "${mcpTestingSensei}/bin/mcp-testing-sensei";
      
      # Minimal environment setup - no npm or node required
      Environment = [
        "PATH=/usr/bin:/bin"
      ];
      
      # Restart on failure
      Restart = "on-failure";
      RestartSec = "5s";
      
      # Security hardening
      PrivateTmp = true;
      ProtectSystem = "strict";
      ProtectHome = "read-only";
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

  launchd.agents.context7-mcp-server = lib.mkIf isDarwin {
    enable = true;
    config = {
      Label = "com.upstash.context7-mcp-server";
      ProgramArguments = [
        "${context7McpServerWrapper}/bin/context7-mcp-server"
      ];
      
      # Set up environment
      EnvironmentVariables = {
        NPM_CONFIG_PREFIX = "%h/.npm-global";
        PATH = "${pkgs.nodejs_22}/bin:%h/.npm-global/bin:/usr/bin:/bin";
      };

      RunAtLoad = false;
      KeepAlive = false;
      
      # Logging
      StandardOutPath = "%h/Library/Logs/context7-mcp-server.log";
      StandardErrorPath = "%h/Library/Logs/context7-mcp-server.error.log";
    };
  };

  launchd.agents.mcp-testing-sensei = lib.mkIf isDarwin {
    enable = true;
    config = {
      Label = "com.kourtni.mcp-testing-sensei";
      ProgramArguments = [
        "${mcpTestingSensei}/bin/mcp-testing-sensei"
      ];
      
      # Minimal environment setup - no npm or node required
      EnvironmentVariables = {
        PATH = "/usr/bin:/bin";
      };

      RunAtLoad = false;
      KeepAlive = false;
      
      # Logging
      StandardOutPath = "%h/Library/Logs/mcp-testing-sensei.log";
      StandardErrorPath = "%h/Library/Logs/mcp-testing-sensei.error.log";
    };
  };

  # Add the wrapper scripts and standalone binary to home packages
  home.packages = [
    shadcnUiMcpServerWrapper
    context7McpServerWrapper
    mcpTestingSensei
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
    
    # context7-mcp-server info
    function mcp-context7-status
      if command -v systemctl >/dev/null 2>&1
        systemctl --user status context7-mcp-server
      else if test (uname) = "Darwin"
        launchctl list | grep context7-mcp-server
      else
        echo "MCP server status not available on this platform"
      end
    end
    
    function mcp-context7-start
      if command -v systemctl >/dev/null 2>&1
        systemctl --user start context7-mcp-server
      else if test (uname) = "Darwin"
        launchctl load ~/Library/LaunchAgents/com.upstash.context7-mcp-server.plist
      else
        context7-mcp-server
      end
    end
    
    function mcp-context7-stop
      if command -v systemctl >/dev/null 2>&1
        systemctl --user stop context7-mcp-server
      else if test (uname) = "Darwin"
        launchctl unload ~/Library/LaunchAgents/com.upstash.context7-mcp-server.plist
      else
        echo "Use Ctrl+C to stop the MCP server"
      end
    end
    
    # mcp-testing-sensei info
    function mcp-testing-sensei-status
      if command -v systemctl >/dev/null 2>&1
        systemctl --user status mcp-testing-sensei
      else if test (uname) = "Darwin"
        launchctl list | grep mcp-testing-sensei
      else
        echo "MCP server status not available on this platform"
      end
    end
    
    function mcp-testing-sensei-start
      if command -v systemctl >/dev/null 2>&1
        systemctl --user start mcp-testing-sensei
      else if test (uname) = "Darwin"
        launchctl load ~/Library/LaunchAgents/com.kourtni.mcp-testing-sensei.plist
      else
        mcp-testing-sensei
      end
    end
    
    function mcp-testing-sensei-stop
      if command -v systemctl >/dev/null 2>&1
        systemctl --user stop mcp-testing-sensei
      else if test (uname) = "Darwin"
        launchctl unload ~/Library/LaunchAgents/com.kourtni.mcp-testing-sensei.plist
      else
        echo "Use Ctrl+C to stop the MCP server"
      end
    end
  '';
}
