# snacks-bibtex.nvim

A lightweight BibTeX picker for [folke/snacks.nvim](https://github.com/folke/snacks.nvim)'s picker API, available at [krissen/snacks-bibtex.nvim](https://github.com/krissen/snacks-bibtex.nvim).
Scan local and global `*.bib` files, preview entries, and insert citation keys or formatted references without leaving Neovim.

## Features

- Finds BibTeX entries from the current project and optional global libraries.
- Search over configurable fields (author, title, year, …) with LaTeX accent awareness and field-priority aware ranking.
- Rich preview rendered directly from the BibTeX entry.
- Ready-made actions for inserting keys, full entries, formatted citations, or individual fields.
- Quick shortcuts for `\cite`, `\citep`, `\citet`, and formatted APA/Harvard/Oxford references (with pickers for the full catalogues).
- APA 7 templates derive family-name in-text citations plus reference entries with editors, publishers, page ranges, and DOI/URL details when available.
- Citation command and format pickers preview the rendered text for the highlighted entry so you can confirm before inserting.
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
`<C-y>` | Open the citation format picker (APA, Harvard, Oxford templates included with live preview).
`<C-f>` | Open a secondary picker to choose and insert a single field value.

`<CR>` works from both the search prompt and the results list, and snacks-bibtex overrides Snacks' default confirm action so Enter always inserts into the buffer you launched the picker from instead of opening the BibTeX source. All insertion shortcuts write into that original buffer and window, and the picker restores your previous insert/replace mode so trigger mappings can safely run without leaving you in normal mode.

The citation format picker renders each enabled template for the highlighted entry, giving you a preview of the exact text that will be inserted.

You can override keymaps globally via `require("snacks-bibtex").setup({ mappings = { ... } })` or per picker call by passing `mappings` to `bibtex({ ... })`. Custom mappings are automatically applied to both the results list and the search prompt unless you provide explicit `mode` options.

### Configuration

```lua
require("snacks-bibtex").setup({
  depth = 1,                        -- recursion depth for project search (nil for unlimited)
  files = nil,                      -- explicit list of project-local bib files
  global_files = {},                -- list of additional bib files
  search_fields = { "author", "year", "title", "journal", "journaltitle", "editor" },
  match_priority = { "author", "year", "title" }, -- remaining search_fields are appended automatically
  format = "%s",                    -- how keys are inserted with <CR>
  preview_format = "{{authors.reference}} ({{year}}) — {{title}}",
  citation_format = "{{apa.in_text}}", -- fallback text when no format template is available
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
  sort = {
    { field = "frecency", direction = "desc" }, -- recently used entries first
    { field = "author", direction = "asc" },    -- then author alphabetical
    { field = "year", direction = "asc" },      -- then year ascending
    { field = "source", direction = "asc" },    -- finally original BibTeX order
  },
  match_sort = nil,                 -- optional: overrides search-time ordering (defaults to score + `match_priority` + `sort`)
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

#### Sorting and frecency

Every successful insertion updates a small history file at `vim.fn.stdpath("data") .. "/snacks-bibtex/history.json"`. The
default `sort` configuration ranks entries by frecency (a blend of usage count and recent activity), then by author and year,
and finally by the order in which items appear in your BibTeX sources. This keeps frequently cited works at the top while still
providing deterministic alphabetical fallbacks.

When you start typing, the picker favours the best scoring matches and then prioritises the fields you care about the most. By default the
`match_sort` rules expand to `{ { field = "score", direction = "desc" }, { field = "match_priority" }, unpack(sort) }`, so score wins first,
then compares on the configured `match_priority` order before falling back to frecency, author, year, and
source order. Override `match_sort` to change that behaviour—for example `{ { field = "score", direction = "desc" }, { field = "match_priority", direction = "asc" }, { field = "recent", direction = "desc" } }`
keeps the best matches first but prefers recently used references over older favourites.

`match_priority` automatically extends your `search_fields` list. The default configuration starts with `author`, `year`, and `title`, then
appends the remaining search fields (`journal`, `journaltitle`, `editor` by default) so matches from earlier fields outrank the rest when their
base scores tie. Adjust `search_fields` or provide an explicit `match_priority` list to fine-tune the order. Direct key matches
always rank ahead of the configured fields, and accent-normalised values inherit the same priority as their original field, so typing
`Tröskelbegrepp` will highlight entries stored as `Tr{\"o}skelbegrepp` without losing relevance.

You can tweak or replace the ordering by editing the `sort` list (used when the prompt is empty) and the `match_sort` list (used after you
begin typing). Each rule accepts a `field` and a `direction` (`"asc"` or `"desc"`). Supported fields include `score`, `match_priority`,
`match_field`, `match_offset`, `frecency`, `frequency`, `recent`, `author`, `title`, `journal`, `year`, `key`, `type`, `label`, `text`,
`file`, and `source` (the original BibTeX order).

```lua
require("snacks-bibtex").setup({
  sort = {
    { field = "author", direction = "asc" },
    { field = "year", direction = "desc" },
    { field = "title", direction = "asc" },
  },
  match_sort = {
    { field = "score", direction = "desc" },
    { field = "recent", direction = "desc" },
    { field = "author", direction = "asc" },
  },
})
```

Removing the `frecency` rule gives you a purely alphabetical picker; keeping it ensures the most frequently used entries float
to the top automatically.

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

The command picker preview pane renders the highlighted command's output for the current entry so you can verify the exact cite string before inserting.

#### Bundled command catalogue

The plugin ships ready-to-enable templates for every `\cite`-family command provided by BibTeX, natbib, and BibLaTeX. Commands are grouped below for convenience:

- **BibTeX**: `\cite`, `\cite*`, `\nocite`.
- **natbib**: `\citet`, `\citet*`, `\Citet`, `\citep`, `\citep*`, `\Citep`, `\citealt`, `\citealt*`, `\Citealt`, `\citealp`, `\citealp*`, `\Citealp`, `\citeauthor`, `\citeauthor*`, `\citeyear`, `\citeyear*`, `\citeyearpar`, `\cites`.
- **BibLaTeX single-entry**: `\cite`, `\cite*`, `\Cite`, `\Cite*`, `\parencite`, `\parencite*`, `\Parencite`, `\Parencite*`, `\footcite`, `\footcite*`, `\Footcite`, `\Footcite*`, `\footcitetext`, `\footfullcite`, `\textcite`, `\textcite*`, `\Textcite`, `\Textcite*`, `\smartcite`, `\smartcite*`, `\Smartcite`, `\Smartcite*`, `\autocite`, `\autocite*`, `\Autocite`, `\Autocite*`, `\supercite`, `\Supercite`, `\fullcite`, `\nocite`, `\citeauthor`, `\citeauthor*`, `\Citeauthor`, `\Citeauthor*`, `\citetitle`, `\citetitle*`, `\Citetitle`, `\Citetitle*`, `\citeyear`, `\citeyear*`, `\citeurl`, `\citeurldate`, `\citedate`, `\citedate*`, `\Citedate`, `\Citedate*`, `\volcite`, `\pvolcite`, `\fvolcite`, `\svolcite`.
- **BibLaTeX multi-entry**: `\cites`, `\Cites`, `\parencites`, `\Parencites`, `\footcites`, `\Footcites`, `\textcites`, `\Textcites`, `\smartcites`, `\Smartcites`, `\autocites`, `\Autocites`, `\supercites`, `\Supercites`, `\nocites`, `\fullcites`, `\footfullcites`, `\volcites`, `\pvolcites`, `\fvolcites`, `\svolcites`.

### Citation formats

`<C-s>` and `<C-r>` insert ready-made textual reference templates. `<C-y>` opens a picker listing every enabled format. The defaults focus on APA 7 (enabled) plus Harvard and Oxford (disabled) in English.

The bundled APA 7 presets derive family-name-only in-text citations and assemble reference entries with editors, book titles, publishers, page ranges, and DOI/URL links whenever that data exists.

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
  template = "{{apa.in_text}}",
  description = "APA 7th edition in-text citation (Swedish locale)",
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
      template = "{{authors.reference}}, {{title}} ({{publisher}}, {{year}})",
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

#### Template placeholders

Each entry exposes derived metadata for templates in addition to the raw BibTeX fields:

- `{{apa.in_text}}` / `{{apa.reference}}`: Fully formatted APA 7 strings that respect author, editor, year, book/journal, publisher, page, and DOI/URL information when available.
- `{{authors.in_text}}`: Author family-name string used for in-text citations (adds `et al.` for 3+ authors).
- `{{authors.reference}}`: Author list formatted for reference lists with initials and Oxford comma handling.
- `{{authors.families}}`: Family names joined with commas and `&` for quick custom styles.
- `{{authors.count}}`: Number of parsed authors.
- `{{editors.collection}}`: Editor initials + family names joined for "In … (Ed./Eds.)" clauses.
- `{{journal}}`, `{{booktitle}}`, `{{publisher}}`, `{{location}}`, `{{volume}}`, `{{issue}}`: Unicode-normalised text pulled from the BibTeX entry.
- `{{pages}}`: Page range without `pp.` (suitable for journal references).
- `{{pages_collection}}`: Page range prefixed with `pp.`/`p.` for chapters and collections.
- `{{doi}}`, `{{url}}`: Cleaned DOI/URL values (`{{doi}}` expands to `https://doi.org/<value>` when needed).
- `{{year}}`, `{{title}}`, `{{organization}}`: Sanitised year, title, and organisation fallbacks.

All derived values strip common LaTeX accent escapes and convert them to UTF-8 so the rendered citation displays the expected characters (e.g. `G\"oteborg` → `Göteborg`).

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
