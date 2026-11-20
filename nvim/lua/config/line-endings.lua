local M = {}
local configured = false

function M.setup()
  if configured then
    return
  end
  local properties = require("editorconfig").properties
  local end_of_line = properties.end_of_line
  properties.end_of_line = function(buffer, value, options)
    if value == "crlf" and vim.bo[buffer].fileformat == "unix" and not vim.bo[buffer].binary then
      for _, line in ipairs(vim.api.nvim_buf_get_lines(buffer, 0, -1, false)) do
        if line:sub(-1) == "\r" then
          -- LF reads retain existing CR bytes; switching to DOS would serialize them twice.
          vim.notify_once(
            "Mixed CRLF/LF endings in "
              .. vim.api.nvim_buf_get_name(buffer)
              .. ". Keeping detected line endings; no file was rewritten.",
            vim.log.levels.WARN,
            { title = "Line endings" }
          )
          return
        end
      end
    end
    end_of_line(buffer, value, options)
  end
  configured = true
end

return M
