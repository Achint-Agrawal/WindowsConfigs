return {
  "folke/snacks.nvim",
  opts = function(_, opts)
    if vim.fn.has("win32") == 0 then
      return
    end

    local script = vim.fs.joinpath(vim.fn.stdpath("config"), "lazygit-open.lua")
    local command = 'nvim --headless -u NONE -l "' .. script .. '" '
    opts.lazygit = vim.tbl_deep_extend("force", opts.lazygit or {}, {
      config = {
        os = {
          open = command .. "0 {{filename}}",
          edit = command .. "0 {{filename}}",
          editAtLine = command .. "{{line}} {{filename}}",
          openDirInEditor = command .. "0 {{dir}}",
        },
      },
    })
  end,
}
