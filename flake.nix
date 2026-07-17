{
  description = "dotfiles";

  inputs = {
    # Use `github:NixOS/nixpkgs/nixpkgs-26.05-darwin` to use Nixpkgs 26.05.
    nixpkgs.url = "github:NixOS/nixpkgs/nixpkgs-26.05-darwin";
    # Use `github:nix-darwin/nix-darwin/nix-darwin-26.05` to use Nixpkgs 26.05.
    nix-darwin.url = "github:nix-darwin/nix-darwin/nix-darwin-26.05";
    nix-darwin.inputs.nixpkgs.follows = "nixpkgs";

    home-manager.url = "github:nix-community/home-manager/release-26.05";
    home-manager.inputs.nixpkgs.follows = "nixpkgs";

    nix-homebrew.url = "github:zhaofengli/nix-homebrew";
  };

  outputs = inputs@{ self, nix-darwin, nix-homebrew, home-manager, nixpkgs }:
    let
      # macOS account short name (what `whoami` returns).
      user = "kishore";

      # macOS home directory. bootstrap.sh rewrites this on first run if
      # the macOS account name differs from `user` above. Must stay in sync
      # with what `dscl . -read /Users/<user> NFSHomeDirectory` reports.
      homeDir = "/Users/kishore";

      # Linux (Ubuntu/Debian) home directory. bootstrap.sh rewrites this on
      # first run to match the actual logged-in user's $HOME (typically
      # /home/<user>). Used by the homeConfigurations."${user}" output below
      # so the same `home.nix` works on Linux standalone home-manager.
      homeDirLinux = "/home/kishore";
    in
    {
      # macOS (unchanged): full nix-darwin + nix-homebrew + home-manager
      darwinConfigurations."mac" = nix-darwin.lib.darwinSystem {
        specialArgs = { inherit user homeDir; };
        modules = [
          ./configuration.nix
          nix-homebrew.darwinModules.nix-homebrew
          home-manager.darwinModules.home-manager
          {
            home-manager.useGlobalPkgs = true;
            home-manager.useUserPackages = true;
            # isLinux = false so home.nix keeps its macOS PATH entries
            # (/opt/homebrew/bin etc.) and behaves identically to before.
            home-manager.extraSpecialArgs = { inherit user homeDir; isLinux = false; };
            home-manager.users.${user} = import ./home.nix;
            # When home-manager finds a file already at a symlink destination,
            # rename it to <name>.backup instead of aborting the build.
            home-manager.backupFileExtension = "backup";
          }
        ];
      };

      # Linux (Ubuntu/Debian): standalone home-manager, no nix-darwin equivalent
      # exists for non-NixOS distros. activate via:
      #   home-manager switch --flake ~/.dotfiles#<user>
      # bootstrap.sh writes the right `user` + `homeDirLinux` into flake.nix
      # on first run so this works for any logged-in Linux account name.
      homeConfigurations."${user}" = home-manager.lib.homeManagerConfiguration {
        pkgs = nixpkgs.legacyPackages.x86_64-linux;  # override per-arch in bootstrap if needed
        extraSpecialArgs = {
          inherit user;
          homeDir = homeDirLinux;
          isLinux = true;
        };
        modules = [ ./home.nix ];
      };
    };
}
