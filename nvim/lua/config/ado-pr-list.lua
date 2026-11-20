local M = {}

function M.list_prs()
  local az, config = require("ado-pr.az"), require("ado-pr.config")
  local args = { "repos", "pr", "list", "--status", "active", "--output", "json", "--top", "1000" }
  for _, field in ipairs({ "repository", "organization", "project" }) do
    local value, err = config["resolve_" .. field]()
    if not value then
      return nil, err
    end
    vim.list_extend(args, { "--" .. field, value })
  end

  local prs, seen, skip = {}, {}, 0
  while true do
    local page_args = vim.list_extend(vim.deepcopy(args), { "--skip", tostring(skip) })
    local page, err = az.az_json(page_args)
    if err then
      return nil, ("Could not load PRs at offset %d: %s"):format(skip, err)
    end
    if type(page) ~= "table" or not vim.islist(page) then
      return nil, ("Azure CLI returned an invalid PR page at offset %d"):format(skip)
    end
    if #page == 0 then
      return prs
    end

    local added = 0
    for _, pr in ipairs(page) do
      if type(pr) ~= "table" or type(pr.pullRequestId) ~= "number" then
        return nil, ("Azure CLI returned an invalid PR entry at offset %d"):format(skip)
      end
      if not seen[pr.pullRequestId] then
        seen[pr.pullRequestId] = true
        prs[#prs + 1] = pr
        added = added + 1
      end
    end
    if added == 0 then
      return nil, ("Azure CLI repeated a PR page at offset %d; refusing an incomplete list"):format(skip)
    end
    skip = skip + #page
  end
end

return M
