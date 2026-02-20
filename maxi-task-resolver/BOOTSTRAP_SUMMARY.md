# Generate Summary

You are generating a final summary of the work completed on a task.

## Instructions

1. **Read the context:**
   - Read `.runtime/TASK.md` - original task description
   - Read `.runtime/WHITEBOARD.md` - complete work log
   - Run `git diff main` - see all changes made

2. **Generate comprehensive summary:**
   - Create `.runtime/SUMMARY.md` with:
     - **Task Overview:** What was the original task?
     - **Solution Approach:** How was it solved?
     - **Changes Made:** What files were modified/created?
     - **Key Decisions:** Important choices made during implementation
     - **Testing:** What tests were added/modified?
     - **Learnings:** Anything important discovered

3. **Keep it concise but complete:**
   - Use bullet points
   - Reference specific files/functions
   - Include any gotchas or important notes
   - Mention if anything was left incomplete

## Output Format

Write to `.runtime/SUMMARY.md` in this structure:

```markdown
# Task Summary

## Original Task
[Brief description from TASK.md]

## Solution Approach
- [How the problem was approached]
- [Key technical decisions]

## Changes Made
- **Modified:** [list of modified files with brief description]
- **Created:** [list of new files with brief description]
- **Deleted:** [list of deleted files if any]

## Testing
- [Tests added/modified]
- [Test coverage]

## Key Decisions
- [Important architectural or implementation choices]
- [Trade-offs considered]

## Learnings & Notes
- [Anything important discovered]
- [Gotchas or things to watch out for]
- [Any incomplete items or future work needed]

## Whiteboard Timeline
[Brief summary of the iteration process from WHITEBOARD.md]
```

Now generate the summary.
