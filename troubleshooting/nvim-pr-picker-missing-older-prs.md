# Older active PRs missing from Neovim's ADO picker

## Symptom

`Space g R` / `:AdoPr` finds a newer PR but not an older active PR in the same
repository, even when searching by its exact ID or by their shared author.
The older PR is still visible on the ADO website.

## Root cause

The pinned `ado-pr.nvim` requests `az repos pr list --status active` without
`--top`, `--skip`, or a pagination loop. Azure CLI makes a single list request
and does not automatically retrieve subsequent pages. The affected repository
returned only 101 recent active PRs, excluding the older PR.

The picker searches the returned rows locally. Searching by ID does not
perform a separate server lookup, so it cannot recover an omitted PR.
Both PRs in the reported case were active; status and author identity were
not the cause.

## Fix

`nvim\lua\config\ado-pr-list.lua` replaces only the plugin's list function
from `nvim\lua\plugins\ado-pr.lua`. It resolves the same repository,
organization, and project and reuses the plugin's validated Azure CLI
transport, including Windows `az.cmd` handling.

The adapter requests explicit pages, advances the offset by the actual
returned count, and continues until an empty page. Shortened server pages
do not truncate the list. Duplicate PR IDs are removed; failed, malformed,
or repeated pages report an error instead of presenting a partial list.
The existing active-only filter, searchable row format, and review action
are unchanged. Installed plugin files and pinned revisions are untouched.

Restart Neovim and reopen `Space g R` to load the updated configuration.
Fetching every page may make the initial list load slower in large repos.

## Prevention

Keep pagination in the repository-owned adapter when updating the pinned
plugin. Avoid replacing it with a fixed maximum number of PRs.

Run `nvim\tests\ado-pr-list.lua` with `NVIM_PR_LIST_TEST_DIR` set to a
temporary directory:

```text
nvim --headless -i NONE --cmd "lua dofile([[<absolute test script path>]])"
```

The regression reproduces older-PR omission, checks normal and shortened
pages, overlapping/repeated pages, errors, empty results, scope handling,
and native picker selection without remote writes or real checkouts.
Completed and abandoned PRs intentionally remain outside this picker.
