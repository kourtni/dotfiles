{
  description = "NixOS WSL + Home Manager Config";

  inputs = {
    
    # Input for the STABLE system foundation
    nixpkgs.url = "github:NixOS/nixpkgs/nixos-25.05";

    # Input for UNSTABLE packages
    nixpkgs-unstable.url = "github:NixOS/nixpkgs/nixos-unstable";

    home-manager.url = "github:nix-community/home-manager/release-25.05";
    home-manager.inputs.nixpkgs.follows = "nixpkgs";
    
    nixos-wsl.url = "github:nix-community/NixOS-WSL";
    nixos-wsl.inputs.nixpkgs.follows = "nixpkgs";

    sops-nix.url = "github:Mic92/sops-nix";
    sops-nix.inputs.nixpkgs.follows = "nixpkgs";

    flake-programs-sqlite.url = "github:wamserma/flake-programs-sqlite";
    flake-programs-sqlite.inputs.nixpkgs.follows = "nixpkgs";
  };

  outputs = { self, nixpkgs, nixpkgs-unstable, home-manager, nixos-wsl, sops-nix, flake-programs-sqlite, ... }: 
    let
      # Supported systems
      supportedSystems = [ "x86_64-linux" "aarch64-linux" "x86_64-darwin" "aarch64-darwin" ];
      
      # Helper function to generate outputs for each system
      forAllSystems = nixpkgs.lib.genAttrs supportedSystems;
      
      # Default system for NixOS configurations
      defaultSystem = "x86_64-linux";
      pkgs = import nixpkgs { system = defaultSystem; };
    in {
      # Used by `sudo nixos-rebuild switch --flake`
      nixosConfigurations.wsl = nixpkgs.lib.nixosSystem {
        system = defaultSystem;
        modules = [
	  
          ({ pkgs, ... }: {
            nixpkgs.overlays = [
              (final: prev: {
                # This adds an 'unstable' attribute to your packages set
                # so you can access unstable packages via 'pkgs.unstable'
                unstable = import nixpkgs-unstable {
                  system = prev.system;
                  # You may need to pass config here if you use unfree packages
                  config.allowUnfree = true; 
                };
              })
            ];
          })

          nixos-wsl.nixosModules.default
          flake-programs-sqlite.nixosModules.programs-sqlite
          ./nixos/configuration.nix
          home-manager.nixosModules.home-manager
          {
            home-manager.useGlobalPkgs = true;
            home-manager.useUserPackages = true;
            home-manager.users.${(import ./user-config.nix).username} = import ./home/default.nix;
            home-manager.sharedModules = [ sops-nix.homeManagerModules.sops ];
          }
        ];
      };

      # Make home-manager accessible via nix run and nix shell for all systems
      packages = forAllSystems (system: {
        home-manager = home-manager.packages.${system}.home-manager;
        default = home-manager.packages.${system}.home-manager;
      });

      # Standalone home-manager configurations
      homeConfigurations =
        let
          username = (import ./user-config.nix).username;
          mkHomeConfig = system: home-manager.lib.homeManagerConfiguration {
            pkgs = import nixpkgs { inherit system; };
            modules = [ ./home/default.nix sops-nix.homeManagerModules.sops ];
          };
        in {
          "${username}@x86_64-linux" = mkHomeConfig "x86_64-linux";
          "${username}@aarch64-linux" = mkHomeConfig "aarch64-linux";
          "${username}@x86_64-darwin" = mkHomeConfig "x86_64-darwin";
          "${username}@aarch64-darwin" = mkHomeConfig "aarch64-darwin";
        };
    };
}
