#!/usr/bin/env lua
--- Test cases for per-filetype insert mode resolution
---
--- Run with: nvim --headless -u NONE -c "luafile tests/insert_mode_resolution_test.lua" -c "qa"

local function setup_path()
  package.path = package.path .. ";lua/?.lua;lua/?/init.lua"
end

local function resolve_insert_mode(filetype, cfg)
  if filetype == "bib" and cfg.bib_file_insert == "entry" then
    return "bib_entry"
  end
  local insert_mode_by_ft = cfg.insert_mode_by_filetype or {}
  local mode = insert_mode_by_ft[filetype] or cfg.default_insert_mode or "key"
  return mode
end

local function test_insert_mode_resolution()
  setup_path()

  local test_cases = {
    {
      name = "default mode is 'key' when nothing configured",
      filetype = "markdown",
      cfg = {},
      expected = "key",
    },
    {
      name = "default_insert_mode is respected",
      filetype = "markdown",
      cfg = { default_insert_mode = "format" },
      expected = "format",
    },
    {
      name = "filetype override takes precedence over default",
      filetype = "markdown",
      cfg = { default_insert_mode = "key", insert_mode_by_filetype = { markdown = "format" } },
      expected = "format",
    },
    {
      name = "unspecified filetype falls back to default",
      filetype = "org",
      cfg = { default_insert_mode = "format", insert_mode_by_filetype = { markdown = "key" } },
      expected = "format",
    },
    {
      name = "tex filetype can be set to key",
      filetype = "tex",
      cfg = { default_insert_mode = "format", insert_mode_by_filetype = { tex = "key" } },
      expected = "key",
    },
    {
      name = "typst filetype can be set to key",
      filetype = "typst",
      cfg = { default_insert_mode = "format", insert_mode_by_filetype = { typst = "key" } },
      expected = "key",
    },
    {
      name = "bib file with bib_file_insert=entry returns bib_entry",
      filetype = "bib",
      cfg = { bib_file_insert = "entry" },
      expected = "bib_entry",
    },
    {
      name = "bib file with bib_file_insert=key uses normal resolution",
      filetype = "bib",
      cfg = { bib_file_insert = "key", default_insert_mode = "format" },
      expected = "format",
    },
    {
      name = "insert_mode_by_filetype.bib is used when bib_file_insert is not entry",
      filetype = "bib",
      cfg = { bib_file_insert = "key", insert_mode_by_filetype = { bib = "key" } },
      expected = "key",
    },
    {
      name = "entry mode can be set for non-bib filetypes",
      filetype = "markdown",
      cfg = { insert_mode_by_filetype = { markdown = "entry" } },
      expected = "entry",
    },
    {
      name = "empty insert_mode_by_filetype table falls through to default",
      filetype = "rst",
      cfg = { default_insert_mode = "format", insert_mode_by_filetype = {} },
      expected = "format",
    },
  }

  local passed = 0
  local failed = 0

  for _, tc in ipairs(test_cases) do
    local result = resolve_insert_mode(tc.filetype, tc.cfg)
    local success = result == tc.expected

    if success then
      passed = passed + 1
      print(string.format("PASS: %s", tc.name))
    else
      failed = failed + 1
      print(string.format("FAIL: %s - expected %q, got %q", tc.name, tc.expected, result))
    end
  end

  print(string.format("\nResults: %d passed, %d failed", passed, failed))
  return failed == 0
end

local success = test_insert_mode_resolution()
if not success then
  os.exit(1)
end
