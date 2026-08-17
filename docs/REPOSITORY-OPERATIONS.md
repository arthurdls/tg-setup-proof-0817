# Repository operations

## Continuous integration

CI runs for pull requests, merge queues, and pushes to `main`. The required
command is:

```sh
go test ./...
```

## Merge queue

Enqueue an approved pull request with:

```sh
gh pr merge <n> --squash --auto
```

The queue is configured for five concurrent builds, `HEADGREEN`, and squash
merges. Do not add a GitHub ruleset with a `creation` rule: it prevents the
queue from creating its `gh-readonly-queue/main/pr-N-<sha>` candidate refs,
even if those refs are listed as exclusions. The one-branch-per-lane rule is
therefore enforced only by the local pre-push hook.

## Auto-merge is armed for you

`.github/workflows/automerge.yml` arms auto-merge on every non-draft pull
request when it is opened, reopened, marked ready for review, or pushed to. A
green pull request therefore merges without anyone remembering a command.

The arming mutation is strategy-sensitive in both directions, and both failures
are silent no-ops that leave a finished pull request sitting:

- when a merge queue owns the branch, naming a strategy is rejected with *"The
  merge strategy for main is set by the merge queue"*;
- when no queue owns it, omitting a strategy defaults to `MERGE`, which this
  squash-only repository rejects with *"Merge method merge commits are not
  allowed on this repository"*.

The workflow asks the repository which case applies instead of guessing, so do
not "simplify" it down to one form. Verify it is live with:

```sh
gh pr view <n> --json autoMergeRequest
gh run list --workflow=automerge.yml
```

## Local push lane scope

The pre-push hook reads its allowlist only from the current repository's Git
directory. Initialize it with a fully-qualified ref for the active lane:

```sh
git rev-parse --git-path touch-grass-allowed-push-refs
printf '%s\n' refs/heads/lanes/example > "$(git rev-parse --git-path touch-grass-allowed-push-refs)"
git config core.hooksPath .githooks
```

The hook reads the standard four-field pre-push updates from stdin. It rejects
refs outside this allowlist and rejects a supplied local object ID that is no
longer the object ID of the named local lane ref.
