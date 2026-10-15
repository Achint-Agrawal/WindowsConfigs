return {
  "folke/noice.nvim",
  opts = {
    lsp = {
      progress = {
        format = {
          "{data.progress.title} ",
          "{data.progress.client} ",
          "({data.progress.percentage}%) ",
          "{data.progress.message}",
        },
      },
    },
  },
}
