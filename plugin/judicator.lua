if vim.g.loaded_judicator then return end
vim.g.loaded_judicator = true

vim.api.nvim_create_user_command("ReviewComment", function(opts)
  require("judicator").comment(opts.line1, opts.line2)
end, { range = true, force = false, desc = "Comment on selected source lines" })

vim.api.nvim_create_user_command("ReviewEdit", function()
  require("judicator").edit()
end, { force = false, desc = "Edit the review Markdown" })
