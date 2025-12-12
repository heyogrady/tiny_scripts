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
