# Claude + tmux Quick Reference

## Your Commands

| Command | What it does |
|---------|--------------|
| `cc` | Start Claude in new tmux window, attach to session |
| `cc myproject` | Same but name the window "myproject" |
| `cc -n` | Open NEW Ghostty window with Claude (don't hijack current terminal) |
| `cc -n myproject` | New Ghostty + named window |

## Inside tmux (prefix is Ctrl-b)

| Keys | Action |
|------|--------|
| `Ctrl-b w` | **List all windows** - arrow keys to select, Enter to switch |
| `Ctrl-b n` | Next window |
| `Ctrl-b p` | Previous window |
| `Ctrl-b 1` | Go to window 1 (or 2, 3, etc.) |
| `Ctrl-b d` | Detach (exit tmux but leave session running) |
| `Ctrl-b ,` | Rename current window |

## From any terminal

| Command | Action |
|---------|--------|
| `tmux attach -t claude` | Attach to your claude session |
| `tmux ls` | List all sessions |
| `tmux list-windows -t claude` | See all windows in claude session |

## Key Points

- **Multiple clients OK**: You can attach from Mac AND phone simultaneously
- **Session persists**: Detach (`Ctrl-b d`) or close terminal - Claude keeps running
- **Phone access**: SSH in, then `tmux attach -t claude`

## If Something Goes Wrong

```bash
# Kill a stuck window
tmux kill-window -t claude:windowname

# Start fresh
tmux kill-session -t claude
cc  # Creates new session automatically
```
