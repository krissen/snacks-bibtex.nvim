local config = require("snacks-bibtex.config")
local parser = require("snacks-bibtex.parser")

local M = {}

local function sanitize_identifier(value)
  if type(value) ~= "string" or value == "" then
    return ""
  end
  local ident = value:gsub("\\", ""):gsub("[^%w]+", "_")
  ident = ident:gsub("^_+", ""):gsub("_+$", "")
  return ident ~= "" and ident:lower() or ""
end

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

local function enabled_citation_commands(cfg)
  local ret = {}
  for _, command in ipairs(cfg.citation_commands or {}) do
    if type(command) == "table" and command.command and command.template and command.enabled ~= false then
      local packages = command.packages
      if type(packages) == "table" then
        packages = table.concat(packages, ", ")
      end
      ret[#ret + 1] = {
        id = command.id or sanitize_identifier(command.command),
        command = command.command,
        template = command.template,
        description = command.description,
        packages = packages,
        source = command,
      }
    end
  end
  return ret
end

local function enabled_citation_formats(cfg)
  local ret = {}
  local fallback = {}
  local locale = cfg.locale or "en"
  for _, format in ipairs(cfg.citation_formats or {}) do
    if type(format) == "table" and format.template and format.enabled ~= false then
      local entry = {
        id = format.id or sanitize_identifier(format.name or format.template),
        name = format.name or format.id or format.template,
        template = format.template,
        description = format.description,
        category = format.category,
        locale = format.locale or "en",
        source = format,
      }
      local target = entry.locale == locale and ret or fallback
      target[#target + 1] = entry
    end
  end
  if #ret == 0 then
    ret = fallback
  end
  return ret
end

---@param cfg SnacksBibtexConfig
---@param spec { id?: string, command?: string }|nil
---@param opts? { enabled_only?: boolean }
---@return SnacksBibtexCitationCommand|nil
local function find_citation_command(cfg, spec, opts)
  if not spec then
    return nil
  end
  local enabled_only = opts and opts.enabled_only
  if enabled_only == nil then
    enabled_only = true
  end
  local desired_id = spec.id and sanitize_identifier(spec.id) or nil
  for _, command in ipairs(cfg.citation_commands or {}) do
    if type(command) == "table" and command.command and command.template then
      if (not enabled_only or command.enabled ~= false) then
        local command_id = sanitize_identifier(command.id or command.command)
        local matches = false
        if spec.command and command.command == spec.command then
          matches = true
        elseif desired_id and command_id == desired_id then
          matches = true
        end
        if matches then
          return command
        end
      end
    end
  end
  return nil
end

---@param cfg SnacksBibtexConfig
---@param spec { id?: string, name?: string }|nil
---@param opts? { enabled_only?: boolean }
---@return SnacksBibtexCitationFormat|nil
local function find_citation_format(cfg, spec, opts)
  if not spec then
    return nil
  end
  local enabled_only = opts and opts.enabled_only
  if enabled_only == nil then
    enabled_only = true
  end
  local desired_id = spec.id and sanitize_identifier(spec.id) or nil
  for _, format in ipairs(cfg.citation_formats or {}) do
    if type(format) == "table" and format.template then
      if (not enabled_only or format.enabled ~= false) then
        local format_id = sanitize_identifier(format.id or format.name or format.template)
        local matches = false
        if desired_id and format_id == desired_id then
          matches = true
        elseif spec.name and format.name == spec.name then
          matches = true
        end
        if matches then
          return format
        end
      end
    end
  end
  return nil
end

local function apply_citation_template(entry, template, fallback)
  local text = format_template(template, entry)
  if text == "" and fallback and fallback ~= "" then
    text = format_template(fallback, entry)
  end
  if text == "" then
    text = entry.key or ""
  end
  return text
end

local function resolve_default_citation_template(cfg)
  local defaults = cfg.citation_format_defaults or {}
  local candidates = {
    defaults.in_text,
    cfg.default_citation_format,
  }
  for _, id in ipairs(candidates) do
    if id and id ~= "" then
      local format = find_citation_format(cfg, { id = id }, { enabled_only = false })
      if format and format.template then
        return format.template
      end
    end
  end
  if cfg.citation_format and cfg.citation_format ~= "" then
    return cfg.citation_format
  end
  return cfg.preview_format
end

local function open_citation_command_picker(snacks, entry, commands, cfg, close_parent)
  local display = cfg.citation_command_picker or {}
  local show_command = display.command ~= false
  local show_description = display.description ~= false
  local show_packages = display.packages ~= false
  local show_template = display.template == true
  local items = {}
  for _, command in ipairs(commands) do
    local description = command.description
    local packages = command.packages
    local template = command.template
    local lines = {}
    if show_command then
      lines[#lines + 1] = command.command
    end
    if show_packages and packages and packages ~= "" then
      lines[#lines + 1] = ("Packages: %s"):format(packages)
    end
    if show_template and template and template ~= "" then
      lines[#lines + 1] = ("Template: %s"):format(template)
    end
    if show_description and description and description ~= "" then
      lines[#lines + 1] = description
    end
    if vim.tbl_isempty(lines) then
      lines[#lines + 1] = command.command
    end
    items[#items + 1] = {
      command = command,
      text = table.concat(lines, " · "),
      label = command.command,
      description = description,
      packages = packages,
      template = template,
    }
  end

  snacks.picker({
    title = display.title or "Citation commands",
    items = items,
    format = function(item)
      local parts = {}
      if show_command then
        parts[#parts + 1] = { item.command.command }
      end
      if show_packages and item.packages and item.packages ~= "" then
        parts[#parts + 1] = { ("[%s]"):format(item.packages), "Comment" }
      end
      if show_template and item.template and item.template ~= "" then
        parts[#parts + 1] = { item.template, "String" }
      end
      if show_description and item.description and item.description ~= "" then
        parts[#parts + 1] = { item.description, "Comment" }
      end
      if vim.tbl_isempty(parts) then
        parts[#parts + 1] = { item.command.command }
      end
      return { parts }
    end,
    actions = {
      apply_citation_command = function(picker, item)
        if not item or not item.command then
          return
        end
        local text = apply_citation_template(entry, item.command.template, resolve_default_citation_template(cfg))
        insert_text(text)
        picker:close()
        if close_parent then
          close_parent()
        end
      end,
    },
    win = {
      list = {
        keys = {
          ["<CR>"] = "apply_citation_command",
        },
      },
    },
  })
end

local function open_citation_format_picker(snacks, entry, formats, cfg, close_parent)
  local items = {}
  for _, format in ipairs(formats) do
    local lines = { format.name }
    if format.category and format.category ~= "" then
      lines[#lines + 1] = ("Category: %s"):format(format.category)
    end
    if format.locale and format.locale ~= "" then
      lines[#lines + 1] = ("Locale: %s"):format(format.locale)
    end
    if format.description and format.description ~= "" then
      lines[#lines + 1] = format.description
    end
    items[#items + 1] = {
      format = format,
      text = table.concat(lines, " · "),
      label = format.name,
      description = format.description,
      category = format.category,
      locale = format.locale,
    }
  end

  snacks.picker({
    title = "Citation formats",
    items = items,
    format = function(item)
      local parts = { { item.label } }
      if item.category and item.category ~= "" then
        parts[#parts + 1] = { ("[%s]"):format(item.category), "Comment" }
      end
      if item.locale and item.locale ~= "" then
        parts[#parts + 1] = { ("(%s)"):format(item.locale), "Comment" }
      end
      if item.description and item.description ~= "" then
        parts[#parts + 1] = { item.description, "Comment" }
      end
      return { parts }
    end,
    actions = {
      apply_citation_format = function(picker, item)
        if not item or not item.format then
          return
        end
        local text = apply_citation_template(entry, item.format.template, resolve_default_citation_template(cfg))
        insert_text(text)
        picker:close()
        if close_parent then
          close_parent()
        end
      end,
    },
    win = {
      list = {
        keys = {
          ["<CR>"] = "apply_citation_format",
        },
      },
    },
  })
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

local function make_quick_command_action(cfg, command_entry)
  return function(picker, item)
    if not item then
      return
    end
    local entry = item.entry or item
    local fallback = resolve_default_citation_template(cfg)
    local text = apply_citation_template(entry, command_entry.template, fallback)
    insert_text(text)
    picker:close()
  end
end

local function make_quick_format_action(cfg, format_entry)
  return function(picker, item)
    if not item then
      return
    end
    local entry = item.entry or item
    local fallback = resolve_default_citation_template(cfg)
    local text = apply_citation_template(entry, format_entry.template, fallback)
    insert_text(text)
    picker:close()
  end
end

local function default_mappings_for_cfg(cfg)
  local mappings = {
    ["<CR>"] = "insert_key",
    ["<C-e>"] = "insert_entry",
    ["<C-f>"] = "pick_field",
    ["<C-c>"] = "insert_citation",
    ["<C-y>"] = "pick_citation_format",
  }

  local defaults = cfg.citation_format_defaults or {}
  if defaults.in_text and defaults.in_text ~= "" then
    mappings["<C-s>"] = { kind = "citation_format", id = defaults.in_text }
  end
  if defaults.reference and defaults.reference ~= "" then
    mappings["<C-r>"] = { kind = "citation_format", id = defaults.reference }
  end

  local quick_commands = {
    { key = "<C-a>", command = "\\cite" },
    { key = "<C-p>", command = "\\citep" },
    { key = "<C-t>", command = "\\citet" },
  }

  for _, quick in ipairs(quick_commands) do
    mappings[quick.key] = { kind = "citation_command", command = quick.command }
  end

  return mappings
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
    local commands = enabled_citation_commands(cfg)
    if #commands == 0 then
      local fallback_template = resolve_default_citation_template(cfg)
      local citation = apply_citation_template(entry, fallback_template, cfg.preview_format)
      insert_text(citation)
      picker:close()
      return
    end
    if #commands == 1 then
      local fallback_template = resolve_default_citation_template(cfg)
      local citation = apply_citation_template(entry, commands[1].template, fallback_template)
      insert_text(citation)
      picker:close()
      return
    end

    open_citation_command_picker(snacks, entry, commands, cfg, function()
      picker:close()
    end)
  end

  actions.pick_citation_format = function(picker, item)
    if not item then
      return
    end
    local entry = item.entry or item
    local formats = enabled_citation_formats(cfg)
    if #formats == 0 then
      local fallback_template = resolve_default_citation_template(cfg)
      local text = apply_citation_template(entry, fallback_template, cfg.preview_format)
      insert_text(text)
      picker:close()
      return
    end
    if #formats == 1 then
      local fallback_template = resolve_default_citation_template(cfg)
      local text = apply_citation_template(entry, formats[1].template, fallback_template)
      insert_text(text)
      picker:close()
      return
    end

    open_citation_format_picker(snacks, entry, formats, cfg, function()
      picker:close()
    end)
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

local function build_keymaps(actions, mappings, cfg)
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
      if action.kind == "citation_command" then
        local command = find_citation_command(cfg, { id = action.id, command = action.command }, { enabled_only = true })
        if command then
          local ident = sanitize_identifier(command.id or command.command)
          if ident == "" then
            ident = tostring(idx)
          end
          local action_name = action.action_name or action.name or ("insert_citation_command_" .. ident .. "_" .. idx)
          idx = idx + 1
          actions[action_name] = make_quick_command_action(cfg, command)
          list_keys[key] = action_name
        end
      elseif action.kind == "citation_format" then
        local format_id = action.id or action.format
        local format = nil
        if format_id then
          format = find_citation_format(cfg, { id = format_id }, { enabled_only = true })
        end
        if not format and action.lookup_name then
          format = find_citation_format(cfg, { name = action.lookup_name }, { enabled_only = true })
        end
        if not format and not format_id and action.name and not action.action_name then
          format = find_citation_format(cfg, { name = action.name }, { enabled_only = true })
        end
        if format then
          local ident = sanitize_identifier(format.id or format.name)
          if ident == "" then
            ident = tostring(idx)
          end
          local action_name = action.action_name or action.name or ("insert_citation_format_" .. ident .. "_" .. idx)
          idx = idx + 1
          actions[action_name] = make_quick_format_action(cfg, format)
          list_keys[key] = action_name
        end
      else
        local name = action.action or ("user_action_%d"):format(idx)
        idx = idx + 1
        actions[name] = action
        list_keys[key] = name
      end
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
  local base_mappings = default_mappings_for_cfg(cfg)
  local mappings = normalize_mappings(base_mappings, cfg.mappings)
  mappings = normalize_mappings(mappings, per_call_mappings)
  local list_keys = build_keymaps(actions, mappings, cfg)

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
