-- Install additional treesitter parsers for better syntax highlighting
return {
  "nvim-treesitter/nvim-treesitter",
  opts = {
    ensure_installed = {
      -- Add parsers needed for Snacks.image features
      "latex", -- For LaTeX math expressions
      "regex", -- For better regex highlighting in cmdline
      "bash", -- For bash command highlighting in cmdline
    },
  },
}
