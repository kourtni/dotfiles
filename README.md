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

### One-Command Installation

```bash
# Install on any supported platform
nix run github:kourtni/dotfiles#home-manager -- switch --flake github:kourtni/dotfiles
```

Or clone and install locally:

```bash
git clone https://github.com/kourtni/dotfiles.git
cd dotfiles
nix run .#home-manager -- switch --flake .
```

## 🖥️ Supported Platforms

| Platform | Architecture | Status |
|----------|-------------|--------|
| Linux | x86_64 | ✅ |
| Linux | aarch64 | ✅ |
| macOS | x86_64 (Intel) | ✅ |
| macOS | aarch64 (Apple Silicon) | ✅ |
| WSL2 | x86_64 | ✅ |

## 📁 Project Structure

```
dotfiles/
├── flake.nix              # Main flake configuration
├── flake.lock             # Locked dependencies
├── home/
│   ├── default.nix        # Main home-manager configuration
│   ├── programs.nix       # Program configurations (git, fish, etc.)
│   ├── platforms.nix      # Platform-specific settings
│   ├── hosts/             # Host-specific overrides
│   ├── secrets/           # Encrypted secrets
│   └── starship-settings-from-toml.nix  # Starship prompt config
├── nixos/
│   ├── configuration.nix  # NixOS system configuration (WSL)
│   └── hardware-configuration.nix
└── README.md
```

## 🔧 Configuration Details

### Shell Environment

- **Shell**: Fish with vi key bindings
- **Prompt**: Starship with custom Gruvbox theme
- **Editor**: Neovim (set as `$EDITOR`)
- **Aliases**: `ll`, `gs` (git status), `hm-rebuild`

### Development Tools

- **Node.js**: Version 22 with npm
- **Git**: Configured with secrets management
- **Claude Code**: Auto-installed CLI tool
- **VS Code**: Platform-aware PATH integration
- **Fonts**: Multiple Nerd Fonts for terminal icons

### Platform-Specific Features

The configuration automatically detects your platform and adapts:

- **WSL**: Adds Windows VS Code to PATH (`/mnt/c/...`)
- **macOS**: Sets Homebrew prefix, uses macOS VS Code path
- **Linux**: Native Linux optimizations
- **Environment Variables**: `SYSTEM_TYPE`, `WSL` for platform detection

## 🔐 Secrets Management

This configuration uses [sops-nix](https://github.com/Mic92/sops-nix) for secure secrets management.

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
# Use specific system configuration
home-manager switch --flake .#kourtni@x86_64-darwin   # macOS Intel
home-manager switch --flake .#kourtni@aarch64-darwin  # macOS Apple Silicon
home-manager switch --flake .#kourtni@x86_64-linux    # Linux x64
home-manager switch --flake .#kourtni@aarch64-linux   # Linux ARM
```

### NixOS (WSL)

```bash
# Rebuild NixOS configuration
sudo nixos-rebuild switch --flake .#wsl
```

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

## 🐛 Troubleshooting

### Common Issues

1. **Secrets not decrypting**: Ensure your age key is in `~/.config/sops/age/keys.txt`
2. **VS Code not in PATH**: Check platform detection with `echo $SYSTEM_TYPE`
3. **Permission errors**: Ensure Nix has proper permissions for your user

### Debug Commands

```bash
# Check platform detection
echo $SYSTEM_TYPE

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