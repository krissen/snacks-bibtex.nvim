local uv = vim.uv or vim.loop

local M = {}

---@class SnacksBibtexEntry
---@field key string
---@field type string
---@field fields table<string, string>
---@field file string
---@field raw string
---@field order integer        # stable order based on appearance across all sources

local function read_file(path)
  local fd = uv.fs_open(path, "r", 438)
  if not fd then
    return nil, ("Could not open %s"):format(path)
  end
  local stat = uv.fs_fstat(fd)
  if not stat then
    uv.fs_close(fd)
    return nil, ("Could not stat %s"):format(path)
  end
  local data = uv.fs_read(fd, stat.size, 0)
  uv.fs_close(fd)
  if not data then
    return nil, ("Could not read %s"):format(path)
  end
  return data
end

local function count_braces(line)
  local open, close = 0, 0
  for c in line:gmatch("[{}]") do
    if c == "{" then
      open = open + 1
    else
      close = close + 1
    end
  end
  return open, close
end

local function parse_value(body, idx)
  local len = #body
  while idx <= len and body:sub(idx, idx):match("%s") do
    idx = idx + 1
  end
  if idx > len then
    return "", idx
  end
  local first = body:sub(idx, idx)
  if first == "{" then
    local depth = 0
    local j = idx
    while j <= len do
      local ch = body:sub(j, j)
      if ch == "{" then
        depth = depth + 1
      elseif ch == "}" then
        depth = depth - 1
        if depth == 0 then
          break
        end
      end
      j = j + 1
    end
    local value = body:sub(idx + 1, j - 1)
    return vim.trim(value), j + 1
  elseif first == '"' then
    local j = idx + 1
    while j <= len do
      local ch = body:sub(j, j)
      if ch == '"' and body:sub(j - 1, j - 1) ~= "\\" then
        break
      end
      j = j + 1
    end
    local value = body:sub(idx + 1, j - 1)
    return vim.trim(value), j + 1
  else
    local s, e = body:find("[^,%}]+", idx)
    if not s then
      return "", len + 1
    end
    local value = vim.trim(body:sub(s, e))
    return value, e + 1
  end
end

local function parse_fields(body)
  local fields = {}
  local idx = 1
  local len = #body
  while idx <= len do
    local _, next_idx, name = body:find("%s*([%w_%-]+)%s*=", idx)
    if not name then
      break
    end
    idx = next_idx + 1
    local value
    value, idx = parse_value(body, idx)
    if value ~= "" then
      fields[name:lower()] = value
    end
    while idx <= len and body:sub(idx, idx):match("[%s,]") do
      idx = idx + 1
    end
  end
  return fields
end

---@param text string
---@param path string
---@return SnacksBibtexEntry[]
local function parse_entries(text, path)
  local entries = {}
  local lines = vim.split(text, "\n", { plain = true })
  local current
  local brace_level = 0
  for _, line in ipairs(lines) do
    if not current then
      local entry_type, rest = line:match("^%s*@(%w+)%s*%{(.*)$")
      if entry_type then
        entry_type = entry_type:lower()
        if entry_type ~= "comment" and entry_type ~= "preamble" and entry_type ~= "string" then
          local key = rest:match("^%s*([^,%s]+)")
          if key then
            current = {
              type = entry_type,
              key = key,
              fields = {},
              file = path,
              lines = { line },
            }
            local open, close = count_braces(line)
            brace_level = open - close
          end
        end
      end
    else
      current.lines[#current.lines + 1] = line
      local open, close = count_braces(line)
      brace_level = brace_level + open - close
      if brace_level <= 0 then
        local raw = table.concat(current.lines, "\n")
        if not raw:match("\n$") then
          raw = raw .. "\n"
        end
        current.raw = raw
        local body = raw:match("@%w+%s*%b{}")
        if body then
          local inner = body:match("%b{}");
          if inner then
            inner = inner:sub(2, -2)
            inner = inner:gsub("^%s*[^,%s]+%s*,", "", 1)
            current.fields = parse_fields(inner)
          end
        end
        entries[#entries + 1] = {
          key = current.key,
          type = current.type,
          fields = current.fields,
          file = current.file,
          raw = current.raw,
        }
        current = nil
        brace_level = 0
      end
    end
  end
  return entries
end

---@param cfg SnacksBibtexConfig
---@return string[]
local function find_project_files(cfg)
  if cfg.files then
    return vim.deepcopy(cfg.files)
  end
  local cwd = (vim.uv and vim.uv.cwd()) or vim.loop.cwd()
  local opts = { path = cwd, type = "file" }
  if cfg.depth ~= nil then
    opts.depth = cfg.depth
  end
  local found = vim.fs.find(function(name, _)
    return name:lower():match("%.bib$") ~= nil
  end, opts)
  return found
end

---@param cfg SnacksBibtexConfig
---@return SnacksBibtexEntry[], string[]
function M.load_entries(cfg)
  local files = {}
  local seen = {} ---@type table<string, boolean>
  for _, path in ipairs(find_project_files(cfg)) do
    if not seen[path] then
      seen[path] = true
      files[#files + 1] = path
    end
  end
  for _, path in ipairs(cfg.global_files or {}) do
    path = vim.fs.normalize(path)
    if not seen[path] then
      seen[path] = true
      files[#files + 1] = path
    end
  end

  local entries = {}
  local errors = {}
  local order = 0
  for _, path in ipairs(files) do
    local text, err = read_file(path)
    if not text then
      errors[#errors + 1] = err or ("Failed to read %s"):format(path)
    else
      local parsed = parse_entries(text, path)
      for _, entry in ipairs(parsed) do
        order = order + 1
        entry.order = order
        entries[#entries + 1] = entry
      end
    end
  end
  return entries, errors
end

return M
