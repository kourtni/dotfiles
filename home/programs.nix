{ pkgs, ... }:

{
  programs.fish = {
    enable = true;

    shellInit = ''
      direnv hook fish | source
      set -gx EDITOR nvim
      fish_vi_key_bindings

      # Add VS Code CLI to PATH (Fish requires extra care with paths that have spaces)
      set -l code_bin "/mnt/c/Users/klact/AppData/Local/Programs/Microsoft VS Code/bin"
      if test -d "$code_bin"
        set -gx PATH $code_bin $PATH
      end
    '';

    functions = {
      ll = "ls -l";
      gs = "git status";
    };
  };

  programs.starship = {
    enable = true;
    enableFishIntegration = true;
    settings = import ./starship-settings-from-toml.nix;
  };

  fonts.fontconfig.enable = true;

  home.packages = with pkgs; [
    curl
    fish
    htop
    vim
    nerd-fonts._0xproto
    nerd-fonts.droid-sans-mono
    nerd-fonts.fira-code
    nerd-fonts.jetbrains-mono
    nerd-fonts.hack
  ];
}
