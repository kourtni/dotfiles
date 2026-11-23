{
  description = "Kourtni's Home Manager configuration for Coder";

  inputs = {
    smyl-coder.url = "git+https://github.com/smyl-fitness/smyl-webapp?ref=main&dir=infra/devops/coder";
    nixpkgs.follows = "smyl-coder/nixpkgs";
    home-manager.follows = "smyl-coder/home-manager";
  };

  outputs = { smyl-coder, nixpkgs, home-manager, ... }: {
    packages.x86_64-linux.home-manager = home-manager.packages.x86_64-linux.home-manager;

    homeConfigurations.kourtni = home-manager.lib.homeManagerConfiguration {
      pkgs = nixpkgs.legacyPackages.x86_64-linux;
      modules = [
        smyl-coder.homeManagerModules.default
        {
          home.username = "kourtni";
          home.homeDirectory = "/home/kourtni";
          targets.genericLinux.enable = !(builtins.pathExists /etc/NIXOS);
          targets.genericLinux.gpu.enable = false;
          programs.bash.shellAliases.t = "tmux new -A -s";
        }
      ];
    };
  };
}
