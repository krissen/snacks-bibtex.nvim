local uv = vim.uv or vim.loop

local M = {}

---@class SnacksBibtexEntry
---@field key string
---@field type string
---@field fields table<string, string>
---@field file string
---@field raw string
---@field line integer
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

---@param line string
---@return integer
local function count_braces(line)
  local level = 0
  for c in line:gmatch("[{}]") do
    level = level + (c == "{" and 1 or -1)
  end
  return level
end

---@param body string
---@param idx integer
---@return string, integer
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
      local prev = j > 1 and body:sub(j - 1, j - 1) or nil
      if ch == '"' and prev ~= "\\" then
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
  for idx, line in ipairs(lines) do
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
              line = idx,
              lines = { line },
            }
            brace_level = count_braces(line)
          end
        end
      end
    else
      current.lines[#current.lines + 1] = line
      brace_level = brace_level + count_braces(line)
      if brace_level <= 0 then
        local raw = table.concat(current.lines, "\n")
        if not raw:match("\n$") then
          raw = raw .. "\n"
        end
        current.raw = raw
        local body = raw:match("@%w+%s*%b{}")
        if body then
          local inner = body:match("%b{}")
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
          line = current.line,
        }
        current = nil
        brace_level = 0
      end
    end
  end
  return entries
end

---Detect bibliography files from the current buffer based on filetype-specific context lines.
---Supports .bib and .bibtex extensions.
---Supports:
--- - pandoc, markdown, rmd: YAML frontmatter `bibliography: file_path` (single or array)
--- - tex: `\bibliography{file}` or `\addbibresource{file}`
---@return string[]|nil
local function detect_context_files()
  local bufnr = vim.api.nvim_get_current_buf()
  local filetype = vim.bo[bufnr].filetype

  -- Get all lines from the buffer
  local lines = vim.api.nvim_buf_get_lines(bufnr, 0, -1, false)
  if not lines or #lines == 0 then
    return nil
  end

  local files = {}
  local seen = {} ---@type table<string, boolean>

  -- Get the directory of the current file for relative path resolution
  local current_file = vim.api.nvim_buf_get_name(bufnr)
  local current_dir = vim.fn.fnamemodify(current_file, ":h")
  if current_dir == "" then
    current_dir = (vim.uv and vim.uv.cwd()) or vim.loop.cwd()
  end

  ---@param file_path string
  local function add_file(file_path)
    if not file_path or file_path == "" then
      return
    end

    -- Expand user paths and environment variables
    if file_path:find("[~$]") then
      local ok, expanded = pcall(vim.fn.expand, file_path)
      if ok and type(expanded) == "string" and expanded ~= "" then
        file_path = expanded
      end
    end

    -- Resolve relative paths
    -- Check if path is already absolute (Unix: starts with /, Windows: has drive letter)
    local is_absolute = file_path:match("^/") or file_path:match("^%a:[/\\]")
    if not is_absolute then
      file_path = vim.fs.joinpath(current_dir, file_path)
    end

    local normalized = vim.fs.normalize(file_path)

    -- Check if file exists and hasn't been added yet
    local stat = uv.fs_stat(normalized)
    if stat and stat.type == "file" and not seen[normalized] then
      seen[normalized] = true
      files[#files + 1] = normalized
    end
  end

  -- Detect based on filetype
  if filetype == "pandoc" or filetype == "markdown" or filetype == "rmd" or filetype == "md" then
    -- YAML frontmatter: bibliography: file_path
    -- Can be single or multiple files
    local in_bibliography_array = false
    local yaml_depth = 0

    for _, line in ipairs(lines) do
      -- Track YAML frontmatter boundaries
      if line:match("^%-%-%-") then
        yaml_depth = yaml_depth + 1
        if yaml_depth > 1 then
          -- Exited YAML frontmatter
          break
        end
      end

      if yaml_depth == 1 then
        -- Match single file: bibliography: path/to/file.bib
        local file_path = line:match("^%s*bibliography:%s*(.+)$")
        if file_path then
          file_path = vim.trim(file_path)
          -- Check if it's the start of an array (empty value after colon)
          if file_path == "" then
            in_bibliography_array = true
          else
            -- Single file value
            file_path = file_path:gsub("^['\"]", ""):gsub("['\"]$", "")
            add_file(file_path)
            in_bibliography_array = false
          end
        elseif in_bibliography_array then
          -- Match array item: - path/to/file.bib or - path/to/file.bibtex
          local array_item = line:match("^%s*%-%s*(.+)$")
          if array_item then
            array_item = vim.trim(array_item)
            -- Only consider it if it looks like a bibliography file
            if array_item:match("%.bib$") or array_item:match("%.bibtex$") then
              array_item = array_item:gsub("^['\"]", ""):gsub("['\"]$", "")
              add_file(array_item)
            end
          elseif not line:match("^%s*$") and not line:match("^%s*#") then
            -- Non-empty, non-comment line that's not an array item
            -- Check if it's a new YAML key (not indented further than bibliography:)
            if line:match("^%w+:") then
              in_bibliography_array = false
            end
          end
        end
      end
    end
  elseif filetype == "tex" or filetype == "plaintex" or filetype == "latex" then
    -- LaTeX: \bibliography{file} or \addbibresource{file}
    for _, line in ipairs(lines) do
      -- \bibliography{file} - file without extension
      local bib_file = line:match("\\bibliography%s*{([^}]+)}")
      if bib_file then
        bib_file = vim.trim(bib_file)
        -- Split on commas for multiple files
        for file in bib_file:gmatch("[^,]+") do
          file = vim.trim(file)
          -- \bibliography command doesn't include .bib extension
          if not file:match("%.bib$") then
            file = file .. ".bib"
          end
          add_file(file)
        end
      end

      -- \addbibresource{file} - file with extension
      local addbib_file = line:match("\\addbibresource%s*{([^}]+)}")
      if addbib_file then
        addbib_file = vim.trim(addbib_file)
        -- Split on commas for multiple files
        for file in addbib_file:gmatch("[^,]+") do
          file = vim.trim(file)
          add_file(file)
        end
      end
    end
  end

  return #files > 0 and files or nil
end

---Find project bibliography files, respecting context awareness settings.
---When context is enabled, returns context-detected files or falls back based on context_fallback.
---When context is disabled, uses explicit files or searches the project directory.
---@param cfg SnacksBibtexConfig
---@return string[], boolean # files, has_context
local function find_project_files(cfg)
  -- Check for context-aware file detection
  if cfg.context then
    local context_files = detect_context_files()
    if context_files and #context_files > 0 then
      -- Context found, return these files (ignoring global_files and normal search)
      return context_files, true
    end
    -- No context found
    if not cfg.context_fallback then
      -- No fallback, return empty
      return {}, false
    end
    -- Fall through to normal behavior
  end

  -- Normal behavior: use explicit files or search
  if cfg.files then
    return vim.deepcopy(cfg.files), false
  end
  local cwd = (vim.uv and vim.uv.cwd()) or vim.loop.cwd()
  local opts = { path = cwd, type = "file" }
  if cfg.depth ~= nil then
    opts.depth = cfg.depth
  end
  local found = vim.fs.find(function(name, _)
    return name:lower():match("%.bib$") ~= nil
  end, opts)
  return found, false
end

---Load BibTeX entries from files, respecting context awareness.
---When context is enabled and found, global_files are ignored.
---@param cfg SnacksBibtexConfig
---@return SnacksBibtexEntry[], string[]
function M.load_entries(cfg)
  local files = {}
  local seen = {} ---@type table<string, boolean>

  -- Get project files (may be context-aware) and cache context status
  local project_files, has_context = find_project_files(cfg)

  for _, path in ipairs(project_files) do
    if not seen[path] then
      seen[path] = true
      files[#files + 1] = path
    end
  end

  -- Only add global files if context is not being used
  -- (context awareness ignores global_files as per spec)
  if not has_context then
    for _, path in ipairs(cfg.global_files or {}) do
      path = vim.fs.normalize(path)
      if not seen[path] then
        seen[path] = true
        files[#files + 1] = path
      end
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
