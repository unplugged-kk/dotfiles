{ config, pkgs, user, homeDir, isLinux ? false, ... }:

let
  dotfiles = "${homeDir}/.dotfiles";
in

{
  home.username      = user;
  home.homeDirectory = homeDir;
  home.stateVersion  = "24.11";
  home.language.base = "en_US.UTF-8";

  # ── Nix user packages ─────────────────────────────────────────────────────
  home.packages = with pkgs; [
    # fast search / navigation
    ripgrep     # fast grep (rg)
    fd          # fast find
    fzf         # fuzzy finder
    zoxide      # smarter cd - learns your most-used dirs
    direnv      # per-directory env vars (.envrc auto-load on cd)

    # json / yaml
    jq          # json processor
    yq-go       # yaml processor (same interface as jq)

    # git workflow
    lazygit     # terminal git UI (lg)
    git-lfs     # large file storage (enterprise repos)
    delta       # beautiful diffs (wired into programs.git below)

    # better cli defaults
    bat         # better cat - syntax highlighted
    eza         # better ls - git status, icons
    tree        # directory tree printer
    htop        # interactive process viewer
    fastfetch   # system info display (replaces neofetch)

    # archive
    zip
    unzip

    # kubernetes
    kubectl     # kubernetes cli (k)
    k9s         # kubernetes TUI

    # editor
    neovim

    # javascript runtime - required by the claude-mem plugin's auto-install
    # hook (scripts/version-check.js runs `bun install --production` to
    # materialize its node_modules). also needed for any npx-based tooling.
    bun

    # fonts: terminal + editor
    nerd-fonts.hack
    nerd-fonts.jetbrains-mono
    noto-fonts
    noto-fonts-cjk-sans
    noto-fonts-color-emoji
  ];
  fonts.fontconfig.enable = true;

  home.sessionVariables = {
    EDITOR    = "nvim";
    _ZO_ECHO  = "1";    # zoxide: print matched dir before jumping
    # firstmate home - where the crew orchestrator lives
    FIRSTMATE_HOME = "/Users/kishore/git/personal/firstmate";
  };

  # ── PATH additions ────────────────────────────────────────────────────────
  # Mac: /opt/homebrew/bin holds brew/cask binaries. ~/.local/bin holds
  # user-installed binaries (no-mistakes, treehouse, etc.). ~/.opencode/bin
  # holds the opencode CLI. ~/.nvm/versions/node/<v>/bin holds node + npm.
  # Mirrored in configuration.nix:24 environment.systemPath for non-interactive
  # shells on macOS.
  #
  # Linux: drop /opt/homebrew/bin (doesn't exist on Linux). Add
  # ~/.nix-profile/bin so nix user-profile packages are on PATH.
  home.sessionPath =
    if isLinux then [
      "$HOME/.nix-profile/bin"
      "$HOME/.local/bin"
      "$HOME/.opencode/bin"
      "$HOME/.nvm/versions/node/v22.12.0/bin"
    ] else [
      "/opt/homebrew/bin"
      "$HOME/.local/bin"
      "$HOME/.opencode/bin"
      "$HOME/.nvm/versions/node/v22.12.0/bin"
    ];

  # ── Shell ─────────────────────────────────────────────────────────────────
  programs.zsh = {
    enable = true;
    autosuggestion.enable    = true;   # ghost text from history
    syntaxHighlighting.enable = true;  # commands turn green when valid
    initContent = ''
      # accept autosuggestion with Ctrl+f
      bindkey '^f' autosuggest-accept

      # zoxide: smarter cd replacement
      eval "$(zoxide init zsh)"
    '';
    shellAliases = {
      # navigation
      ".."  = "cd ..";
      "..." = "cd ../..";

      # git shortcuts
      add      = "git add .";
      push     = "git push";
      pushf    = "git push --force-with-lease";  # safer force push
      pull     = "git pull";
      m        = "git switch main";
      amend    = "git commit --amend --no-edit";
      undo     = "git reset --soft HEAD^";
      rebasem  = "git rebase -i main";
      lg       = "lazygit";

      # better cli defaults
      ls   = "eza --icons --git";
      ll   = "eza -l --icons --git --time-style relative";
      la   = "eza -la --icons --git --time-style relative";
      lt   = "eza --tree --icons --git -L 2";
      cat  = "bat --paging=never";

      # kubernetes
      k    = "kubectl";
      kns  = "kubectl config set-context --current --namespace";
      kctx = "kubectl config use-context";

      # terraform
      tf  = "terraform";
      tfp = "terraform plan";
      tfa = "terraform apply";
      tfd = "terraform destroy";
      tfi = "terraform init";

      # apply dotfiles changes
      #   rebuild         - fast: apply current dotfiles (no version bumps)
      #   rebuild --upgrade - full upgrade: nix flake update + package upgrade + switch
      #   rebuild --dry-run  - preview the --upgrade plan without changes
      # Mac uses darwin-rebuild (full nix-darwin + home-manager + nix-homebrew).
      # Linux uses standalone home-manager (no nix-darwin on non-NixOS distros).
      rebuild = if isLinux then
        "home-manager switch --flake ~/.dotfiles#${user}"
      else
        "sudo /run/current-system/sw/bin/darwin-rebuild switch --flake ~/.dotfiles#mac";
      # short alias for the full upgrade flow (runs ./rebuild.sh --upgrade)
      reup = "~/.dotfiles/rebuild.sh --upgrade";

      # agent shortcuts - high-agency, know what these do before using
      cc = "claude --dangerously-skip-permissions";
      cmd = "command-code";
      oc = "opencode";

      # parallel agent worktrees (treehouse)
      th = "treehouse";

      # overnight agent runner
      # usage: gnhf "your objective" or gnhf --worktree "task1" & gnhf --worktree "task2" &
      # gnhf is already on PATH via npm global

      # firstmate: multi-agent crew orchestrator
      # cd to firstmate home and launch - "ahoy! fix X, add Y, and investigate Z"
      fm = "cd $FIRSTMATE_HOME && claude";
    };
  };

  # ── Prompt ────────────────────────────────────────────────────────────────
  programs.starship = {
    enable = true;
    settings = {
      command_timeout = 1000;   # ms - prevents slow git/kubectl from hanging prompt
      add_newline     = false;
      format = "$directory$git_branch$git_status$kubernetes$terraform$cmd_duration$line_break$character";
      character = {
        success_symbol = "[❯](purple)";
        error_symbol   = "[❯](red)";
      };
      cmd_duration.format = "[$duration]($style) ";
      kubernetes = {
        disabled = true;
        format   = "[$symbol$context( \\($namespace\\))](cyan) ";
        symbol   = "⎈ ";
      };
      terraform = {
        disabled = false;
        format   = "[$symbol$workspace]($style) ";
      };
    };
  };

  # ── Git ───────────────────────────────────────────────────────────────────
  programs.git = {
    enable     = true;
    lfs.enable = true;
    settings = {
      user = {
        name  = "Kishore Kumar Behera";
        email = "kishore.behera2010@gmail.com";
      };
      core.editor          = "nvim";
      color.ui             = true;
      pull.rebase          = true;
      push.autoSetupRemote = true;
      rebase.updateRefs    = true;   # auto-update stacked branches on rebase
      init.defaultBranch   = "main";
      credential.helper    = "osxkeychain";
      http.postBuffer      = 524288000;  # 500 MB for large enterprise repos
    };
  };

  # delta: beautiful diffs - kept separate from programs.git per new home-manager API
  programs.delta = {
    enable               = true;
    enableGitIntegration = true;
  };

  # ── Symlinks: edit-in-place, no rebuild needed ────────────────────────────
  # The real files live here in the repo; ~/.config just points at them.
  home.file.".config/wezterm".source =
    config.lib.file.mkOutOfStoreSymlink "${dotfiles}/home/.config/wezterm";
  home.file.".config/nvim".source =
    config.lib.file.mkOutOfStoreSymlink "${dotfiles}/home/.config/nvim";
  home.file.".config/herdr".source =
    config.lib.file.mkOutOfStoreSymlink "${dotfiles}/home/.config/herdr";
  home.file.".config/opencode/opencode.jsonc".source =
    config.lib.file.mkOutOfStoreSymlink "${dotfiles}/home/.config/opencode/opencode.jsonc";
  home.file.".config/treehouse/config.toml".source =
    config.lib.file.mkOutOfStoreSymlink "${dotfiles}/home/.config/treehouse/config.toml";
  home.file.".config/kimchi/harness/mcp.json".source =
    config.lib.file.mkOutOfStoreSymlink "${dotfiles}/home/.config/kimchi/harness/mcp.json";

  # Agent rules: one source file, three clients
  home.file.".claude/CLAUDE.md".source =
    config.lib.file.mkOutOfStoreSymlink "${dotfiles}/home/AGENTS.md";
  home.file.".codex/AGENTS.md".source =
    config.lib.file.mkOutOfStoreSymlink "${dotfiles}/home/AGENTS.md";
  home.file.".config/opencode/AGENTS.md".source =
    config.lib.file.mkOutOfStoreSymlink "${dotfiles}/home/AGENTS.md";

  # Claude Code settings (theme + permissions; secrets in ~/.claude/settings.local.json)
  home.file.".claude/settings.json".source =
    config.lib.file.mkOutOfStoreSymlink "${dotfiles}/home/.claude/settings.json";

  # Command Code MCP config (user-scoped, applies across all projects)
  home.file.".commandcode/mcp.json".source =
    config.lib.file.mkOutOfStoreSymlink "${dotfiles}/home/.commandcode/mcp.json";

  # Cursor CLI MCP config (global scope, applies across all projects)
  home.file.".cursor/mcp.json".source =
    config.lib.file.mkOutOfStoreSymlink "${dotfiles}/home/.cursor/mcp.json";
}
