# Agent Guidelines

These instructions apply to the entire repository.

## General workflow
- Always read this file before making changes. Check for additional scoped instructions in subdirectories.
- Keep all code comments and documentation in **English**.
- Whenever you add, remove, or modify a function, update both in-code documentation (e.g., EmmyLua annotations or comments) **and** external documentation (such as the README or module docs) to describe the change.

## Development practices
- Prefer small, focused commits that address a single concern.
- Ensure Lua code remains idiomatic and formatted. If `stylua` is available, run `stylua lua`. Otherwise, ensure formatting manually.
- When introducing configuration options, document them in `README.md`.

## Verification
- After changes, run `nvim --headless -u NONE -c "lua require('snacks-bibtex').setup({})" -c qa` when Neovim is available.
- If Neovim is not installed, explicitly note this limitation in the final report.

## Pull requests
- Summarise functional changes and list affected modules in the PR description.
- Cite tests or commands executed during verification.

