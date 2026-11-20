local root = assert(vim.env.NVIM_PR_LIST_TEST_DIR, "Set NVIM_PR_LIST_TEST_DIR to a temporary directory")
local output = {}

local function check(value, message)
  assert(value, message)
  output[#output + 1] = "OK " .. message
end

local function run()
  require("lazy").load({ plugins = { "ado-pr.nvim" } })
  local az, config = require("ado-pr.az"), require("ado-pr.config")
  config.setup({ organization = "https://dev.azure.com/fixture", project = "Fixture Project", repository = "fixture" })
  local prs = {}
  for id = 2300, 1, -1 do
    prs[#prs + 1] = { pullRequestId = id, title = "Fixture PR " .. id, createdBy = { displayName = "Fixture Author" } }
  end
  local requests, scenario = {}, "normal"
  local original_system = vim.system
  local function flag(command, name)
    for index, value in ipairs(command) do
      if value == name then
        return command[index + 1]
      end
    end
    return nil
  end
  vim.system = function(command, options)
    local is_list = false
    for index, value in ipairs(command) do
      if value == "repos" and command[index + 1] == "pr" and command[index + 2] == "list" then
        is_list = true
        break
      end
    end
    if not is_list then
      return original_system(command, options)
    end
    local skip, top = tonumber(flag(command, "--skip")) or 0, tonumber(flag(command, "--top")) or 101
    requests[#requests + 1] = { skip = skip, top = top, command = vim.deepcopy(command) }
    local result = { code = 0, stderr = "" }
    if scenario == "failure" and skip > 0 then
      result.code, result.stderr, result.stdout = 1, "fixture page failure", ""
    elseif scenario == "malformed" and skip > 0 then
      result.stdout = '{"unexpected":"object"}'
    elseif scenario == "invalid-pr" and skip > 0 then
      result.stdout = '[{"title":"missing id"}]'
    elseif scenario == "empty" then
      result.stdout = "[]"
    else
      local start, size = skip, top
      if scenario == "capped" then
        size = math.min(37, top)
      end
      if scenario == "overlap" and skip > 0 then
        start = skip - 1
      end
      if scenario == "repeated" then
        start = 0
      end
      local page = {}
      for index = start + 1, math.min(start + size, #prs) do
        page[#page + 1] = prs[index]
      end
      result.stdout = vim.json.encode(page)
    end
    return {
      wait = function()
        return result
      end,
    }
  end

  local result, err = az.list_prs()
  assert(result, err)
  check(#result == #prs, "PRs older than the CLI default page remain searchable")
  check(result[#result].pullRequestId == 1, "The oldest active PR is included")
  check(
    #requests == 4 and requests[2].skip == 1000 and requests[4].skip == 2300,
    "Pagination advances by the returned count and ends on an empty page"
  )
  for _, request in ipairs(requests) do
    check(
      flag(request.command, "--status") == "active"
        and flag(request.command, "--organization") == "https://dev.azure.com/fixture"
        and flag(request.command, "--project") == "Fixture Project"
        and flag(request.command, "--repository") == "fixture",
      "Each page preserves the active-PR filter and resolved scope"
    )
  end

  requests, scenario = {}, "capped"
  result, err = az.list_prs()
  check(result and #result == #prs, "Server-shortened pages do not truncate the list")
  requests, scenario = {}, "overlap"
  result, err = az.list_prs()
  local seen = {}
  for _, pr in ipairs(result or {}) do
    assert(not seen[pr.pullRequestId], "Duplicate PR in the picker")
    seen[pr.pullRequestId] = true
  end
  check(result and #result == #prs, "Overlapping pages do not create duplicate picker entries")
  for _, name in ipairs({ "failure", "malformed", "invalid-pr", "repeated" }) do
    requests, scenario = {}, name
    result, err = az.list_prs()
    check(
      result == nil and type(err) == "string" and err ~= "",
      name .. " reports an error instead of returning a partial PR list"
    )
  end
  requests, scenario = {}, "empty"
  result, err = az.list_prs()
  check(result and #result == 0 and #requests == 1, "A repository with no active PRs terminates normally")

  requests, scenario = {}, "normal"
  local fzf, review = require("fzf-lua"), require("ado-pr.review")
  local picked, selected
  fzf.fzf_exec = function(entries, opts)
    picked = { entries = entries, opts = opts }
  end
  review.open = function(id)
    selected = id
  end
  require("ado-pr.picker").pick()
  check(
    picked
      and #picked.entries == #prs
      and picked.entries[#picked.entries]:find("!1  ", 1, true)
      and picked.entries[#picked.entries]:find("Fixture Author", 1, true),
    "The native picker exposes older PR IDs and author names in the same searchable row"
  )
  picked.opts.actions.default({ picked.entries[#picked.entries] })
  check(selected == 1, "Selecting an older PR preserves the normal review action without a test checkout")

  local original_resolve = config.resolve_repository
  config.resolve_repository = function()
    return nil, "fixture scope failure"
  end
  requests = {}
  result, err = az.list_prs()
  check(
    result == nil and err == "fixture scope failure" and #requests == 0,
    "Scope errors stop before running Azure CLI"
  )
  config.resolve_repository = original_resolve
  vim.system = original_system
  output[#output + 1] = "PASS"
end

vim.api.nvim_create_autocmd("VimEnter", {
  once = true,
  callback = function()
    vim.defer_fn(function()
      local ok, err = xpcall(run, debug.traceback)
      if not ok then
        vim.list_extend(output, vim.split(err, "\n", { plain = true }))
      end
      vim.fn.mkdir(root, "p")
      vim.fn.writefile(output, vim.fs.joinpath(root, "results.log"))
      vim.cmd(ok and "qa!" or "cquit")
    end, 500)
  end,
})
