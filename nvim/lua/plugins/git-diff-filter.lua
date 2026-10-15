local function set_filter(picker, staged)
  picker.opts.staged = staged
  picker.title = staged == nil and "Git Diff" or staged and "Git Diff (staged)" or "Git Diff (unstaged)"
  picker:update_titles()
  picker.list:set_target()
  picker:find()
end

local function diff_finder(opts, ctx)
  local git = require("snacks.picker.source.git")
  local args = git.git("diff", "--no-color", "--no-ext-diff", "--diff-filter=u", { args = { "--no-pager" } }, opts)
  if opts.base then
    vim.list_extend(args, { "--merge-base", opts.base })
  end
  local stages = { opts.staged == true }
  if opts.staged == nil and opts.base == nil then
    stages[#stages + 1] = true
  end
  local cwd = ctx:git_root()
  ctx.picker:set_cwd(cwd)

  return function(cb)
    local items = {}
    for _, staged in ipairs(stages) do
      local command = vim.deepcopy(args)
      if staged then
        command[#command + 1] = "--cached"
      end
      local chunks = {}
      -- Line-oriented process output strips CR bytes needed for exact hunk application.
      require("snacks.picker.source.proc").proc({
        cmd = "git",
        args = command,
        cwd = cwd,
        raw = true,
      }, ctx)(function(item)
        chunks[#chunks + 1] = item.text
      end)
      require("snacks.picker.source.diff").diff({
        diff = table.concat(chunks):gsub("\n$", ""),
        cwd = cwd,
        group = opts.group,
        annotations = opts.annotations,
      }, ctx)(function(item)
        if not opts.base then
          item.staged = staged
        end
        items[#items + 1] = item
      end)
    end
    table.sort(items, function(a, b)
      if a.file ~= b.file then
        return a.file < b.file
      end
      return a.pos[1] < b.pos[1]
    end)
    for _, item in ipairs(items) do
      cb(item)
    end
  end
end

local function finder(opts, ctx)
  local git = require("snacks.picker.source.git")
  local diff = diff_finder(opts, ctx)
  return function(cb)
    diff(cb)
    if opts.staged or opts.base then
      return
    end
    local cwd = ctx:git_root()
    require("snacks.picker.source.proc").proc(
      ctx:opts({
        cmd = "git",
        args = git.git("ls-files", "--others", "--exclude-standard", "-z", { args = { "--no-pager" } }),
        sep = "\0",
        cwd = cwd,
        transform = function(item)
          item.file, item.cwd, item.status = item.text, cwd, "??"
        end,
      }),
      ctx
    )(cb)
  end
end

local function preview(ctx)
  if ctx.item.status == "??" then
    return Snacks.picker.preview.file(ctx)
  end
  local item = vim.tbl_extend("force", ctx.item, {
    diff = ctx.item.diff:gsub("\r\n", "\n"):gsub("\r$", ""),
  })
  return Snacks.picker.preview.diff(setmetatable({ item = item }, { __index = ctx }))
end

return {
  "folke/snacks.nvim",
  opts = {
    picker = {
      sources = {
        git_diff = {
          finder = finder,
          preview = preview,
          actions = {
            git_diff_cycle = function(picker)
              local staged = picker.opts.staged
              if staged == nil then
                set_filter(picker, false)
              elseif staged == false then
                set_filter(picker, true)
              else
                set_filter(picker, nil)
              end
            end,
          },
          win = {
            input = {
              keys = {
                ["<a-s>"] = { "git_diff_cycle", mode = { "n", "i" }, desc = "Cycle all/unstaged/staged" },
              },
            },
          },
        },
      },
    },
  },
  keys = {
    {
      "<leader>gu",
      function()
        Snacks.picker.git_diff({ staged = false, title = "Git Diff (unstaged)" })
      end,
      desc = "Git Diff (unstaged)",
    },
  },
}
