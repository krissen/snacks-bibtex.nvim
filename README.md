# snacks-bibtex.nvim

A lightweight BibTeX picker for [folke/snacks.nvim](https://github.com/folke/snacks.nvim)'s picker API, available at [krissen/snacks-bibtex.nvim](https://github.com/krissen/snacks-bibtex.nvim).
Scan local and global `*.bib` files, preview entries, and insert citation keys or formatted references without leaving Neovim.

## Features

- Finds BibTeX entries from the current project and optional global libraries.
- Search over configurable fields (author, title, year, …) with LaTeX accent awareness.
- Rich preview rendered directly from the BibTeX entry.
- Ready-made actions for inserting keys, full entries, formatted citations, or individual fields.
- Quick shortcuts for `\cite`, `\citep`, `\citet`, and formatted APA/Harvard/Oxford references (with pickers for the full catalogues).
- Customisable mappings and picker options via Lua.
- Toggle which metadata columns the citation command picker displays (packages, descriptions, templates).

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
  "krissen/snacks-bibtex.nvim",
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
`<CR>` | Insert the citation key (formatted with `config.format`, default `%s`).
`<C-e>` | Insert the full BibTeX entry at the cursor.
`<C-a>` | Insert `\cite{<key>}` (generic BibTeX/BibLaTeX citation).
`<C-p>` | Insert `\citep{<key>}` (natbib parenthetical citation).
`<C-t>` | Insert `\citet{<key>}` (natbib textual citation).
`<C-c>` | Open the citation command picker covering the full BibTeX/natbib/BibLaTeX catalogue.
`<C-s>` | Insert the default in-text citation format (APA 7 in English by default).
`<C-r>` | Insert the default reference-list citation format (APA 7 in English by default).
`<C-y>` | Open the citation format picker (APA, Harvard, Oxford templates included).
`<C-f>` | Open a secondary picker to choose and insert a single field value.

You can override keymaps globally via `require("snacks-bibtex").setup({ mappings = { ... } })` or per picker call by passing `mappings` to `bibtex({ ... })`.

### Configuration

```lua
require("snacks-bibtex").setup({
  depth = 1,                        -- recursion depth for project search (nil for unlimited)
  files = nil,                      -- explicit list of project-local bib files
  global_files = {},                -- list of additional bib files
  search_fields = { "author", "title", "year", "journal", "journaltitle", "editor" },
  format = "%s",                    -- how keys are inserted with <CR>
  preview_format = "{{author}} ({{year}}), {{title}}",
  citation_format = "{{author}} ({{year}})", -- fallback text when no format template is available
  default_citation_format = "apa7_in_text",   -- id from `citation_formats` used as the fallback
  citation_format_defaults = {
    in_text = "apa7_in_text",       -- default for <C-s>
    reference = "apa7_reference",   -- default for <C-r>
  },
  citation_command_picker = {
    title = "Citation commands",    -- picker title (set to false/nil to use default)
    packages = true,                 -- show the required packages column
    description = true,              -- show human-readable descriptions
    template = false,                -- include the raw template text
  },
  locale = "en",                    -- preferred locale for textual formats
  citation_commands = {             -- toggle citation templates or add your own
    -- each entry: { command, template, description?, packages?, enabled? }
  },
  citation_formats = {
    -- each entry: { id, name, template, description?, category?, locale?, enabled? }
  },
  mappings = {                      -- customise picker keymaps / actions
    -- use { kind = "citation_command", command = "\\autocite" } to remap quick cite keys
    -- use { kind = "citation_format", id = "apa7_reference" } for quick format slots
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

#### Quick command shortcuts

The picker binds the most common citation commands out of the box:

- `<C-a>` → `\cite`
- `<C-p>` → `\citep`
- `<C-t>` → `\citet`

Remap or add shortcuts through the `mappings` table using `kind = "citation_command"`:

```lua
require("snacks-bibtex").setup({
  mappings = {
    ["<C-a>"] = { kind = "citation_command", command = "\\autocite" },
    ["<C-p>"] = false, -- disable natbib parenthetical cite if unused
    ["<M-f>"] = { kind = "citation_command", command = "\\footcite" },
  },
})
```

#### Command picker display

Tweak which columns the citation command picker shows via `citation_command_picker`:

```lua
require("snacks-bibtex").setup({
  citation_command_picker = {
    title = "BibTeX command palette",
    packages = false,  -- hide required packages to declutter
    description = true,
    template = true,   -- show the raw template snippet instead
  },
})
```

The command name is always displayed, while descriptions, packages, and templates can be toggled on or off as needed.

#### Bundled command catalogue

The plugin ships ready-to-enable templates for every `\cite`-family command provided by BibTeX, natbib, and BibLaTeX. Commands are grouped below for convenience:

- **BibTeX**: `\cite`, `\cite*`, `\nocite`.
- **natbib**: `\citet`, `\citet*`, `\Citet`, `\citep`, `\citep*`, `\Citep`, `\citealt`, `\citealt*`, `\Citealt`, `\citealp`, `\citealp*`, `\Citealp`, `\citeauthor`, `\citeauthor*`, `\citeyear`, `\citeyear*`, `\citeyearpar`, `\cites`.
- **BibLaTeX single-entry**: `\cite`, `\cite*`, `\Cite`, `\Cite*`, `\parencite`, `\parencite*`, `\Parencite`, `\Parencite*`, `\footcite`, `\footcite*`, `\Footcite`, `\Footcite*`, `\footcitetext`, `\footfullcite`, `\textcite`, `\textcite*`, `\Textcite`, `\Textcite*`, `\smartcite`, `\smartcite*`, `\Smartcite`, `\Smartcite*`, `\autocite`, `\autocite*`, `\Autocite`, `\Autocite*`, `\supercite`, `\Supercite`, `\fullcite`, `\nocite`, `\citeauthor`, `\citeauthor*`, `\Citeauthor`, `\Citeauthor*`, `\citetitle`, `\citetitle*`, `\Citetitle`, `\Citetitle*`, `\citeyear`, `\citeyear*`, `\citeurl`, `\citeurldate`, `\citedate`, `\citedate*`, `\Citedate`, `\Citedate*`, `\volcite`, `\pvolcite`, `\fvolcite`, `\svolcite`.
- **BibLaTeX multi-entry**: `\cites`, `\Cites`, `\parencites`, `\Parencites`, `\footcites`, `\Footcites`, `\textcites`, `\Textcites`, `\smartcites`, `\Smartcites`, `\autocites`, `\Autocites`, `\supercites`, `\Supercites`, `\nocites`, `\fullcites`, `\footfullcites`, `\volcites`, `\pvolcites`, `\fvolcites`, `\svolcites`.

### Citation formats

`<C-s>` and `<C-r>` insert ready-made textual reference templates. `<C-y>` opens a picker listing every enabled format. The defaults focus on APA 7 (enabled) plus Harvard and Oxford (disabled) in English.

Enable or extend formats through `citation_formats`:

```lua
local cfg = require("snacks-bibtex.config").get()

-- keep the bundled APA 7 entries, but enable Harvard and add a Swedish variant
for _, format in ipairs(cfg.citation_formats) do
  if format.id:find("harvard", 1, true) then
    format.enabled = true
  end
end

table.insert(cfg.citation_formats, {
  id = "apa7_in_text_sv",
  name = "APA 7 (in-text, Swedish)",
  template = "({{author}}, {{year}})",
  description = "APA 7th edition in-text citation (Swedish)",
  category = "in_text",
  locale = "sv",
  enabled = true,
})

cfg.locale = "sv"
cfg.citation_format_defaults = {
  in_text = "apa7_in_text_sv",
  reference = "apa7_reference",
}

cfg.mappings = cfg.mappings or {}
cfg.mappings["<C-s>"] = { kind = "citation_format", id = "apa7_in_text_sv" }

require("snacks-bibtex").setup(cfg)
```

To disable unwanted templates, set `enabled = false` or remove them entirely. You can also create a clean slate:

```lua
require("snacks-bibtex").setup({
  citation_formats = {
    {
      id = "oxford_reference",
      name = "Oxford (reference list)",
      template = "{{author}}, {{title}} ({{publisher}}, {{year}})",
      category = "reference",
      locale = "en",
      enabled = true,
    },
  },
  citation_format_defaults = {
    in_text = "apa7_in_text",
    reference = "oxford_reference",
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
