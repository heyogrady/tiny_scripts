# Git Worktree Commands

Manage git worktrees for isolated branch development.

## Commands

### `gwt` - Switch to branch worktree

```bash
gwt                     # List all worktrees
gwt <branch>            # Switch to branch (creates worktree if needed)
```

### `gwtc` - Create new branch with worktree

```bash
gwtc <new-branch>       # Create branch + worktree, switch to it
```

Both commands open Cursor automatically after switching.

## Examples

```bash
# Review someone's PR
gwt their-feature-branch

# Start new work
gwtc my-new-feature

# See all worktrees
gwt
```

## Notes

- Worktrees are created in `.worktrees/<branch-name>/` within the repo
- Branch names with `/` become `-` in directory names (e.g., `feature/foo` → `feature-foo`)
- Also available as `git wt` and `git wtc`
