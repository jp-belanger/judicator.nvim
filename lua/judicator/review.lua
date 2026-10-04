-- One editable Markdown file per repository. No hidden annotation state.
local M = {}
local uv = vim.uv or vim.loop

local function atomic_write(path, text)
  local tmp = path .. "." .. tostring(uv.hrtime()) .. ".tmp"
  local fd = assert(uv.fs_open(tmp, "wx", 384)) -- 0600
  local written, err = uv.fs_write(fd, text, 0)
  uv.fs_close(fd)
  if written ~= #text then
    uv.fs_unlink(tmp)
    error(err or "Incomplete review write")
  end
  local ok, rename_err = uv.fs_rename(tmp, path)
  if not ok then
    uv.fs_unlink(tmp)
    error(rename_err)
  end
end

function M.path(repository)
  local path = repository .. "/review.md"
  if not uv.fs_stat(path) then
    atomic_write(path, "# Review: " .. repository .. "\n\n")
  end
  return path
end

local function render(record, comment)
  local rev = record.revision
  local version = rev.commit or (rev.kind == "working_tree" and "working tree" or rev.kind)
  if rev.stage ~= nil then version = version .. " stage " .. rev.stage end
  local context = record.side and (record.side .. ", " .. version) or version
  local out = { string.format("## %s:%d–%d (%s)", record.path,
    record.selection.start_line, record.selection.end_line, context) }
  if rev.kind ~= "commit" then
    local text = table.concat(record.selection.lines, "\n")
    local length = 3
    for run in text:gmatch("`+") do length = math.max(length, #run + 1) end
    local fence = string.rep("`", length)
    table.insert(out, fence .. "\n" .. text .. "\n" .. fence)
  end
  table.insert(out, comment)
  return table.concat(out, "\n") .. "\n"
end

function M.append(record, comment)
  assert(comment:find("%S"), "Comment is empty; use :q! to cancel")
  local path = M.path(record.repository)
  local buffers = {}
  for _, buf in ipairs(vim.api.nvim_list_bufs()) do
    if vim.api.nvim_buf_is_loaded(buf) and vim.api.nvim_buf_get_name(buf) == path then
      assert(not vim.bo[buf].modified, "Save review.md before adding another comment")
      table.insert(buffers, buf)
    end
  end
  local text = table.concat(vim.fn.readfile(path, "b"), "\n")
  local separator = ""
  if text ~= "" and text:sub(-2) ~= "\n\n" then
    separator = text:sub(-1) == "\n" and "\n" or "\n\n"
  end
  atomic_write(path, text .. separator .. render(record, comment))
  -- Refresh clean buffers so later manual saves cannot undo the append.
  for _, buf in ipairs(buffers) do
    vim.api.nvim_buf_call(buf, function() vim.cmd("silent edit!") end)
  end
end

function M.comment(record)
  local buf = vim.api.nvim_create_buf(false, true)
  vim.bo[buf].buftype = "acwrite"
  vim.bo[buf].bufhidden = "wipe"
  vim.bo[buf].swapfile = false
  vim.bo[buf].filetype = "markdown"
  vim.api.nvim_buf_set_name(buf, "judicator://comment/" .. tostring(uv.hrtime()))
  local width = math.max(1, math.min(80, vim.o.columns - 4))
  local height = math.max(1, math.min(12, vim.o.lines - 6))
  local win = vim.api.nvim_open_win(buf, true, {
    relative = "editor", style = "minimal", border = "rounded",
    width = width, height = height,
    row = math.max(0, math.floor((vim.o.lines - height - 2) / 2)),
    col = math.max(0, math.floor((vim.o.columns - width - 2) / 2)),
    title = string.format(" %s:%d–%d (%s) ", record.path,
      record.selection.start_line, record.selection.end_line, record.side or "working tree"),
    title_pos = "center", footer = " :w save & close · :q! cancel ", footer_pos = "center",
  })
  vim.wo[win].wrap = true
  vim.wo[win].linebreak = true
  local saved = false
  vim.api.nvim_create_autocmd("BufWriteCmd", {
    buffer = buf,
    callback = function()
      if saved then return end
      -- Let errors propagate: a failed :wq must leave the comment open.
      M.append(record, table.concat(vim.api.nvim_buf_get_lines(buf, 0, -1, false), "\n"))
      saved = true
      vim.bo[buf].modified = false
      -- Defer so :wq can finish without accidentally closing the underlying pane.
      vim.schedule(function()
        if vim.api.nvim_win_is_valid(win) then vim.api.nvim_win_close(win, true) end
      end)
    end,
  })
  vim.cmd("startinsert")
end

function M.edit(repository)
  local path = M.path(repository)
  vim.cmd("botright split " .. vim.fn.fnameescape(path))
  vim.b.judicator_repository = repository
end

return M
