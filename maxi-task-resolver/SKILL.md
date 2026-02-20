---
description: Autonomously resolve a task from start to finish
user_invocable: true
---

# Task Resolver

Autonomously resolves a development task from start to finish using iterative agent loops.

## What This Does

1. Creates a git worktree from main branch
2. Sets up a `.runtime/` workspace with task description and whiteboard
3. Launches autonomous Claude Code agents in a tmux session to complete the task
4. Runs autonomously in background (20-40 minutes typical)
5. Generates a comprehensive summary of the work
6. Creates a commit and pushes the branch

## Usage

Invoke this skill with a Linear issue (ID or URL) or task description:

```
/maxi-task-resolver PROJ-1234
```

```
/maxi-task-resolver https://linear.app/your-org/issue/PROJ-1234/add-user-authentication
```

```
/maxi-task-resolver Add user authentication endpoint with JWT tokens
```

The LLM launcher will automatically detect whether the input is a Linear issue or a task description.

## Agent Instructions

When this skill is invoked, you (the LLM launcher) must execute these steps:

### Step 1: Detect Input Type and Gather Task Information

First, analyze the user input to determine its type:

**Detection patterns:**
- **Linear issue ID**: Matches pattern `[A-Z]+-\d+` (e.g., `PROJ-1234`)
- **Linear URL**: Contains `linear.app/` (e.g., `https://linear.app/your-org/issue/PROJ-1234/...`)
- **Task description**: Anything else

**If input is Linear issue (ID or URL):**
1. Extract issue ID from URL if needed (e.g., `PROJ-1234` from URL path)
2. Use Linear MCP (`mcp__linear__get_issue`) to fetch complete issue details:
   - Title
   - Description
   - Comments
   - Status, Priority, Labels
3. Analyze the issue to determine:
   - Branch type (feat, fix, refactor, docs)
   - Affected service/package (or "general" if unclear)
   - Short action description for branch name

**If input is task description:**
1. Use the description as-is for TASK.md
2. Infer branch type (default: feat)
3. Infer service name (default: general)
4. Create short action from description (first few words, sanitized)

### Step 2: Determine Branch Name

Use the branch naming pattern: `<type>/<service>-<descriptive-action>`

**Branch Types:**
- `feat` - Almost everything is a feature, if it adds a functionality, is a feature
- `fix` - Only if it solves a problem, without changing any signatures or functionality
- `refactor` - Changes in the code without changes in the functionality or function signatures
- `docs` - Only changes on public or private docs

**Service/Package Naming:**
- Services are in `services/` directory (e.g., `api`, `worker`, `auth`)
- Packages are in `packages/` directory (e.g., `utils`, `core`)
- Use the service or package short name (directory name)
- If changes span multiple services or are general, use `general` or the most affected service

**Descriptive Action:**
- Brief description of what the branch does (e.g., `add-endpoint`, `handle-null-payload`, `simplify-schema`)
- Sanitize: lowercase, alphanumeric + hyphens only, max 40 chars
- Should clearly communicate the change

**Examples:**
- `feat/api-add-endpoint`
- `fix/worker-handle-null`
- `refactor/utils-simplify-schema`
- `docs/general-update-readme`

### Step 3: Execute Startup Script

Run the startup script with the determined branch name:

```bash
~/.claude/skills/maxi-task-resolver/startup.sh --branch-name <branch-name>
```

The script will:
- Create the base `.worktree` directory if it doesn't exist
- Create a new worktree in `<git-root>.worktree/<sanitized-branch-name>`
- Copy critical gitignored files (`.envrc`, `CLAUDE.local.md`, `.env*`) from main repo
- Initialize the `.runtime/` directory with WHITEBOARD.md

Capture the worktree path from the last line of output (format: `Worktree path: <path>`).

### Step 4: Fill TASK.md Template

Read the TASK.md template and fill it with gathered information using the Write tool.

**Template location:** `~/.claude/skills/maxi-task-resolver/templates/TASK.md.template`

**Placeholders to replace:**
- `{{TITLE}}` - Issue title or description summary
- `{{DESCRIPTION}}` - Full description from Linear or user input
- `{{DETAILS}}` - Comments, additional context, requirements (or "None" if empty)
- `{{LINEAR_ID}}` - Linear issue ID or "N/A"
- `{{PRIORITY}}` - Priority from Linear or "N/A"
- `{{LABELS}}` - Comma-separated labels or "None"
- `{{TIMESTAMP}}` - Current timestamp (use Bash tool with `date -Iseconds`)

**Important:**
- Use the worktree path captured in Step 3
- Use Write tool to create `<captured-worktree-path>/.runtime/TASK.md`
- Preserve markdown formatting
- If a field is not available, use "N/A" or "None" appropriately
- Combine comments into Details section if present

### Step 5: Launch Resolution Loop in Tmux

Using the worktree path and sanitized branch name from Step 3, launch the loop in a detached tmux session:

```bash
tmux new-session -d -s "task-resolver-<sanitized-branch-name>" "cd <captured-worktree-path> && ~/.claude/skills/maxi-task-resolver/loop.sh"
```

Then report to the user:
- **Session name**: `task-resolver-<sanitized-branch-name>`
- **Attach command**: `tmux attach -t task-resolver-<sanitized-branch-name>`
- **Alternative**: Open new terminal and run the attach command directly
- **Note**: The loop will run autonomously and may take 20-40 minutes. User can check progress by:
  - Attaching to the tmux session
  - Asking you to read the WHITEBOARD.md or check if SUMMARY.md exists

## How It Works

### Phase 0: LLM Launcher (You)
- Fetches Linear issue details (if input is Linear issue) using MCP
- Determines branch naming following `<type>/<service>-<action>` convention
- Calls startup.sh with branch name
- Fills TASK.md template with gathered information
- Writes TASK.md to worktree using Write tool
- Launches loop.sh in a detached tmux session
- Reports tmux session name and attach instructions to user

### Phase 1: Worktree Setup (startup.sh)
- Updates `main` branch from remote
- Creates new git worktree in `<git-root>.worktree/<sanitized-branch-name>` (slashes replaced with hyphens)
- Copies critical gitignored files (`.envrc`, `CLAUDE.local.md`, `.env*`) from main repo
- Initializes `.runtime/` directory with:
  - `WHITEBOARD.md` - Agent's collaborative workspace (template)
  - (TASK.md created by LLM launcher afterward)

### Phase 2: Resolution Loop (loop.sh)
- Runs in a detached tmux session (user can attach to monitor)
- Launches Claude Code agents iteratively
- Each agent:
  - Reads TASK.md and WHITEBOARD.md
  - Makes incremental progress on the task
  - Appends observations to WHITEBOARD.md with timestamp
  - Reports "DONE" when complete
- When agent reports DONE, a **Critical Reviewer** is launched:
  - Compares TASK.md requirements against actual implementation
  - Checks for missing functionality, incorrect assumptions, incomplete work
  - If issues found: writes to WHITEBOARD.md and returns "CONTINUE"
  - If all requirements met: returns "TOTALLY DONE"
- Loop continues until Critical Reviewer says TOTALLY DONE
- Maximum 20 iterations (safety limit)

### Phase 3: Finalization
- Generates `.runtime/SUMMARY.md` with comprehensive summary
- Creates commit following Conventional Commits format
- Pushes branch to remote
- Saves PR description and URL to `.runtime/PR_PROPOSAL.md`
- Reports completion

## Files Created

In the worktree's `.runtime/` directory:
- `TASK.md` - Original task description (from Linear or manual input)
- `WHITEBOARD.md` - Iteration log with timestamps
- `SUMMARY.md` - Final summary (created at end)
- `PR_PROPOSAL.md` - PR description and creation URL (created at end)

## Requirements

- Must be run in a git repository that has a `main` branch
- `claude` CLI must be installed and configured
- `tmux` must be installed (for running the loop in background)
- Linear MCP integration (if using Linear issue input)

## Safety Features

- Maximum iteration limit (20)
- Isolated worktree (doesn't affect main workspace)
- All work logged to WHITEBOARD.md
- Branch follows project naming conventions

## Troubleshooting

If any error occurs during execution (Linear API failure, git errors, script failures, etc.):
- **Stop immediately** - Do not attempt to fix or work around the error
- **Report to user** - Explain what happened and what step failed
- **Wait for user guidance** - Let the user decide how to proceed

## Monitoring Progress

The loop runs in a detached tmux session. To monitor:

**Ask Claude to check progress:**
- "Check the progress of task-resolver-feat-api-add-endpoint"
- Claude will read WHITEBOARD.md and report current status

**List all task-resolver sessions:**
```bash
tmux ls | grep task-resolver
```

**Attach to a specific session:**
```bash
tmux attach -t task-resolver-<sanitized-branch-name>
```

**Detach from session** (while attached): Press `Ctrl+b` then `d`

**Check status files manually** (without attaching):
```bash
cat <worktree-path>/.runtime/WHITEBOARD.md  # See iteration log
ls <worktree-path>/.runtime/SUMMARY.md 2>/dev/null && echo "COMPLETED" || echo "RUNNING"
```

## Example Flow

```
1. User invokes: /maxi-task-resolver PROJ-1234
2. LLM fetches Linear issue, determines branch: feat/api-add-endpoint
3. Creates worktree at <repo-path>.worktree/feat-api-add-endpoint
4. Fills TASK.md with issue details
5. Launches tmux session: task-resolver-feat-api-add-endpoint
6. Reports to user:
   - "Loop started in tmux session 'task-resolver-feat-api-add-endpoint'"
   - "Attach with: tmux attach -t task-resolver-feat-api-add-endpoint"
   - "This will take 20-40 minutes. Check progress by attaching or asking me."
7. Loop runs autonomously in background:
   - Iteration 1: Agent reads task, implements basic structure
   - Iteration 2: Agent adds tests
   - Iteration 3: Agent fixes test failures
   - Iteration 4: Agent verifies completion → DONE → Critical Review finds missing requirement
   - Iteration 5: Agent implements missing requirement → DONE → Critical Review: TOTALLY DONE
8. Generates summary in .runtime/SUMMARY.md
9. Creates commit and pushes branch
10. Saves PR proposal to .runtime/PR_PROPOSAL.md
11. Tmux session shows completion message
```

## Skill Contents

This skill includes:
- `SKILL.md` - This file (skill definition and LLM launcher instructions)
- `startup.sh` - Worktree creation script (called by LLM launcher)
- `loop.sh` - Resolution loop script (called by LLM launcher)
- `BOOTSTRAP_RESOLVE_TASK.md` - Bootstrap for task resolution agents
- `BOOTSTRAP_CRITICAL_REVIEW.md` - Bootstrap for critical review validation
- `BOOTSTRAP_SUMMARY.md` - Bootstrap for generating summary
- `templates/TASK.md.template` - Template for TASK.md
- `templates/WHITEBOARD.md.template` - Template for WHITEBOARD.md
