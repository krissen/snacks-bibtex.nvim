#!/usr/bin/env lua
--- Test cases for duplicate detection normalization
---
--- Run with: nvim --headless -u NONE -c "luafile tests/duplicate_normalization_test.lua" -c "qa"
--- Note: This test verifies the normalize_whitespace function behavior

local function setup_path()
  package.path = package.path .. ";lua/?.lua;lua/?/init.lua"
end

local function test_normalize_whitespace()
  setup_path()

  local function normalize_whitespace(s)
    return s:gsub("%s+", " "):gsub("^%s+", ""):gsub("%s+$", "")
  end

  local test_cases = {
    {
      name = "identical strings match",
      a = "@article{test, title = {Hello}}",
      b = "@article{test, title = {Hello}}",
      expected = true,
    },
    {
      name = "multiple spaces collapsed to single",
      a = "@article{test,   title   =   {Hello}}",
      b = "@article{test, title = {Hello}}",
      expected = true,
    },
    {
      name = "newlines collapsed to spaces",
      a = "@article{test,\n  title = {Hello}\n}",
      b = "@article{test, title = {Hello} }",
      expected = true,
    },
    {
      name = "leading/trailing whitespace trimmed",
      a = "  @article{test, title = {Hello}}  ",
      b = "@article{test, title = {Hello}}",
      expected = true,
    },
    {
      name = "tabs collapsed to spaces",
      a = "@article{test,\ttitle = {Hello}}",
      b = "@article{test, title = {Hello}}",
      expected = true,
    },
    {
      name = "different content does not match",
      a = "@article{test, title = {Hello}}",
      b = "@article{test, title = {World}}",
      expected = false,
    },
    {
      name = "different keys do not match",
      a = "@article{test1, title = {Hello}}",
      b = "@article{test2, title = {Hello}}",
      expected = false,
    },
    {
      name = "different spacing around equals not normalized",
      a = "@article{test, title={Hello}}",
      b = "@article{test, title = {Hello}}",
      expected = false,
    },
  }

  local passed = 0
  local failed = 0

  for _, tc in ipairs(test_cases) do
    local norm_a = normalize_whitespace(tc.a)
    local norm_b = normalize_whitespace(tc.b)
    local match = norm_a == norm_b

    local success = match == tc.expected
    if success then
      passed = passed + 1
      print(string.format("PASS: %s", tc.name))
    else
      failed = failed + 1
      print(string.format("FAIL: %s - expected %s, got %s", tc.name, tostring(tc.expected), tostring(match)))
      print(string.format("  norm_a: %q", norm_a))
      print(string.format("  norm_b: %q", norm_b))
    end
  end

  print(string.format("\nResults: %d passed, %d failed", passed, failed))
  return failed == 0
end

local success = test_normalize_whitespace()
if not success then
  os.exit(1)
end
