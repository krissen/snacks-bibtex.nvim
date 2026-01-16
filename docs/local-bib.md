# Local Bibliography Target

The `local_bib` feature lets you automatically copy BibTeX entries from a master bibliography to a local project file when inserting citations. This is useful for workflows where you maintain a central reference library but want each project to have its own self-contained `.bib` file.

## Quick Start

```lua
require("snacks-bibtex").setup({
  files_exclude = { "refs.bib" },  -- exclude local file from sources
  local_bib = {
    enabled = true,
    target = "refs.bib",
    auto_add = true,
    create_if_missing = true,
  },
})
```

With this setup:
1. The picker shows entries from your master bibliography only
2. When you insert a citation (`<CR>`), the entry is automatically copied to `refs.bib`
3. Source status indicators show which entries have been added locally

## Configuration

### Basic Options

| Option | Default | Description |
|--------|---------|-------------|
| `enabled` | `false` | Enable the local bib feature |
| `target` | `nil` | Explicit target file path (relative to cwd or absolute) |
| `targets` | `nil` | Per-directory targets: `{ ["/path/to/project"] = "refs.bib" }` |
| `patterns` | `{"local.bib", "references.bib"}` | Auto-detect target by matching existing files |
| `auto_add` | `false` | Copy entry to target on every insert via `<CR>` |
| `notify_on_add` | `true` | Show notification when entry is copied |
| `create_if_missing` | `false` | Create target file if it doesn't exist |
| `duplicate_check` | `true` | Skip copy if key already exists in target |

### Shortcuts

**Boolean shortcut:** `local_bib = true` enables with all defaults.

**Implicit enabled:** Setting `target`, `targets`, or `auto_add` automatically sets `enabled = true`:

```lua
-- These are equivalent:
local_bib = { target = "refs.bib" }
local_bib = { enabled = true, target = "refs.bib" }
```

### Target Resolution

The target file is resolved in this order:

1. **`targets[cwd]`** — Per-directory explicit mapping
2. **`target`** — Global explicit target
3. **`patterns`** — First matching existing file in cwd

**Important:** `create_if_missing` only works with explicit `target` or `targets`. Pattern-based detection requires the file to already exist.

### Example Configurations

**Simple setup with auto-add:**

```lua
local_bib = {
  target = "local.bib",
  auto_add = true,
  create_if_missing = true,
}
```

**Per-project targets:**

```lua
local_bib = {
  targets = {
    ["/home/user/thesis"] = "thesis-refs.bib",
    ["/home/user/papers/2024"] = "paper-refs.bib",
  },
  auto_add = false,  -- use <C-l> to copy manually
}
```

**Pattern-based detection:**

```lua
local_bib = {
  enabled = true,
  patterns = { "local.bib", "refs.bib", "bibliography.bib" },
  auto_add = true,
}
```

## Keybindings

| Key | Action |
|-----|--------|
| `<C-l>` | Copy to local bib + insert citation |
| `<M-l>` | Copy to local bib only (no insertion) |

Both keybindings are available when `local_bib.enabled = true`.

When `auto_add = false`, use `<C-l>` to copy and cite, or `<M-l>` to just build up your local bib without inserting citations yet. When `auto_add = true`, entries are copied automatically on `<CR>`.

### Duplicate Handling

When `duplicate_check = true` (default):
- If the key already exists in the target file, the entry is **not** copied
- A notification is shown: "Entry 'key' already exists in target.bib"
- The citation is still inserted into your document

This prevents accidental overwrites while allowing you to cite entries multiple times.

## Excluding Files from Sources

Use `files_exclude` to prevent the local target from appearing as a source:

```lua
require("snacks-bibtex").setup({
  files_exclude = { "local.bib", "refs.bib" },
  local_bib = { ... },
})
```

**Pattern matching:** Patterns match against both filename and relative path:
- `"local.bib"` — matches any file named `local.bib`
- `"**/generated/*.bib"` — matches `.bib` files in any `generated` directory

## Source Status Indicators

Indicators help you understand where entries come from and whether they've been copied locally.

### When Both Local and Global Files Are Visible

| Indicator | Meaning |
|-----------|---------|
| `[L]` | Entry exists only in local file(s) |
| `[G]` | Entry exists only in global file(s) |
| `[L=G]` | Local entry, identical copy exists in global |
| `[G=L]` | Global entry, identical copy exists in local |
| `[L≠G]` | Local entry, differs from global version |
| `[G≠L]` | Global entry, differs from local version |

The **first letter** indicates which source the current row comes from. When an entry exists in both sources, you'll see two rows.

### When Local Target Is Excluded (Common Workflow)

If your local bib target is excluded via `files_exclude`:

| Indicator | Meaning |
|-----------|---------|
| `[+L]` | Entry has been added to local (identical to global) |
| `[*L]` | Entry exists in local but differs from global |

### Classification Logic

- Files listed in `global_files` are classified as **global**
- All other files (including auto-detected project files) are classified as **local**

### Comparison Method

Entries are compared using whitespace-normalized content:
- All whitespace (spaces, tabs, newlines) is collapsed to single spaces
- Leading/trailing whitespace is trimmed
- This allows detecting identical entries even with different formatting

### Disabling Indicators

```lua
display = {
  show_source_status = false,
}
```

Indicators are automatically hidden when all entries come from a single source (no meaningful information to show).

## Health Check

Run `:checkhealth snacks-bibtex` to verify your local_bib configuration:

```
snacks-bibtex: ~
- OK snacks.nvim: found
- OK config module: loaded
- OK local_bib: enabled
- OK target: /path/to/project/refs.bib (via target)
- OK create_if_missing: compatible (explicit target configured)
- INFO auto_add: enabled (entries copied automatically on insert)
- OK files_exclude: 1 pattern(s) configured
    - refs.bib
```

The health check validates:
- Target resolution and file existence
- `create_if_missing` compatibility (requires explicit target)
- `auto_add` status
- `files_exclude` patterns

## Troubleshooting

### Entry not being copied

1. Check that `local_bib.enabled = true`
2. Verify target resolution: `:checkhealth snacks-bibtex`
3. If using patterns, ensure the target file exists
4. Check if `duplicate_check` is blocking (key already exists)

### No source indicators showing

Indicators only appear when:
- There are entries from both local and global sources, OR
- Local target is excluded and contains entries

### Target file not created

`create_if_missing` requires explicit `target` or `targets` configuration. Pattern-based detection cannot create files.

### Wrong file being used as target

Check resolution order: `targets[cwd]` → `target` → `patterns`. Use `:checkhealth snacks-bibtex` to see which source is being used.
