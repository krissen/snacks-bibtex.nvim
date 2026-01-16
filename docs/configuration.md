# Configuration Reference

Complete reference for all snacks-bibtex configuration options.

## Full Configuration Example

```lua
require("snacks-bibtex").setup({
  -- File discovery
  depth = 1,                        -- recursion depth for project search (nil = unlimited)
  files = nil,                      -- explicit list of project-local bib files
  global_files = {},                -- global bib files (outside project)
  files_exclude = {},               -- patterns to exclude (e.g., { "local.bib" })

  -- Local bibliography target
  local_bib = {
    enabled = false,
    target = nil,                   -- explicit target path
    targets = {},                   -- per-directory: { ["/path"] = "refs.bib" }
    patterns = { "local.bib", "references.bib" },
    auto_add = false,
    notify_on_add = true,
    create_if_missing = false,
    duplicate_check = true,
  },

  -- Context-aware detection
  context = {
    enabled = false,
    fallback = true,
    inherit = true,
    depth = 1,
    max_files = 100,
  },

  -- Search and matching
  search_fields = { "author", "year", "title", "journal", "journaltitle", "editor" },
  match_priority = { "author", "year", "title" },

  -- Insertion formats
  format = "%s",                    -- key insertion format
  preview_format = "{{authors.reference}} ({{year}}) — {{title}}",
  citation_format = "{{apa.in_text}}",
  default_citation_format = "apa7_in_text",
  citation_format_defaults = {
    in_text = "apa7_in_text",
    reference = "apa7_reference",
  },

  -- Display options
  display = {
    show_key = true,
    show_preview = true,
    key_separator = " — ",
    preview_fields = nil,
    preview_fields_separator = " — ",
    show_source_status = true,
  },

  -- Sorting
  sort = {
    { field = "frecency", direction = "desc" },
    { field = "author", direction = "asc" },
    { field = "year", direction = "asc" },
    { field = "source", direction = "asc" },
  },
  match_sort = nil,                 -- defaults to score + match_priority + sort

  -- Insertion behavior
  locale = "en",
  bib_file_insert = "entry",        -- "entry" or "key"
  default_insert_mode = "key",      -- "key", "format", or "entry"
  insert_mode_by_filetype = {},     -- { markdown = "format", tex = "key" }

  -- Duplicate handling
  warn_on_duplicate_key = true,
  warn_on_duplicate_entry = true,
  duplicate_normalization_mode = "whitespace",  -- "none" or "whitespace"

  -- Parser
  parser_unescape_basic = true,

  -- Citation command picker
  citation_command_picker = {
    title = "Citation commands",
    packages = true,
    description = true,
    template = false,
  },

  -- Keymaps
  mappings = {},

  -- Commands and formats (see docs/citation-commands.md)
  citation_commands = {},
  citation_formats = {},
})
```

## Option Reference

### File Discovery

| Option | Type | Default | Description |
|--------|------|---------|-------------|
| `depth` | `integer\|nil` | `1` | Directory recursion depth for local bib search |
| `files` | `string[]\|nil` | `nil` | Explicit list of project-local bib files |
| `global_files` | `string[]` | `{}` | Global bib files (always included unless context found) |
| `files_exclude` | `string[]` | `{}` | Glob patterns to exclude files |

### Local Bibliography Target

| Option | Type | Default | Description |
|--------|------|---------|-------------|
| `local_bib.enabled` | `boolean` | `false` | Enable local bib feature |
| `local_bib.target` | `string\|nil` | `nil` | Explicit target path |
| `local_bib.targets` | `table` | `{}` | Per-directory targets |
| `local_bib.patterns` | `string[]` | `{"local.bib", "references.bib"}` | Auto-detect patterns |
| `local_bib.auto_add` | `boolean` | `false` | Auto-copy on insert |
| `local_bib.notify_on_add` | `boolean` | `true` | Show notification |
| `local_bib.create_if_missing` | `boolean` | `false` | Create target file |
| `local_bib.duplicate_check` | `boolean` | `true` | Check for duplicates |

**Shortcut:** `local_bib = true` enables with defaults.

### Context Detection

| Option | Type | Default | Description |
|--------|------|---------|-------------|
| `context.enabled` | `boolean` | `false` | Enable context detection |
| `context.fallback` | `boolean` | `true` | Fall back to project search |
| `context.inherit` | `boolean` | `true` | Inherit from main files |
| `context.depth` | `integer\|nil` | `1` | Parent search depth |
| `context.max_files` | `integer` | `100` | Max files to check |

**Shortcut:** `context = true` enables with defaults.

### Display

| Option | Type | Default | Description |
|--------|------|---------|-------------|
| `display.show_key` | `boolean` | `true` | Show citation key |
| `display.show_preview` | `boolean` | `true` | Show formatted preview |
| `display.key_separator` | `string` | `" — "` | Separator between key and preview |
| `display.preview_fields` | `string[]\|nil` | `nil` | Custom preview fields (overrides preview_format) |
| `display.preview_fields_separator` | `string` | `" — "` | Separator between preview fields |
| `display.show_source_status` | `boolean` | `true` | Show [L]/[G] indicators |

### Sorting

| Option | Type | Default | Description |
|--------|------|---------|-------------|
| `sort` | `SortSpec[]` | frecency → author → year → source | Initial sort order |
| `match_sort` | `SortSpec[]\|nil` | `nil` | Sort during search (defaults to score + match_priority + sort) |

**Sort fields:** `score`, `match_priority`, `match_field`, `match_offset`, `frecency`, `frequency`, `recent`, `author`, `title`, `journal`, `year`, `key`, `type`, `label`, `text`, `file`, `source`

### Insertion Behavior

| Option | Type | Default | Description |
|--------|------|---------|-------------|
| `format` | `string` | `"%s"` | Key insertion format |
| `locale` | `string` | `"en"` | Preferred locale |
| `bib_file_insert` | `"entry"\|"key"` | `"entry"` | What to insert in .bib files |
| `default_insert_mode` | `"key"\|"format"\|"entry"` | `"key"` | Default for <CR> |
| `insert_mode_by_filetype` | `table` | `{}` | Per-filetype overrides |

### Duplicate Handling

| Option | Type | Default | Description |
|--------|------|---------|-------------|
| `warn_on_duplicate_key` | `boolean` | `true` | Warn if key exists |
| `warn_on_duplicate_entry` | `boolean` | `true` | Warn if entry exists |
| `duplicate_normalization_mode` | `"none"\|"whitespace"` | `"whitespace"` | Comparison method |

### Parser

| Option | Type | Default | Description |
|--------|------|---------|-------------|
| `parser_unescape_basic` | `boolean` | `true` | Unescape `\"` and `\\` in quoted strings |

## Default Keymaps

| Key | Action |
|-----|--------|
| `<CR>` | Insert citation (respects `insert_mode_by_filetype`) |
| `<C-e>` | Insert full BibTeX entry |
| `<C-k>` | Insert key only |
| `<C-a>` | Insert `\cite{key}` |
| `<C-p>` | Insert `\citep{key}` |
| `<C-t>` | Insert `\citet{key}` |
| `<C-c>` | Open citation command picker |
| `<C-s>` | Insert in-text citation format |
| `<C-r>` | Insert reference format |
| `<C-y>` | Open citation format picker |
| `<C-f>` | Open field picker |
| `<C-g>` | Jump to BibTeX source |
| `<C-l>` | Copy to local bib (when enabled) |

## Custom Mappings

```lua
mappings = {
  ["<C-a>"] = { kind = "citation_command", command = "\\autocite" },
  ["<C-s>"] = { kind = "citation_format", id = "apa7_in_text_sv" },
  ["<C-p>"] = false,  -- disable
  ["<M-f>"] = "insert_entry",  -- action name
}
```

## Health Check

Run `:checkhealth snacks-bibtex` to verify configuration.
