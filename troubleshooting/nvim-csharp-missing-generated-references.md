# Neovim C# reports missing references after restore or in a fresh worktree

## Symptom

Roslyn reports `CS0012`, `CS0246`, or missing EntityFx namespaces in
`MountDiskStateMachine.cs`, even though the code builds in a configured checkout.
The correct RP solution is selected, but some dependency projects fail to load.
Restoring packages can remove most errors while leaving missing
`ReadOnlyEntityContext` and `OrcasBreadthSchemaVersion` symbols.

Another case is missing `ILogger`, `Newtonsoft.Json.Linq.JObject`, or
`NpgsqlConnection` in sidecar files even though this same checkout builds
and its current restore graph includes those packages.

## Root cause

These failures have separate causes:

- Roslyn initially loaded before the checkout's NuGet restore outputs existed.
  Completing restore did not repair that already-failed solution load.
- A long-running Roslyn workspace retained stale references after packages or
  project frameworks changed. The restored assemblies existed, but its
  in-memory compilation still could not resolve them.
- MetadataStore's schema-generation target ran during design-time loading,
  before its schema-merger executable had been built and copied into place.

MetadataStore includes the generated `OrcasBreadthSchemaVersion.cs` and runs its
schema-merger target after `ResolveReferences`. The checkout's
`Directory.Build.targets` skips `CopyNeededFilesFromProjectReferences` during
design-time builds, so this first editor load cannot bootstrap the missing
merger. The LSP log reports `schema merge failed`, and dependent projects then
appear to have missing types.

Build outputs from another worktree or configuration do not supply these
prerequisites. This is not the separate Windows source-watcher problem described
in `nvim-csharp-stale-external-changes.md`.

## Fix

If the same checkout and configuration already build, reload Roslyn first:

```vim
:lsp restart roslyn_ls
```

Wait for `Roslyn project initialization complete`, then check diagnostics
and definitions again. This reloads the project graph without rewriting
source files or disabling compiler diagnostics. The command restarts all
running Roslyn workspaces in that Neovim instance.

For the sidecar case, reloading the affected workspace removed all 38
false compiler errors in `PostgresMongoCluster.cs`. Fresh diagnostic
requests reported no compiler errors, and definitions for `ILogger`,
`JObject`, and `NpgsqlConnection` resolved again. No additional restore,
build, package-reference edit, or diagnostic suppression was required.

If reloading does not resolve it, inspect the project-load errors and use
the prerequisite recovery below rather than assuming every missing type
has the same cause.

Complete the checkout's normal developer setup and dependency restore first.
If the log reports the MetadataStore schema-merge failure, build just that
project and its prerequisites from the affected checkout root in Developer
PowerShell for Visual Studio:

```powershell
$project = '.\src\OrcasBreadthRP\MetadataStore\' +
  'Microsoft.SqlServer.OrcasBreadth.ResourceProvider.MetadataStore.csproj'
msbuild $project /p:Configuration=Debug /p:Platform=x64 `
  /p:SkipTestsOnBuild=true /m
```

This builds/copies the schema merger and generates the schema source through
the project's normal targets. Use the configuration selected by the editor;
this setup uses Debug/x64. No application-source edits or diagnostic
suppressions are needed.

After the build succeeds, reload Roslyn in Neovim:

```vim
:lsp restart roslyn_ls
```

Wait for `Roslyn project initialization complete`. Restarting Neovim also
reloads the solution. In the affected file, this sequence reduced compiler
errors from 417 to 29 after restore/reload, then to zero after the scoped
build/reload. A fresh Neovim process also resolved definitions and still
reported an intentionally introduced in-memory compiler error.

## Prevention

- Restore and generate required sources in each new worktree before opening
  its solution, using the checkout's normal build workflow.
- Reload Roslyn after fixing a failed initial project load.
- Reload a long-running workspace after package/framework changes if its
  references disagree with a successful build in that same checkout.
- Inspect the actual project-load error before adding references or suppressing
  missing-type diagnostics. Get the log path with
  `:lua print(vim.lsp.log.get_filename())`.
- Keep genuine compiler diagnostics enabled; a successful build elsewhere does
  not establish that this checkout's design-time dependencies are ready.
