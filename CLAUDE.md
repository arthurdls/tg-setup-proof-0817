# Repository operating contract

Run the repository checks before handing off a change. Keep temporary or
machine-specific state out of version control.

## Native merge queue

Enqueue a pull request with `gh pr merge <n> --squash --auto`. The queue builds
five candidates at a time, uses `HEADGREEN`, and lands squash merges only.

Never install a GitHub ruleset containing a `creation` rule. The merge queue
must create `gh-readonly-queue/main/pr-N-<sha>` refs, and a creation rule
silently evicts every queue entry; excluding `gh-readonly-queue/**` does not
fix it. Enforce one branch per lane only through the local pre-push hook.

Local pushes are protected by `.githooks/pre-push`. Its lane scope is the
repository-local file Git resolves as `touch-grass-allowed-push-refs`; do not
override this scope with environment variables. Each line contains one allowed
fully-qualified branch ref, such as `refs/heads/lanes/example`.

Install the hook with `git config core.hooksPath .githooks` after copying this
template into a repository. The bootstrap reconciler creates `AGENTS.md` as a
symlink to this file.
