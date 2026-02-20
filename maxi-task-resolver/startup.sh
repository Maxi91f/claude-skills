#!/bin/bash
set -e

# Task Resolver - Startup Script
# Creates a git worktree and initializes the .runtime/ workspace for autonomous task resolution
# Usage: startup.sh --branch-name <name>

BRANCH_NAME=""

# Parse arguments
while [[ $# -gt 0 ]]; do
  case $1 in
    --branch-name)
      BRANCH_NAME="$2"
      shift 2
      ;;
    *)
      echo "Unknown option: $1"
      exit 1
      ;;
  esac
done

# Validate inputs
if [ -z "$BRANCH_NAME" ]; then
  echo "Error: Must provide --branch-name"
  exit 1
fi

# Validate we're in a git repository
if ! git rev-parse --git-dir >/dev/null 2>&1; then
  echo "Error: Not in a git repository"
  exit 1
fi

# Validate main branch exists
if ! git rev-parse --verify main >/dev/null 2>&1; then
  echo "Error: 'main' branch does not exist"
  exit 1
fi

# Validate template exists
TEMPLATE_PATH="$(dirname "$0")/templates/WHITEBOARD.md.template"
if [ ! -f "$TEMPLATE_PATH" ]; then
  echo "Error: Template not found at $TEMPLATE_PATH"
  exit 1
fi

echo "Branch name: $BRANCH_NAME"

# Check for uncommitted changes
if ! git diff-index --quiet HEAD -- 2>/dev/null; then
  echo "Warning: Uncommitted changes detected. Creating stash..."
  git stash push -m "task-resolver: auto-stash before creating worktree"
  echo "Changes stashed. Restore later with: git stash pop"
fi

# Calculate sanitized branch name
SANITIZED_BRANCH_NAME="${BRANCH_NAME//\//-}"
if [ "$BRANCH_NAME" != "$SANITIZED_BRANCH_NAME" ]; then
  echo "Sanitized name: $SANITIZED_BRANCH_NAME"
fi

# Check if tmux session already exists
TMUX_SESSION="task-resolver-$SANITIZED_BRANCH_NAME"
if tmux has-session -t "$TMUX_SESSION" 2>/dev/null; then
  echo "Warning: tmux session '$TMUX_SESSION' already exists"
  echo "You may want to kill it first: tmux kill-session -t $TMUX_SESSION"
fi

# Step 1: Update main branch
echo "Updating main branch..."
git checkout main

if ! git pull origin main; then
  echo "Warning: Failed to pull from origin/main"
  echo "Continuing with local main branch..."
fi

# Step 2: Create worktree from main
GIT_ROOT=$(git rev-parse --show-toplevel)
WORKTREE_BASE="$GIT_ROOT.worktree"
WORKTREE_PATH="$WORKTREE_BASE/$SANITIZED_BRANCH_NAME"
echo "Creating worktree at: $WORKTREE_PATH"

# Create base worktree directory if it doesn't exist
mkdir -p "$WORKTREE_BASE"

# Remove worktree if it already exists
if [ -d "$WORKTREE_PATH" ]; then
  echo "Removing existing worktree..."
  git worktree remove "$WORKTREE_PATH" --force 2>/dev/null || true
fi

# Remove branch if it already exists
git branch -D "$BRANCH_NAME" 2>/dev/null || true

git worktree add -b "$BRANCH_NAME" "$WORKTREE_PATH" main

# Step 3: Copy critical gitignored files from main repo
echo "Copying critical configuration files..."

# Critical files - needed for AWS auth and user context
if [ -f "$GIT_ROOT/.envrc" ]; then
  cp "$GIT_ROOT/.envrc" "$WORKTREE_PATH/.envrc"
  echo "  ✓ Copied .envrc"
else
  echo "  ⚠ Warning: .envrc not found in main repo"
fi

if [ -f "$GIT_ROOT/CLAUDE.local.md" ]; then
  cp "$GIT_ROOT/CLAUDE.local.md" "$WORKTREE_PATH/CLAUDE.local.md"
  echo "  ✓ Copied CLAUDE.local.md"
else
  echo "  ⚠ Warning: CLAUDE.local.md not found in main repo"
fi

# Important files - environment variables for development
for ENV_FILE in .env .env.local .env.development.local .env.test.local; do
  if [ -f "$GIT_ROOT/$ENV_FILE" ]; then
    cp "$GIT_ROOT/$ENV_FILE" "$WORKTREE_PATH/$ENV_FILE"
    echo "  ✓ Copied $ENV_FILE"
  fi
done

# VSCode configuration - may have local modifications
if [ -f "$GIT_ROOT/.vscode/launch.json" ]; then
  mkdir -p "$WORKTREE_PATH/.vscode"
  cp "$GIT_ROOT/.vscode/launch.json" "$WORKTREE_PATH/.vscode/launch.json"
  echo "  ✓ Copied .vscode/launch.json"
fi

# Step 4: Create .runtime directory in worktree
echo "Setting up .runtime directory..."
mkdir -p "$WORKTREE_PATH/.runtime"

# Step 5: Create WHITEBOARD.md from template
cp "$TEMPLATE_PATH" "$WORKTREE_PATH/.runtime/WHITEBOARD.md"

echo ""
echo "✓ Worktree created at: $WORKTREE_PATH"
echo "✓ Branch: $BRANCH_NAME"
echo "✓ Critical files copied"
echo "✓ .runtime directory initialized"
echo ""
echo "Worktree path: $WORKTREE_PATH"
