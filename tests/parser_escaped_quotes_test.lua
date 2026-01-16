#!/usr/bin/env lua
--- Test cases for parser escaped quote handling and unescape functionality
---
--- Run with: nvim --headless -u NONE -c "luafile tests/parser_escaped_quotes_test.lua" -c "qa"

local function setup_path()
  package.path = package.path .. ";lua/?.lua;lua/?/init.lua"
end

local function write_temp_bib(content)
  local tmpfile = os.tmpname() .. ".bib"
  local f = io.open(tmpfile, "w")
  if not f then
    return nil
  end
  f:write(content)
  f:close()
  return tmpfile
end

local function test_parser_unescape()
  setup_path()
  local parser = require("snacks-bibtex.parser")

  local test_cases = {
    {
      name = "simple quoted string (unescape=true)",
      input = '@article{test,\n  title = "Hello World"\n}\n',
      unescape = true,
      expected_title = "Hello World",
    },
    {
      name = "escaped quote inside string (unescape=true)",
      input = '@article{test,\n  title = "Say \\"Hello\\""\n}\n',
      unescape = true,
      expected_title = 'Say "Hello"',
    },
    {
      name = "double backslash before quote (unescape=true)",
      input = '@article{test,\n  title = "Path C:\\\\",\n  author = "Smith"\n}\n',
      unescape = true,
      expected_title = "Path C:\\",
      expected_author = "Smith",
    },
    {
      name = "triple backslash before quote (unescape=true)",
      input = '@article{test,\n  title = "Say \\\\\\"Hi\\\\\\""\n}\n',
      unescape = true,
      expected_title = 'Say \\"Hi\\"',
    },
    {
      name = "backslash at end without quote (unescape=true)",
      input = '@article{test,\n  title = "Test\\\\value"\n}\n',
      unescape = true,
      expected_title = "Test\\value",
    },
    {
      name = "LaTeX accent in quoted string gets unescaped (unescape=true)",
      input = '@article{test,\n  title = "G\\"oteborg"\n}\n',
      unescape = true,
      expected_title = 'G"oteborg',
    },
    {
      name = "LaTeX accent in braces preserved (unescape=true)",
      input = '@article{test,\n  title = {G{\\"o}teborg}\n}\n',
      unescape = true,
      expected_title = 'G{\\"o}teborg',
    },
    {
      name = "escaped quote inside string (unescape=false)",
      input = '@article{test,\n  title = "Say \\"Hello\\""\n}\n',
      unescape = false,
      expected_title = 'Say \\"Hello\\"',
    },
    {
      name = "double backslash (unescape=false)",
      input = '@article{test,\n  title = "Path C:\\\\"\n}\n',
      unescape = false,
      expected_title = "Path C:\\\\",
    },
  }

  local passed = 0
  local failed = 0

  for _, tc in ipairs(test_cases) do
    local tmpfile = write_temp_bib(tc.input)
    if not tmpfile then
      print(string.format("SKIP: %s - could not create temp file", tc.name))
      goto continue
    end

    local cfg = {
      files = { tmpfile },
      global_files = {},
      parser_unescape_basic = tc.unescape,
      context = { enabled = false },
    }

    local entries = parser.load_entries(cfg)
    os.remove(tmpfile)

    local entry = entries and entries[1]
    local success = true
    local msg = ""

    if not entry then
      success = false
      msg = "no entry parsed"
    else
      if tc.expected_title then
        local actual = entry.fields and entry.fields.title or ""
        if actual ~= tc.expected_title then
          success = false
          msg = string.format("title: expected %q, got %q", tc.expected_title, actual)
        end
      end
      if tc.expected_author and success then
        local actual = entry.fields and entry.fields.author or ""
        if actual ~= tc.expected_author then
          success = false
          msg = string.format("author: expected %q, got %q", tc.expected_author, actual)
        end
      end
    end

    if success then
      passed = passed + 1
      print(string.format("PASS: %s", tc.name))
    else
      failed = failed + 1
      print(string.format("FAIL: %s - %s", tc.name, msg))
    end

    ::continue::
  end

  print(string.format("\nResults: %d passed, %d failed", passed, failed))
  return failed == 0
end

local success = test_parser_unescape()
if not success then
  os.exit(1)
end
