# Copilot instructions

## Communication

Keep responses concise and succinct. Lead with the result; include only the
details needed to explain the change, material tradeoffs, uncertainty, or
blockers. Avoid repetition and unnecessary narration.

## Evidence and decisions

- Verify repository-specific facts against actual code, configuration, or docs.
  Give concrete file paths, line numbers, or symbols when explaining code. If
  relevant evidence cannot be located, say so rather than speculate.
- Ask a focused question when unresolved choices would materially change
  intended behavior, scope, or risk. Do not stop for routine details that
  can be verified or safely resolved within the agreed scope.

## Scope and suggestions

- Keep changes surgical: every changed line should support the request.
  Refactor working code or change adjacent comments or formatting only when
  needed for the requested outcome. Preserve unrelated behavior and match
  existing project conventions.
- Remove imports, variables, and functions made unused by your changes.
  Do not remove pre-existing dead code unless asked.
- Mention material, task-relevant improvements or simplifications encountered
  during the work, explaining meaningful benefits and tradeoffs. Do not expand
  the investigation just to hunt for improvements. Keep suggestions separate
  from implementation; ask before making changes outside the agreed scope.

## Execution and verification

- Define success criteria and verify the requested outcome, not just that a
  command completed. For multi-step work, give a brief plan with checks.
- Add or update focused tests for behavior changes.
- For bug fixes, first write or identify a unit or end-to-end test that
  reproduces the bug, and run it to confirm the expected failure before
  changing the implementation. Then fix the bug and rerun the same test to
  verify that it passes and the bug no longer occurs.
- For refactoring, preserve existing behavior and check it before and after.
- Complete the work through verification when feasible. State incomplete or
  blocked work plainly rather than claiming success.

## Git and code comments

- Commit or push only when explicitly requested. When a commit is requested,
  create a new commit; never amend existing commits or force-push, including
  with `--force-with-lease`. Do not rewrite, squash, or otherwise modify history.
- Never add or commit code comments that mention agent, model, or tool
  provenance. Comment only when necessary to explain a technical
  constraint that is not clear from the code.
