-- Resolve selected source lines in ordinary files or Diffview panes.
local M = {}

local function current_view()
  local ok, lib = pcall(require, "diffview.lib")
  return ok and lib.get_current_view() or nil
end

local function git_root(directory)
  local output = vim.fn.system({ "git", "-C", directory, "rev-parse", "--show-toplevel" })
  assert(vim.v.shell_error == 0, "Open a file inside a Git working tree")
  return vim.fs.normalize(vim.trim(output))
end

function M.repository()
  if vim.b.judicator_repository then return vim.b.judicator_repository end
  local view = current_view()
  if view and view.adapter then return view.adapter.ctx.toplevel end
  local name = vim.api.nvim_buf_get_name(0)
  return git_root(name ~= "" and vim.bo.buftype == "" and vim.fs.dirname(name) or vim.fn.getcwd())
end

-- All Diffview internals are isolated here. Normal files need no Diffview plugin.
local function target()
  local view = current_view()
  if view then
    local layout = view.cur_layout
    assert(layout and #layout.windows == 2, "Only two-way Diffview layouts are supported")
    for _, win in ipairs(layout.windows) do
      if win.id == vim.api.nvim_get_current_win() then
        local file = win.file
        assert(file and file.bufnr == vim.api.nvim_get_current_buf(), "Not a loaded diff buffer")
        assert(not file.nulled, "Select the populated side of this diff")
        assert(not file.binary, "Binary files are not supported")
        assert(file.symbol == "a" or file.symbol == "b", "Unknown Diffview side")
        local types = require("diffview.vcs.rev").RevType
        local kinds = { [types.LOCAL] = "working_tree", [types.COMMIT] = "commit", [types.STAGE] = "index" }
        return {
          repository = file.adapter.ctx.toplevel, path = file.path,
          side = file.symbol == "a" and "old" or "new",
          revision = {
            kind = assert(kinds[file.rev.type], "Unsupported revision type"),
            commit = file.rev.commit, stage = file.rev.stage,
          },
        }
      end
    end
    error("Select lines in a diff pane, not the file panel")
  end

  assert(vim.bo.buftype == "" and not vim.b.judicator_repository, "Select lines in a source file")
  assert(not vim.bo.binary, "Binary files are not supported")
  local name = vim.api.nvim_buf_get_name(0)
  assert(name ~= "", "Give the file a name before commenting")
  local absolute = vim.fs.normalize(vim.fn.fnamemodify(name, ":p"))
  local repository = M.repository()
  local prefix = repository .. "/"
  assert(absolute:sub(1, #prefix) == prefix, "File is outside the resolved repository")
  return {
    repository = repository, path = absolute:sub(#prefix + 1),
    revision = { kind = "working_tree" },
  }
end

function M.capture(first, last)
  local record = target()
  assert(first >= 1 and last >= first and last <= vim.api.nvim_buf_line_count(0), "Invalid line range")
  record.selection = {
    start_line = first, end_line = last,
    lines = vim.api.nvim_buf_get_lines(0, first - 1, last, false),
  }
  return record
end

return M
