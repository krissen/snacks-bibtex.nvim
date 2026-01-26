# Context-Aware Bibliography Detection

When `context.enabled = true`, snacks-bibtex looks for context lines in your currently opened file that specify which bibliography file(s) to use. This is useful for multi-project workflows where different documents reference different bibliography files.

By default, `context.enabled = false`, meaning the plugin always searches your project directory for `.bib` files and includes `global_files`.

## How It Works

- When context is detected (e.g., `bibliography:` in YAML frontmatter or `\addbibresource{}` in LaTeX), **only** those files are used
- Both `global_files` and the normal project directory search are ignored when context is found
- If no context is detected and `context.fallback = true` (the default), the plugin falls back to searching your project directory
- If no context is detected and `context.fallback = false`, no entries will be shown

## Configuration Options

| Option | Default | Description |
|--------|---------|-------------|
| `enabled` | `false` | Enable context-aware detection |
| `fallback` | `true` | Fall back to project search if no context found |
| `inherit` | `true` | Inherit context from main files in multi-file projects |
| `depth` | `1` | Directory depth for searching parent files (0=current only, nil=unlimited) |
| `max_files` | `100` | Max files to check per directory when searching |

**Boolean shortcut:** `context = true` is equivalent to `{ enabled = true, fallback = true, inherit = true, depth = 1 }`.

## Supported Filetypes and Patterns

| Filetype | Context Pattern | Example |
|----------|----------------|---------|
| `pandoc`, `markdown`, `md`, `rmd` | YAML frontmatter `bibliography:` | `bibliography: refs.bib` or array format |
| `tex`, `plaintex`, `latex` | `\bibliography{file}` | `\bibliography{references}` (extension added automatically) |
| `tex`, `plaintex`, `latex` | `\addbibresource{file}` | `\addbibresource{references.bib}` |
| `typst` | `#bibliography("file")` | `#bibliography("references.bib")` or `#bibliography("references.yml")` |
| `typst` | `#import "file.typ": refs` | Detects bibliography from imported `.typ` files |

## Examples

### Markdown with YAML Frontmatter

```markdown
---
title: My Paper
bibliography: references.bib
---

# Introduction
Citations go here [@key].
```

### LaTeX with BibLaTeX

```latex
\documentclass{article}
\usepackage{biblatex}
\addbibresource{references.bib}
\begin{document}
Citations go here \cite{key}.
\end{document}
```

### Typst

```typst
#bibliography("references.bib")

= Introduction
Citations go here @key.
```

### Typst with Imported References

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

## Configuration Examples

**Basic context awareness:**

```lua
require("snacks-bibtex").setup({
  context = {
    enabled = true,
    fallback = true,
  },
})
```

**Strict mode (require explicit bibliography declaration):**

```lua
require("snacks-bibtex").setup({
  context = {
    enabled = true,
    fallback = false,
  },
})
```

**Per-invocation control:**

```lua
-- Enable for this call only
require("snacks-bibtex").bibtex({ context = { enabled = true } })

-- Strict mode for this call
require("snacks-bibtex").bibtex({ context = { enabled = true, fallback = false } })
```

## Behavior Summary

| `context.enabled` | `context.fallback` | Context found? | Result |
|-------------------|-------------------|----------------|--------|
| `true` | `true` | Yes | Use context files only |
| `true` | `true` | No | Fall back to project search + `global_files` |
| `true` | `false` | Yes | Use context files only |
| `true` | `false` | No | Show no entries |
| `false` | any | any | Always use project search + `global_files` |

## Context Inheritance for Multi-File Projects

When working with multi-file LaTeX or Typst projects, sub-files often don't explicitly mention the bibliography but depend on a main file that does.

### How Inheritance Works

With `context.inherit = true` (the default), snacks-bibtex will:

1. First check if the current file has explicit bibliography context
2. If not found, search for potential main files that include the current file via `\input{}`, `\include{}`, `\subfile{}`, `#include`, etc.
3. If a main file is found with bibliography context, inherit those bibliography files
4. If no inheritance is possible, fall back to `context.fallback` behavior

### LaTeX Multi-File Example

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

### Typst Multi-File Example

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

### Inheritance Configuration

```lua
require("snacks-bibtex").setup({
  context = {
    enabled = true,
    inherit = true,     -- Enable inheritance (default)
    depth = 1,          -- Search depth for parent files
    max_files = 100,    -- Max files to check per directory
    fallback = true,
  },
})
```

**Disable inheritance (strict direct context only):**

```lua
context = {
  enabled = true,
  inherit = false,
  fallback = false,
}
```

**Search deeper for parent files:**

```lua
context = {
  enabled = true,
  inherit = true,
  depth = 2,  -- Current, parent, and grandparent directories
}
```

### Supported Inclusion Patterns

**LaTeX:**
- `\input{file}` or `\input{file.tex}`
- `\include{file}` or `\include{file.tex}`
- `\subfile{file}` or `\subfile{file.tex}` (subfiles package)
- `\subfileinclude{file}` (subfiles package)

**Typst:**
- `#include "file.typ"` or `#include 'file.typ'`

### Depth Setting Details

| Value | Behavior |
|-------|----------|
| `0` | Search only current directory |
| `1` | Search current and parent directory (default) |
| `2` | Search current, parent, and grandparent directories |
| `nil` | Unlimited search (not recommended - may impact performance) |
| negative | Treated as 0 |

### Notes

- When context is inherited, `global_files` are still ignored (same as direct context)
- Main file detection is based on finding inclusion commands that reference the current file
- The `max_files` setting prevents performance issues in directories with many files
