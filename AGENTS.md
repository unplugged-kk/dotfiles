# AGENTS.md

This file contains project-wide instructions that apply to every future agent session.

## Engineering Principles

- Prioritize correctness over speed.
- Prefer simplicity over cleverness.
- Prefer maintainability over short-term convenience.
- Optimize for long-term ownership, not the quickest implementation.
- Do not introduce unnecessary abstractions or dependencies.
- Make the smallest change that fully solves the problem.

## Before Writing Code

Always understand the existing implementation before modifying it.

Before making significant changes:

- Read the surrounding code.
- Understand why the current implementation exists.
- Follow existing architectural patterns.
- Reuse existing utilities before creating new ones.
- Search the repository for similar implementations.

Do not rewrite working code simply because you prefer a different style.

## Bug Fixes

Never guess.

When fixing bugs:

1. Reproduce the issue whenever possible.
2. Identify the root cause.
3. Fix the root cause instead of masking symptoms.
4. Consider similar code paths that may contain the same defect.
5. Add or update tests that would have caught the bug.

## Code Quality

Leave the codebase better than you found it.

If you encounter:

- broken tests
- flaky tests
- lint failures
- obvious technical debt
- duplicated logic
- incorrect documentation

fix them if they are reasonably related to your work.

Avoid drive-by refactors unrelated to the task.

## Testing

Never assume code works.

Before considering work complete:

- run relevant tests
- run linters
- verify changed behavior manually when appropriate
- ensure existing functionality still works

Do not disable tests to make CI pass.

## Git

Keep commits clean.

- Never add yourself as a co-author.
- Do not rewrite history unless explicitly requested.
- Do not commit generated artifacts unless the repository intentionally tracks them.
- Never commit secrets, credentials, tokens, or local configuration.

## Generated Files

Do not manually edit generated files unless explicitly instructed.

Regenerate them using the project's documented tooling.

Examples include:

- generated APIs
- lock files (unless dependency changes require them)
- generated documentation
- generated clients

## Documentation

When behavior changes:

- update relevant documentation
- remove outdated documentation
- avoid duplicating information already documented elsewhere

Point readers to the canonical source whenever possible.

---

# Project Decisions

The following decisions are intentional.

## Homebrew cleanup

`homebrew.onActivation.cleanup = "zap"` in `configuration.nix` is intentional.

Do **not** change it to `"uninstall"` or `"none"`.

The repository intentionally enforces that every Homebrew package is declared through Nix rather than installed manually. This keeps developer machines reproducible.

Users are warned in the README. This note exists to prevent agents from "fixing" the configuration.

## Bun

`bun` is declared in `home.nix` `home.packages`, not installed manually.

The `claude-mem` Claude Code plugin (`~/.claude/plugins/cache/thedotmack/claude-mem/`) requires `bun` on PATH for its `Setup` hook to materialize runtime dependencies (`zod` and tree-sitter grammars). A manual install at `~/.bun/bin/bun` is left in place as a fallback but the Nix-managed binary at `/etc/profiles/per-user/kishore/bin/bun` wins on PATH and is what the plugin's auto-install uses.

If the plugin ever reports `Cannot find module 'zod/v3'`, run from the plugin root: `bun install --production` and ensure `.install-version` matches the plugin version.

## Validation Evidence

Never commit `.no-mistakes/`.

This directory is intentionally gitignored.

If validation pipelines accidentally stage files from `.no-mistakes/`, remove them before committing or merging.

---

# When Updating This File

This file should contain only long-lived knowledge useful for almost every future agent session.

Prefer:

- updating existing entries
- rewriting outdated guidance
- removing obsolete information

Avoid:

- temporary project notes
- implementation details already visible in code
- task-specific instructions
- duplicated documentation

Keep entries concise and high signal.

---

# Style

When generating code:

- Match the existing project style.
- Minimize unnecessary comments.
- Write readable code instead of clever code.
- Prefer explicit behavior over implicit magic.
- Avoid introducing new dependencies unless they provide substantial value.

When generating commit messages:

- Use conventional commits if the repository already uses them.
- Do not add your own attribution.
- Keep commit messages concise and descriptive.

When writing documentation:

- Prefer examples over long explanations.
- Keep Markdown clean and easy to scan.
- Link to the canonical source rather than duplicating content.

## Decision Making

Before introducing a new library, framework, or pattern:

- Check whether the repository already solves the problem.
- Prefer consistency with the existing codebase over introducing a newer technology.
- Explain trade-offs when proposing architectural changes.

## Scope Discipline

Stay within the requested scope.

Do not perform unrelated refactors unless they are necessary for correctness, security, or compilation.
