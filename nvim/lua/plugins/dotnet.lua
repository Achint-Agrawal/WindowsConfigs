return {
  {
    "neovim/nvim-lspconfig",
    opts = function(_, opts)
      local defaults = vim.lsp.config.roslyn_ls
      local command = vim.deepcopy(defaults.cmd)
      if vim.fn.executable(command[1]) == 0 then
        local extensions = vim.fs.joinpath(vim.env.USERPROFILE, ".vscode", "extensions")
        local servers = vim.fn.globpath(
          extensions,
          "ms-dotnettools.csharp-*\\.roslyn\\Microsoft.CodeAnalysis.LanguageServer.dll",
          false,
          true
        )
        local function version(path)
          return vim.fs.basename(vim.fs.dirname(vim.fs.dirname(path))):match("csharp%-(%d+%.%d+%.%d+)")
        end
        table.sort(servers, function(a, b)
          return vim.version.cmp(version(a), version(b)) > 0
        end)
        if servers[1] then
          command[1] = servers[1]
          table.insert(command, 1, "dotnet")
        end
      end

      opts.servers.omnisharp.filetypes = { "vb" }
      local server = {
        mason = false,
        cmd = command,
        settings = {
          ["csharp|background_analysis"] = {
            dotnet_analyzer_diagnostics_scope = "openFiles",
            dotnet_compiler_diagnostics_scope = "openFiles",
          },
          ["csharp|completion"] = {
            dotnet_show_completion_items_from_unimported_namespaces = true,
          },
        },
        handlers = {
          ["workspace/_roslyn_projectNeedsRestore"] = function()
            vim.notify(
              "Restore the solution's NuGet dependencies using its normal developer workflow.",
              vim.log.levels.WARN,
              { title = "roslyn_ls" }
            )
            return vim.NIL
          end,
        },
      }
      opts.servers.roslyn_ls = server

      if vim.fn.has("win32") == 1 then
        -- Use Roslyn's native watcher; Neovim's Windows relative globs miss normalized paths.
        server.capabilities = {
          workspace = {
            didChangeWatchedFiles = { dynamicRegistration = false },
          },
        }
      end

      server.root_dir = function(bufnr, on_dir)
        local filename = vim.api.nvim_buf_get_name(bufnr)
        local util = require("lspconfig.util")
        local solution_root = util.root_pattern("*.slnx")(filename) or util.root_pattern("*.sln")(filename)
        if solution_root then
          on_dir(solution_root)
          return
        end

        -- Shared RP projects live beside, rather than below, the main solution.
        local rp_solution = "src\\OrcasBreadthRP\\ResourceProvider\\OrcasBreadthRP.sln"
        local repo_root = vim.fs.root(bufnr, function(name, path)
          return name == "dirs.proj" and vim.fn.filereadable(vim.fs.joinpath(path, rp_solution)) == 1
        end)
        if repo_root then
          on_dir(vim.fs.dirname(vim.fs.joinpath(repo_root, rp_solution)))
        else
          defaults.root_dir(bufnr, on_dir)
        end
      end
    end,
  },
}
