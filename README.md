# dotfiles

Kishore's personal Mac setup, managed with **nix-darwin** and **home-manager**.
One repo, one command, and a fresh Mac ends up configured identically every time.
---

## What you get

### System defaults (macOS)
- Dark mode, auto-hide dock + menu bar, no desktop icons
- Fast key repeat, tap-to-click, natural scroll OFF
- Finder: list view, path bar, show all extensions
- Autocorrect / autocaps / smart quotes all disabled (essential for coding)

### Homebrew CLI tools
| Tool | Purpose |
|------|---------|
| `herdr` | Agent session multiplexer - think tmux, built for agents |
| `terraform` | Infrastructure as code |
| `vault` | HashiCorp secrets management |
| `boundary` | HashiCorp zero-trust network access |
| `flux` | Kubernetes GitOps |
| `azure-cli` | Azure CLI (`az`) |
| `kubelogin` | Azure Kubernetes Service auth |
| `helm` | Kubernetes package manager |
| `supabase` | Supabase backend CLI |
| `gh` | GitHub CLI - declared here (not in Nix) so brew's internal subprocesses can find it at `/opt/homebrew/bin/gh` for installing formulas that fetch private releases |

### Homebrew casks (Mac apps)
WezTerm, Ghostty, Warp, Cursor, VS Code, Claude Code, GitHub Copilot CLI, Lens, Obsidian, Bruno, Discord, LocalSend

### Nix user packages
| Package | Purpose |
|---------|---------|
| `ripgrep` / `fd` / `fzf` | Fast search and fuzzy find |
| `zoxide` (`z`) | Smarter cd |
| `jq` / `yq` | JSON and YAML on the command line |
| `lazygit` (`lg`) | Terminal git UI |
| `git-lfs` / `delta` | LFS support and beautiful diffs |
| `bat` / `eza` / `tree` / `htop` | Better cat, ls, tree, process viewer |
| `fastfetch` | System info display |
| `kubectl` (`k`) / `k9s` | Kubernetes CLI + TUI |
| `neovim` | Terminal editor |
| Hack + JetBrains Mono + Noto fonts | Terminal and editor fonts |

### Agent toolchain (installed outside nix/brew)
| Tool | Stars | Purpose |
|------|-------|---------|
| `no-mistakes` | 6.1k | AI-gated PR pipeline |
| `treehouse` (`th`) | 884 | Reusable worktree pool for parallel agents |
| `gh-axi` | 160 | Token-efficient GitHub CLI for agents |
| `gnhf` | 3.2k | Overnight autonomous agent runner |
| `firstmate` (`fm`) | 1.2k | Multi-agent crew orchestrator |
| `headroom` | 59k | Token compression layer (20-95% fewer tokens) |
| `code-review-graph` | 19.5k | PR-level structural review, ~82x token reduction |
| `@dietrichgebert/ponytail` | 82.6k | Lazy senior dev mode (YAGNI, -54% code) |

### MCP servers (available in all agents)
| Server | Transport | Purpose |
|--------|-----------|---------|
| `codegraph` | stdio | Symbol-level code intelligence per project |
| `headroom` | stdio | Token compression - 20-95% savings |
| `code-review-graph` | stdio | PR-level structural code review (https://github.com/tirth8205/code-review-graph) |
| `claude-mem` | stdio | Cross-session memory across all agents |
| `atlassian` | HTTP | Jira, Confluence, Bitbucket integration (Atlassian Rovo remote MCP, OAuth 2.1) |
| `obsidian` | stdio | Obsidian vault access (disabled by default, needs API key) |

#### Per-agent MCP config locations

| Agent CLI | Config file | Format |
|-----------|-------------|--------|
| OpenCode (`oc`) | `home/.config/opencode/opencode.jsonc` | `{ "mcp": { "name": { "type": "local"\|"remote", ... } } }` |
| Claude Code (`cc`) | `home/.claude/settings.json` | `{ "mcpServers": { "name": { "command"\|"type", ... } } }` |
| Kimchi | `home/.config/kimchi/harness/mcp.json` | `{ "mcpServers": { "name": { "command", "args", "env" } } }` |
| Command Code (`cmd`) | `home/.commandcode/mcp.json` | `{ "mcpServers": { "name": { "command"\|"url", ... } } }` |
| Cursor CLI (`agent`/`cursor-agent`) | `home/.cursor/mcp.json` | `{ "mcpServers": { "name": { "command"\|"url", ... } } }` |
| GitHub Copilot CLI (`copilot`) | `~/.copilot/` (managed by `/mcp` slash command) | stdio servers via `/mcp add`, remote via `/mcp add` with `type=http` |

All declarative CLIs (OpenCode/Claude/Kimchi/Command Code/Cursor) symlink their MCP config to the same 5 server set from dotfiles. Changes to any file take effect on next CLI launch.

#### Cursor CLI setup (one-time)

Cursor CLI (binary: `agent`, alias: `cursor-agent`) ships its own MCP config format and an explicit approval model. After `bootstrap.sh` step 11b installs it:

```bash
# Verify the symlink landed:
ls -la ~/.cursor/mcp.json   # -> ~/dotfiles/home/.cursor/mcp.json

# Approve each server (config defines them, but Cursor requires explicit enable):
agent mcp enable codegraph
agent mcp enable headroom
agent mcp enable code-review-graph
agent mcp enable claude-mem
agent mcp enable atlassian

# Confirm:
agent mcp list
# All five should show "ready" (atlassian will show "requires_authentication"
# until first OAuth flow completes).
```

Cursor supports `${workspaceFolder}` interpolation in `command`/`args`/`env`/`url`/`headers`, used by the `codegraph` entry to scope symbol lookups to the current project.

#### GitHub Copilot CLI setup (one-time)

Copilot CLI is installed by `configuration.nix` as the `copilot-cli` Homebrew cask. Launch it with `copilot`, then authenticate with `/login` on first use.

Copilot CLI manages MCP servers interactively via the `/mcp` slash command inside its REPL. The configs for OpenCode/Claude/Kimchi/Command Code/Cursor don't apply to Copilot - you must add servers directly in Copilot:

```text
# Inside Copilot CLI REPL:
/mcp                                              # opens MCP server list TUI
                                                   # remove any broken entries (e.g. typos like "code-review-grap")
/mcp add code-review-graph stdio /Users/kishore/.local/bin/code-review-graph serve
/mcp add atlassian http https://mcp.atlassian.com/v1/mcp/authv2
```

After adding, run `/mcp` again to confirm both show "connected" status. Atlassian will prompt OAuth via browser on first use.

### Skills (92 total across all agents)
Skills live in `~/.agents/skills/` (61 cross-agent) + `~/.claude/skills/` (92 total including mattpocock and addyosmani packs). All symlinked to Claude Code, available in OpenCode and Kimchi.

**Skill packs installed:**
- `~/.agents/skills/` - 61 skills: caveman, grill-me, tdd, code-review, walkthrough, wayfinder, implement, pr-raise, diagnosing-bugs, and 52 more
- mattpocock/skills - grill-with-docs, to-spec, to-tickets, implement, wayfinder, triage, domain-modeling, code-review, TDD
- addyosmani/agent-skills - 24 production skills: spec, plan, build, test, review, ship lifecycle

All five are from [kunchenguid](https://github.com/kunchenguid) and installed by `bootstrap.sh`.

### Shell (zsh)
- Autosuggestions + syntax highlighting, `Ctrl+f` to accept
- Starship prompt: git status, k8s context `⎈`, terraform workspace, command duration
- `command_timeout = 1000ms` - slow kubectl never stalls the prompt

### Git
- delta diffs, git-lfs, rebase-on-pull, `rebase.updateRefs = true`
- `pushf` uses `--force-with-lease` (safe force push)

### Agent configs
`~/.claude/CLAUDE.md`, `~/.codex/AGENTS.md`, `~/.config/opencode/AGENTS.md` all point at one file: `home/AGENTS.md`

---

## First-time setup

### Prerequisites
- Apple Silicon Mac (Intel: set `hostPlatform = "x86_64-darwin"` in `configuration.nix`)
- Internet access

### Step 1 - Clone
```bash
git clone https://github.com/unplugged-kk/dotfiles.git ~/dotfiles
cd ~/dotfiles
```

### Step 2 - Back up files that will become symlinks
```bash
cp ~/.claude/CLAUDE.md ~/.claude/CLAUDE.md.manual-backup 2>/dev/null || true
cp ~/.claude/settings.json ~/.claude/settings.json.manual-backup 2>/dev/null || true
cp ~/.config/opencode/opencode.jsonc ~/.config/opencode/opencode.jsonc.manual-backup 2>/dev/null || true
rm -f ~/.zshrc.backup  # remove stale backups from previous attempts
```

### Step 3 - Authenticate Claude Code
```bash
# Run Claude Code once and sign in with your personal Anthropic account
claude
# Follow the browser prompt to log in. Your OAuth token is stored in
# ~/.claude/.credentials.json. If you also want to override defaults
# (model, env vars, etc.) without committing them, create settings.local.json
# (gitignored) - the schema is the same as settings.json.
```

### Step 4 - Run bootstrap
```bash
chmod +x bootstrap.sh rebuild.sh
./bootstrap.sh
```

What bootstrap does (10 steps):

| Step | Action |
|------|--------|
| 1 | Install Determinate Nix (if missing) |
| 2 | Install Homebrew (if missing) |
| 3 | Symlink repo to `~/.dotfiles` |
| 4 | Check `user` in `flake.nix` matches your macOS username |
| 5 | `darwin-rebuild switch` - applies all Nix config (5-20 min first time) |
| 6 | Install nvm + Node.js LTS |
| 7 | Install `no-mistakes` + `treehouse` to `~/.local/bin` |
| 8 | Install `gh-axi` + `gnhf` as npm globals |
| 9 | Set up `gh-axi` session hooks (feeds GitHub context into every agent session) |
| 10 | Clone `firstmate` to `~/git/personal/firstmate` |

### Step 5 - Open a new terminal
```bash
exec zsh
```

### Step 6 - Verify
```bash
# Core tools
which rg fd fzf bat eza kubectl k9s az gh nvim lazygit

# Agent toolchain
no-mistakes --version
treehouse --version
gh-axi --version
gnhf --version
ls ~/git/personal/firstmate/AGENTS.md
```

---

## Daily workflow

### Applying config changes
```bash
rebuild                          # fast: apply current dotfiles, no version bumps
rebuild --upgrade                # full upgrade: nix flake update + brew upgrade,
                                 #   then activate. Only packages with newer
                                 #   versions get rebuilt.
rebuild --dry-run                # preview the --upgrade plan without changes
```

Files under `home/` are **symlinked live** - edit them and the change is immediately active without a rebuild.

### Upgrade flow (what `--upgrade` does, in order)

1. `nix flake update` - bumps `flake.lock` to latest nixpkgs / nix-darwin / home-manager
2. Shows the lockfile diff so you see what changed
3. `darwin-rebuild build` - compiles only changed packages (no activation yet)
4. `darwin-rebuild switch` - activates the new generation
5. `brew upgrade --greedy` - bumps brew packages (and casks with `auto_updates true`) to latest
6. `nix profile upgrade '.*'` - bumps any user-profile packages (currently none - everything's declarative)

If anything blows up mid-flow, roll back with `darwin-rebuild --rollback` and compare generations with `darwin-rebuild --list-generations`.

### Validate before applying
```bash
nix flake check --no-build
nix build .#darwinConfigurations.mac.system --dry-run
```

---

## Agentic workflows

### Overview: the full agent stack

```
                    you
                     |
         ┌───────────┼───────────┐
         │           │           │
      herdr      firstmate    gnhf
   (multiplexer)  (crew mgr)  (overnight)
         │           │
    ┌────┴────┐  ┌───┴────┐
  treehouse  treehouse  treehouse   <- isolated worktrees
    │              │         │
   cc/oc        cc/oc      cc/oc    <- agents
    │
 no-mistakes                        <- before every push
    │
   origin                           <- clean PR, CI green
```

### herdr - multiplexed sessions (already configured)

```bash
herdr
```

Prefix: `Ctrl+b`

| Shortcut | Action |
|----------|--------|
| `Ctrl+b "` | Split pane horizontally |
| `Ctrl+b %` | Split pane vertically |
| `Ctrl+b h/j/k/l` | Move focus |
| `Ctrl+b c` | New tab |
| `Ctrl+b w` | Workspace picker |
| `Ctrl+b y` | Copy mode |

### no-mistakes - AI-gated PR quality

One-time setup per repo:
```bash
cd my-go-service
no-mistakes init
```

Then push through the gate instead of directly to origin:
```bash
# instead of: git push origin
git push no-mistakes
```

What happens:
1. Disposable worktree spins up (your work stays untouched)
2. AI runs: code review → tests → docs → lint
3. Safe fixes applied automatically
4. PR opened only after everything is green

The `/no-mistakes` agent skill is also installed - ask your agent to use it directly:
```
cc "/no-mistakes fix the connection pool race condition"
```

**Platform/SRE use cases:**
- Push Terraform changes - validates plan, checks for hardcoded secrets, resource limits
- Push k8s manifests - validates structure, checks resource requests/limits
- Push Go services - reviews error handling, test coverage, lint

### treehouse - parallel agent worktrees

Each agent gets an isolated worktree with warm build cache. No conflicts, no cloning.

```bash
# Run an agent on a task
th               # drops into isolated worktree subshell
cc "fix the race condition in the auth handler"
exit             # worktree returns to pool

# Run multiple agents in parallel (in separate herdr panes)
# Pane 1:
th && cc "refactor the Vault auth package"
# Pane 2:
th && oc "add integration tests for the k8s controller"
# Both work on the same repo, neither steps on the other
```

Useful commands:
```bash
th               # get a worktree and drop in
treehouse status # see pool state
treehouse prune  # dry-run cleanup of stale worktrees
```

### gnhf - overnight autonomous agent

Give it an objective and let it run. Each iteration commits incrementally. Wake up to a branch of clean work.

```bash
cd my-go-service
gnhf "reduce cyclomatic complexity without changing behaviour"
# go to sleep

# Multiple objectives in parallel using worktrees
gnhf --worktree "improve test coverage of the service layer" &
gnhf --worktree "add structured logging throughout the package" &

# Push each iteration as it completes
gnhf --current-branch --push "keep improving error handling"

# Cap the run
gnhf --max-iterations 20 "refactor the Terraform modules"
```

### gh-axi - GitHub CLI for agents

Session hooks were installed during bootstrap - every new agent session automatically gets current repo context (open PRs, issues, recent CI runs).

```bash
# Manually
gh-axi                    # dashboard
gh-axi issue list         # issues
gh-axi pr view 42         # PR details
gh-axi run list           # CI runs
gh-axi run view 123 --log-failed  # failed CI log
```

Agents can now autonomously: triage issues, investigate CI failures, review PR status, manage Actions secrets and variables, interact with Projects boards.

### firstmate - multi-agent crew

Talk to one agent (the first mate). It spawns a crew of agents, each in their own treehouse worktree, supervises them, and brings you finished PRs or investigation reports.

```bash
fm   # alias for: cd ~/git/personal/firstmate && claude
```

Then just talk:
```
> ahoy! look at the PSL service, fix the flaky integration test,
  and investigate why the vault auth is slow in staging

# firstmate dispatches:
# - fm-fix-test-k3   (treehouse worktree, working on the test)
# - fm-investigate-p7 (scout agent, checking vault auth)
# You get PRs and a report. You just approve.
```

Task shapes:
- **ship task** - delivers a change as a PR
- **scout task** - investigates, plans, or audits and leaves a report

---

## Kubernetes workflow

```bash
k get pods -A           # kubectl shorthand
k9s                     # interactive cluster explorer
kns my-namespace        # set default namespace
kctx staging            # switch cluster context
kubelogin convert-kubeconfig -l azurecli  # Azure AKS
flux get all            # GitOps status
flux reconcile source git flux-system
```

Prompt shows `⎈ cluster (namespace)` when inside a k8s context.

---

## Infrastructure workflow

```bash
tfi   # terraform init
tfp   # terraform plan
tfa   # terraform apply
tfd   # terraform destroy

vault login
vault kv get secret/myapp/config
```

---

## Node.js

nvm is installed by bootstrap. Nix does NOT manage Node to keep `.nvmrc` compatibility.

```bash
nvm use 22
nvm install --lts
```

---

## Neovim

### First launch
```bash
nvim
# lazy.nvim bootstraps itself - wait, then press q
```

### Keymaps (`Space` = leader)

| Key | Action |
|-----|--------|
| `Space f` | Find files |
| `Space s` | Search text (grep) |
| `Space b` | Buffers |
| `Space e` | File browser (Oil) |
| `Space g` | Git (Neogit) |
| `Space ?` | All keymaps (which-key) |
| `gd` | Go to definition |
| `Esc` | Save |

---

## Shell aliases reference

| Alias | Expands to | Category |
|-------|-----------|---------|
| `..` / `...` | `cd ..` / `cd ../..` | navigation |
| `z <fragment>` | zoxide smart jump | navigation |
| `ls` / `ll` / `la` / `lt` | eza variants | files |
| `cat` | `bat --paging=never` | files |
| `add` / `push` / `pushf` / `pull` | git shortcuts | git |
| `m` | `git switch main` | git |
| `amend` / `undo` / `rebasem` | git shortcuts | git |
| `lg` | `lazygit` | git |
| `rebuild` | `darwin-rebuild switch --flake ~/.dotfiles#mac` | dotfiles |
| `k` | `kubectl` | kubernetes |
| `kns` / `kctx` | namespace / context switch | kubernetes |
| `tf` / `tfp` / `tfa` / `tfd` / `tfi` | terraform commands | infra |
| `cc` | `claude --dangerously-skip-permissions` | agents |
| `co` | `codex --full-auto` | agents |
| `oc` | `opencode` | agents |
| `th` | `treehouse` | agents |
| `fm` | `cd ~/git/personal/firstmate && claude` | agents |

---

## How symlinks work

Files under `home/` are the real files. `home.nix` uses `mkOutOfStoreSymlink` to point `~/.config/...` at `home/.config/...` in this repo. Edit here, change is live instantly.

```
~/.config/wezterm             -> ~/.dotfiles/home/.config/wezterm/
~/.config/nvim                -> ~/.dotfiles/home/.config/nvim/
~/.config/herdr               -> ~/.dotfiles/home/.config/herdr/
~/.config/treehouse/config.toml -> ~/.dotfiles/home/.config/treehouse/config.toml
~/.config/opencode/opencode.jsonc -> ~/.dotfiles/home/.config/opencode/opencode.jsonc
~/.claude/CLAUDE.md           -> ~/.dotfiles/home/AGENTS.md
~/.codex/AGENTS.md            -> ~/.dotfiles/home/AGENTS.md
~/.config/opencode/AGENTS.md  -> ~/.dotfiles/home/AGENTS.md
~/.claude/settings.json       -> ~/.dotfiles/home/.claude/settings.json
```

If home-manager finds a regular file at a symlink target it renames it to `<name>.backup` automatically (`backupFileExtension = "backup"` in `flake.nix`).

---

## Adapting for a new machine

1. **Username** - `bootstrap.sh` detects and offers to fix; or change `user = "kishore"` in `flake.nix`
2. **Home dir** - change `homeDir = "/Users/kishore"` in `flake.nix` if different
3. **CPU arch** - `hostPlatform` in `configuration.nix` (`aarch64-darwin` or `x86_64-darwin`)
4. **Git identity** - `userName` + `userEmail` in `home.nix`
5. **Enterprise secrets** - `~/.claude/settings.local.json` (gitignored)
6. **Homebrew cleanup** - `onActivation.cleanup = "zap"` removes anything not in the lists. Scan `configuration.nix` before first rebuild.

---

## Repo layout

```
flake.nix           entry point: nixpkgs 26.05, nix-darwin, home-manager, nix-homebrew
configuration.nix   system: macOS defaults, PATH, login shell, Homebrew
home.nix            user: packages, zsh, git, starship, PATH, symlinks
rebuild.sh          daily driver: `./rebuild.sh` (fast) or `./rebuild.sh --upgrade` (full upgrade)
bootstrap.sh        one-time: Nix + Brew + darwin-rebuild + nvm + agent tools
home/
  AGENTS.md                           shared rules - Claude, Codex, OpenCode
  .claude/settings.json               Claude Code: theme, permissions
  .config/
    wezterm/wezterm.lua               rose-pine moon, 120fps, blur
    nvim/                             lazy.nvim, rose-pine moon, oil, snacks, neogit
    herdr/config.toml                 agent multiplexer: vim keys, Ctrl+b
    treehouse/config.toml             worktree pool: max 16 trees
    opencode/opencode.jsonc           model, codegraph MCP, thinking on

Agent tools (installed to ~/.local/bin and npm globals):
  ~/.local/bin/no-mistakes            AI-gated PR pipeline (Go)
  ~/.local/bin/treehouse              worktree pool manager (Go)
  gh-axi                              GitHub CLI for agents (npm global)
  gnhf                                overnight agent runner (npm global)
  ~/git/personal/firstmate/           multi-agent crew distro (git clone)
```

---

## License

MIT No Attribution.

---

---

# Agentic Engineering Playbook

> Step-by-step guide to using this setup for 100x productivity.
> Written so a beginner can understand every piece.
>
> Reference: Kun Chen's workflow video - https://youtu.be/iQyg-KypKAA

---

## The mental model: you are the captain

Before touching any tool, get this idea into your head:

**You are the captain. Agents are crew.**

A captain does not write every line of code, run every command, or investigate every alert. A captain sets direction, makes decisions, reviews outcomes, and approves work. The crew executes.

| Your job (captain) | Agent's job (crew) |
|--------------------|-------------------|
| Define the objective | Write the code |
| Set quality standards in AGENTS.md | Run the tests |
| Review and approve PRs | Investigate issues |
| Make judgment calls | Fix lint and coverage |
| Decide what to work on next | Open PRs |

**The shift:** Stop thinking "what should I code?" and start thinking "what should I delegate, and how do I verify it was done right?"

---

## The stack: what each tool does

```
                        YOU (captain)
                             |
             give directions / review outcomes
                             |
          ┌──────────────────┼───────────────────┐
          |                  |                   |
    cc / co / oc         firstmate (fm)         gnhf
   (single agent)    (multi-agent crew)      (overnight)
          |                  |
          └──────────────────┘
                    |
                herdr
          (terminal workspace)
                    |
              treehouse
       (isolated worktrees per agent)
                    |
             no-mistakes
        (AI gate before every push)
                    |
              clean PR on GitHub
              (gh-axi tracks it)
```

---

## Level 1: Single agent, one task

Start here. One task, one agent, you watch it work.

### Open your workspace

```bash
herdr
# herdr is your mission control - everything runs inside it
```

### Give an agent a task

```bash
cc "look at pkg/vault/auth.go and fix the race condition in the token renewal loop"
oc "write unit tests for the HTTP handlers in internal/api/"
co "add structured logging to all gRPC handlers using the internal logger"
```

### Be specific - it makes a huge difference

```bash
# Vague - agent guesses, often gets it wrong
cc "fix the bug"

# Good - agent knows exactly what to do
cc "the integration test TestVaultAuthHandler in pkg/vault/auth_test.go fails ~20% of the time with 'context deadline exceeded'. The Vault client has a 5s timeout hardcoded at client.go:47. Find the root cause - do not just increase the timeout."

# Great - gives context, constraints, and expected outcome
cc "TestVaultAuthHandler in pkg/vault/auth_test.go is flaky (~20% failure rate, 'context deadline exceeded'). The test creates a real Vault client but does not configure any timeouts. The default HTTP client timeout is 0 (unlimited). The test environment has network latency of ~2s. Fix the root cause: add proper context-aware timeout configuration to the Vault client constructor. All other tests must still pass."
```

---

## Level 2: Multi-pane workflow (herdr)

The real power starts when you run agents alongside your other work.

### herdr key bindings

| Key | Action |
|-----|--------|
| `Ctrl+b "` | Split pane horizontally (top/bottom) |
| `Ctrl+b %` | Split pane vertically (left/right) |
| `Ctrl+b h/j/k/l` | Move between panes |
| `Ctrl+b c` | New tab |
| `Ctrl+b w` | Tab/workspace picker |
| `Ctrl+b y` | Copy mode |

### Pattern 1: agent + live test feedback

```
┌────────────────────────────────────┐
│  TOP: cc "refactor the auth pkg"   │
│  [agent writing code...]           │
├────────────────────────────────────┤
│  BOTTOM: watch -n2 go test ./...   │
│  [shows test results updating live]│
└────────────────────────────────────┘
```

```bash
herdr
# Ctrl+b "  (split)
# TOP PANE:
cc "refactor the PostgreSQL connection pool in pkg/db to use pgxpool"
# Ctrl+b j  (go to bottom)
# BOTTOM PANE:
watch -n2 go test ./pkg/db/... -count=1
```

The agent sees both panes. Failing tests become immediate feedback.

### Pattern 2: agent + k8s monitoring

```
┌──────────────────┬─────────────────┐
│  LEFT            │  RIGHT          │
│  oc "update HPA  │  k9s            │
│  config for      │  (live pods)    │
│  API service"    │                 │
└──────────────────┴─────────────────┘
```

### Pattern 3: agent + Terraform plan

```
┌──────────────────┬─────────────────┐
│  LEFT            │  RIGHT          │
│  cc "refactor    │  tfp            │
│  AKS nodepool    │  (plan output   │
│  Terraform"      │   updating)     │
└──────────────────┴─────────────────┘
```

### Use tabs for separate concerns

```bash
Ctrl+b c      # new tab
Ctrl+b w      # switch between tabs
```

Example day:
- **Tab 1**: Go service work
- **Tab 2**: Terraform / infra
- **Tab 3**: Kubernetes / Flux
- **Tab 4**: Incident investigation

---

## Level 3: Parallel agents with treehouse

**The problem treehouse solves:** Two agents working on the same repo collide - uncommitted changes conflict, builds interfere, tests race.

**treehouse gives each agent its own isolated worktree** with warm build cache already in place. No cloning. Instant.

```
your repo/             <- your main checkout, never touched
  main branch

~/.treehouse/my-service/
  worktree-1/          <- agent 1 works here
  worktree-2/          <- agent 2 works here
  worktree-3/          <- in pool, ready for next agent
```

### One agent in a worktree

```bash
cd ~/git/my-go-service
th                     # alias for treehouse, drops you into isolated subshell
cc "add OpenTelemetry tracing to all gRPC handlers"
exit                   # worktree returns to pool automatically
```

### Two agents in parallel (two herdr panes)

```bash
# TOP PANE (Ctrl+b "):
cd ~/git/my-go-service && th
cc "write integration tests for the Vault auth package - 80% coverage target"

# BOTTOM PANE (Ctrl+b j):
cd ~/git/my-go-service && th
oc "refactor error handling in the API layer to use structured errors with codes"
```

Both work on the same repo at the same time. No conflicts.

### Three in parallel (third tab)

```bash
# Tab 1, Pane 1:
cd ~/git/my-go-service && th && cc "improve test coverage"
# Tab 1, Pane 2:
cd ~/git/my-go-service && th && oc "standardize error handling"
# Tab 2:
cd ~/git/my-go-service && th && cc "update godoc comments for all exported types"
```

### Manage the pool

```bash
treehouse status       # see all worktrees
treehouse prune        # dry-run cleanup
treehouse prune --yes  # actually clean stale worktrees
```

---

## Level 4: Clean PRs with no-mistakes

Every PR you open goes through an AI validation gate first. No more back-and-forth on review for things a machine can catch.

### How it works

```
OLD WAY:
  code → git push origin → open PR → reviewer finds issues
  → back and forth → CI fails → fix → repeat

NEW WAY:
  code → git push no-mistakes
  → isolated worktree (your work untouched)
  → AI: code review + tests + docs + lint
  → auto-fixes safe issues
  → asks you about judgment calls
  → pushes to origin ONLY when everything is green
  → opens clean PR automatically
```

### One-time setup per repo

```bash
cd my-go-service
no-mistakes init
# Takes 5 seconds. Adds a `no-mistakes` git remote.
```

### Daily use

```bash
git add . && git commit -m "feat: add connection pooling to Vault client"

# Instead of: git push origin
git push no-mistakes

# Watch the TUI
no-mistakes
```

### Auto-fix vs ask you

- **Auto-fix** - mechanical changes (formatting, godoc stubs, obvious lint): applied automatically
- **Ask-you** - judgment calls (logic changes, security tradeoffs, design decisions): escalated to you

You approve, fix, or skip each finding. Nothing reaches origin until you say so.

### The /no-mistakes agent skill

```bash
cc "/no-mistakes refactor the connection pool and make it production-ready"
# Claude does the work AND runs it through the gate AND fixes what it can
# Only brings you things that need a human decision
```

### For Terraform and k8s

Add `.no-mistakes.yaml` to your infra repo:

```yaml
pipeline:
  - name: validate
    run: terraform validate
  - name: plan
    run: terraform plan -out=tfplan
  - name: security
    run: tfsec .
```

Now `git push no-mistakes` validates Terraform before it reaches origin.

---

## Level 5: Overnight work with gnhf

Give it an objective before you leave. Come back to a branch of incremental, committed work.

### Basic overnight run

```bash
cd my-go-service
gnhf "reduce cyclomatic complexity of the service layer without changing behaviour"
# go to sleep
# wake up to branch gnhf/reduce-cyclomatic-complexity
# full of incremental commits, one per agent iteration
```

### Multiple parallel overnight runs

```bash
gnhf --worktree "improve test coverage of the service layer to 80%" &
gnhf --worktree "add structured logging with trace IDs throughout" &
gnhf --worktree "update all Go dependencies to latest minor versions" &
# 3 agents, 3 worktrees, all running in parallel overnight
```

### Controlling the run

```bash
gnhf --max-iterations 10 "add input validation to all HTTP handlers"
gnhf --max-tokens 5000000 "refactor the auth package"
gnhf --stop-when "all public functions have godoc comments" "document the API"

# Push each iteration live
gnhf --current-branch --push "incrementally improve Terraform module structure"
```

### Reviewing work in the morning

```bash
git branch | grep gnhf/
git log gnhf/improve-test-coverage --oneline
git diff main...gnhf/improve-test-coverage

# Validate before PR
git checkout gnhf/improve-test-coverage
git push no-mistakes
```

### Common overnight objectives for Platform/SRE/Go

```bash
# Go quality
gnhf --worktree "add Prometheus metrics to all service methods" &
gnhf --worktree "add context propagation to all functions that do I/O" &
gnhf --worktree "improve error messages to include enough context for debugging" &

# Infrastructure
gnhf "update Terraform modules to use latest provider versions and fix deprecations"
gnhf "find and replace all hardcoded values that should be Terraform variables"

# Documentation
gnhf "write runbooks for each service in docs/runbooks/"
gnhf "add architecture decision records for the major design choices"
```

---

## Level 6: Multi-agent crew with firstmate

Stop managing individual agents. Talk to one agent (the first mate) and it manages the crew for you.

### Start firstmate

```bash
fm
# alias for: cd ~/git/personal/firstmate && claude
# then just talk
```

### What it looks like

```
YOU:
  "ahoy! look at the PSL service:
   1. the integration test TestVaultAuth is flaky
   2. the k8s HPA config needs updating for new traffic patterns
   3. investigate why the Temporal workflow is timing out in staging"

FIRSTMATE:
  Spawning crew...
  → fm-fix-auth-k3    (ship task: fix flaky test)
  → fm-update-hpa-p7  (ship task: update HPA config)
  → fm-investigate-q2 (scout task: Temporal timeout)

  [each agent works in its own treehouse worktree]
  [you watch the agent panel in herdr]

  Hours later:
  → PR ready: fix flaky TestVaultAuth (CI green)
  → PR ready: update HPA config
  → Scout report: Temporal timeout root cause + recommended fix

YOU:
  "merge them both, what did the Temporal investigation find?"
```

### Two task shapes

**Ship task** - delivers code as a PR:
```
> fix the race condition in the connection pool
→ crewmate works in worktree
→ git push no-mistakes
→ clean PR opened, CI green
→ you review and approve
```

**Scout task** - investigates and reports, never pushes:
```
> investigate why p99 latency spiked in staging last Tuesday
→ scout reads logs, traces, code
→ writes report to data/<id>/report.md
→ firstmate surfaces findings to you
→ you decide what to do with the findings
```

### Useful firstmate commands

```bash
> /bearings
# Full status: open PRs, CI state, active agents, scout reports, backlog
# Use every morning to pick up where you left off

> /afk I'll be in meetings for 3 hours, continue working on the backlog
# Away mode: self-handles routine updates, only wakes you for real decisions

> /updatefirstmate
# Pull latest firstmate updates and re-read instructions
```

### Project modes

Register projects once, then firstmate knows how to ship them:

```
no-mistakes mode  - all work through AI gate → clean PR (best for production)
direct-PR mode    - open PR directly, skip gate (low-risk repos)
local-only mode   - merge locally, no remote PR (personal/experimental)
```

---

## Level 7: gh-axi - GitHub is now agent-native

gh-axi session hooks are already active. Every new agent session in a git repo automatically gets: open PRs, CI status, recent issues. You no longer need to copy-paste GitHub context into prompts.

### What agents can now do without being told how

```bash
cc "the CI run failed on main - find out why and fix it"
# agent fetches failed CI logs via gh-axi, reads them, fixes the code

cc "look at the open issues and label them by priority"
# agent lists issues, reads each one, applies labels

cc "watch PR #42's CI - if it fails, fix it and push again"
# agent monitors CI, reads failure logs, patches code, pushes

cc "add the new DB password to GitHub Actions secrets"
# agent sets the secret securely (via stdin, never in args)
```

### Direct usage

```bash
gh-axi                              # dashboard: PRs, issues, CI
gh-axi pr list                      # all open PRs
gh-axi run list                     # recent CI runs
gh-axi run view 123 --log-failed    # failed lines only from CI log
gh-axi issue list --label bug       # filter issues
```

---

## The full daily workflow

### Morning (10 minutes)

```bash
herdr                              # open your workspace
git branch | grep gnhf/            # check overnight work
git push no-mistakes               # validate any good branches

fm                                 # start firstmate
> /bearings                        # brief: PRs, agents, reports, backlog
```

### During the day: delegate, run parallel

```bash
# Every time you catch yourself writing boilerplate, running tests
# manually, fixing lint, investigating CI - delegate it instead

# Multiple agents in parallel (separate herdr panes)
th && cc "implement rate limiting middleware"       # Tab 1
th && oc "update AKS Terraform module"             # Tab 2
th && cc "add Prometheus metrics"                  # Tab 3 (new herdr tab)

# Let firstmate manage a fleet
fm
> fix issues #42 and #67, and investigate the Temporal timeout in staging
```

### Before pushing anything: gate it

```bash
# Never:
git push origin

# Always:
git push no-mistakes
```

### End of day: launch overnight runs

```bash
gnhf --worktree "audit all endpoints for missing input validation" &
gnhf --worktree "add golangci-lint and fix all violations" &

fm
> work through the backlog overnight, prioritize test coverage
> /afk
```

---

## Practical recipes

### Recipe 1: Fix a flaky test

```bash
cc "the test TestConnectionPool in pkg/db/pool_test.go fails ~30% of the time with 'connection refused'. Investigate the root cause. Do not add sleep() or retry logic as a band-aid."
```

### Recipe 2: Investigate a production incident

```bash
fm
> scout task: investigate why API latency spiked 3x in production at 14:30 UTC yesterday.
> Look at: application logs, k8s events, recent deployments (gh-axi), Temporal workflow history.
> Deliverable: root cause, contributing factors, recommended fixes ranked by impact.
```

### Recipe 3: Terraform refactor

```bash
no-mistakes init                    # one-time per repo
cc "refactor the AKS Terraform module to separate node pools into their own module. Requirements: backwards compatible, no resource recreation, all variables documented, outputs match current interface."
git push no-mistakes                # gate runs terraform validate + plan + tfsec
```

### Recipe 4: Go service full observability

```bash
gnhf --worktree "add OpenTelemetry tracing to all methods that do I/O (DB, Vault, HTTP, gRPC)" &
gnhf --worktree "add Prometheus metrics: request count, duration, error rate per handler" &
gnhf --worktree "add structured logging with trace ID correlation throughout" &
# All three running in parallel overnight
```

### Recipe 5: Security audit

```bash
fm
> scout task: security audit of pkg/vault.
> Check for: hardcoded credentials, overly broad Vault policies, missing token renewal,
> sensitive data in logs or error messages, improper TLS configuration.
> Deliverable: findings report with severity (critical/high/medium/low) and fix recommendations.
```

### Recipe 6: PR review assistance

```bash
gh-axi pr view 42
cc "review PR #42 - focus on: error handling correctness, missing test cases, security issues in the Vault integration. Write a structured review with specific file:line comments I can paste directly into GitHub."
```

### Recipe 7: Dependency update

```bash
gnhf --max-iterations 30 "update Go module dependencies: patch versions first, then minor. Run go test ./... after each update. Stop and report if any update breaks tests."
```

### Recipe 8: Documentation from scratch

```bash
gnhf --worktree "add godoc comments to all exported functions and types that lack them" &
gnhf --worktree "write runbooks in docs/runbooks/ for each service: startup, shutdown, common failures, recovery steps" &
```

---

## Common mistakes to avoid

### 1. Being vague

```bash
# Bad
cc "fix the tests"

# Good
cc "the test TestVaultTokenRenewal in pkg/vault/client_test.go fails after 5 minutes with 'token expired'. The Vault client does not renew tokens. Add automatic renewal using a background goroutine - renew at 75% of TTL (1 hour default). All other tests must still pass."
```

### 2. Watching the agent instead of working in parallel

While one agent works, start the next task in another pane. Agents work at human speed - use that time.

### 3. Pushing to origin directly

One bad PR wastes hours of review time. `git push no-mistakes` catches issues before your team sees them.

### 4. Not updating AGENTS.md

Every time you correct an agent ("don't use fmt.Println, use the internal logger"), add it to `home/AGENTS.md`. It becomes a standing rule for all future sessions.

```bash
nvim ~/.dotfiles/home/AGENTS.md
# Save - active immediately in all agents, no rebuild needed
```

### 5. Delegating architecture decisions

Agents excel at implementing clear specifications. They are not good at deciding what to build. Write the spec, let them implement it.

---

## AGENTS.md: your global standing orders

The single highest-leverage file in this setup. Every agent reads it at the start of every session. Rules you add here apply permanently.

```markdown
## Code standards
- Use pkg/logger (internal), not zap directly
- All errors: fmt.Errorf("operation: %w", err)
- Never hardcode timeouts - use constants from pkg/config
- All k8s containers must have resource requests and limits

## Always do before finishing
- Run go test ./... and ensure all tests pass
- Run golangci-lint and fix all issues
- No TODO comments left in changed files

## Never do
- No retry logic without exponential backoff and jitter
- Never log sensitive data (tokens, passwords, PII)
- No fmt.Println in production code - use the logger
- Never hardcode credentials or API keys

## Project context
- This is my personal dotfiles/playground setup
- Personal projects: usually Node/TypeScript, occasional Python or Rust
- GitHub account: unplugged-kk (kishore.behera2010@gmail.com)
```

Edit it live - takes effect in the next agent session:

```bash
nvim ~/.dotfiles/home/AGENTS.md
```

---

## The 100x framework: what to keep, what to delegate

### Keep for yourself
- Architecture and design decisions
- Security and access decisions
- Final PR approval (read the diff, then approve)
- Incident commander role
- Anything requiring business context agents don't have

### Delegate aggressively
- All boilerplate code
- Test writing (unit, integration, e2e)
- Lint, formatting, coverage
- Documentation and godoc
- CI failure investigation
- Dependency updates
- Code refactoring with clear spec
- Terraform and k8s config changes (with no-mistakes gate)
- GitHub issue triage and labeling
- Security audits and reports

### The multiplier

```
1 agent doing 1 task in sequence  =  1x
3 agents in parallel (treehouse)  =  3x
8-hour overnight run (gnhf)       = multiply by 8x
firstmate crew (5+ agents)        = 10x+
all of the above combined         = 100x
```

**Start today:**

```bash
herdr                              # open your workspace
# Ctrl+b "                         # split pane
cc "improve test coverage of [any package you know needs it]"
# while it works, open another pane and do something else
```

That is the first step. The rest follows naturally.
