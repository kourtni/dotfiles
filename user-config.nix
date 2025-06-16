# User Configuration
# Copy this file and modify the values to match your setup

{
  # User settings
  username = "kourtni";
  homeDirectory = "/home/kourtni";
  
  # Git settings (can be overridden by sops secrets if configured)
  git = {
    name = "Your Name";
    email = "your.email@example.com";
  };
  
  # Platform-specific paths
  windowsUsername = "klact"; # Your Windows username for WSL VS Code integration
  
  # System settings
  stateVersion = "24.11"; # Home Manager state version
}