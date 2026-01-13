#!/usr/bin/env lua
--- Test cases for parser escaped quote handling (backslash parity)
---
--- Run with: nvim --headless -u NONE -c "luafile tests/parser_escaped_quotes_test.lua" -c "qa"
--- Or directly: lua tests/parser_escaped_quotes_test.lua (requires snacks-bibtex in lua path)

local function test_parse_value()
  local ok, parser = pcall(require, "snacks-bibtex.parser")
  if not ok then
    package.path = package.path .. ";lua/?.lua;lua/?/init.lua"
    parser = require("snacks-bibtex.parser")
  end

  local test_cases = {
    {
      name = "simple quoted string",
      input = '@article{test, title = "Hello World"}',
      expected_title = "Hello World",
    },
    {
      name = "escaped quote inside string",
      input = '@article{test, title = "Say \\"Hello\\""}',
      expected_title = 'Say "Hello"',
    },
    {
      name = "double backslash before quote (terminates string)",
      input = '@article{test, title = "Path C:\\\\", author = "Smith"}',
      expected_title = "Path C:\\",
      expected_author = "Smith",
    },
    {
      name = "triple backslash before quote (escaped quote)",
      input = '@article{test, title = "Say \\\\\\"Hi\\\\\\""}',
      expected_title = 'Say \\"Hi\\"',
    },
    {
      name = "backslash at end without quote",
      input = '@article{test, title = "Test\\\\value"}',
      expected_title = "Test\\value",
    },
  }

  local passed = 0
  local failed = 0

  for _, tc in ipairs(test_cases) do
    local entries = parser.parse(tc.input)
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
  end

  print(string.format("\nResults: %d passed, %d failed", passed, failed))
  return failed == 0
end

local success = test_parse_value()
if not success then
  os.exit(1)
end
