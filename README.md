# Ship360
GenAI for Ship360

## Branch Protection Rules

Restrict deletions:

✔️ No one can delete the main branch.
Require a pull request before merging (1 approval):

✔️ All changes must go through a PR and be approved by at least one reviewer.
Dismiss stale pull request approvals when new commits are pushed:

✔️ If new commits are added to a PR, previous approvals are dismissed, ensuring reviewers see the latest changes.
 Allowed merge methods: Merge, Squash, Rebase:

✔️ You allow all standard merge methods. This is fine—choose what fits your workflow.
Require status checks to pass:

✔️ PRs can only be merged if all required status checks pass.
⚠️ Note: You haven’t added any specific status checks yet, so this won’t block merges until you do.

Require branches to be up to date before merging:
✔️ PRs must be up to date with main before merging, preventing integration issues.

Blocked force pushes:
✔️ No one can force-push to main, protecting history.
