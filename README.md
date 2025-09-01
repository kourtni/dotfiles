# Kourtni's Dotfiles

A portable, reproducible development environment configuration using Nix flakes and Home Manager with secure secrets management.

## ✨ Features

- **🖥️ Multi-Platform Support**: Works on Linux, macOS, WSL, and various architectures
- **🔒 Secure Secrets Management**: Encrypted secrets using sops-nix and age encryption
- **🐚 Modern Shell**: Fish shell with Starship prompt and vi key bindings
- **🎨 Beautiful Terminal**: Gruvbox Dark theme with Nerd Fonts
- **🔧 Development Tools**: Node.js, npm, git, Claude Code CLI auto-installation
- **📦 Reproducible**: Declarative configuration with Nix flakes
- **⚡ Fast Setup**: One-command installation on any supported system

## 🚀 Quick Start

### Prerequisites

- [Nix package manager](https://nixos.org/download.html) with flakes enabled
- [Home Manager](https://github.com/nix-community/home-manager) (installed automatically)

### Setup Your Configuration

1. **Clone the repository**:
   ```bash
   git clone https://github.com/kourtni/dotfiles.git
   cd dotfiles
   ```

2. **Create your user configuration**:
   ```bash
   cp user-config.nix.template user-config.nix
   # Edit user-config.nix with your username, email, etc.
   ```

3. **Install**:
   
   **For macOS/Darwin users:**
   ```bash
   # Use the home-manager configuration (NOT nixosConfigurations)
   nix run .#home-manager -- switch --flake .
   # Or explicitly specify your system:
   nix run .#home-manager -- switch --flake .#$(whoami)@$(uname -m)-darwin
   ```
   
   **For Linux/WSL users:**
   ```bash
   nix run .#home-manager -- switch --flake .
   ```
   
   **For NixOS users:**
   ```bash
   sudo nixos-rebuild switch --impure --flake .#wsl
   ```

### Quick Install (Advanced)

If you want to try the configuration as-is:
```bash
# Uses default "kourtni" configuration
nix run github:kourtni/dotfiles#home-manager -- switch --flake github:kourtni/dotfiles
```

## 🖥️ Supported Platforms

The configuration automatically detects your platform and adapts accordingly:

| Platform | Architecture | Detection | Status |
|----------|-------------|-----------|--------|
| NixOS | x86_64, aarch64 | `nixos` | ✅ |
| NixOS on WSL | x86_64 | `nixos-wsl` | ✅ |
| Linux + Nix | x86_64, aarch64 | `linux` | ✅ |
| Linux + Nix on WSL | x86_64 | `linux-wsl` | ✅ |
| macOS + Nix | x86_64, aarch64 | `darwin` | ✅ |

**Platform Variables Available:**
- `SYSTEM_TYPE`: One of the detection values above
- `IS_NIXOS`: `true` on NixOS, `false` on other Linux distros
- `IS_WSL`: `true` in WSL environments, `false` on native systems

## 📁 Project Structure

```
dotfiles/
├── flake.nix                    # Main flake configuration
├── flake.lock                   # Locked dependencies
├── user-config.nix              # User-specific settings (create from template)
├── user-config.nix.template     # Template for user configuration
├── home/
│   ├── default.nix              # Main home-manager configuration
│   ├── programs.nix             # Program configurations (git, fish, etc.)
│   ├── platforms.nix            # Platform-specific settings and detection
│   ├── hosts/                   # Host-specific overrides
│   ├── secrets/                 # Encrypted secrets (sops-nix)
│   └── starship-settings-from-toml.nix  # Starship prompt config
├── nixos/
│   ├── configuration.nix        # NixOS system configuration
│   └── hardware-configuration.nix
└── README.md
```

## 🖥️ MCP Server Management

This repository can also be used to manage Model Context Protocol (MCP) server configurations.

- **Configuration**: Server details are defined in `home/mcp-servers.nix`.
- **Setup**: The `scripts/setup-mcp.sh` script applies the configurations to the servers.

### Available MCP Servers

1. **shadcn-ui-mcp-server**: Access to shadcn/ui v4 components and blocks
2. **context7**: Upstash Context7 MCP server for context management
3. **playwright**: Browser automation and testing via Playwright
4. **nixos**: NixOS configuration and package management assistance
5. **testing-sensei**: Enforces and guides unit testing principles in code generation

### Managing MCP Servers

#### On Linux/WSL:
MCP servers can be managed as systemd services:

```bash
# For managed servers (shadcn, context7, testing-sensei):
mcp-<server>-status   # Check server status via systemctl
mcp-<server>-start    # Start the server via systemctl
mcp-<server>-stop     # Stop the server via systemctl
```

#### On macOS:
MCP servers are invoked on-demand by Claude Code directly. No manual management is needed.

```bash
mcp-status           # Check which MCP servers are installed
mcp-<server>-start   # Shows info that servers auto-start on macOS
```

**Note**: The `playwright` and `nixos` servers are invoked on-demand on all platforms.

### Adding MCP Servers to Projects

Run the setup script in any project directory:
```bash
~/dotfiles/scripts/setup-mcp.sh
```

This creates a `.mcp.json` file that configures Claude Code to use the available MCP servers.

## NixOS Hardware Configuration

For NixOS systems, this repository expects a `hardware-configuration.nix` file to be present in the `nixos/` directory. This file is machine-specific and should **not** be committed to the repository.

**To set up your `hardware-configuration.nix`:**

1.  **Generate the file on your NixOS system**:
    ```bash
    sudo nixos-generate-config --show-configuration > /tmp/hardware-configuration.nix
    ```
2.  **Copy it to your dotfiles**:
    ```bash
    cp /tmp/hardware-configuration.nix nixos/hardware-configuration.nix
    ```
    (Ensure you are in the root of your dotfiles repository when running this command.)
3.  **Add it to your local `.gitignore`**:
    To prevent accidentally committing your machine-specific hardware configuration, add the following line to your `.gitignore` file:
    ```
    nixos/hardware-configuration.nix
    ```
    This step is crucial for maintaining the portability of your dotfiles.

## 🔧 Configuration Details

### Shell Environment

- **Shell**: Fish with vi key bindings
- **Prompt**: Starship with custom Gruvbox theme
- **Editor**: Neovim (set as `$EDITOR`)
- **Aliases**: `ll`, `gs` (git status), `hm-rebuild` (works on all platforms)

### Development Tools

- **Node.js**: Version 22 with npm
- **Git**: Configured with secrets management
- **Claude Code**: Auto-installed CLI tool
- **VS Code**: Platform-aware PATH integration
- **Fonts**: Multiple Nerd Fonts for terminal icons (auto-installed on Linux, manual install required on macOS)

### Platform-Specific Features

The configuration automatically detects your platform and adapts:

- **NixOS**: Handles Nix store paths and NixOS-specific filesystem layout
- **Traditional Linux**: Uses standard paths like `/bin/bash` for compatibility  
- **WSL**: Adds Windows VS Code integration, cross-platform file access
- **macOS**: Sets Homebrew prefix, uses macOS-specific paths, provides font installation instructions
- **Environment Variables**: `SYSTEM_TYPE`, `IS_NIXOS`, `IS_WSL` for platform detection

## 🔐 Secrets Management

This configuration uses [sops-nix](https://github.com/Mic92/sops-nix) for secure secrets management. Works identically on all platforms (Linux, WSL, macOS).

### For New Users

1. **Generate your age key**:
   ```bash
   mkdir -p ~/.config/sops/age
   age-keygen -o ~/.config/sops/age/keys.txt
   ```

2. **Get your public key**:
   ```bash
   age-keygen -y ~/.config/sops/age/keys.txt
   ```

3. **Create your secrets file**:
   ```bash
   # Copy the example and edit with your values
   cp home/secrets/secrets.yaml.example home/secrets/secrets.yaml
   
   # Encrypt with your age key
   sops -e -a $(age-keygen -y ~/.config/sops/age/keys.txt) home/secrets/secrets.yaml > home/secrets/secrets.enc.yaml
   ```

4. **Update the flake**: Replace the age recipient in `home/secrets/secrets.enc.yaml` with your public key.

### Secrets Structure

```yaml
# home/secrets/secrets.yaml (unencrypted template)
github:
  name: "Your Name"
  email: "your.email@example.com"
  token: "ghp_your_github_token"
```

## 🏠 Host-Specific Customization

Add host-specific configurations in `home/hosts/default.nix`:

```nix
{ config, pkgs, ... }:
{
  # Add your host-specific overrides here
  home.packages = with pkgs; [
    # Additional packages for this host
  ];
}
```

## 📋 Available Commands

### Home Manager

```bash
# Switch to new configuration
home-manager switch --flake .

# Switch and recreate lock file
nix run .#home-manager -- switch --flake . --recreate-lock-file

# Quick rebuild (aliased as 'hm-rebuild' in fish)
hm-rebuild
```

### System-Specific Commands

```bash
# Use specific system configuration (replace 'username' with your actual username)
home-manager switch --flake .#username@x86_64-darwin   # macOS Intel
home-manager switch --flake .#username@aarch64-darwin  # macOS Apple Silicon
home-manager switch --flake .#username@x86_64-linux    # Linux x64
home-manager switch --flake .#username@aarch64-linux   # Linux ARM
```

### NixOS (WSL)

```bash
# Rebuild NixOS configuration
sudo nixos-rebuild switch --impure --flake .#wsl
```
We need `--impure` because our build build relies on the host specific, locally
installed `/etc/nixos/hardware-configuration.nix` file.

## ⚙️ User Configuration

The `user-config.nix` file contains all user-specific settings:

```nix
{
  # User settings
  username = "your-username";
  homeDirectory = "/home/your-username";
  
  # Git settings (overridden by sops secrets if configured)
  git = {
    name = "Your Full Name";
    email = "your.email@example.com";
  };
  
  # Platform-specific paths
  windowsUsername = "your-windows-username"; # For WSL VS Code integration (ignored on macOS)
  
  # System settings
  stateVersion = "24.11"; # Home Manager state version
}
```

This approach makes the dotfiles completely generic while allowing easy customization.

## 🔄 Updating

```bash
# Update flake inputs
nix flake update

# Apply updates
home-manager switch --flake .
```

## 🛠️ Customization

### Adding Packages

Edit `home/platforms.nix` to add packages:

```nix
home.packages = with pkgs; [
  # Your additional packages
  firefox
  discord
];
```

### Platform-Specific Packages

```nix
# In home/platforms.nix
++ lib.optionals isDarwin [
  # macOS-specific packages
]
++ lib.optionals isLinux [
  # Linux-specific packages
]
```

### Modifying Shell Configuration

Edit `home/programs.nix` to customize fish shell, git, or other programs.

## 🎨 Fonts on macOS

Due to fontconfig dependencies that are Linux-specific, Nerd Fonts need to be installed separately on macOS:

### Via Homebrew (Recommended):
```bash
brew tap homebrew/cask-fonts
brew install --cask font-0xproto-nerd-font
brew install --cask font-droid-sans-mono-nerd-font
brew install --cask font-fira-code-nerd-font
brew install --cask font-jetbrains-mono-nerd-font
brew install --cask font-hack-nerd-font
```

### Manual Installation:
Download fonts from [Nerd Fonts Downloads](https://www.nerdfonts.com/font-downloads) and install them by double-clicking the `.ttf` files.

## 🐛 Troubleshooting

### Common Issues

1. **Secrets not decrypting**: Ensure your age key is in `~/.config/sops/age/keys.txt`
2. **VS Code not in PATH**: Check platform detection with `echo $SYSTEM_TYPE`
3. **Permission errors**: Ensure Nix has proper permissions for your user
4. **`code` command not found in Fish shell**: The configuration includes a portable `code` function that works on all platforms. If it still doesn't work:
   ```bash
   mkdir -p ~/.config/fish/functions
   echo 'function code
       "/mnt/c/Users/YOUR_USERNAME/AppData/Local/Programs/Microsoft VS Code/bin/code" $argv
   end' > ~/.config/fish/functions/code.fish
   ```
   Replace `YOUR_USERNAME` with your Windows username. This manually overrides the built-in function.

5. **VS Code Remote-WSL fails on NixOS** with error "Could not start dynamically linked executable": This occurs because VS Code's node binary cannot find required shared libraries on NixOS. To fix:
   
   a. Create the `server-env-setup` script that VS Code will run automatically:
   ```bash
   # Copy the server-env-setup script from sonowz/vscode-remote-wsl-nixos
   curl -o ~/.vscode-server/server-env-setup https://raw.githubusercontent.com/sonowz/vscode-remote-wsl-nixos/master/server-env-setup
   ```
   
   b. If you still get "libstdc++.so.6: cannot open shared object file", manually patch the node binary:
   ```bash
   # Patch the VS Code server node binary with correct library paths  
   nix shell nixpkgs#patchelf nixpkgs#stdenv.cc -c patchelf --set-rpath "$(nix eval --raw nixpkgs#stdenv.cc.cc.lib)/lib/" ~/.vscode-server/bin/*/node
   ```
   
   c. Try `code .` again - it should now work properly.
   
   Note: You may need to repeat step (b) after VS Code updates, as new versions will download fresh unpatched binaries.

### Debug Commands

```bash
# Check platform detection (works on all platforms)
echo "System: $SYSTEM_TYPE, NixOS: $IS_NIXOS, WSL: $IS_WSL"

# View decrypted secrets (for debugging)
sops -d home/secrets/secrets.enc.yaml

# Check flake evaluation
nix flake check
```

## 📄 License

This configuration is open source and available under the [MIT License](LICENSE).

## 🤝 Contributing

Feel free to fork this repository and adapt it for your own use! If you find improvements or fixes, pull requests are welcome.

## 🙏 Acknowledgments

- [Nix](https://nixos.org/) - Reproducible package management
- [Home Manager](https://github.com/nix-community/home-manager) - Declarative dotfiles management
- [sops-nix](https://github.com/Mic92/sops-nix) - Secrets management for Nix
- [Starship](https://starship.rs/) - Cross-shell prompt
- [Fish Shell](https://fishshell.com/) - Friendly interactive shell

---

**Made with ❤️ and Nix**
