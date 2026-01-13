# 📚 snacks-bibtex.nvim

A lightweight BibTeX picker for [folke/snacks.nvim](https://github.com/folke/snacks.nvim)'s picker API.

Scan local and global `*.bib` files, preview entries, and insert citation keys or formatted references without leaving Neovim.

## ✨ Features

- 📖 **Flexible BibTeX integration** – Finds entries from project-local and global libraries
- 🎯 **Context awareness** – Auto-detect bibliography files from YAML frontmatter, LaTeX preambles, or Typst documents
- 🔍 **Smart search** – Configurable fields (author, title, year, …) with LaTeX accent awareness
- 📝 **Multiple insertion modes** – Citation keys, formatted references, full entries, individual fields, or insert raw `bib`-entries
- 🎯 **Rich previews** – See BibTeX source and formatted output before inserting
- ⚡ **Quick shortcuts** – Pre-configured for `\cite`, `\citep`, `\citet`, `@key`, and common citation formats
- 🎨 **Citation styles** – APA 7, Harvard, Oxford templates with live preview
- 🔧 **Highly customizable** – Mappings, sorting, format templates via Lua
- 📊 **Frecency sorting** – Frequently and recently used entries float to the top
- 🎭 **Command picker** – Browse and preview the full BibTeX/natbib/BibLaTeX/Typst catalog
- 🧭 **Jump to source** – Navigate directly to BibTeX entries for editing

## 🤔 Why this plugin?

While [vimtex](https://github.com/lervag/vimtex) combined with completion plugins like [nvim-cmp](https://github.com/hrsh7th/nvim-cmp) provides excellent LaTeX citation support, there are scenarios where a dedicated BibTeX picker is valuable:

- **Beyond LaTeX** – Writing Markdown, Org-mode, Typst, or other formats that use BibTeX but aren't LaTeX documents
- **Custom workflows** – Manual invocation for citation insertion in any context
- **Unsupported commands** – Custom `\cite*` variants that completion engines don't recognize
- **Universal access** – Quick reference lookup regardless of the current document type
- **Frecency-based ordering** – Automatically prioritize your most-used references
- **Format flexibility** – Generate APA/Harvard/Oxford citations outside of LaTeX compilation
- **Context awareness** – Automatically detect bibliography files from your document's frontmatter or preamble

This plugin complements existing tools by providing a universal, on-demand interface to your BibTeX libraries.

## 🔗 Related Projects

### [telescope-bibtex.nvim](https://github.com/nvim-telescope/telescope-bibtex.nvim)

- **Similarities**: Both provide fuzzy-finding over BibTeX entries using their respective picker frameworks (Telescope vs Snacks)
- **Key differences**:
  - snacks-bibtex leverages snacks.nvim's picker infrastructure and follows its conventions
  - Built-in citation format templates (APA, Harvard, Oxford) with live preview
  - Frecency tracking for frequently-used entries
  - Field-priority aware matching and sorting
  - Direct integration with citation command catalog
- **Choose telescope-bibtex if**: You're already using Telescope and prefer its ecosystem
- **Choose snacks-bibtex if**: You're using snacks.nvim or want advanced formatting features

### [cmp-bibtex](https://github.com/crispgm/cmp-bibtex)

- **Purpose**: Completion source for nvim-cmp
- **Complementary use**: cmp-bibtex for inline completion while typing, snacks-bibtex for manual invocation and format browsing
- **Key difference**: cmp-bibtex is completion-driven; snacks-bibtex is command/picker-driven

### [vimtex](https://github.com/lervag/vimtex)

- **Purpose**: Comprehensive LaTeX editing environment
- **Integration**: Works alongside vimtex for enhanced citation workflow
- **Key difference**: vimtex focuses on complete LaTeX support; snacks-bibtex specializes in BibTeX citation insertion across file types

## ⚡ Requirements

- **Neovim** >= 0.9
- [folke/snacks.nvim](https://github.com/folke/snacks.nvim) with picker module enabled

## 📦 Installation

### [lazy.nvim](https://github.com/folke/lazy.nvim)

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

### Other plugin managers

For [vim-plug](https://github.com/junegunn/vim-plug), [packer.nvim](https://github.com/wbthomason/packer.nvim), or manual installation, ensure:

1. [folke/snacks.nvim](https://github.com/folke/snacks.nvim) is installed with `picker` module enabled
2. Clone or install `snacks-bibtex.nvim`
3. Call `require("snacks-bibtex").setup(opts)` in your config

## 🚀 Usage

Run `:SnacksBibtex` or call `require("snacks-bibtex").bibtex()` to open the picker.

### Default keybindings

Default actions inside the picker:

Key | Action
----|-------
`<CR>` | Insert the citation key (formatted with `config.format`, default `%s`). When launched from a `.bib` file with `bib_file_insert = "entry"`, inserts the full BibTeX entry instead.
`<C-e>` | Insert the full BibTeX entry at the cursor (with duplicate warnings when in a `.bib` file).
`<C-k>` | Insert the citation key only (ignores `bib_file_insert` setting).
`<C-a>` | Insert `\cite{<key>}` (generic BibTeX/BibLaTeX citation).
`<C-p>` | Insert `\citep{<key>}` (natbib parenthetical citation).
`<C-t>` | Insert `\citet{<key>}` (natbib textual citation).
`<C-c>` | Open the citation command picker covering the full BibTeX/natbib/BibLaTeX catalog.
`<C-g>` | Jump to the BibTeX source file at the first line of the selected entry (reuses the window you launched the picker from).
`<C-s>` | Insert the default in-text citation format (APA 7 in English by default).
`<C-r>` | Insert the default reference-list citation format (APA 7 in English by default).
`<C-y>` | Open the citation format picker (APA, Harvard, Oxford templates included with live previews, labelled rows, and inline samples).
`<C-f>` | Open a secondary picker to choose and insert a single field value.

`<CR>` works from both the search prompt and the results list, and snacks-bibtex overrides Snacks' default confirm action so Enter always inserts into the buffer you launched the picker from instead of opening the BibTeX source. All insertion shortcuts write into that original buffer and window, and the picker restores your previous insert/replace mode so trigger mappings can safely run without leaving you in normal mode. Use `<C-g>` whenever you want to tweak the bibliographic data itself—the picker closes and focuses the BibTeX file at the entry's first line in the originating window so you can edit immediately without juggling splits.

The citation format picker renders each enabled template for the highlighted entry, giving you a preview of the exact text that will be inserted. APA (in-text and reference), Harvard (in-text and reference), and Oxford (reference) formats ship enabled by default so you can immediately compare them; disable or extend the list through `citation_formats`.

You can override keymaps globally via `require("snacks-bibtex").setup({ mappings = { ... } })` or per picker call by passing `mappings` to `bibtex({ ... })`. Custom mappings are automatically applied to both the results list and the search prompt unless you provide explicit `mode` options.

## ⚙️ Configuration

```lua
require("snacks-bibtex").setup({
  depth = 1,                        -- recursion depth for project search (nil for unlimited)
  files = nil,                      -- explicit list of project-local bib files (supports ~ / $ENV expansion)
  global_files = {},                -- list of additional bib files (supports ~ / $ENV expansion)
  context = {                       -- context-aware bibliography file detection
    enabled = false,                --   enable context detection (default: false)
    fallback = true,                --   fall back to project search if no context found (default: true)
    inherit = true,                 --   inherit context from main files in multi-file projects (default: true)
    depth = 1,                      --   directory depth for searching parent files (default: 1, 0=current only, nil=unlimited/not recommended)
    max_files = 100,                --   max number of files to check per directory when searching for main files (default: 100)
  },
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
  display = {
    show_key = true,                -- show citation key in picker list
    show_preview = true,            -- show formatted preview in picker list
    key_separator = " — ",          -- separator between key and preview when both shown
    preview_fields = nil,           -- optional list of field names to show in preview (overrides preview_format)
    preview_fields_separator = " — ", -- separator between preview fields when preview_fields is used
  },
  sort = {
    { field = "frecency", direction = "desc" }, -- recently used entries first
    { field = "author", direction = "asc" },    -- then author alphabetical
    { field = "year", direction = "asc" },      -- then year ascending
    { field = "source", direction = "asc" },    -- finally original BibTeX order
  },
  match_sort = nil,                 -- optional: overrides search-time ordering (defaults to score + `match_priority` + `sort`)
  locale = "en",                    -- preferred locale for textual formats
  bib_file_insert = "entry",        -- what to insert when picker is opened from a .bib file ("entry" or "key")
  warn_on_duplicate_key = true,     -- warn when inserting an entry whose key already exists (in .bib files)
  warn_on_duplicate_entry = true,   -- warn when inserting an exact duplicate entry (in .bib files)
  parser_unescape_basic = true,     -- unescape \" and \\ in quoted strings during parsing (default: true)
  duplicate_normalization_mode = "whitespace", -- how to normalize entry text for duplicate detection ("none" or "whitespace")
  citation_commands = {             -- toggle citation templates or add your own
    -- each entry: { command, template, description?, packages?, enabled? }
  },
  citation_formats = {
    -- each entry: { id, name, template, description?, category?, locale?, enabled? }
  },
  mappings = {                      -- customise picker keymaps / actions
    -- use { kind = "citation_command", command = "\\autocite" } to remap quick cite keys
    -- use { kind = "citation_format", id = "apa7_reference" } for quick format slots
    -- map "open_entry" to another key if you prefer a different shortcut for jumping to the BibTeX file
  },
})
```

Paths supplied through `files` or `global_files` may include `~` or environment variables (for example `"~/Documents/library.bib"` or `"$ZOTERO_HOME/export.bib"`); snacks-bibtex expands these before attempting to read the files.

### Display configuration

The `display` table controls how entries appear in the picker list:

```lua
require("snacks-bibtex").setup({
  display = {
    show_key = true,                -- show citation key in picker list
    show_preview = true,            -- show formatted preview in picker list
    key_separator = " — ",          -- separator between key and preview when both shown
    preview_fields = nil,           -- optional list of field names to show in preview
    preview_fields_separator = " — ", -- separator between preview fields
  },
})
```

By default, both the citation key and the formatted preview are shown (`smith2020 — Smith, J. (2020) — Article Title`). If you have long citation keys that take up too much space, you can hide them by setting `show_key = false` to display only the formatted preview information. Conversely, setting `show_preview = false` shows only the citation keys. The `key_separator` can be customized to any string you prefer when both are visible.

When both `show_key` and `show_preview` are enabled but the preview is identical to the key (which happens when the entry has minimal metadata), only the key is shown to avoid duplication.

#### Customizing preview fields

You can customize which fields appear in the preview by specifying `preview_fields`. This provides a simpler alternative to writing a full `preview_format` template:

```lua
require("snacks-bibtex").setup({
  display = {
    preview_fields = { "author", "year", "title" },
    preview_fields_separator = " • ",  -- customize the separator between fields
  },
})
```

When `preview_fields` is set, it overrides the `preview_format` setting. The fields are joined with the `preview_fields_separator` (default: `" — "`).

**Available field names:**

You can use any of the following in `preview_fields` (field names are case-insensitive):

- **BibTeX fields**: `author`, `editor`, `title`, `journal`, `journaltitle`, `booktitle`, `publisher`, `year`, `volume`, `number`, `issue`, `pages`, `doi`, `url`, `organization`, `institution`, `location`, `address`, `edition`, `series`, and any other standard BibTeX field
- **Derived fields**: `authors.in_text`, `authors.reference`, `authors.families`, `authors.count`, `editors.collection`, `apa.in_text`, `apa.reference`
- **Special fields**: `key`, `type`, `file`

See the [Template placeholders](#template-placeholders) section for more details on derived fields.

> **Note:** Using raw BibTeX field names (e.g., `"author"`, `"title"`) in `preview_fields` will return the unformatted BibTeX value (e.g., `"Smith, John and Doe, Jane"`).  
> For formatted output (e.g., `"Smith, J. & Doe, J."`), use derived fields like `"authors.reference"` or `"apa.in_text"`.

Examples:

```lua
-- Show only author and year (using BibTeX field names)
display = {
  preview_fields = { "author", "year" },
}
-- Result: "Smith, John and Doe, Jane — 2020"  (raw BibTeX value; not formatted)

-- Show author, title, and journal with custom separator
display = {
  preview_fields = { "author", "title", "journal" },
  preview_fields_separator = " | ",
}
-- Result: "Smith, John and Doe, Jane | Machine Learning Applications | Journal of Computing"

-- Use derived fields for formatted output
display = {
  preview_fields = { "authors.reference", "year", "title" },
}
-- Result: "Smith, J. & Doe, J. — 2020 — Machine Learning Applications"
```

### Context-aware bibliography file detection

When `context.enabled = true`, snacks-bibtex looks for context lines in your currently opened file that specify which bibliography file(s) to use. This is particularly useful for multi-project workflows where different documents reference different bibliography files. By default, `context.enabled = false`, meaning the plugin will always search your project directory for `.bib` files and include `global_files`.

**How it works:**

- When context is detected (e.g., `bibliography:` in YAML frontmatter or `\addbibresource{}` in LaTeX), **only** those files are used
- Both `global_files` and the normal project directory search are ignored when context is found
- If no context is detected and `context.fallback = true` (the default), the plugin falls back to searching your project directory
- If no context is detected and `context.fallback = false`, no entries will be shown

**When to use `context.fallback = false`:**

- You want strict mode: only show citations when the document explicitly declares its bibliography
- You're working in a repository with multiple unrelated documents and want to avoid accidentally citing from the wrong bibliography
- You want to enforce that all documents must declare their bibliography sources

**Supported filetypes and context patterns:**

| Filetype | Context Pattern | Example |
|----------|----------------|---------|
| `pandoc`, `markdown`, `md`, `rmd` | YAML frontmatter `bibliography:` | `bibliography: refs.bib` or array format |
| `tex`, `plaintex`, `latex` | `\bibliography{file}` | `\bibliography{references}` (extension added automatically) |
| `tex`, `plaintex`, `latex` | `\addbibresource{file}` | `\addbibresource{references.bib}` |
| `typst` | `#bibliography("file")` | `#bibliography("references.bib")` or `#bibliography("references.yml")` |
| `typst` | `#import "file.typ": refs` | Detects bibliography from imported `.typ` files (supports `#let refs = bibliography("file")`) |

**Example Markdown file with context:**

```markdown
---
title: My Paper
bibliography: references.bib
---

# Introduction
Citations go here [@key].
```

**Example LaTeX file with context:**

```latex
\documentclass{article}
\usepackage{biblatex}
\addbibresource{references.bib}
\begin{document}
Citations go here \cite{key}.
\end{document}
```

**Example Typst file with context:**

```typst
#bibliography("references.bib")

= Introduction
Citations go here @key.
```

**Example Typst file with imported references:**

```typst
#import "refs.typ": refs

= Introduction
Citations: @berger1967 and @hjarpe2019.

== References
#refs
```

Where `refs.typ` contains:

```typst
#let refs = bibliography("refs.bib")
```

**Configuration example:**

```lua
require("snacks-bibtex").setup({
  context = {
    enabled = true,   -- Enable context awareness (default: false)
    fallback = true,  -- Fall back to project search if no context found (default: true)
  },
})

-- For strict mode (only show citations when document declares bibliography):
require("snacks-bibtex").setup({
  context = {
    enabled = true,
    fallback = false,  -- No fallback: require explicit bibliography declaration
  },
})

-- Default behavior (always search project):
require("snacks-bibtex").setup({
  context = {
    enabled = false,  -- Always use project directory search (default)
  },
})

-- Backward compatible: boolean still works
require("snacks-bibtex").setup({
  context = true,  -- Equivalent to { enabled = true, fallback = true, inherit = true, depth = 1 }
})
```

**Per-invocation context control:**

```lua
-- Enable context for this call only
require("snacks-bibtex").bibtex({ context = { enabled = true } })

-- Disable context for this call
require("snacks-bibtex").bibtex({ context = { enabled = false } })

-- Strict mode for this call (no fallback)
require("snacks-bibtex").bibtex({ context = { enabled = true, fallback = false } })

-- Backward compatible: boolean still works
require("snacks-bibtex").bibtex({ context = true })
```

**Summary of behavior:**

| `context.enabled` | `context.fallback` | Context found? | Result |
|-------------------|-------------------|----------------|--------|
| `true` | `true` | Yes | Use context files only |
| `true` | `true` | No | Fall back to project search + `global_files` |
| `true` | `false` | Yes | Use context files only |
| `true` | `false` | No | Show no entries |
| `false` | any | any | Always use project search + `global_files` (context is ignored) |

#### Context inheritance for multi-file projects

When working with multi-file LaTeX or Typst projects, sub-files often don't explicitly mention the bibliography but depend on a main file that does. For example:

**LaTeX example:**

**Main file (`main.tex`):**

```latex
\documentclass{article}
\usepackage{biblatex}
\addbibresource{references.bib}

\input{chapters/introduction}
\input{chapters/methods}

\printbibliography
\end{document}
```

**Sub-file (`chapters/introduction.tex`):**

```latex
% No \addbibresource here - depends on main.tex preamble
\section{Introduction}
Some text with citations \cite{key}.
```

**Typst example:**

**Main file (`main.typ`):**

```typst
#bibliography("references.bib")

#include "chapters/introduction.typ"
#include "chapters/methods.typ"
```

**Sub-file (`chapters/introduction.typ`):**

```typst
// No bibliography declaration - depends on main.typ
= Introduction
Some text with citations @key.
```

With `context.inherit = true` (the default), snacks-bibtex will:

1. First check if the current file has explicit bibliography context (e.g., `\addbibresource{}` or `#bibliography()`)
2. If not found, search for potential main files that include the current file via `\input{}`, `\include{}`, `\subfile{}`, `#include`, etc.
3. If a main file is found with bibliography context, inherit those bibliography files
4. If no inheritance is possible, fall back to `context.fallback` behavior

**Configuration:**

```lua
require("snacks-bibtex").setup({
  context = {
    enabled = true,    -- Enable context awareness
    inherit = true,    -- Enable context inheritance (default: true)
    depth = 1,         -- Directory depth for parent search (default: 1, 0=current only, nil=unlimited)
    max_files = 100,   -- Max files to check per directory (default: 100)
    fallback = true,   -- Fall back if no context or inheritance found
  },
})

-- Disable context inheritance (strict: only direct context):
require("snacks-bibtex").setup({
  context = {
    enabled = true,
    inherit = false,  -- Sub-files must have their own context
    fallback = false,
  },
})

-- Search deeper for parent files (e.g., deeply nested sub-files):
require("snacks-bibtex").setup({
  context = {
    enabled = true,
    inherit = true,
    depth = 2,        -- Search up to 2 directory levels for parent files
  },
})
```

**Supported inclusion patterns:**

**LaTeX:**

- `\input{file}` or `\input{file.tex}`
- `\include{file}` or `\include{file.tex}`
- `\subfile{file}` or `\subfile{file.tex}` (subfiles package)
- `\subfileinclude{file}` (subfiles package)

**Typst:**

- `#include "file.typ"` or `#include 'file.typ'`

**Notes:**

- Context inheritance supports LaTeX and Typst multi-file projects
- The `context.depth` setting controls how many directory levels up to search for parent files
  - `depth = 0`: searches only current directory
  - `depth = 1`: searches current and parent directory (default)
  - `depth = 2`: searches current, parent, and grandparent directories
  - `depth = nil`: unlimited search (not recommended - may impact performance)
  - Negative values are treated as 0
- The `context.max_files` setting limits the number of files checked per directory (default: 100)
  - This prevents performance issues in directories with many files
  - Increase if you have large projects with many parent files
- Main file detection is based on finding inclusion commands that reference the current file
- When context is inherited, `global_files` are still ignored (same as direct context)

### Sorting and frecency

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

If the stored history file contains timestamps that appear to come from the future (for example after the system clock moves backwards), snacks-bibtex warns once during the next session and ignores the negative age so frecency ordering remains stable.

### Parser robustness

The parser keeps track of brace balance with a net counter and honors escaped quotes, allowing it to process nested fields and
quoted values reliably. Author/editor names are split only on the literal lowercase ` and ` separator at brace depth zero, so
capitalized words that contain "And" stay intact while still following BibTeX's requirements.

**Quoted string unescaping:**

By default (`parser_unescape_basic = true`), the parser unescapes `\"` and `\\` sequences inside quoted field values:

- `\"` becomes `"` (literal quote)
- `\\` becomes `\` (literal backslash)

This means a BibTeX field like `title = "Say \"Hello\""` will be parsed as `Say "Hello"` rather than the raw `Say \"Hello\"`. LaTeX accent commands like `\"a` (ä) are preserved for later conversion by the display layer.

Set `parser_unescape_basic = false` to disable this behavior and keep quoted strings in their raw form.

### BibTeX file insertion behavior

When you open the picker from a `.bib` file, snacks-bibtex changes its default behavior to help you copy entries between bibliography files:

- **`bib_file_insert = "entry"`** (default): `<CR>` inserts the full BibTeX entry instead of just the key
- **`bib_file_insert = "key"`**: `<CR>` always inserts the key, even in `.bib` files

Regardless of this setting, you can always use:

- `<C-e>` to insert the full entry (with duplicate warnings)
- `<C-k>` to insert just the key

**Duplicate detection:**

When inserting entries into a `.bib` file, snacks-bibtex warns you about potential duplicates:

| Option | Default | Description |
|--------|---------|-------------|
| `warn_on_duplicate_entry` | `true` | Warn when the exact entry text already exists |
| `warn_on_duplicate_key` | `true` | Warn when the citation key already exists (different entry) |
| `duplicate_normalization_mode` | `"whitespace"` | How to compare entries for duplicates |

The `duplicate_normalization_mode` setting controls how entry text is compared:

- `"whitespace"` (default): Collapse all whitespace (spaces, newlines, tabs) to single spaces before comparing. This detects duplicates even when formatting differs.
- `"none"`: Compare raw text exactly. Only entries with identical formatting are flagged as duplicates.

Warnings are shown via `vim.notify` but insertion proceeds anyway—resolving duplicates is the user's responsibility.

```lua
-- Disable duplicate warnings
require("snacks-bibtex").setup({
  warn_on_duplicate_key = false,
  warn_on_duplicate_entry = false,
})

-- Always insert keys, even from .bib files
require("snacks-bibtex").setup({
  bib_file_insert = "key",
})
```

## 📋 Citation Commands

Pressing `<C-c>` opens a dedicated picker with all enabled citation templates. Each row shows the command, required packages (if any), description, and a rendered sample for the highlighted entry so you can confirm the output before inserting. By default the following commands are active:

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

All other BibTeX, natbib, and BibLaTeX `\cite*` variants ship with the plugin but are disabled by default to keep the picker concise.

### Enable more commands

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

Use `require("snacks-bibtex.config").sanitize_identifier("My Custom Command")` to generate stable IDs for custom commands or
formats when you need to reference them from mappings or defaults.

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

### Quick command shortcuts

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

### Command picker display

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
Each row renders the enabled columns inline together with a sample citation snippet so you can see what will be inserted before confirming.

The command picker preview pane renders the highlighted command's output for the current entry so you can verify the exact cite string before inserting.
Press `<CR>` to apply the highlighted command; snacks-bibtex overrides Snacks' default confirm action so the picker always writes back into the buffer where you launched it.
All bundled templates render canonical snippets such as `\cite{key}` without extra whitespace inside the braces so inserted commands follow common LaTeX style guides out of the box.

### Bundled command catalog

The plugin ships ready-to-enable templates for every `\cite`-family command provided by BibTeX, natbib, and BibLaTeX, plus Typst citation formats. Commands are grouped below for convenience:

- **BibTeX**: `\cite`, `\cite*`, `\nocite`.
- **natbib**: `\citet`, `\citet*`, `\Citet`, `\citep`, `\citep*`, `\Citep`, `\citealt`, `\citealt*`, `\Citealt`, `\citealp`, `\citealp*`, `\Citealp`, `\citeauthor`, `\citeauthor*`, `\citeyear`, `\citeyear*`, `\citeyearpar`, `\cites`.
- **BibLaTeX single-entry**: `\cite`, `\cite*`, `\Cite`, `\Cite*`, `\parencite`, `\parencite*`, `\Parencite`, `\Parencite*`, `\footcite`, `\footcite*`, `\Footcite`, `\Footcite*`, `\footcitetext`, `\footfullcite`, `\textcite`, `\textcite*`, `\Textcite`, `\Textcite*`, `\smartcite`, `\smartcite*`, `\Smartcite`, `\Smartcite*`, `\autocite`, `\autocite*`, `\Autocite`, `\Autocite*`, `\supercite`, `\Supercite`, `\fullcite`, `\nocite`, `\citeauthor`, `\citeauthor*`, `\Citeauthor`, `\Citeauthor*`, `\citetitle`, `\citetitle*`, `\Citetitle`, `\Citetitle*`, `\citeyear`, `\citeyear*`, `\citeurl`, `\citeurldate`, `\citedate`, `\citedate*`, `\Citedate`, `\Citedate*`, `\volcite`, `\pvolcite`, `\fvolcite`, `\svolcite`.
- **BibLaTeX multi-entry**: `\cites`, `\Cites`, `\parencites`, `\Parencites`, `\footcites`, `\Footcites`, `\textcites`, `\Textcites`, `\smartcites`, `\Smartcites`, `\autocites`, `\Autocites`, `\supercites`, `\Supercites`, `\nocites`, `\fullcites`, `\footfullcites`, `\volcites`, `\pvolcites`, `\fvolcites`, `\svolcites`.
- **Typst**: `@key`, `@key[supplement]`.

## 🎨 Citation Formats

`<C-s>` and `<C-r>` insert ready-made textual reference templates. `<C-y>` opens a picker listing every enabled format with descriptive labels and per-entry samples.
Press `<CR>` to apply the highlighted format—just like the command picker, the confirm action inserts into the originating buffer rather than attempting to jump to a source file. Both `<C-c>` and `<C-y>` reuse the same insertion helper as the main `<CR>` action so these pickers always write back into the buffer where you launched them.
APA 7 (in-text and reference), Harvard (in-text and reference), and Oxford (reference) ship enabled by default so you can compare them immediately.

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

### Template placeholders

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
- Wrap placeholders in triple braces (e.g. `{{{key}}}`) to automatically surround the resolved value with `{}` while trimming stray whitespace.

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

## 📄 License

[MIT](./LICENSE)

## 🙏 Acknowledgments

- [folke/snacks.nvim](https://github.com/folke/snacks.nvim) – The excellent picker framework that powers this plugin
- [lervag/vimtex](https://github.com/lervag/vimtex) – Comprehensive LaTeX support for Vim/Neovim
- [nvim-telescope/telescope-bibtex.nvim](https://github.com/nvim-telescope/telescope-bibtex.nvim) – Inspiration for BibTeX integration patterns
- The BibTeX and LaTeX communities for maintaining robust citation standards
