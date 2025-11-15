# snacks-bibtex.nvim

A lightweight BibTeX picker for [folke/snacks.nvim](https://github.com/folke/snacks.nvim)'s picker API.  
Scan local and global `*.bib` files, preview entries, and insert citation keys or formatted references without leaving Neovim.

## Features

- Finds BibTeX entries from the current project and optional global libraries.
- Search over configurable fields (author, title, year, …).
- Rich preview rendered directly from the BibTeX entry.
- Ready-made actions for inserting keys, full entries, formatted citations, or individual fields.
- Customisable mappings and picker options via Lua.

## Installation

Use your favourite plugin manager. With [`lazy.nvim`](https://github.com/folke/lazy.nvim):

```lua
{
  "folke/snacks.nvim",
  opts = {
    picker = {}, -- enable the picker module
  },
},
{
  "kristijanhusak/snacks-bibtex.nvim",
  dependencies = { "folke/snacks.nvim" },
  opts = {
    -- optional overrides (see below)
    -- global_files = { "~/Documents/library.bib" },
  },
  keys = {
    {
      "<leader>bc",
      function()
        require("snacks-bibtex").bibtex()
      end,
      desc = "BibTeX citations (Snacks)",
    },
  },
},
```

## Usage

Run `:SnacksBibtex` or call `require("snacks-bibtex").bibtex()` to open the picker. Default actions inside the picker:

Key | Action
----|-------
`<CR>` | Insert the citation key (formatted with `config.format`, default `@%s`).
`<C-e>` | Insert the full BibTeX entry at the cursor.
`<C-c>` | Insert a formatted citation string (defaults to `{{author}} ({{year}})`).
`<C-f>` | Open a secondary picker to choose and insert a single field value.

You can override keymaps globally via `require("snacks-bibtex").setup({ mappings = { ... } })` or per picker call by passing `mappings` to `bibtex({ ... })`.

### Configuration

```lua
require("snacks-bibtex").setup({
  depth = 1,                        -- recursion depth for project search (nil for unlimited)
  files = nil,                      -- explicit list of project-local bib files
  global_files = {},                -- list of additional bib files
  search_fields = { "author", "title", "year", "journal", "journaltitle", "editor" },
  format = "@%s",                   -- how keys are inserted with <CR>
  preview_format = "{{author}} ({{year}}), {{title}}",
  citation_format = "{{author}} ({{year}})",
  mappings = {                      -- customise picker keymaps / actions
    -- ["<C-y>"] = function(picker, item) ... end,
  },
})
```

Call `bibtex()` with overrides for a single invocation:

```lua
require("snacks-bibtex").bibtex({
  global_files = { "~/notes/references.bib" },
  mappings = {
    ["<C-y>"] = "insert_entry",
  },
  picker = {
    title = "Project citations",
  },
})
```

## License

[MIT](./LICENSE)
