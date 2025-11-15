local config = require("snacks-bibtex.config")
local parser = require("snacks-bibtex.parser")

local M = {}

---@type table<string, string>
local default_mappings = {
  ["<CR>"] = "insert_key",
  ["<C-e>"] = "insert_entry",
  ["<C-f>"] = "pick_field",
  ["<C-c>"] = "insert_citation",
}

---@param opts? {silent?: boolean}
---@return any
local function ensure_snacks(opts)
  local ok, Snacks = pcall(require, "snacks")
  if not ok or not Snacks.picker then
    if not (opts and opts.silent) then
      vim.notify("snacks.nvim with picker module is required for snacks-bibtex", vim.log.levels.ERROR, {
        title = "snacks-bibtex",
      })
    end
    return nil
  end
  return Snacks
end

local function field_value(entry, name)
  if not name or name == "" then
    return ""
  end
  name = name:lower()
  if name == "key" then
    return entry.key or ""
  elseif name == "type" then
    return entry.type or ""
  elseif name == "file" then
    return entry.file or ""
  end
  return entry.fields[name] or ""
end

local function format_template(template, entry)
  if not template or template == "" then
    return ""
  end
  return (template:gsub("{{(.-)}}", function(field)
    field = vim.trim(field)
    return field_value(entry, field)
  end))
end

local function make_item(entry, cfg)
  local fields = entry.fields or {}
  local search_parts = { entry.key }
  for _, name in ipairs(cfg.search_fields or {}) do
    local value = fields[name:lower()]
    if value and value ~= "" then
      search_parts[#search_parts + 1] = value
    end
  end
  local preview = format_template(cfg.preview_format, entry)
  if preview == "" then
    preview = entry.key
  end
  local label = preview
  if preview ~= entry.key then
    label = ("%s — %s"):format(entry.key, preview)
  end
  return {
    key = entry.key,
    type = entry.type,
    fields = fields,
    file = entry.file,
    raw = entry.raw,
    entry = entry,
    text = table.concat(search_parts, " · "),
    label = label,
    preview = {
      text = entry.raw,
      ft = "bib",
    },
  }
end

local function to_lines(text)
  local lines = vim.split(text, "\n", { plain = true })
  if #lines > 0 and lines[#lines] == "" then
    table.remove(lines)
  end
  return lines
end

local function insert_text(text)
  if not text or text == "" then
    return
  end
  local win = vim.api.nvim_get_current_win()
  local buf = vim.api.nvim_win_get_buf(win)
  local cursor = vim.api.nvim_win_get_cursor(win)
  local row = cursor[1] - 1
  local col = cursor[2]
  local lines = to_lines(text)
  if #lines == 0 then
    return
  end
  vim.api.nvim_buf_set_text(buf, row, col, row, col, lines)
  local final_row = row + (#lines - 1)
  local final_col
  if #lines == 1 then
    final_col = col + #lines[1]
  else
    final_col = #lines[#lines]
  end
  vim.api.nvim_win_set_cursor(win, { final_row + 1, final_col })
end

local function make_actions(snacks, cfg)
  local actions = {}
  actions.insert_key = function(picker, item)
    if not item then
      return
    end
    local text = item.key
    if cfg.format and cfg.format ~= "" then
      local ok, formatted = pcall(string.format, cfg.format, item.key)
      if ok and formatted then
        text = formatted
      end
    end
    insert_text(text)
    picker:close()
  end

  actions.insert_entry = function(picker, item)
    if not item then
      return
    end
    insert_text(item.raw)
    picker:close()
  end

  actions.insert_citation = function(picker, item)
    if not item then
      return
    end
    local entry = item.entry or item
    local citation = format_template(cfg.citation_format or cfg.preview_format, entry)
    if citation == "" then
      citation = entry.key or ""
    end
    insert_text(citation)
    picker:close()
  end

  actions.pick_field = function(_, item)
    if not item then
      return
    end
    local fields = {}
    for name, value in pairs(item.fields or {}) do
      fields[#fields + 1] = {
        field = name,
        value = value,
        text = name .. ": " .. value,
        label = name .. ": " .. value,
      }
    end
    table.sort(fields, function(a, b)
      return a.field < b.field
    end)
    if vim.tbl_isempty(fields) then
      vim.notify("No fields available for " .. (item.key or "entry"), vim.log.levels.INFO, { title = "snacks-bibtex" })
      return
    end
    snacks.picker({
      title = "BibTeX fields",
      items = fields,
      format = function(field_item)
        return { { field_item.label or field_item.text } }
      end,
      actions = {
        insert_field = function(picker, field_item)
          if not field_item then
            return
          end
          insert_text(field_item.value)
          picker:close()
        end,
      },
      win = {
        list = {
          keys = {
            ["<CR>"] = "insert_field",
          },
        },
      },
    })
  end

  return actions
end

local function normalize_mappings(base, overrides)
  local keys = vim.deepcopy(base)
  for key, value in pairs(overrides or {}) do
    if value == false then
      keys[key] = nil
    else
      keys[key] = value
    end
  end
  return keys
end

local function build_keymaps(actions, mappings)
  local list_keys = {}
  local idx = 1
  for key, action in pairs(mappings) do
    if type(action) == "string" then
      list_keys[key] = action
    elseif type(action) == "function" then
      local name = ("user_action_%d"):format(idx)
      idx = idx + 1
      actions[name] = action
      list_keys[key] = name
    elseif type(action) == "table" then
      local name = action.action or ("user_action_%d"):format(idx)
      idx = idx + 1
      actions[name] = action
      list_keys[key] = name
    end
  end
  return list_keys
end

local function register_with_snacks()
  local Snacks = ensure_snacks({ silent = true })
  if not Snacks then
    return
  end
  Snacks.picker.bibtex = M.bibtex
end

function M.setup(opts)
  config.setup(opts)
  register_with_snacks()
end

---@param opts? SnacksBibtexConfig & { picker?: snacks.picker.Config }
function M.bibtex(opts)
  local Snacks = ensure_snacks()
  if not Snacks then
    return
  end
  opts = vim.deepcopy(opts or {})
  local per_call_mappings = opts.mappings
  local picker_opts_user = opts.picker
  opts.mappings = nil
  opts.picker = nil
  local cfg = config.resolve(opts)
  local entries, errors = parser.load_entries(cfg)
  for _, err in ipairs(errors) do
    vim.notify(err, vim.log.levels.WARN, { title = "snacks-bibtex" })
  end
  if vim.tbl_isempty(entries) then
    vim.notify("No BibTeX entries found", vim.log.levels.INFO, { title = "snacks-bibtex" })
    return
  end

  local items = {}
  for _, entry in ipairs(entries) do
    items[#items + 1] = make_item(entry, cfg)
  end

  local actions = make_actions(Snacks, cfg)
  local mappings = normalize_mappings(default_mappings, cfg.mappings)
  mappings = normalize_mappings(mappings, per_call_mappings)
  local list_keys = build_keymaps(actions, mappings)

  local picker_opts = vim.tbl_deep_extend("force", {
    title = "BibTeX",
    prompt = " ",
    items = items,
    format = function(item)
      return { { item.label or item.text } }
    end,
    actions = actions,
    preview = "preview",
    win = {
      list = {
        keys = list_keys,
      },
    },
  }, picker_opts_user or {})

  return Snacks.picker(picker_opts)
end

register_with_snacks()

return M
