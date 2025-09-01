{ config, pkgs, lib, ... }:

let
  # Platform detection
  isLinux = pkgs.stdenv.isLinux;
  isDarwin = pkgs.stdenv.isDarwin;
  
  # Import shared npm utilities
  npmUtils = import ./npm-utils.nix { inherit pkgs; };
  
  # Only build these wrappers on Linux where they're used
  shadcnUiMcpServerWrapper = if isLinux then
    pkgs.writeShellScriptBin "shadcn-ui-mcp-server" ''
      # Load GitHub token from sops if available
      if [ -f "${config.sops.secrets.github_mcp_token.path}" ]; then
        export GITHUB_PERSONAL_ACCESS_TOKEN="$(cat ${config.sops.secrets.github_mcp_token.path})"
        echo "✅ Using GitHub MCP token from sops"
      else
        echo "ℹ️  No GitHub MCP token found, running with default rate limits"
      fi
      
      # Run the MCP server
      exec ${pkgs.nodejs_22}/bin/npx @jpisnice/shadcn-ui-mcp-server "$@"
    ''
  else null;
  
  context7McpServerWrapper = if isLinux then
    pkgs.writeShellScriptBin "context7-mcp-server" ''
      # Run the context7 MCP server
      exec ${pkgs.nodejs_22}/bin/npx -y @upstash/context7-mcp "$@"
    ''
  else null;
  
  # Define the mcp-testing-sensei binary
  mcpTestingSenseiBinary = pkgs.fetchurl {
    url = "https://github.com/kourtni/mcp-testing-sensei/releases/download/v0.2.1/mcp-testing-sensei-${if pkgs.stdenv.isDarwin then "macos" else "linux"}";
    sha256 = if pkgs.stdenv.isDarwin 
      then "1yrqmgyzf7zffl9vzdjz7v6ipdxrjvyw21i57gdhdwdis7y8f0qp"  # Need to update this for macOS
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
  # Install npm packages via activation scripts (works on all platforms)
  home.activation.shadcnUiMcpServer = config.lib.dag.entryAfter ["writeBoundary"] (
    npmUtils.mkNpmPackageActivation {
      packageName = "@jpisnice/shadcn-ui-mcp-server";
      binaryName = "shadcn-mcp";
      displayName = "shadcn-ui-mcp-server";
    }
  );

  home.activation.context7McpServer = config.lib.dag.entryAfter ["writeBoundary"] (
    npmUtils.mkNpmPackageActivation {
      packageName = "@upstash/context7-mcp";
      binaryName = "context7-mcp";
      displayName = "context7-mcp-server";
    }
  );

  # Create systemd user services for Linux/WSL only
  systemd.user.services.shadcn-ui-mcp-server = lib.mkIf isLinux {
    Unit = {
      Description = "shadcn/ui MCP Server";
      Documentation = "https://github.com/Jpisnice/shadcn-ui-mcp-server";
    };

    Service = {
      Type = "simple";
      ExecStart = "${shadcnUiMcpServerWrapper}/bin/shadcn-ui-mcp-server";
      
      Environment = [
        "NPM_CONFIG_PREFIX=%h/.npm-global"
        "PATH=${pkgs.nodejs_22}/bin:%h/.npm-global/bin:/usr/bin:/bin"
      ];
      
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
      ExecStart = "${context7McpServerWrapper}/bin/context7-mcp-server";
      
      Environment = [
        "NPM_CONFIG_PREFIX=%h/.npm-global"
        "PATH=${pkgs.nodejs_22}/bin:%h/.npm-global/bin:/usr/bin:/bin"
      ];
      
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
      ExecStart = "${mcpTestingSensei}/bin/mcp-testing-sensei";
      
      Environment = [
        "PATH=/usr/bin:/bin"
      ];
      
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

  # Note: On macOS, MCP servers are run on-demand by Claude Code directly
  # We don't need launchd agents since the npm packages are installed globally
  # and Claude Code will invoke them as needed via the .mcp.json configuration

  # Add packages to home only for the platforms where they work
  home.packages = lib.optionals isLinux [
    shadcnUiMcpServerWrapper
    context7McpServerWrapper
    mcpTestingSensei
  ] ++ lib.optionals isDarwin [
    # Only the testing-sensei binary works standalone on Darwin
    mcpTestingSensei
  ];

  # Add information about MCP server management to the user's shell
  # These functions work cross-platform but behave differently
  programs.fish.shellInit = lib.mkIf config.programs.fish.enable (
    if isLinux then ''
      # MCP server management functions for Linux
      function mcp-shadcn-status
        systemctl --user status shadcn-ui-mcp-server
      end
      
      function mcp-shadcn-start
        systemctl --user start shadcn-ui-mcp-server
      end
      
      function mcp-shadcn-stop
        systemctl --user stop shadcn-ui-mcp-server
      end
      
      function mcp-context7-status
        systemctl --user status context7-mcp-server
      end
      
      function mcp-context7-start
        systemctl --user start context7-mcp-server
      end
      
      function mcp-context7-stop
        systemctl --user stop context7-mcp-server
      end
      
      function mcp-testing-sensei-status
        systemctl --user status mcp-testing-sensei
      end
      
      function mcp-testing-sensei-start
        systemctl --user start mcp-testing-sensei
      end
      
      function mcp-testing-sensei-stop
        systemctl --user stop mcp-testing-sensei
      end
    '' else if isDarwin then ''
      # MCP server info for macOS
      # On macOS, MCP servers are invoked on-demand by Claude Code
      # These functions provide helpful information
      
      function mcp-status
        echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
        echo "📝 MCP Servers on macOS"
        echo ""
        echo "MCP servers are invoked on-demand by Claude Code."
        echo "No manual start/stop is needed."
        echo ""
        echo "Installed servers:"
        if test -f ~/.npm-global/bin/shadcn-mcp
          echo "  ✅ shadcn-ui-mcp-server"
        else
          echo "  ❌ shadcn-ui-mcp-server (not installed)"
        end
        if test -f ~/.npm-global/bin/context7-mcp
          echo "  ✅ context7-mcp-server"
        else
          echo "  ❌ context7-mcp-server (not installed)"
        end
        if command -v mcp-testing-sensei >/dev/null 2>&1
          echo "  ✅ mcp-testing-sensei"
        else
          echo "  ❌ mcp-testing-sensei (not installed)"
        end
        echo ""
        echo "Configure in your project with:"
        echo "  ~/dotfiles/scripts/setup-mcp.sh"
        echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
      end
      
      # Provide helpful aliases that inform the user
      function mcp-shadcn-start
        echo "ℹ️  On macOS, MCP servers start automatically when Claude Code needs them."
        echo "Make sure you've configured your project with: ~/dotfiles/scripts/setup-mcp.sh"
      end
      
      function mcp-context7-start
        echo "ℹ️  On macOS, MCP servers start automatically when Claude Code needs them."
        echo "Make sure you've configured your project with: ~/dotfiles/scripts/setup-mcp.sh"
      end
      
      function mcp-testing-sensei-start
        echo "ℹ️  On macOS, MCP servers start automatically when Claude Code needs them."
        echo "Make sure you've configured your project with: ~/dotfiles/scripts/setup-mcp.sh"
      end
    '' else ""
  );
}