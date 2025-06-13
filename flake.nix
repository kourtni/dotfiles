{
  description = "NixOS WSL + Home Manager Config";

  inputs = {
    nixpkgs.url = "github:NixOS/nixpkgs/nixos-unstable";

    home-manager.url = "github:nix-community/home-manager";
    home-manager.inputs.nixpkgs.follows = "nixpkgs";
    
    nixos-wsl.url = "github:nix-community/NixOS-WSL";
    nixos-wsl.inputs.nixpkgs.follows = "nixpkgs";

    sops-nix.url = "github:Mic92/sops-nix";
    sops-nix.inputs.nixpkgs.follows = "nixpkgs";
  };

  outputs = { self, nixpkgs, home-manager, nixos-wsl, sops-nix, ... }: 
    let
      system = "x86_64-linux";
      pkgs = import nixpkgs { inherit system; };
    in {
      # Used by `sudo nixos-rebuild switch --flake`
      nixosConfigurations.wsl = nixpkgs.lib.nixosSystem {
        inherit system;
        modules = [
          nixos-wsl.nixosModules.default
          ./nixos/configuration.nix
          home-manager.nixosModules.home-manager
          sops-nix.nixosModules.sops
          {
            home-manager.useGlobalPkgs = true;
            home-manager.useUserPackages = true;
            home-manager.extraSpecialArgs = {
              inherit home-manager;
            };
            home-manager.users.kourtni = import ./home/default.nix;
          }
        ];
      };

      # This is for `home-manager switch --flake`
      homeConfigurations.kourtni = home-manager.lib.homeManagerConfiguration {
        pkgs = pkgs;
        modules = [ ./home/default.nix ];
        extraSpecialArgs = {
          inherit home-manager;
        };
      };

      # Make home-manager accessible via nix run and nix shell
      packages.x86_64-linux.home-manager = home-manager.packages.${system}.home-manager;
      defaultPackage.x86_64-linux = home-manager.packages.${system}.home-manager;
    };
}
