#!/bin/bash
set -e

# Task Resolver - Resolution Loop
# Runs autonomous Claude Code agents iteratively until task completion
# Must be run from a worktree with .runtime/ directory set up

SCRIPT_DIR="$(dirname "$(readlink -f "$0")")"
MAX_ITERATIONS=20
ITERATION=0

echo "Starting task resolution loop..."
echo "Working directory: $(pwd)"
echo ""

# Validate claude CLI is installed
if ! command -v claude >/dev/null 2>&1; then
  echo "Error: 'claude' CLI not found. Please install it first."
  exit 1
fi

# Check we're in a worktree with .runtime
if [ ! -d ".runtime" ]; then
  echo "Error: .runtime directory not found. Run startup.sh first."
  exit 1
fi

# Validate required files exist
if [ ! -f ".runtime/TASK.md" ]; then
  echo "Error: .runtime/TASK.md not found. Run startup.sh steps 1-4 first."
  exit 1
fi

if [ ! -f ".runtime/WHITEBOARD.md" ]; then
  echo "Error: .runtime/WHITEBOARD.md not found. Run startup.sh first."
  exit 1
fi

# Validate bootstrap files exist
RESOLVE_BOOTSTRAP="$SCRIPT_DIR/BOOTSTRAP_RESOLVE_TASK.md"
SUMMARY_BOOTSTRAP="$SCRIPT_DIR/BOOTSTRAP_SUMMARY.md"
CRITICAL_REVIEW_BOOTSTRAP="$SCRIPT_DIR/BOOTSTRAP_CRITICAL_REVIEW.md"

if [ ! -f "$RESOLVE_BOOTSTRAP" ]; then
  echo "Error: Bootstrap file not found at $RESOLVE_BOOTSTRAP"
  exit 1
fi

if [ ! -f "$SUMMARY_BOOTSTRAP" ]; then
  echo "Error: Bootstrap file not found at $SUMMARY_BOOTSTRAP"
  exit 1
fi

if [ ! -f "$CRITICAL_REVIEW_BOOTSTRAP" ]; then
  echo "Error: Bootstrap file not found at $CRITICAL_REVIEW_BOOTSTRAP"
  exit 1
fi

# Main loop: resolve task until critical review says TOTALLY DONE
TOTALLY_DONE=false
while [ "$TOTALLY_DONE" = "false" ] && [ $ITERATION -lt $MAX_ITERATIONS ]; do
  ITERATION=$((ITERATION + 1))
  echo "=== Iteration $ITERATION ==="
  echo ""

  # Run claude code with resolve-task prompt
  PROMPT=$(cat "$RESOLVE_BOOTSTRAP")

  echo "Running Claude Code..."
  unset CLAUDECODE  # Allow nested claude sessions

  # Use a temporary file to capture full output for DONE detection
  TEMP_OUTPUT=$(mktemp)
  TEMP_TEXT=$(mktemp)

  set +e  # Temporarily disable exit on error
  echo "$PROMPT" | claude code --print --permission-mode bypassPermissions --output-format stream-json --verbose 2>&1 | tee "$TEMP_OUTPUT" | while IFS= read -r line; do
    # Show formatted output in real-time and save to temp text file
    FORMATTED=$(echo "$line" | jq -r '
      if .type == "assistant" then
        .message.content[] |
        if .type == "text" then .text
        elif .type == "tool_use" then "🔧 \(.name): \(.input | to_entries | map("\(.key)=\(.value)") | join(", "))"
        else empty end
      elif .type == "user" and .tool_use_result then
        "✓ \(.tool_use_result.stdout // .tool_use_result.stderr // "no output")"
      else empty end
    ' 2>/dev/null || true)

    if [ -n "$FORMATTED" ]; then
      echo "$FORMATTED"
      echo "$FORMATTED" >> "$TEMP_TEXT"
    fi
  done
  CLAUDE_EXIT_CODE=$?
  set -e  # Re-enable exit on error

  echo ""

  # Check if claude failed completely
  if [ $CLAUDE_EXIT_CODE -ne 0 ] && [ ! -s "$TEMP_OUTPUT" ]; then
    echo "⚠ Claude Code failed completely. Stopping loop."
    rm -f "$TEMP_OUTPUT" "$TEMP_TEXT"
    exit 1
  fi

  # Check if output contains DONE at the end (case-insensitive)
  if tail -n 10 "$TEMP_TEXT" 2>/dev/null | grep -iq "^DONE$"; then
    echo "✓ Agent reported DONE - running critical review..."
    echo ""

    # Run critical reviewer to validate completion
    REVIEW_PROMPT=$(cat "$CRITICAL_REVIEW_BOOTSTRAP")
    TEMP_REVIEW=$(mktemp)

    unset CLAUDECODE
    set +e
    echo "$REVIEW_PROMPT" | claude code --print --permission-mode bypassPermissions --output-format stream-json --verbose 2>&1 | tee /dev/null | while IFS= read -r line; do
      FORMATTED=$(echo "$line" | jq -r '
        if .type == "assistant" then
          .message.content[] |
          if .type == "text" then .text
          elif .type == "tool_use" then "🔧 \(.name): \(.input | to_entries | map("\(.key)=\(.value)") | join(", "))"
          else empty end
        elif .type == "user" and .tool_use_result then
          "✓ \(.tool_use_result.stdout // .tool_use_result.stderr // "no output")"
        else empty end
      ' 2>/dev/null || true)

      if [ -n "$FORMATTED" ]; then
        echo "$FORMATTED"
        echo "$FORMATTED" >> "$TEMP_REVIEW"
      fi
    done
    set -e

    # Check if reviewer says TOTALLY DONE
    if tail -n 10 "$TEMP_REVIEW" 2>/dev/null | grep -iq "TOTALLY DONE"; then
      echo ""
      echo "✓ Critical review passed - TOTALLY DONE"
      TOTALLY_DONE=true
    else
      echo ""
      echo "○ Critical review found issues - continuing..."
    fi

    rm -f "$TEMP_REVIEW"
  else
    echo "○ Task in progress, continuing..."
  fi

  rm -f "$TEMP_OUTPUT" "$TEMP_TEXT"

  echo ""
done

if [ $ITERATION -ge $MAX_ITERATIONS ]; then
  echo "⚠ Max iterations reached ($MAX_ITERATIONS). Proceeding to summary anyway."
fi

echo ""
echo "=== Task Resolution Complete ==="
echo ""

# Step 1: Generate summary
echo "Generating summary..."
SUMMARY_PROMPT=$(cat "$SUMMARY_BOOTSTRAP")

unset CLAUDECODE  # Allow nested claude sessions
set +e
echo "$SUMMARY_PROMPT" | claude code --print --permission-mode bypassPermissions --output-format stream-json --verbose 2>&1 | while IFS= read -r line; do
  echo "$line" | jq -r '
    if .type == "assistant" then
      .message.content[] |
      if .type == "text" then .text
      elif .type == "tool_use" then "🔧 \(.name): \(.input | to_entries | map("\(.key)=\(.value)") | join(", "))"
      else empty end
    elif .type == "user" and .tool_use_result then
      "✓ \(.tool_use_result.stdout // .tool_use_result.stderr // "no output")"
    else empty end
  ' 2>/dev/null || true
done
SUMMARY_EXIT_CODE=$?
set -e

echo ""

if [ $SUMMARY_EXIT_CODE -ne 0 ] || [ ! -f ".runtime/SUMMARY.md" ]; then
  echo "⚠ Warning: Summary generation may have failed"
  echo "Exit code: $SUMMARY_EXIT_CODE"
else
  echo "✓ Summary generated at .runtime/SUMMARY.md"
fi
echo ""

# Step 2: Create commit, push, and generate PR proposal
echo "Creating commit and pushing branch..."

# Get repo URL dynamically for PR creation
REPO_URL=$(git remote get-url origin 2>/dev/null | sed 's/\.git$//' | sed 's/git@github.com:/https:\/\/github.com\//' | sed 's/git@gitlab.com:/https:\/\/gitlab.com\//')

# Read summary to create PR description
COMMIT_AND_PR_PROMPT="Follow this commit and PR workflow:

1. Run git status - if already on a branch matching pattern and nothing to commit, skip to step 6
2. Switch to main: git checkout main
3. Pull: git pull
4. Create branch: git checkout -b <current-branch-name-from-status>
5. Commit with Conventional Commits format (max 72 chars): git commit -am \"type(scope): description\"
6. Push: git push -u origin <branch-name>
7. Generate PR description following this EXACT template (do not use nested codeblocks, no links, no backticks for code):

# Change Description

<Summary from SUMMARY.md in 1-3 paragraphs>

## Background (Why we did this)

<1-3 sentences from TASK.md explaining motivation - WHY not WHAT>

## Testing

<Leave empty for user to fill>

## Pull Request Checklist

- [x] If you are adding a dependency, please explain how it was chosen
- [x] Ensure all items left for future development have been appropriately documented

8. Show PR creation URL: ${REPO_URL}/compare/<branch-name>?expand=1

Run git diff main --stat first to understand full scope.
Do NOT include Co-Authored-By lines in commits."

unset CLAUDECODE  # Allow nested claude sessions
set +e
echo "$COMMIT_AND_PR_PROMPT" | claude code --print --permission-mode bypassPermissions --output-format stream-json --verbose 2>&1 | while IFS= read -r line; do
  echo "$line" | jq -r '
    if .type == "assistant" then
      .message.content[] |
      if .type == "text" then .text
      elif .type == "tool_use" then "🔧 \(.name): \(.input | to_entries | map("\(.key)=\(.value)") | join(", "))"
      else empty end
    elif .type == "user" and .tool_use_result then
      "✓ \(.tool_use_result.stdout // .tool_use_result.stderr // "no output")"
    else empty end
  ' 2>/dev/null || true
done
COMMIT_EXIT_CODE=$?
set -e

# Save the PR proposal (already generated by the agent above)
# If the agent didn't save it, create a basic one
if [ ! -f ".runtime/PR_PROPOSAL.md" ]; then
  CURRENT_BRANCH=$(git rev-parse --abbrev-ref HEAD)
  PR_URL="${REPO_URL}/compare/${CURRENT_BRANCH}?expand=1"

  cat > .runtime/PR_PROPOSAL.md <<EOF
# PR Creation URL

$PR_URL

# PR Description

See output above for the full PR description.
EOF
fi

echo ""
if [ $COMMIT_EXIT_CODE -ne 0 ]; then
  echo "⚠ Warning: Commit/push may have failed (exit code: $COMMIT_EXIT_CODE)"
else
  echo "✓ Changes committed and pushed"
fi
echo "✓ PR proposal saved to .runtime/PR_PROPOSAL.md"
echo ""

echo "=== All Done! ==="
echo ""
echo "Next steps for humans:"
echo "  1. Review changes in this worktree"
echo "  2. Check .runtime/SUMMARY.md"
echo "  3. Check .runtime/PR_PROPOSAL.md for PR description and URL"
