{ pkgs, user, homeDir, ... }:

{
  # Determinate already manages the Nix daemon, so nix-darwin shouldn't.
  nix.enable = false;

  nixpkgs.config.allowUnfree = true;
  nixpkgs.hostPlatform = "aarch64-darwin"; # use x86_64-darwin for Intel CPU

  system.primaryUser = user;
  users.users.${user} = {
    home  = homeDir;
    shell = pkgs.zsh;
  };
  system.stateVersion = 6;

  # ── PATH: make nix tools and user profile bins always findable ────────────
  # /opt/homebrew/bin holds brew/cask binaries (gh, copilot, etc.). ~/.local/bin
  # holds user-installed binaries (claude, headroom, code-review-graph,
  # codegraph, kimchi, opencode symlink). ~/.opencode/bin holds the opencode binary.
  # ~/.nvm/versions/node/v22.12.0/bin holds node + npm + npx + commandcode.
  # home.sessionPath in home.nix sets these too, but environment.systemPath overrides
  # in non-interactive shells (MCP server spawn, cron, etc.) so we set them here.
  environment.systemPath = [
    "/run/current-system/sw/bin"
    "/opt/homebrew/bin"
    "/etc/profiles/per-user/${user}/bin"
    "${homeDir}/.nix-profile/bin"
    "${homeDir}/.local/bin"
    "${homeDir}/.opencode/bin"
    "${homeDir}/.nvm/versions/node/v22.12.0/bin"
  ];

  # ── macOS defaults ────────────────────────────────────────────────────────
  system.defaults = {
    NSGlobalDomain = {
      AppleInterfaceStyle        = "Dark";
      KeyRepeat                  = 2;      # fast key repeat
      InitialKeyRepeat           = 15;     # short delay before repeat
      _HIHideMenuBar             = true;   # auto-hide the menu bar
      AppleShowAllExtensions     = true;
      # scroll direction: false = traditional (scroll bar follows finger)
      "com.apple.swipescrolldirection" = false;
      # turn off all the autocorrect / autocomplete annoyances
      NSAutomaticCapitalizationEnabled     = false;
      NSAutomaticPeriodSubstitutionEnabled = false;
      NSAutomaticSpellingCorrectionEnabled = false;
      NSAutomaticQuoteSubstitutionEnabled  = false;
      # always show full save panel (not the collapsed one)
      NSNavPanelExpandedStateForSaveMode  = true;
      NSNavPanelExpandedStateForSaveMode2 = true;
    };
    dock = {
      autohide = true;
    };
    finder = {
      FXPreferredViewStyle  = "Nlsv";   # list view by default
      CreateDesktop         = false;    # clean desktop - no icons
      AppleShowAllExtensions = true;
      ShowPathbar           = true;     # breadcrumb path bar at the bottom
    };
    trackpad.Clicking = true;           # tap to click
  };

  # ── Homebrew ──────────────────────────────────────────────────────────────
  nix-homebrew = {
    enable      = true;
    inherit user;
    autoMigrate = true;   # adopt existing homebrew install on first switch
  };
  homebrew = {
    enable = true;
    onActivation.cleanup    = "zap";  # remove anything not listed here
    onActivation.autoUpdate = true;
    onActivation.extraFlags = [ "--force" ];

    # ── CLI tools ───────────────────────────────────────────────────────────
    taps = [
      "hashicorp/tap"       # terraform, vault, boundary
      "azure/kubelogin"     # kubelogin
      "fluxcd/tap"          # flux
      "supabase/tap"        # supabase
      "avirajkhare00/yoyo"  # yoyo
      "devops-rob/tap"      # target
    ];

    brews = [
      # agent session multiplexer (homebrew-core)
      "herdr"

      # infrastructure - fully qualified so homebrew uses the right tap
      "hashicorp/tap/terraform"
      "hashicorp/tap/vault"
      "hashicorp/tap/boundary"

      # kubernetes
      "azure-cli"  # homebrew-core
      "azure/kubelogin/kubelogin"
      "fluxcd/tap/flux"
      "helm"  # homebrew-core

      # backend
      "supabase/tap/supabase"

      # other tools already installed
      "avirajkhare00/yoyo/yoyo"
      "devops-rob/tap/target"

      # github cli - declared here (not in home.nix) because brew's internal
      # subprocesses (used by some formula installs, e.g. tools that fetch
      # private releases via `gh release download`) hard-look for `gh` in
      # /opt/homebrew/bin. If gh only lives in the nix store at
      # /etc/profiles/per-user/kishore/bin/gh, the parent shell's `which gh`
      # works but the brew subprocess fails with "GitHub CLI (gh) not found".
      "gh"
    ];

    # ── Mac apps ────────────────────────────────────────────────────────────
    casks = [
      # terminals
      "wezterm"
      "ghostty"
      "warp"

      # editors / IDEs
      "cursor"
      "visual-studio-code"

      # ai agents
      "claude-code"
      "copilot-cli"

      # kubernetes
      "lens"

      # notes / knowledge
      "obsidian"

      # api testing
      "bruno"

      # communication
      "discord"

      # utilities
      "localsend"

      # NOTE: brave-browser is installed via DMG - macOS SIP prevents brew
      # from taking ownership of it. Manage it manually outside this config.
    ];
  };
}
