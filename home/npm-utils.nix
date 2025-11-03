# Shared utilities for npm package management
{ pkgs }:

{
  # Reusable function to generate npm package installation/update script
  mkNpmPackageActivation = { packageName, binaryName, displayName }: ''
    set -e  # Exit on any error
    
    echo "🔧 Setting up ${displayName}..."
    
    # Create npm global directory in home
    export NPM_CONFIG_PREFIX="$HOME/.npm-global"
    mkdir -p "$HOME/.npm-global"
    
    # Add Node.js (includes npm), and system tools to PATH for this activation script
    export PATH="${pkgs.nodejs_20}/bin:${pkgs.gnutar}/bin:${pkgs.gzip}/bin:$PATH"
    
    echo "✅ node found: $(which node 2>/dev/null || echo 'node')"
    echo "✅ npm found: $(which npm 2>/dev/null || echo 'npm')"
    echo "📍 NPM prefix: $NPM_CONFIG_PREFIX"
    
    # Install or update the package
    if [ ! -f "$HOME/.npm-global/bin/${binaryName}" ]; then
      echo "📦 Installing ${displayName}..."
      npm install -g ${packageName} || {
        echo "❌ Failed to install ${displayName}"
        exit 1
      }
      echo "✅ ${displayName} installed successfully!"
    else
      echo "🔄 ${displayName} already installed, checking for updates..."
      # Check if update is available
      CURRENT_VERSION=$(npm list -g ${packageName} --json 2>/dev/null | ${pkgs.jq}/bin/jq -r '.dependencies["${packageName}"].version' 2>/dev/null || echo "0.0.0")
      LATEST_VERSION=$(npm view ${packageName} version 2>/dev/null || echo "0.0.0")
      
      if [ "$CURRENT_VERSION" != "$LATEST_VERSION" ] && [ "$LATEST_VERSION" != "0.0.0" ]; then
        echo "📦 Update available: $CURRENT_VERSION → $LATEST_VERSION"
        
        # Extract org and package name for temp directory cleanup
        ORG_NAME=$(echo "${packageName}" | cut -d'/' -f1)
        PKG_NAME=$(echo "${packageName}" | cut -d'/' -f2)
        
        # Clean up any leftover temp directories first
        rm -rf "$HOME/.npm-global/lib/node_modules/$ORG_NAME/.$PKG_NAME-"* 2>/dev/null || true
        
        # Clean reinstall to avoid ENOTEMPTY errors
        npm uninstall -g ${packageName} 2>/dev/null || true
        npm install -g ${packageName} || {
          echo "⚠️  Failed to update ${displayName}, but continuing..."
        }
      else
        echo "✅ ${displayName} is up to date (version $CURRENT_VERSION)"
      fi
    fi
    
    echo "📋 Contents of ~/.npm-global/bin/:"
    ls -la "$HOME/.npm-global/bin/" || echo "Directory doesn't exist yet"
  '';
}
