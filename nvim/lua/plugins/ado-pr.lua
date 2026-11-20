return {
  "jinyeow/ado-pr.nvim",
  commit = "6c82ebe4edea1c399ae15d676df73fc418e76073",
  main = "ado-pr",
  cmd = {
    "AdoPr",
    "AdoPrReview",
    "AdoPrVote",
    "AdoPrComment",
    "AdoPrIterations",
    "AdoPrSetScope",
    "AdoPrShowScope",
    "AdoPrResetScope",
    "AdoPrSetDiffBase",
    "AdoPrShowDiffBase",
    "AdoPrResetDiffBase",
    "AdoPrComments",
    "AdoPrNextComment",
    "AdoPrPrevComment",
  },
  dependencies = {
    { "ibhagwan/fzf-lua", opts = {} },
    {
      "dlyongemallo/diffview-plus.nvim",
      cmd = { "DiffviewOpen", "DiffviewClose", "DiffviewFileHistory" },
      opts = function()
        local actions = require("diffview.actions")
        local review = require("config.diffview-review")
        local inline = require("config.diffview-inline")
        inline.setup()
        return {
          view = {
            foldlevel = 99,
            default = { layout = "diff1_inline", focus_diff = true },
            cycle_layouts = { default = { "diff1_inline", "diff2_horizontal" } },
          },
          keymaps = {
            view = {
              { "n", "<leader>gv", actions.cycle_layout, { desc = "Toggle inline diff" } },
              { "n", "<leader>ghw", review.toggle_hunk, { desc = "Toggle hunk reviewed" } },
              {
                "n",
                "]T",
                function()
                  require("config.ado-comments").next(1)
                end,
                { desc = "Next PR comment" },
              },
              {
                "n",
                "[T",
                function()
                  require("config.ado-comments").next(-1)
                end,
                { desc = "Previous PR comment" },
              },
              { "n", "]r", review.next_unreviewed, { desc = "Next unreviewed hunk" } },
              {
                "n",
                "[r",
                function()
                  review.next_unreviewed(-1)
                end,
                { desc = "Previous unreviewed hunk" },
              },
            },
            file_panel = {
              { "n", "<leader>gv", actions.cycle_layout, { desc = "Toggle inline diff" } },
              {
                "n",
                "]T",
                function()
                  require("config.ado-comments").next(1)
                end,
                { desc = "Next PR comment" },
              },
              {
                "n",
                "[T",
                function()
                  require("config.ado-comments").next(-1)
                end,
                { desc = "Previous PR comment" },
              },
              { "n", "]r", review.next_unreviewed, { desc = "Next unreviewed hunk" } },
              {
                "n",
                "[r",
                function()
                  review.next_unreviewed(-1)
                end,
                { desc = "Previous unreviewed hunk" },
              },
            },
          },
          hooks = {
            view_opened = review.attach,
            view_enter = review.refresh,
            view_closed = review.detach,
            selection_changed = review.selection_changed,
          },
        }
      end,
    },
  },
  keys = {
    { "<leader>gR", "<cmd>AdoPr<cr>", desc = "ADO Pull Requests" },
    { "<leader>gC", "<cmd>AdoPrComments<cr>", desc = "ADO PR Comments" },
  },
  opts = {},
  config = function(_, opts)
    require("ado-pr").setup(opts)
    require("ado-pr.az").list_prs = require("config.ado-pr-list").list_prs
    vim.api.nvim_create_user_command("AdoPrComments", function()
      require("config.ado-comments").open()
    end, {})
    vim.api.nvim_create_user_command("AdoPrNextComment", function()
      require("config.ado-comments").next(1)
    end, {})
    vim.api.nvim_create_user_command("AdoPrPrevComment", function()
      require("config.ado-comments").next(-1)
    end, {})
  end,
}
