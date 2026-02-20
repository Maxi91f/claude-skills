# Claude Code Skills

Custom skills for [Claude Code](https://claude.ai/claude-code) CLI.

## Skills

### maxi-task-resolver

Autonomously resolves development tasks from start to finish using iterative agent loops.

**Features:**
- Creates isolated git worktree
- Launches Claude agents in tmux session
- Critical reviewer validates completion
- Generates PR proposal

**Usage:**
```
/maxi-task-resolver PROJ-1234
/maxi-task-resolver https://linear.app/your-org/issue/PROJ-1234/...
/maxi-task-resolver Add authentication endpoint
```

## Installation

Clone to `~/.claude/skills/`:

```bash
git clone https://github.com/Maxi91f/claude-skills.git ~/.claude/skills
```

## Requirements

- Claude Code CLI
- tmux
- Linear MCP (optional, for Linear integration)
