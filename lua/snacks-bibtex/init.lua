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

local latex_accent_map = {
  ['"'] = {
    a = "ä",
    A = "Ä",
    e = "ë",
    E = "Ë",
    i = "ï",
    I = "Ï",
    o = "ö",
    O = "Ö",
    u = "ü",
    U = "Ü",
    y = "ÿ",
    Y = "Ÿ",
  },
  ["'"] = {
    a = "á",
    A = "Á",
    e = "é",
    E = "É",
    i = "í",
    I = "Í",
    o = "ó",
    O = "Ó",
    u = "ú",
    U = "Ú",
    y = "ý",
    Y = "Ý",
    c = "ć",
    C = "Ć",
    n = "ń",
    N = "Ń",
  },
  ["`"] = {
    a = "à",
    A = "À",
    e = "è",
    E = "È",
    i = "ì",
    I = "Ì",
    o = "ò",
    O = "Ò",
    u = "ù",
    U = "Ù",
  },
  ["^"] = {
    a = "â",
    A = "Â",
    e = "ê",
    E = "Ê",
    i = "î",
    I = "Î",
    o = "ô",
    O = "Ô",
    u = "û",
    U = "Û",
    c = "ĉ",
    C = "Ĉ",
  },
  ["~"] = {
    a = "ã",
    A = "Ã",
    n = "ñ",
    N = "Ñ",
    o = "õ",
    O = "Õ",
  },
  ["="] = {
    a = "ā",
    A = "Ā",
    e = "ē",
    E = "Ē",
    i = "ī",
    I = "Ī",
    o = "ō",
    O = "Ō",
    u = "ū",
    U = "Ū",
  },
  ["."] = {
    e = "ė",
    E = "Ė",
    z = "ż",
    Z = "Ż",
  },
  c = {
    c = "ç",
    C = "Ç",
  },
  v = {
    s = "š",
    S = "Š",
    c = "č",
    C = "Č",
    z = "ž",
    Z = "Ž",
  },
  H = {
    o = "ő",
    O = "Ő",
    u = "ű",
    U = "Ű",
  },
  u = {
    a = "ă",
    A = "Ă",
    e = "ĕ",
    E = "Ĕ",
    i = "ĭ",
    I = "Ĭ",
    o = "ŏ",
    O = "Ŏ",
    u = "ŭ",
    U = "Ŭ",
  },
  k = {
    a = "ą",
    A = "Ą",
    e = "ę",
    E = "Ę",
    i = "į",
    I = "Į",
    u = "ų",
    U = "Ų",
  },
  b = {
    o = "ḅ",
    O = "Ḅ",
  },
  d = {
    a = "ḍ",
    A = "Ḍ",
  },
  r = {
    a = "ŕ",
    A = "Ŕ",
  },
  t = {
    s = "ṫ",
    S = "Ṫ",
  },
}

local latex_simple_map = {
  ["\\aa"] = "å",
  ["\\AA"] = "Å",
  ["\\ae"] = "æ",
  ["\\AE"] = "Æ",
  ["\\oe"] = "œ",
  ["\\OE"] = "Œ",
  ["\\o"] = "ø",
  ["\\O"] = "Ø",
  ["\\ss"] = "ß",
  ["\\l"] = "ł",
  ["\\L"] = "Ł",
  ["\\ng"] = "ŋ",
  ["\\NG"] = "Ŋ",
  ["\\th"] = "þ",
  ["\\TH"] = "Þ",
}

local function apply_latex_accent(cmd, letter)
  local map = latex_accent_map[cmd]
  if not map then
    return letter
  end
  return map[letter] or map[letter:lower()] or letter
end

local function latex_to_unicode(value)
  if type(value) ~= "string" or value == "" then
    return ""
  end

  local text = value

  text = text:gsub("{\\(%a+)}", function(cmd)
    local seq = "\\" .. cmd
    return latex_simple_map[seq] or cmd
  end)

  for seq, replacement in pairs(latex_simple_map) do
    text = text:gsub(seq, replacement)
  end

  text = text:gsub("\\([\"'`^~=%.Hckbdruvt])%s*%{(%a)%}", function(cmd, letter)
    return apply_latex_accent(cmd, letter)
  end)

  text = text:gsub("\\([\"'`^~=%.Hckbdruvt])(%a)", function(cmd, letter)
    return apply_latex_accent(cmd, letter)
  end)

  text = text:gsub("[{}]", "")

  text = text:gsub("\\(%a+)", function(cmd)
    local seq = "\\" .. cmd
    return latex_simple_map[seq] or cmd
  end)

  text = text:gsub("~", " ")

  return text
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

---@param snacks snacks.picker
---@param entry SnacksBibtexEntry
---@param commands SnacksBibtexCitationCommand[]
---@param cfg SnacksBibtexConfig
---@param parent_picker snacks.Picker
---@param close_parent? fun()
local function open_citation_command_picker(snacks, entry, commands, cfg, parent_picker, close_parent)
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
        insert_text(parent_picker, text)
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

---@param snacks snacks.picker
---@param entry SnacksBibtexEntry
---@param formats SnacksBibtexCitationFormat[]
---@param cfg SnacksBibtexConfig
---@param parent_picker snacks.Picker
---@param close_parent? fun()
local function open_citation_format_picker(snacks, entry, formats, cfg, parent_picker, close_parent)
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
        insert_text(parent_picker, text)
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
      local normalized = latex_to_unicode(value)
      if normalized ~= "" and normalized ~= value then
        search_parts[#search_parts + 1] = normalized
      end
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

---Insert `text` into the window where the picker was launched, falling back to the
---current picker main window when the origin is no longer available.
---@param picker snacks.Picker
---@param text string
local function insert_text(picker, text)
  if not text or text == "" then
    return
  end
  local win
  if picker and picker._snacks_bibtex_origin_win and vim.api.nvim_win_is_valid(picker._snacks_bibtex_origin_win) then
    win = picker._snacks_bibtex_origin_win
  elseif picker and picker.main and vim.api.nvim_win_is_valid(picker.main) then
    win = picker.main
  end
  win = win or vim.api.nvim_get_current_win()
  if not vim.api.nvim_win_is_valid(win) then
    return
  end
  local buf = vim.api.nvim_win_get_buf(win)
  local cursor = vim.api.nvim_win_get_cursor(win)
  local row = cursor[1] - 1
  local col = cursor[2]
  local lines = to_lines(text)
  if #lines == 0 then
    return
  end
  local ok = pcall(vim.api.nvim_buf_set_text, buf, row, col, row, col, lines)
  if not ok then
    return
  end
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
    insert_text(picker, text)
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
    insert_text(picker, text)
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
    insert_text(picker, text)
    picker:close()
  end

  actions.insert_entry = function(picker, item)
    if not item then
      return
    end
    insert_text(picker, item.raw)
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
      insert_text(picker, citation)
      picker:close()
      return
    end
    if #commands == 1 then
      local fallback_template = resolve_default_citation_template(cfg)
      local citation = apply_citation_template(entry, commands[1].template, fallback_template)
      insert_text(picker, citation)
      picker:close()
      return
    end

    open_citation_command_picker(snacks, entry, commands, cfg, picker, function()
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
      insert_text(picker, text)
      picker:close()
      return
    end
    if #formats == 1 then
      local fallback_template = resolve_default_citation_template(cfg)
      local text = apply_citation_template(entry, formats[1].template, fallback_template)
      insert_text(picker, text)
      picker:close()
      return
    end

    open_citation_format_picker(snacks, entry, formats, cfg, picker, function()
      picker:close()
    end)
  end

  actions.pick_field = function(picker, item)
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
    -- keep a reference to the original picker so field insertions target the source buffer
    local parent_picker = picker
    snacks.picker({
      title = "BibTeX fields",
      items = fields,
      format = function(field_item)
        return { { field_item.label or field_item.text } }
      end,
      actions = {
        insert_field = function(field_picker, field_item)
          if not field_item then
            return
          end
          insert_text(parent_picker, field_item.value)
          field_picker:close()
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

---Attach a keybinding specification to a picker window target.
---@param target table<string, any>
---@param key string
---@param action_name string
---@param opts table<string, any>?
local function register_key_spec(target, key, action_name, opts)
  if not opts or vim.tbl_isempty(opts) then
    target[key] = action_name
    return
  end
  local spec = vim.deepcopy(opts)
  spec[1] = action_name
  target[key] = spec
end

---Extract key mapping configuration from a mapping definition table.
---@param map any
---@return table<string, any>
local function extract_key_options(map)
  if type(map) ~= "table" then
    return {}
  end
  local opts = {}
  for _, name in ipairs({ "mode", "expr", "desc", "silent", "noremap" }) do
    if map[name] ~= nil then
      opts[name] = map[name]
    end
  end
  return opts
end

---Build keymaps for both the picker list window and the search input.
---@param actions table<string, snacks.picker.Action.spec>
---@param mappings table<string, any>
---@param cfg SnacksBibtexResolvedConfig
---@return table<string, any> list_keys
---@return table<string, any> input_keys
local function build_keymaps(actions, mappings, cfg)
  local list_keys = {}
  local input_keys = {}
  local idx = 1
  for key, action in pairs(mappings) do
    local key_opts = extract_key_options(action)
    if type(action) == "string" then
      register_key_spec(list_keys, key, action, key_opts)
      if not key_opts.mode then
        key_opts = vim.deepcopy(key_opts)
        key_opts.mode = { "n", "i" }
      end
      register_key_spec(input_keys, key, action, key_opts)
    elseif type(action) == "function" then
      local name = ("user_action_%d"):format(idx)
      idx = idx + 1
      actions[name] = action
      register_key_spec(list_keys, key, name, key_opts)
      if not key_opts.mode then
        key_opts = vim.deepcopy(key_opts)
        key_opts.mode = { "n", "i" }
      end
      register_key_spec(input_keys, key, name, key_opts)
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
          register_key_spec(list_keys, key, action_name, key_opts)
          if not key_opts.mode then
            key_opts = vim.deepcopy(key_opts)
            key_opts.mode = { "n", "i" }
          end
          register_key_spec(input_keys, key, action_name, key_opts)
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
          register_key_spec(list_keys, key, action_name, key_opts)
          if not key_opts.mode then
            key_opts = vim.deepcopy(key_opts)
            key_opts.mode = { "n", "i" }
          end
          register_key_spec(input_keys, key, action_name, key_opts)
        end
      else
        local name = action.action or ("user_action_%d"):format(idx)
        idx = idx + 1
        actions[name] = action
        register_key_spec(list_keys, key, name, key_opts)
        if not key_opts.mode then
          key_opts = vim.deepcopy(key_opts)
          key_opts.mode = { "n", "i" }
        end
        register_key_spec(input_keys, key, name, key_opts)
      end
    end
  end
  return list_keys, input_keys
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
  local picker_opts_user = opts.picker and vim.deepcopy(opts.picker) or nil
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
  local list_keys, input_keys = build_keymaps(actions, mappings, cfg)

  local origin_win = vim.api.nvim_get_current_win()
  local user_on_show
  if picker_opts_user and picker_opts_user.on_show then
    user_on_show = picker_opts_user.on_show
    picker_opts_user.on_show = nil
  end

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
      input = {
        keys = input_keys,
      },
    },
    on_show = function(picker)
      if origin_win and vim.api.nvim_win_is_valid(origin_win) then
        picker._snacks_bibtex_origin_win = origin_win
      end
    end,
  }, picker_opts_user or {})

  if user_on_show then
    local base_on_show = picker_opts.on_show
    picker_opts.on_show = function(picker)
      if base_on_show then
        base_on_show(picker)
      end
      user_on_show(picker)
    end
  end

  return Snacks.picker(picker_opts)
end

register_with_snacks()

return M
