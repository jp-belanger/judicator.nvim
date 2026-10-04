# judicator

Review code in Neovim. Select lines, write a comment, and collect feedback in
`review.md` at the repository root. Edit that file directly and give it to your
coding agent when ready.

Two commands. No configuration, default keybindings, or agent integration.

## Requirements

- Neovim 0.10+ (tested with 0.12.5).
- Git and a file inside a Git working tree.
- Optional: [Diffview](https://github.com/sindrets/diffview.nvim) for annotating
  either side of two-way diffs, including deleted and committed code.

## Install

With lazy.nvim:

```lua
{
  "jp-belanger/judicator",
  cmd = { "ReviewComment", "ReviewEdit" },
}
```

No `setup()` call or `opts` needed. The plugin registers commands without loading
its Lua implementation until a command is invoked. No files are created at startup.

## Use

1. Select lines with `V`, then `:ReviewComment` (retain the visual range).
   Without a range, the current line is used.
2. Write a comment in the floating window. `:w` saves and closes; `:q!` cancels.
   `:wq` also works.
3. `:ReviewEdit` opens `<repo-root>/review.md`. Edit, delete, or reorder feedback
   and save normally. Later edits to saved comments happen here.
4. Ask your agent to read `review.md`. Nothing is sent automatically.

Normal buffers capture unsaved text without saving the source. In Diffview,
annotate additions on the new side and deletions on the old side.

See `:help judicator` for details and the small Lua API.

## Review file

Markdown is the source of truth. New comments append without regenerating old
content. Existing `review.md` files are used as-is; no header is required.
Unsaved review-buffer edits must be saved before appending another comment.
Clean review buffers refresh automatically after appending.

Working-tree/index comments include selected text. Committed-code comments
include a full commit SHA instead, allowing the agent to retrieve the source.
There are no snapshots, JSON drafts, or hidden IDs.

Files are created with mode 0600. Git ignore settings are left alone; add
`/review.md` to `.git/info/exclude` if you want it excluded locally. Rename the
review file to start a new review. One review per repository, shared across branches.

## Limits

- One Neovim process per review; no cross-process write locking.
- No unnamed/special buffers, files outside Git, binary files, or merge layouts.
- Renames and Diffview file-history views need further testing.
- Anchors do not track later source edits.
- Diffview integration uses internals, tested against commit
  `4516612fe98ff56ae0415a259ff6361a89419b0a`.
