---
name: interactive-testing
description: "Invoke ONLY when the user explicitly says 'interactive testing workflow' or 'run interactive test guide'. Do NOT auto-invoke for general testing, debugging, or QA tasks."
---

# Skill: Interactive Testing Workflow

Interactive testing with live documentation. Creates a test guide, user runs commands step-by-step, agent updates the doc with actual results.

---

## Phase 1: Create the Test Guide

1. Ask the user what they want to test (feature, error path, API behavior, etc.)
2. Research the codebase to find:
   - Relevant API endpoints, scripts, or CLI commands
   - Required parameters, authentication, and prerequisites
   - Expected outcomes
3. Create a markdown file in `MyDocs/DocumentDB/guides/` (or another location the user specifies) with:
   - Title and purpose
   - Prerequisites (services that need to be running, tools needed, etc.)
   - Setup steps (loading scripts, environment config)
   - Numbered test steps with exact commands to run
   - Expected results for each step
   - Cleanup commands
   - Related files table

## Phase 2: Interactive Execution

For each test step:

1. **Present the command** to the user to run
2. **Wait for the user** to paste the output
3. **Update the doc** immediately with:
   - The actual result (success or failure)
   - Fill in dynamic values (operation IDs, request IDs) into subsequent commands
   - If a command fails, diagnose the issue, update the doc with the fix (and a note about the pitfall), then give the user the corrected command
4. **Move to the next step** once the current one succeeds

## Phase 3: Wrap Up

1. Verify all test steps have actual results documented
2. Mark pass/fail with ✅ or ❌
3. Commit and push the doc when the user is ready

---

## Rules

- **Always use PowerShell 7** (`pwsh`) for scripts that use `-SkipCertificateCheck`
- **Run sqlcmd commands directly** — use `sqlcmd -S localhost -E -Q "..."` to query the Flex RP database (OrcasBreadthRpDatabase) for debugging. Do not use `Invoke-Sqlcmd` unless the SqlServer module is confirmed installed.
- **Never run user-facing commands yourself** — present them to the user and wait for output. However, you CAN run diagnostic queries (sqlcmd, file reads, grep) yourself to gather context.
- **Keep the doc as the single source of truth** — all findings, fixes, and results go in the doc
- **Document pitfalls** — if a command fails due to a non-obvious issue (wrong parameter name, default values that don't work, etc.), add a `> **Note**:` block in the doc explaining the fix
- **Fill in concrete values** — replace placeholders like `<operation-id>` with actual values from previous step outputs as soon as they're available
- **Parse structured output** — when the user gets JSON responses, suggest parsing with `| ConvertFrom-Json | ConvertTo-Json -Depth 5` for readability
- **Update cleanup commands** if resource names changed during testing

---

## Example Interaction Pattern

```
User: "I want to test the new error code for multi-node clusters"

Agent: *researches codebase, creates test guide doc*
Agent: "Run this command for Step 1: ..."

User: *pastes output*

Agent: *updates doc with result, fills in IDs*
Agent: "Step 1 complete. Run this for Step 2: ..."

User: *pastes output showing error*

Agent: *diagnoses issue, updates doc with fix and note*
Agent: "The default storage size doesn't work. Try this instead: ..."
```
