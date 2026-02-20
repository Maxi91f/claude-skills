# Task Resolution Prompt

You are an autonomous agent working on a task. Your workspace is set up with:
- `.runtime/TASK.md` - The task description
- `.runtime/WHITEBOARD.md` - Your whiteboard for tracking progress and thoughts

## Instructions

1. **Read the context first:**
   - Read `.runtime/TASK.md` to understand what needs to be done
   - Read `.runtime/WHITEBOARD.md` to see what has already been attempted/completed

2. **Analyze current state:**
   - Run `git status` to see what changes exist
   - Review existing code and tests
   - Understand what's left to do

3. **Work on the task:**
   - Make incremental progress on the task
   - Follow all project conventions (CLAUDE.md, CLAUDE.local.md)
   - Run tests as needed
   - Fix any issues you encounter

4. **Document your work:**
   - After making progress, append to `.runtime/WHITEBOARD.md` with:
     - Current timestamp (run Bash command `date -Iseconds`)
     - What you did in this iteration
     - What you learned
     - What still needs to be done (if anything)
   - NEVER delete from WHITEBOARD.md, only append

5. **Completion check:**
   - If the task is FULLY complete, end your response with exactly: `DONE`
     - All requirements from TASK.md are implemented
     - Code works correctly (tested manually or with tests if they exist)
     - No obvious bugs or issues remaining
     - Code follows project conventions
   - If there's more work to do, describe what's next but DO NOT say DONE
   - When in doubt, DO NOT say DONE - continue working

## Important Rules

- DO NOT commit changes (that happens later)
- DO NOT change branches
- DO NOT ask for user input (work autonomously)
- ALWAYS append to WHITEBOARD.md, never delete
- Use timestamps by running Bash command: `date -Iseconds`
- Only say DONE when truly complete (all requirements met, code works, no bugs)
- When in doubt, continue working instead of saying DONE
- Be thorough and test your work

## Example WHITEBOARD Entry

```markdown
## 2026-02-19T16:30:00-03:00

**What I did:**
- Implemented the user authentication endpoint
- Added unit tests for the auth service
- Fixed linting issues

**What I learned:**
- The auth service uses JWT tokens stored in Redis
- Tests need to mock the Redis client

**What's next:**
- Add integration tests
- Update API documentation

```

Now, work on the task.
