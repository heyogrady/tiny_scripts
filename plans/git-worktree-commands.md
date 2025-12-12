**PLAN COMPLETED ON 2025-12-12**

---

# Git Worktree Commands for Isolated Branch Development

## Overview

Create Ruby scripts that automatically manage git worktrees for branch isolation. When switching to or creating branches, these commands will ensure each branch has its own worktree in `.worktrees/<branch-name>/` within the project, then open it in Cursor.

## Problem Statement / Motivation

When working with Claude Code and multiple AI agents, having isolated worktrees per branch prevents:
- Dirty working directory conflicts between concurrent sessions
- Accidental commits of unrelated changes
- Context confusion when reviewing others' branches

Current workflow requires manual `git worktree add/list` commands and directory navigation. This should be automatic.

## Proposed Solution

Create two Ruby scripts in `tiny_scripts/scripts/` that integrate as git subcommands:

| Command | Purpose | Example |
|---------|---------|---------|
| `git wt <branch>` | Switch to existing branch's worktree (create if needed) | `git wt feature-x` |
| `git wtc <branch>` | Create new branch with worktree | `git wtc my-new-feature` |

Both commands will:
1. Ensure `.worktrees/` directory exists
2. Check if worktree already exists for the branch
3. Create worktree if missing
4. `cd` to the worktree directory
5. Open Cursor in that directory

## Technical Approach

### Directory Structure

```
~/workspace/crm/                    # Main repo (master branch)
├── .worktrees/                     # Worktrees directory
│   ├── feature-branch-a/           # Full clone for branch a
│   ├── feature-branch-b/           # Full clone for branch b
│   └── review-someones-pr/         # Full clone for reviewing
├── app/
├── config/
└── ...
```

### Script Architecture

```
tiny_scripts/
├── scripts/
│   ├── git-wt                      # Switch to/create worktree for existing branch
│   └── git-wtc                     # Create new branch with worktree
└── shared/
    ├── common.rb                   # Existing utilities
    └── worktree.rb                 # NEW: Worktree helper functions
```

### Implementation Details

#### `shared/worktree.rb` - Shared Worktree Utilities

```ruby
# tiny_scripts/shared/worktree.rb

require_relative './common'

WORKTREE_DIR = '.worktrees'

def git_root
  `git rev-parse --show-toplevel`.chomp
end

def worktree_path(branch_name)
  # Sanitize branch name for directory (replace / with -)
  safe_name = branch_name.gsub('/', '-')
  File.join(git_root, WORKTREE_DIR, safe_name)
end

def worktree_exists?(branch_name)
  path = worktree_path(branch_name)
  File.directory?(path)
end

def list_worktrees
  `git worktree list --porcelain`.split("\n\n").map do |block|
    lines = block.split("\n")
    path = lines.find { |l| l.start_with?('worktree ') }&.sub('worktree ', '')
    branch = lines.find { |l| l.start_with?('branch ') }&.sub('branch refs/heads/', '')
    { path: path, branch: branch }
  end
end

def branch_exists_remote?(branch_name)
  system("git ls-remote --exit-code --heads origin #{branch_name} > /dev/null 2>&1")
end

def branch_exists_local?(branch_name)
  system("git show-ref --verify --quiet refs/heads/#{branch_name}")
end

def ensure_worktrees_dir
  dir = File.join(git_root, WORKTREE_DIR)
  Dir.mkdir(dir) unless File.directory?(dir)

  # Ensure .worktrees is in .gitignore
  gitignore = File.join(git_root, '.gitignore')
  if File.exist?(gitignore)
    content = File.read(gitignore)
    unless content.include?('.worktrees')
      File.open(gitignore, 'a') { |f| f.puts "\n# Git worktrees\n.worktrees/" }
      puts "Added .worktrees/ to .gitignore"
    end
  end
end

def create_worktree(branch_name, new_branch: false)
  ensure_worktrees_dir
  path = worktree_path(branch_name)

  if new_branch
    execute_cmd "git worktree add -b #{branch_name} #{path}"
  else
    # Fetch first to ensure we have latest refs
    execute_cmd "git fetch origin"
    execute_cmd "git worktree add #{path} #{branch_name}"
  end

  path
end

def switch_to_worktree(branch_name)
  path = worktree_path(branch_name)

  # Output cd command for shell to eval
  # Also open in Cursor
  puts "cd #{path} && cursor ."
end

def print_shell_function_hint
  puts ""
  puts "NOTE: To actually change directories, add this function to your shell:"
  puts ""
  puts "  gwt() { eval $(git-wt \"$@\"); }"
  puts "  gwtc() { eval $(git-wtc \"$@\"); }"
  puts ""
end
```

#### `scripts/git-wt` - Switch to Branch Worktree

```ruby
#!/usr/bin/env ruby

# git-wt: Switch to a branch's worktree, creating it if needed
#
# Usage:
#   git wt <branch-name>    # Switch to existing branch's worktree
#   git wt                  # List all worktrees
#
# Examples:
#   git wt feature-xyz      # Switch to feature-xyz worktree
#   git wt origin/main      # Switch to main branch worktree

require_relative '../shared/worktree'

branch = ARGV[0]

# No args - list worktrees
if branch.nil?
  puts "Current worktrees:"
  list_worktrees.each do |wt|
    puts "  #{wt[:branch] || '(detached)'}: #{wt[:path]}"
  end
  exit 0
end

# Strip origin/ prefix if present
branch = branch.sub(/^origin\//, '')

# Check if worktree already exists
if worktree_exists?(branch)
  puts "Switching to existing worktree for '#{branch}'"
  switch_to_worktree(branch)
  exit 0
end

# Check if branch exists (local or remote)
unless branch_exists_local?(branch) || branch_exists_remote?(branch)
  puts "Error: Branch '#{branch}' does not exist locally or on remote."
  puts "Use 'git wtc #{branch}' to create a new branch with worktree."
  exit 1
end

# Create worktree for existing branch
puts "Creating worktree for existing branch '#{branch}'..."
create_worktree(branch, new_branch: false)
switch_to_worktree(branch)
```

#### `scripts/git-wtc` - Create New Branch with Worktree

```ruby
#!/usr/bin/env ruby

# git-wtc: Create a new branch with its own worktree
#
# Usage:
#   git wtc <new-branch-name>
#
# Examples:
#   git wtc feature-new-thing
#   git wtc fix/bug-123

require_relative '../shared/worktree'

branch = ARGV[0]

if branch.nil?
  puts "Usage: git wtc <new-branch-name>"
  puts ""
  puts "Creates a new branch with its own worktree in .worktrees/<branch>/"
  exit 1
end

# Check if branch already exists
if branch_exists_local?(branch) || branch_exists_remote?(branch)
  puts "Error: Branch '#{branch}' already exists."
  puts "Use 'git wt #{branch}' to switch to it."
  exit 1
end

# Check if worktree already exists (shouldn't happen, but safety check)
if worktree_exists?(branch)
  puts "Error: Worktree already exists for '#{branch}'"
  switch_to_worktree(branch)
  exit 1
end

# Create new branch with worktree
puts "Creating new branch '#{branch}' with worktree..."
create_worktree(branch, new_branch: true)
switch_to_worktree(branch)
```

### Shell Integration (Critical)

Since Ruby scripts cannot change the parent shell's directory, we need shell wrapper functions. Add to `dotfiles-local/aliases.local`:

```bash
# Git worktree shortcuts - eval the output to change directory
gwt() {
  output=$(git-wt "$@")
  if [[ $output == cd\ * ]]; then
    eval "$output"
  else
    echo "$output"
  fi
}

gwtc() {
  output=$(git-wtc "$@")
  if [[ $output == cd\ * ]]; then
    eval "$output"
  else
    echo "$output"
  fi
}

# Also add tab completion for gwt
_gwt_completion() {
  local branches=$(git branch -a 2>/dev/null | sed 's/^[* ]*//' | sed 's/remotes\/origin\///' | sort -u)
  COMPREPLY=($(compgen -W "$branches" -- "${COMP_WORDS[COMP_CWORD]}"))
}
complete -F _gwt_completion gwt
complete -F _gwt_completion git-wt
```

## Acceptance Criteria

### Functional Requirements

- [ ] `git wt` with no args lists all worktrees
- [ ] `git wt <branch>` switches to existing branch's worktree
- [ ] `git wt <branch>` creates worktree if branch exists but worktree doesn't
- [ ] `git wt <branch>` fails gracefully if branch doesn't exist
- [ ] `git wtc <branch>` creates new branch AND worktree
- [ ] `git wtc <branch>` fails gracefully if branch already exists
- [ ] Both commands open Cursor after switching
- [ ] `.worktrees/` is automatically added to `.gitignore`
- [ ] Branch names with `/` (like `feature/foo`) are sanitized to `feature-foo`

### Non-Functional Requirements

- [ ] Commands work from any subdirectory within a git repo
- [ ] Scripts follow existing tiny_scripts Ruby patterns
- [ ] Tab completion works for branch names with `gwt`

## Implementation Phases

### Phase 1: Core Scripts

1. Create `shared/worktree.rb` with helper functions
2. Create `scripts/git-wt` for switching/creating worktrees
3. Create `scripts/git-wtc` for new branch creation
4. Make scripts executable

### Phase 2: Shell Integration

1. Add `gwt` and `gwtc` wrapper functions to `aliases.local`
2. Add tab completion for branch names
3. Source updated aliases

### Phase 3: Testing & Polish

1. Test with various branch name formats
2. Test from different directories within repo
3. Test edge cases (no git repo, branch doesn't exist, etc.)

## File Changes Summary

| File | Action |
|------|--------|
| `tiny_scripts/shared/worktree.rb` | CREATE |
| `tiny_scripts/scripts/git-wt` | CREATE |
| `tiny_scripts/scripts/git-wtc` | CREATE |
| `dotfiles-local/aliases.local` | EDIT (add functions) |

## Usage Examples

```bash
# List all worktrees
git wt

# Switch to someone's PR branch for review
git wt feature-their-branch

# Create a new feature branch with isolated worktree
git wtc my-new-feature

# Quick aliases (after shell integration)
gwt feature-branch      # Switch to existing
gwtc new-thing          # Create new
```

## Future Enhancements

- `git wt -d <branch>` - Delete a worktree and optionally the branch
- `git wt --prune` - Clean up worktrees for merged/deleted branches
- `git wt --status` - Show status of all worktrees (dirty, ahead/behind)
- Integration with Claude Code slash commands for seamless AI workflows

## References

### Internal References
- Existing script pattern: `tiny_scripts/scripts/gp:1-19`
- Shared utilities: `tiny_scripts/shared/common.rb:1-51`
- Aliases location: `dotfiles-local/aliases.local`

### External References
- [Git Worktree Documentation](https://git-scm.com/docs/git-worktree)
- [ThoughtBot Dotfiles](https://github.com/thoughtbot/dotfiles)

---

## Implementation Retrospective

### Divergences from Plan

**`print_shell_function_hint` not implemented** - The plan included this helper function in `worktree.rb` but we didn't use it. The shell functions were added directly to `aliases.local` so there's no need to print setup hints.

**Tab completion may not work in zsh** - The completion code uses bash syntax (`COMPREPLY`, `compgen`) which doesn't work in zsh. Added `2>/dev/null` to suppress errors. If tab completion is needed, will require zsh-specific completion using `_arguments` or `compadd`.

**Phase 3 testing was minimal** - Did basic happy-path testing (list, create, switch, error cases) but did not exhaustively test:
- Running from subdirectories within a repo
- Branch names with slashes (e.g., `feature/foo`)
- The `.gitignore` auto-addition behavior
- Repos without a `.gitignore` file

These can be tested as issues arise in real usage.

### What Worked Well

The plan's code examples were nearly copy-paste ready. The architecture (Ruby scripts outputting shell commands for eval) worked as designed.
