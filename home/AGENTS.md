# global agent instructions

## Writing & communication
- Never use the em dash "-". Use plain dash "-" instead
- When writing commit messages, NEVER auto-add your agent name as co-author

## Files
- Never manually modify CHANGELOG.md files or any files that are marked as auto-generated

## Technical decisions
- When making technical decisions, do not give much weight to development cost.
  Instead, prefer quality, simplicity, robustness, scalability, and long-term maintainability.

## Bug fixing
- When doing bug fixes, always start with reproducing the bug in an E2E setting as closely aligned
  with how an end user would experience it as possible.
  This makes sure you find the real problem so your fix will actually solve it.

## Quality bar
- When end-to-end testing a product, be picky about the UI you see and be obsessed with pixel perfection.
  If something clearly looks off, even if it is not directly related to what you are doing, try to get it fixed along the way.
- Apply that same high standard to engineering excellence: lint, test failures, and test flakiness.
  If you see one, even if it is not caused by what you are working on right now, still get it fixed.

## Infrastructure (Terraform, Kubernetes)
- When modifying Terraform, always run `terraform plan` before proposing `terraform apply`.
- Never hard-code credentials, secrets, or API keys. Use environment variables or secret stores.
- For Kubernetes manifests, always specify resource requests and limits.
- Use `kubectl diff` before `kubectl apply` when making changes to live clusters.

## Git workflow
- Prefer small, focused commits with clear messages (conventional commits: feat/fix/chore/docs).
- Always check `git status` and `git diff --staged` before committing.
- Never force-push to main/master.

## Code review standards
- When reviewing or generating code, check for: SQL injection, XSS, hardcoded secrets, missing error handling.
- Always suggest adding tests for non-trivial logic.
