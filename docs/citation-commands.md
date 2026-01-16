# Citation Commands and Formats

snacks-bibtex provides two types of citation insertion:
- **Commands** — LaTeX/Typst syntax like `\cite{key}` or `@key`
- **Formats** — Rendered text like "(Smith & Doe, 2020)" or full reference strings

## Citation Commands

Press `<C-c>` to open the command picker with all enabled citation templates.

### Default Commands

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
| `@<key>` | Typst | Basic citation |
| `@<key>[supplement]` | Typst | Citation with supplement |

All other BibTeX, natbib, and BibLaTeX `\cite*` variants ship with the plugin but are disabled by default.

### Quick Command Shortcuts

| Key | Command |
|-----|---------|
| `<C-a>` | `\cite` |
| `<C-p>` | `\citep` |
| `<C-t>` | `\citet` |

Remap via `mappings`:

```lua
require("snacks-bibtex").setup({
  mappings = {
    ["<C-a>"] = { kind = "citation_command", command = "\\autocite" },
    ["<C-p>"] = false,  -- disable
    ["<M-f>"] = { kind = "citation_command", command = "\\footcite" },
  },
})
```

### Enabling More Commands

Enable all bundled commands:

```lua
local cfg = require("snacks-bibtex.config").get()
for _, cmd in ipairs(cfg.citation_commands) do
  cmd.enabled = true
end
require("snacks-bibtex").setup(cfg)
```

Add a custom command:

```lua
table.insert(cfg.citation_commands, {
  command = "pandoc cite",
  template = "[@{{key}}]",
  description = "Pandoc inline citation",
  packages = "pandoc",
  enabled = true,
})
```

Filter to specific commands:

```lua
cfg.citation_commands = vim.tbl_filter(function(cmd)
  return cmd.command == "\\smartcite" or cmd.command == "\\Smartcite"
end, cfg.citation_commands)
```

### Command Picker Display

```lua
require("snacks-bibtex").setup({
  citation_command_picker = {
    title = "BibTeX command palette",
    packages = false,   -- hide package column
    description = true,
    template = true,    -- show raw template
  },
})
```

### Bundled Command Catalog

- **BibTeX**: `\cite`, `\cite*`, `\nocite`
- **natbib**: `\citet`, `\citet*`, `\Citet`, `\citep`, `\citep*`, `\Citep`, `\citealt`, `\citealt*`, `\Citealt`, `\citealp`, `\citealp*`, `\Citealp`, `\citeauthor`, `\citeauthor*`, `\citeyear`, `\citeyear*`, `\citeyearpar`, `\cites`
- **BibLaTeX single-entry**: `\cite`, `\cite*`, `\Cite`, `\Cite*`, `\parencite`, `\parencite*`, `\Parencite`, `\Parencite*`, `\footcite`, `\footcite*`, `\Footcite`, `\Footcite*`, `\footcitetext`, `\footfullcite`, `\textcite`, `\textcite*`, `\Textcite`, `\Textcite*`, `\smartcite`, `\smartcite*`, `\Smartcite`, `\Smartcite*`, `\autocite`, `\autocite*`, `\Autocite`, `\Autocite*`, `\supercite`, `\Supercite`, `\fullcite`, `\nocite`, `\citeauthor`, `\citeauthor*`, `\Citeauthor`, `\Citeauthor*`, `\citetitle`, `\citetitle*`, `\Citetitle`, `\Citetitle*`, `\citeyear`, `\citeyear*`, `\citeurl`, `\citeurldate`, `\citedate`, `\citedate*`, `\Citedate`, `\Citedate*`, `\volcite`, `\pvolcite`, `\fvolcite`, `\svolcite`
- **BibLaTeX multi-entry**: `\cites`, `\Cites`, `\parencites`, `\Parencites`, `\footcites`, `\Footcites`, `\textcites`, `\Textcites`, `\smartcites`, `\Smartcites`, `\autocites`, `\Autocites`, `\supercites`, `\Supercites`, `\nocites`, `\fullcites`, `\footfullcites`, `\volcites`, `\pvolcites`, `\fvolcites`, `\svolcites`
- **Typst**: `@key`, `@key[supplement]`

## Citation Formats

Press `<C-y>` to open the format picker. Use `<C-s>` for in-text and `<C-r>` for reference formats.

### Default Formats

APA 7 (in-text and reference), Harvard (in-text and reference), and Oxford (reference) ship enabled by default.

### Quick Format Shortcuts

| Key | Default |
|-----|---------|
| `<C-s>` | In-text citation (APA 7) |
| `<C-r>` | Reference list format (APA 7) |
| `<C-y>` | Open format picker |

Configure defaults:

```lua
require("snacks-bibtex").setup({
  citation_format_defaults = {
    in_text = "apa7_in_text",
    reference = "apa7_reference",
  },
})
```

### Adding Custom Formats

```lua
local cfg = require("snacks-bibtex.config").get()

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
cfg.citation_format_defaults.in_text = "apa7_in_text_sv"
cfg.mappings["<C-s>"] = { kind = "citation_format", id = "apa7_in_text_sv" }

require("snacks-bibtex").setup(cfg)
```

### Creating a Clean Slate

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

## Template Placeholders

Templates use `{{placeholder}}` syntax. Available placeholders:

### Derived Fields (Formatted)

| Placeholder | Description |
|-------------|-------------|
| `{{apa.in_text}}` | Full APA 7 in-text citation |
| `{{apa.reference}}` | Full APA 7 reference entry |
| `{{authors.in_text}}` | Family names for in-text (with et al. for 3+) |
| `{{authors.reference}}` | Formatted author list with initials |
| `{{authors.families}}` | Family names joined with commas and & |
| `{{authors.count}}` | Number of authors |
| `{{editors.collection}}` | Editors for "In ... (Ed./Eds.)" clauses |

### BibTeX Fields (Raw)

| Placeholder | Description |
|-------------|-------------|
| `{{key}}` | Citation key |
| `{{year}}` | Publication year |
| `{{title}}` | Title |
| `{{author}}` | Raw author field |
| `{{journal}}` | Journal name |
| `{{booktitle}}` | Book title |
| `{{publisher}}` | Publisher |
| `{{location}}` | Publication location |
| `{{volume}}` | Volume number |
| `{{issue}}` | Issue number |
| `{{pages}}` | Page range (no prefix) |
| `{{pages_collection}}` | Page range with pp./p. prefix |
| `{{doi}}` | DOI (expands to full URL) |
| `{{url}}` | URL |
| `{{organization}}` | Organization |

### Special Syntax

- **Triple braces** `{{{field}}}`: Wrap resolved value in `{}` (for LaTeX)
- All derived values convert LaTeX accents to UTF-8 (e.g., `G\"oteborg` → `Göteborg`)

## Generating Stable IDs

Use `sanitize_identifier` for custom commands/formats:

```lua
local id = require("snacks-bibtex.config").sanitize_identifier("My Custom Format")
-- Returns: "my_custom_format"
```
