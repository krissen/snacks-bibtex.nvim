# snacks-bibtex.nvim

A BibTeX citation picker for [folke/snacks.nvim](https://github.com/folke/snacks.nvim).

Scan local and global `.bib` files, preview entries, and insert citation keys or formatted references without leaving Neovim.

## Features

- **Flexible BibTeX integration** — Project-local and global libraries
- **Context awareness** — Auto-detect bibliography from YAML frontmatter, LaTeX preambles, or Typst documents
- **Smart search** — Configurable fields with LaTeX accent awareness
- **Multiple insertion modes** — Keys, formatted references, full entries, or individual fields
- **Citation styles** — APA 7, Harvard, Oxford templates with live preview
- **Frecency sorting** — Frequently and recently used entries float to the top
- **Local bibliography target** — Auto-copy entries from master library to project-local files
- **Jump to source** — Navigate directly to BibTeX entries for editing

## Requirements

- **Neovim** >= 0.9
- [folke/snacks.nvim](https://github.com/folke/snacks.nvim) with picker module enabled

## Installation

### lazy.nvim

```lua
{
  "folke/snacks.nvim",
  opts = { picker = {} },
},
{
  "krissen/snacks-bibtex.nvim",
  dependencies = { "folke/snacks.nvim" },
  opts = {
    -- global_files = { "~/Documents/library.bib" },
  },
  keys = {
    { "<leader>bc", function() require("snacks-bibtex").bibtex() end, desc = "BibTeX citations" },
  },
},
```

## Quick Start

Run `:SnacksBibtex` or call `require("snacks-bibtex").bibtex()` to open the picker.

### Default Keybindings

| Key | Action |
|-----|--------|
| `<CR>` | Insert citation (key or format based on filetype) |
| `<C-e>` | Insert full BibTeX entry |
| `<C-k>` | Insert key only |
| `<C-a>` | Insert `\cite{key}` |
| `<C-p>` | Insert `\citep{key}` (natbib) |
| `<C-t>` | Insert `\citet{key}` (natbib) |
| `<C-c>` | Open citation command picker |
| `<C-s>` | Insert in-text citation (APA) |
| `<C-r>` | Insert reference format (APA) |
| `<C-y>` | Open citation format picker |
| `<C-f>` | Pick and insert a single field |
| `<C-g>` | Jump to BibTeX source file |
| `<C-l>` | Copy to local bib + insert citation (when enabled) |
| `<M-l>` | Copy to local bib only (when enabled) |

## Configuration

```lua
require("snacks-bibtex").setup({
  depth = 1,                          -- directory search depth
  global_files = {},                  -- global bib files
  files_exclude = {},                 -- patterns to exclude

  local_bib = {                       -- copy entries to local file
    enabled = false,
    target = nil,                     -- e.g., "refs.bib"
    auto_add = false,                 -- auto-copy on insert
    create_if_missing = false,
  },

  context = {                         -- detect bibliography from document
    enabled = false,
    fallback = true,
  },

  display = {
    show_key = true,
    show_preview = true,
    show_source_status = true,        -- [L]/[G] indicators
  },

  search_fields = { "author", "year", "title", "journal", "journaltitle", "editor" },
  format = "%s",                      -- key insertion format
  locale = "en",
})
```

**Full configuration reference:** [docs/configuration.md](docs/configuration.md)

## Key Features

### Local Bibliography Target

Auto-copy entries from a master library to a project-local `.bib` file:

```lua
require("snacks-bibtex").setup({
  files_exclude = { "refs.bib" },     -- exclude local file from sources
  local_bib = {
    enabled = true,
    target = "refs.bib",
    auto_add = true,
    create_if_missing = true,
  },
})
```

Source status indicators show where entries come from:
- `[L]` / `[G]` — Local only / Global only
- `[L=G]` / `[G=L]` — Exists in both, identical
- `[L≠G]` / `[G≠L]` — Exists in both, differs
- `[+L]` / `[*L]` — Added to local (when target is excluded)

**Full documentation:** [docs/local-bib.md](docs/local-bib.md)

### Context-Aware Detection

Auto-detect bibliography files from your document:

```lua
require("snacks-bibtex").setup({
  context = {
    enabled = true,
    fallback = true,    -- fall back to project search if no context
    inherit = true,     -- inherit from main file in multi-file projects
  },
})
```

Supports YAML frontmatter (Markdown), `\addbibresource` (LaTeX), and `#bibliography()` (Typst).

**Full documentation:** [docs/context.md](docs/context.md)

### Citation Commands and Formats

Press `<C-c>` for LaTeX/Typst commands, `<C-y>` for formatted citations (APA, Harvard, Oxford).

**Full documentation:** [docs/citation-commands.md](docs/citation-commands.md)

### Per-Filetype Insertion

Configure what `<CR>` inserts based on filetype:

```lua
require("snacks-bibtex").setup({
  default_insert_mode = "key",
  insert_mode_by_filetype = {
    markdown = "format",    -- insert "(Smith & Doe, 2020)"
    tex = "key",            -- insert "smith2020"
  },
})
```

### Sorting and Frecency

Entries are sorted by frecency (usage count + recency), then author, year, and source order. History is stored in `~/.local/share/nvim/snacks-bibtex/history.json`.

### BibTeX File Insertion

When opening the picker from a `.bib` file:
- `<CR>` inserts the full entry (configurable via `bib_file_insert`)
- Duplicate warnings for existing keys/entries

## Health Check

Run `:checkhealth snacks-bibtex` to verify your configuration.

## Documentation

- [Configuration Reference](docs/configuration.md)
- [Local Bibliography Target](docs/local-bib.md)
- [Context-Aware Detection](docs/context.md)
- [Citation Commands and Formats](docs/citation-commands.md)

## Related Projects

- [telescope-bibtex.nvim](https://github.com/nvim-telescope/telescope-bibtex.nvim) — Telescope-based BibTeX picker
- [cmp-bibtex](https://github.com/crispgm/cmp-bibtex) — Completion source for nvim-cmp
- [vimtex](https://github.com/lervag/vimtex) — Comprehensive LaTeX support

## License

[MIT](./LICENSE)

## Acknowledgments

- [folke/snacks.nvim](https://github.com/folke/snacks.nvim) — The picker framework
- [lervag/vimtex](https://github.com/lervag/vimtex) — LaTeX support for Vim/Neovim
- [nvim-telescope/telescope-bibtex.nvim](https://github.com/nvim-telescope/telescope-bibtex.nvim) — Inspiration
