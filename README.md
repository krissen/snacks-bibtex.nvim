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
`<C-c>` | Open a citation command picker covering BibTeX, natbib, and BibLaTeX templates.
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
  citation_commands = {             -- toggle citation templates or add your own
    -- each entry: { command, template, description?, packages?, enabled? }
  },
  mappings = {                      -- customise picker keymaps / actions
    -- ["<C-y>"] = function(picker, item) ... end,
  },
})
```

### Citation commands

Pressing `<C-c>` opens a dedicated picker with all enabled citation templates. By default the following commands are active:

| Command | Package(s) | Description |
|---------|------------|-------------|
| `\cite{<key>}` | BibTeX, BibLaTeX | Generic cite |
| `\citet{<key>}` | natbib | Textual cite |
| `\citep{<key>}` | natbib | Parenthetical cite |
| `\citeauthor{<key>}` | natbib, BibLaTeX | Author only |
| `\citeyear{<key>}` | natbib, BibLaTeX | Year only |
| `\parencite{<key>}` | BibLaTeX | Parenthetical cite |
| `\footcite{<key>}` | BibLaTeX | Footnote cite |
| `\textcite{<key>}` | BibLaTeX | Textual cite |
| `\autocite{<key>}` | BibLaTeX | Context-aware cite |
| `\nocite{<key>}` | BibTeX, BibLaTeX | Bibliography-only |
| `\fullcite{<key>}` | BibLaTeX | Full citation |

All other BibTeX, natbib, and BibLaTeX `\cite*` variants ship with the plugin but are disabled by default to keep the picker concise.

#### Enable more commands

To enable additional templates, copy the defaults, toggle `enabled`, and pass the result back into `setup`. The snippet below enables every bundled command and adds a custom Pandoc cite style:

```lua
local cfg = require("snacks-bibtex.config").get()
for _, cmd in ipairs(cfg.citation_commands) do
  cmd.enabled = true
end
table.insert(cfg.citation_commands, {
  command = "pandoc cite",
  template = "[@{{key}}]",
  description = "Pandoc inline citation",
  packages = "pandoc",
  enabled = true,
})

require("snacks-bibtex").setup(cfg)
```

You can also opt-in to specific commands by filtering the defaults:

```lua
local cfg = require("snacks-bibtex.config").get()
cfg.citation_commands = vim.tbl_filter(function(cmd)
  return cmd.command == "\\smartcite" or cmd.command == "\\Smartcite"
end, cfg.citation_commands)
for _, cmd in ipairs(cfg.citation_commands) do
  cmd.enabled = true
end

require("snacks-bibtex").setup(cfg)
```

#### Bundled command catalogue

The plugin ships ready-to-enable templates for every `\cite`-family command provided by BibTeX, natbib, and BibLaTeX. Commands are grouped below for convenience:

- **BibTeX**: `\cite`, `\cite*`, `\nocite`.
- **natbib**: `\citet`, `\citet*`, `\Citet`, `\citep`, `\citep*`, `\Citep`, `\citealt`, `\citealt*`, `\Citealt`, `\citealp`, `\citealp*`, `\Citealp`, `\citeauthor`, `\citeauthor*`, `\citeyear`, `\citeyear*`, `\citeyearpar`, `\cites`.
- **BibLaTeX single-entry**: `\cite`, `\cite*`, `\Cite`, `\Cite*`, `\parencite`, `\parencite*`, `\Parencite`, `\Parencite*`, `\footcite`, `\footcite*`, `\Footcite`, `\Footcite*`, `\footcitetext`, `\footfullcite`, `\textcite`, `\textcite*`, `\Textcite`, `\Textcite*`, `\smartcite`, `\smartcite*`, `\Smartcite`, `\Smartcite*`, `\autocite`, `\autocite*`, `\Autocite`, `\Autocite*`, `\supercite`, `\Supercite`, `\fullcite`, `\nocite`, `\citeauthor`, `\citeauthor*`, `\Citeauthor`, `\Citeauthor*`, `\citetitle`, `\citetitle*`, `\Citetitle`, `\Citetitle*`, `\citeyear`, `\citeyear*`, `\citeurl`, `\citeurldate`, `\citedate`, `\citedate*`, `\Citedate`, `\Citedate*`, `\volcite`, `\pvolcite`, `\fvolcite`, `\svolcite`.
- **BibLaTeX multi-entry**: `\cites`, `\Cites`, `\parencites`, `\Parencites`, `\footcites`, `\Footcites`, `\textcites`, `\Textcites`, `\smartcites`, `\Smartcites`, `\autocites`, `\Autocites`, `\supercites`, `\Supercites`, `\nocites`, `\fullcites`, `\footfullcites`, `\volcites`, `\pvolcites`, `\fvolcites`, `\svolcites`.

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
