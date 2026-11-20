return {
  {
    "neovim/nvim-lspconfig",
    opts = {
      diagnostics = {
        underline = {
          severity = { min = vim.diagnostic.severity.WARN },
        },
        virtual_text = {
          severity = { min = vim.diagnostic.severity.WARN },
        },
      },
    },
  },
  {
    "mfussenegger/nvim-lint",
    optional = true,
    opts = function()
      vim.diagnostic.config({
        virtual_text = false,
        underline = false,
      }, require("lint").get_namespace("markdownlint-cli2"))
    end,
  },
}
