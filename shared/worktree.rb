require 'fileutils'
require_relative './common'

# Worktrees live outside the repo, at <root>/<repo>/<branch>. Keeping them
# inside the repo made every filesystem walk from the repo root (editors, file
# watchers, search, the entire CLI's per-prompt hook) traverse every branch's
# full checkout. Override the root with GIT_WT_ROOT.
WORKTREE_ROOT = File.expand_path(ENV.fetch('GIT_WT_ROOT', '~/worktrees'))

def main_worktree_root
  list_worktrees.first&.dig(:path)
end

def worktree_repo_dir
  root = main_worktree_root
  abort 'Not inside a git repository (no worktrees found).' if root.nil?

  File.join(WORKTREE_ROOT, File.basename(root))
end

# Where a worktree for this branch would be created under the current layout.
def default_worktree_path(branch_name)
  # Sanitize branch name for directory (replace / with -)
  File.join(worktree_repo_dir, branch_name.gsub('/', '-'))
end

# The location git already tracks for this branch (or worktree directory name),
# if any. Lets worktrees created under the old in-repo layout keep working until
# they are migrated, instead of looking absent and colliding on re-create.
def registered_worktree_path(name)
  main = main_worktree_root

  list_worktrees.each do |wt|
    path = wt[:path]
    next if path.nil? || path == main

    return path if wt[:branch] == name || File.basename(path) == name
  end

  nil
end

def worktree_path(branch_name)
  registered_worktree_path(branch_name) || default_worktree_path(branch_name)
end

def worktree_exists?(branch_name)
  path = worktree_path(branch_name)
  File.directory?(path)
end

def list_worktrees
  output = `git worktree list --porcelain`
  return [] if output.empty?

  output.split("\n\n").map do |block|
    lines = block.split("\n")
    path = lines.find { |l| l.start_with?('worktree ') }&.sub('worktree ', '')
    branch = lines.find { |l| l.start_with?('branch ') }&.sub('branch refs/heads/', '')
    { path: path, branch: branch }
  end.compact
end

def branch_exists_remote?(branch_name)
  system("git ls-remote --exit-code --heads origin #{branch_name} > /dev/null 2>&1")
end

def branch_exists_local?(branch_name)
  system("git show-ref --verify --quiet refs/heads/#{branch_name}")
end

# Worktrees live outside the repo now, so nothing needs to be gitignored.
def ensure_worktree_root
  FileUtils.mkdir_p(worktree_repo_dir)
end

def call_hook(hook_name, *args)
  hook_path = File.join(main_worktree_root, '.worktree-hooks', hook_name)
  return unless File.executable?(hook_path)

  warn "Calling #{hook_name} hook..."
  system(hook_path, *args)
end

def create_worktree(branch_name, new_branch: false)
  ensure_worktree_root
  path = worktree_path(branch_name)

  if new_branch
    execute_cmd "git worktree add -b #{branch_name} '#{path}'"
  else
    # Fetch first to ensure we have latest refs
    execute_cmd "git fetch origin"
    execute_cmd "git worktree add '#{path}' #{branch_name}"
  end

  # Call post-create hook if it exists
  call_hook('post-create', path, branch_name)

  path
end

def remove_worktree(worktree_name)
  path = worktree_path(worktree_name)

  # Call pre-delete hook
  call_hook('pre-delete', path, worktree_name)

  # Remove worktree
  execute_cmd "git worktree remove '#{path}'"

  # Call post-delete hook
  call_hook('post-delete', path, worktree_name)
end

def switch_to_worktree(branch_name)
  path = worktree_path(branch_name)

  # Output cd command for shell to eval
  # Also open in Cursor and Sublime Merge
  # puts "cd #{path} && cursor . && smerge -n \"$(pwd)\""
  puts "cd '#{path}'"
end
