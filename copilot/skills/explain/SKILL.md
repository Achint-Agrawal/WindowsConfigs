---
name: explain
description: "Use /explain for a read-only description of a function, subsystem, or diff. Show what the code does, how it works, and where to find it."
disable-model-invocation: true
---

# Explain

Give an engineer who is new to the code enough context to work on it.
Keep the task read-only. Do not edit files or change repository state.

## Find the relevant code

1. Use the target in `/explain <topic>`. If none is given, use the code or diff under discussion.
2. If there are multiple possible targets, identify the one that best fits the question. Ask only if the choice changes the answer.
3. Find the entry point. Follow the calls, state changes, and conditions that change the result. Read tests that show the behavior.
4. For a diff, compare the old and new paths through the code. Show what changes for callers or users.

## Write the explanation

- Start with a short answer. Show what the code does. Identify what calls it.
- Follow one example from input to result. Identify the component responsible for each step.
- Show how the code handles errors that affect the result. Add a diagram only if it helps the reader follow the flow.
- Give file paths and line numbers for the important steps. Identify details that the available sources do not confirm.
- Use short sentences and specific terms. Describe the behavior without restating each line of source code.

## Examples

- `/explain how the retry queue handles a failed request`
- `/explain where the command parser gets its defaults`
- `/explain what this diff changes for callers`

Based on the approach in [Poteto's pstack `/how`](https://github.com/cursor/plugins/tree/main/pstack/skills/how).
