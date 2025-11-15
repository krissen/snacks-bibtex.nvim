local M = {}

---@class SnacksBibtexConfig
---@field depth integer|nil           # directory recursion depth for local bib search
---@field files string[]|nil          # explicit list of project-local bib files
---@field global_files string[]|nil   # list of global bib files (outside project)
---@field search_fields string[]      # ordered list of fields to search (e.g. {"author","title","year","keywords"})
---@field format string               # default format for inserting citation keys / labels
---@field preview_format string       # how to format the preview line(s)
---@field citation_format? string     # template used when inserting formatted citations
---@field mappings table<string, SnacksBibtexMapping>|nil  # custom action mappings for the picker

---@alias SnacksBibtexMapping string|fun(picker: snacks.Picker, item: snacks.picker.Item)|snacks.picker.Action.spec

local defaults ---@type SnacksBibtexConfig

local function deepcopy(tbl)
  return vim.deepcopy(tbl)
end

local function normalize_files(files)
  if not files then
    return nil
  end
  local ret = {}
  local seen = {} ---@type table<string, boolean>
  for _, file in ipairs(files) do
    if type(file) == "string" and file ~= "" then
      local normalized = vim.fs.normalize(file)
      if not seen[normalized] then
        seen[normalized] = true
        ret[#ret + 1] = normalized
      end
    end
  end
  return ret
end

---@return SnacksBibtexConfig
local function init_defaults()
  defaults = {
    depth = 1,
    files = nil,
    global_files = {},
    search_fields = { "author", "title", "year", "journal", "journaltitle", "editor" },
    format = "@%s",
    preview_format = "{{author}} ({{year}}), {{title}}",
    citation_format = "{{author}} ({{year}})",
    mappings = {},
  }
  return defaults
end

---@type SnacksBibtexConfig
local options = init_defaults()

---@param opts? SnacksBibtexConfig
---@return SnacksBibtexConfig
function M.setup(opts)
  if not opts then
    return deepcopy(options)
  end
  local merged = vim.tbl_deep_extend("force", deepcopy(defaults), opts)
  merged.files = normalize_files(merged.files)
  merged.global_files = normalize_files(merged.global_files) or {}
  options = merged
  return deepcopy(options)
end

---@return SnacksBibtexConfig
function M.get()
  return deepcopy(options)
end

---@param opts? SnacksBibtexConfig
---@return SnacksBibtexConfig
function M.resolve(opts)
  if not opts then
    return M.get()
  end
  local merged = vim.tbl_deep_extend("force", M.get(), opts)
  merged.files = normalize_files(merged.files) or merged.files
  merged.global_files = normalize_files(merged.global_files) or merged.global_files
  merged.global_files = merged.global_files or {}
  return merged
end

return M
