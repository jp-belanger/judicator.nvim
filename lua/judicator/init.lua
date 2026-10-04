local M = {}

local function run(action)
  local ok, err = pcall(action)
  if not ok then vim.notify(tostring(err), vim.log.levels.ERROR, { title = "Judicator" }) end
end

---Comment on an inclusive range of source lines (defaults to the current line).
---@param first? integer
---@param last? integer
function M.comment(first, last)
  run(function()
    first = first or vim.api.nvim_win_get_cursor(0)[1]
    local record = require("judicator.capture").capture(first, last or first)
    require("judicator.review").comment(record)
  end)
end

---Open the current repository's review.md for ordinary editing.
function M.edit()
  run(function()
    local repository = require("judicator.capture").repository()
    require("judicator.review").edit(repository)
  end)
end

return M
