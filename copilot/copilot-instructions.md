When outputting shell commands, break long commands across multiple lines using backtick (`) line continuation for PowerShell or backslash (\) for bash/zsh. Keep each line under 80 characters.

When generating or editing Markdown files, follow markdownlint conventions:

- Surround headings with blank lines (before and after).
- Surround fenced code blocks with blank lines (before and after).
- Surround lists with blank lines (before and after).
- End files with a single newline.
- Use consistent list marker style (dashes `-`).

Do not make assumptions or guess. When unsure about something, verify it by reading the actual code, configs, or docs before answering. Always provide concrete code pointers (file paths, line numbers, function/class names) rather than vague descriptions. If you cannot locate the relevant code, say so explicitly instead of speculating.

Never amend existing commits (`git commit --amend`) or force-push (`git push --force`, `git push --force-with-lease`). Always create new commits for changes. Do not rewrite, squash, or otherwise modify git history.

# CLAUDE.md

Behavioral guidelines to reduce common LLM coding mistakes. Merge with project-specific instructions as needed.

Tradeoff: These guidelines bias toward caution over speed. For trivial tasks, use judgment.

## 1. Think Before Coding

Don't assume. Don't hide confusion. Surface tradeoffs. Before implementing:

- State your assumptions explicitly. If uncertain, ask.
- If multiple interpretations exist, present them—don't pick silently.
- If a simpler approach exists, say so. Push back when warranted.
- If something is unclear, stop. Name what's confusing. Ask.

## 2. Simplicity First

Minimum code that solves the problem. Nothing speculative.

- No features beyond what was asked.
- No abstractions for single-use code.
- No "flexibility" or "configurability" that wasn't requested.
- No error handling for impossible scenarios.
- If you write 200 lines and it could be 50, rewrite it.
- Ask yourself: "Would a senior engineer say this is overcomplicated?" If yes, simplify.

## 3. Surgical Changes

Touch only what you must. Clean up only your own mess. When editing existing code:

- Don't "improve" adjacent code, comments, or formatting.
- Don't refactor things that aren't broken.
- Match existing style, even if you'd do it differently.
- If you notice unrelated dead code, mention it—don't delete it.
- When your changes create orphans: Remove imports/variables/functions that YOUR changes made unused. Don't remove pre-existing dead code unless asked.
- The test: Every changed line should trace directly to the user's request.

## 4. Goal-Driven Execution

Define success criteria. Loop until verified. Transform tasks into verifiable goals:

- "Add validation" → "Write tests for invalid inputs, then make them pass"
- "Fix the bug" → "Write a test that reproduces it, then make it pass"
- "Refactor X" → "Ensure tests pass before and after"
- For multi-step tasks, state a brief plan:
  1. [Step] → verify: [check]
  2. [Step] → verify: [check]
