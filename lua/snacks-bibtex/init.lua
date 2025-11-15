local config = require("snacks-bibtex.config")
local parser = require("snacks-bibtex.parser")

local sanitize_identifier = assert(config.sanitize_identifier, "snacks-bibtex.config is missing sanitize_identifier")

local uv = vim.uv or vim.loop

local M = {}

local history ---@type table<string, { count: integer, last: integer }>
local history_loaded = false
local history_dirty = false

local insert_modes = {
  i = true,
  ic = true,
  ix = true,
}

local replace_modes = {
  R = true,
  Rc = true,
  Rx = true,
}

---@return string|nil
local function history_path()
  local ok, data_dir = pcall(vim.fn.stdpath, "data")
  if not ok or not data_dir or data_dir == "" then
    return nil
  end
  return vim.fs.joinpath(data_dir, "snacks-bibtex", "history.json")
end

---@param value any
---@return { count: integer, last: integer }|nil
local function sanitize_history_record(value)
  if type(value) ~= "table" then
    return nil
  end
  local count = tonumber(value.count) or 0
  if count < 0 then
    count = 0
  end
  local last = tonumber(value.last) or 0
  if last < 0 then
    last = 0
  end
  return { count = math.floor(count), last = math.floor(last) }
end

local function ensure_history_loaded()
  if history_loaded then
    return history
  end
  history_loaded = true
  history = {}
  local path = history_path()
  if not path then
    return history
  end
  local stat = uv.fs_stat(path)
  if not stat or stat.type ~= "file" then
    return history
  end
  local fd = uv.fs_open(path, "r", 438)
  if not fd then
    return history
  end
  local data = uv.fs_read(fd, stat.size, 0)
  uv.fs_close(fd)
  if not data then
    return history
  end
  local ok, decoded = pcall(vim.json.decode, data)
  if not ok or type(decoded) ~= "table" then
    return history
  end
  for key, value in pairs(decoded) do
    if type(key) == "string" then
      local record = sanitize_history_record(value)
      if record then
        history[key] = record
      end
    end
  end
  return history
end

local function get_history()
  return ensure_history_loaded()
end

local function save_history()
  if not history_dirty then
    return
  end
  local path = history_path()
  if not path then
    return
  end
  local dir = vim.fs.dirname(path)
  if dir and dir ~= "" then
    pcall(vim.fn.mkdir, dir, "p")
  end
  local ok, encoded = pcall(vim.json.encode, history or {})
  if not ok or type(encoded) ~= "string" then
    return
  end
  local fd = uv.fs_open(path, "w", 420)
  if not fd then
    return
  end
  uv.fs_write(fd, encoded, 0)
  uv.fs_close(fd)
  history_dirty = false
end

---@param key string|nil
local function record_entry_usage(key)
  if not key or key == "" then
    return
  end
  local store = get_history()
  local record = store[key]
  if not record then
    record = { count = 0, last = 0 }
    store[key] = record
  end
  record.count = math.max(0, (tonumber(record.count) or 0)) + 1
  record.last = os.time()
  history_dirty = true
  save_history()
end

---@param key string|nil
---@return { count: integer, last: integer }|nil
local function get_history_entry(key)
  if not key or key == "" then
    return nil
  end
  local store = get_history()
  local record = store[key]
  if not record then
    return nil
  end
  return {
    count = math.max(0, tonumber(record.count) or 0),
    last = math.max(0, tonumber(record.last) or 0),
  }
end

---@param record { count: integer, last: integer }|nil
---@param now integer
---@return number
local function compute_frecency(record, now)
  if not record then
    return 0
  end
  local count = math.max(0, tonumber(record.count) or 0)
  local last = math.max(0, tonumber(record.last) or 0)
  local recency = 0
  if last > 0 then
    local age = now - last
    if age < 0 then
      age = 0
    end
    recency = math.max(0, 1000000 - age)
  end
  return (count * 1000000) + recency
end

---@param value any
---@return string|nil
local function normalize_sort_string(value)
  if type(value) == "number" then
    value = tostring(value)
  end
  if type(value) ~= "string" then
    return nil
  end
  local trimmed = vim.trim(value)
  if trimmed == "" then
    return nil
  end
  return trimmed:lower()
end

---@param fields table<string, string>
---@return integer|nil
local function extract_year(fields)
  local candidate = fields.year or fields.date
  if type(candidate) == "number" then
    return math.floor(candidate)
  end
  if type(candidate) ~= "string" then
    return nil
  end
  local year = candidate:match("%d%d%d%d")
  if year then
    return tonumber(year)
  end
  return nil
end

---@param item table
---@param field string
---@return any
local function get_sort_value(item, field)
  field = field:lower()
  local fields = item.fields or (item.entry and item.entry.fields) or {}
  if field == "frecency" then
    return item.frecency or 0
  elseif field == "frequency" then
    local record = item.history
    return record and record.count or 0
  elseif field == "recent" or field == "recency" then
    local record = item.history
    return record and record.last or 0
  elseif field == "score" then
    return item.score or 0
  elseif field == "match_priority" then
    return item._sb_match_priority or item._sb_priority_default or math.huge
  elseif field == "match_field" then
    return normalize_sort_string(item._sb_match_field)
  elseif field == "match_offset" then
    return item._sb_match_offset or math.huge
  elseif field == "author" then
    return normalize_sort_string(fields.author) or normalize_sort_string(fields.editor)
  elseif field == "title" then
    return normalize_sort_string(fields.title)
  elseif field == "journal" or field == "journaltitle" then
    return normalize_sort_string(fields.journal or fields.journaltitle)
  elseif field == "year" then
    return extract_year(fields)
  elseif field == "key" then
    return normalize_sort_string(item.key)
  elseif field == "type" then
    return normalize_sort_string(item.type)
  elseif field == "file" then
    return normalize_sort_string(item.file)
  elseif field == "label" then
    return normalize_sort_string(item.label)
  elseif field == "text" then
    return normalize_sort_string(item.text)
  elseif field == "source" or field == "order" then
    return item.order or (item.entry and item.entry.order) or 0
  end
  return nil
end

---@param a any
---@param b any
---@return integer
local function compare_values(a, b)
  if a == b then
    return 0
  end
  if a == nil then
    return 1
  end
  if b == nil then
    return -1
  end
  local ta, tb = type(a), type(b)
  if ta == "number" and tb == "number" then
    if a == b then
      return 0
    end
    return a < b and -1 or 1
  end
  local sa = normalize_sort_string(a) or tostring(a)
  local sb = normalize_sort_string(b) or tostring(b)
  if sa == sb then
    return 0
  end
  return sa < sb and -1 or 1
end

---Return `true` when `a` should appear before `b` after applying the provided sort rules.
---@param a table
---@param b table
---@param rules SnacksBibtexSortSpec[]
---@return boolean
local function compare_with_rules(a, b, rules)
  if rules and not vim.tbl_isempty(rules) then
    for _, rule in ipairs(rules) do
      if rule.field and rule.field ~= "" then
        local va = get_sort_value(a, rule.field)
        local vb = get_sort_value(b, rule.field)
        if va == nil and vb ~= nil then
          return false
        elseif vb == nil and va ~= nil then
          return true
        end
        local cmp = compare_values(va, vb)
        if cmp ~= 0 then
          if rule.direction == "desc" then
            return cmp > 0
          else
            return cmp < 0
          end
        end
      end
    end
  end
  local ao = a.order or (a.entry and a.entry.order) or 0
  local bo = b.order or (b.entry and b.entry.order) or 0
  if ao == bo then
    local ak = normalize_sort_string(a.key) or ""
    local bk = normalize_sort_string(b.key) or ""
    if ak == bk then
      return false
    end
    return ak < bk
  end
  return ao < bo
end

---Sort the initial list of picker items according to the configured rule chain
---while preserving BibTeX order as the final fallback.
---@param items table[]
---@param cfg SnacksBibtexResolvedConfig
local function apply_sort(items, cfg)
  local rules = cfg.sort or {}
  table.sort(items, function(a, b)
    return compare_with_rules(a, b, rules)
  end)
end

---Build a Snacks-compatible sorter that prioritises matcher scores before the
---configured tie-breakers.
---@param cfg SnacksBibtexResolvedConfig
---@return snacks.picker.sort|nil
local function make_match_sorter(cfg)
  local rules = cfg.match_sort or {}
  if vim.tbl_isempty(rules) then
    return nil
  end
  return function(a, b)
    return compare_with_rules(a, b, rules)
  end
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

local ensure_template_values

local function field_value(entry, name)
  if not entry or not name or name == "" then
    return ""
  end
  local placeholder = vim.trim(name)
  if placeholder == "" then
    return ""
  end
  local lowered = placeholder:lower()
  local values = ensure_template_values(entry)
  if lowered:find("%.") then
    local current = values
    for part in lowered:gmatch("[^%.]+") do
      part = part:lower()
      if type(current) ~= "table" then
        current = nil
        break
      end
      current = current[part]
    end
    if type(current) == "string" or type(current) == "number" then
      return tostring(current)
    end
  elseif values and (type(values[lowered]) == "string" or type(values[lowered]) == "number") then
    return tostring(values[lowered])
  end
  local name = lowered
  if name == "key" then
    return entry.key or ""
  elseif name == "type" then
    return entry.type or ""
  elseif name == "file" then
    return entry.file or ""
  end
  return entry.fields[name] or ""
end

---Format a template using entry metadata, supporting triple braces to wrap values in `{}` automatically.
---@param template string
---@param entry SnacksBibtexEntry
---@return string
local function format_template(template, entry)
  if not template or template == "" then
    return ""
  end
  ensure_template_values(entry)
  local function resolve(field)
    field = vim.trim(field or "")
    if field == "" then
      return ""
    end
    return field_value(entry, field)
  end
  local text = template
  text = text:gsub("{{{%s*(.-)%s*}}}", function(field)
    local value = resolve(field)
    if value == "" then
      return ""
    end
    return "{" .. value .. "}"
  end)
  text = text:gsub("{{%s*(.-)%s*}}", function(field)
    return resolve(field)
  end)
  text = text:gsub("{%s+", "{")
  text = text:gsub("%s+}", "}")
  return text
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

---@param value string|nil
---@return string
local function strip_outer_braces(value)
  if type(value) ~= "string" then
    return ""
  end
  local trimmed = vim.trim(value)
  while trimmed:match("^%b{}$") do
    trimmed = trimmed:sub(2, -2)
    trimmed = vim.trim(trimmed)
  end
  return trimmed
end

---@param value string|nil
---@return string[]
local function split_names(value)
  local names = {}
  if type(value) ~= "string" or value == "" then
    return names
  end
  local text = value
  local len = #text
  local depth = 0
  local start = 1
  local i = 1
  while i <= len do
    local ch = text:sub(i, i)
    if ch == "{" then
      depth = depth + 1
      i = i + 1
    elseif ch == "}" then
      depth = math.max(0, depth - 1)
      i = i + 1
    elseif depth == 0 and text:sub(i, i + 4):lower() == " and " then
      names[#names + 1] = text:sub(start, i - 1)
      start = i + 5
      i = start
    else
      i = i + 1
    end
  end
  names[#names + 1] = text:sub(start)
  return names
end

---@param text string|nil
---@return string
local function first_utf8_char(text)
  if type(text) ~= "string" or text == "" then
    return ""
  end
  local char = text:match("[%z\1-\127\194-\244][\128-\191]*")
  return char or text:sub(1, 1)
end

---@param char string|nil
---@return string
local function to_upper(char)
  if type(char) ~= "string" or char == "" then
    return ""
  end
  local ok, res = pcall(vim.fn.toupper, char)
  if ok and type(res) == "string" then
    return res
  end
  return char:upper()
end

---@param given string|nil
---@return string
local function compute_initials(given)
  if type(given) ~= "string" or given == "" then
    return ""
  end
  local parts = {}
  for word in given:gmatch("%S+") do
    local hyphenated = {}
    for segment in word:gmatch("[^%-]+") do
      local char = first_utf8_char(segment)
      if char ~= "" then
        hyphenated[#hyphenated + 1] = to_upper(char)
      end
    end
    if #hyphenated > 0 then
      parts[#parts + 1] = table.concat(hyphenated, ".-") .. "."
    end
  end
  return table.concat(parts, " ")
end

---@param raw string
---@return table|nil
local function parse_name_segment(raw)
  if type(raw) ~= "string" then
    return nil
  end
  local literal = latex_to_unicode(strip_outer_braces(raw))
  local cleaned = literal
  if cleaned == "" then
    return nil
  end
  local parts = {}
  for part in cleaned:gmatch("[^,]+") do
    parts[#parts + 1] = vim.trim(part)
  end

  local family, suffix, given
  if #parts > 1 then
    family = parts[1]
    if #parts == 2 then
      given = parts[2]
    else
      suffix = parts[2]
      given = parts[3]
    end
  else
    local tokens = {}
    for token in cleaned:gmatch("%S+") do
      tokens[#tokens + 1] = token
    end
    if #tokens == 1 then
      family = tokens[1]
    else
      family = tokens[#tokens]
      given = table.concat(tokens, " ", 1, #tokens - 1)
    end
  end

  family = latex_to_unicode(family or "")
  given = latex_to_unicode(given or "")
  suffix = latex_to_unicode(suffix or "")

  local initials = compute_initials(given)
  local reference
  if family ~= "" and initials ~= "" then
    reference = ("%s, %s"):format(family, initials)
  else
    reference = literal
  end
  if suffix ~= "" and reference ~= literal then
    reference = ("%s, %s"):format(reference, suffix)
  end

  local editor_reference
  if initials ~= "" and family ~= "" then
    if suffix ~= "" then
      editor_reference = ("%s %s, %s"):format(initials, family, suffix)
    else
      editor_reference = ("%s %s"):format(initials, family)
    end
  else
    editor_reference = literal
  end

  local in_text
  if family ~= "" then
    in_text = family
  else
    in_text = literal
  end

  return {
    literal = literal,
    family = family,
    given = given,
    suffix = suffix,
    initials = initials,
    reference = reference,
    editor_reference = editor_reference,
    in_text = in_text,
  }
end

---@param value string|nil
---@return table[]
local function parse_name_list(value)
  local list = {}
  if type(value) ~= "string" or value == "" then
    return list
  end
  for _, segment in ipairs(split_names(value)) do
    local name = parse_name_segment(segment)
    if name then
      list[#list + 1] = name
    end
  end
  return list
end

---@param list string[]
---@return string
local function join_serial(list)
  if #list == 0 then
    return ""
  elseif #list == 1 then
    return list[1]
  elseif #list == 2 then
    return ("%s & %s"):format(list[1], list[2])
  end
  local leading = table.concat(list, ", ", 1, #list - 1)
  return ("%s, & %s"):format(leading, list[#list])
end

---@param names table[]
---@return string
local function format_authors_in_text(names)
  local count = #names
  if count == 0 then
    return ""
  elseif count == 1 then
    return names[1].in_text
  elseif count == 2 then
    return join_serial({ names[1].in_text, names[2].in_text })
  end
  return ("%s et al."):format(names[1].in_text)
end

---@param names table[]
---@return string
local function format_authors_reference(names)
  if #names == 0 then
    return ""
  end
  local formatted = {}
  for _, name in ipairs(names) do
    formatted[#formatted + 1] = name.reference
  end
  local count = #formatted
  if count == 1 then
    return formatted[1]
  elseif count == 2 then
    return ("%s & %s"):format(formatted[1], formatted[2])
  elseif count <= 20 then
    local leading = table.concat(formatted, ", ", 1, count - 1)
    return ("%s, & %s"):format(leading, formatted[count])
  end
  local truncated = {}
  for i = 1, 19 do
    truncated[#truncated + 1] = formatted[i]
  end
  truncated[#truncated + 1] = "..."
  truncated[#truncated + 1] = formatted[count]
  return table.concat(truncated, ", ")
end

---@param names table[]
---@return string
local function format_editors_collection(names)
  if #names == 0 then
    return ""
  end
  local formatted = {}
  for _, name in ipairs(names) do
    formatted[#formatted + 1] = name.editor_reference
  end
  return join_serial(formatted)
end

---@param names table[]
---@return string
local function join_families(names)
  if #names == 0 then
    return ""
  end
  local families = {}
  for _, name in ipairs(names) do
    families[#families + 1] = name.family ~= "" and name.family or name.literal
  end
  return join_serial(families)
end

---@param names table[]
---@return table
local function build_person_meta(names)
  return {
    list = names,
    count = #names,
    in_text = format_authors_in_text(names),
    reference = format_authors_reference(names),
    collection = format_editors_collection(names),
    families = join_families(names),
  }
end

---@param value string|nil
---@return string
local function normalize_page_range(value)
  if type(value) ~= "string" or value == "" then
    return ""
  end
  local text = latex_to_unicode(value)
  text = vim.trim(text)
  if text == "" then
    return ""
  end
  text = text:gsub("%s*%-%s*", "–")
  text = text:gsub("^[Pp]+%.?%s*", "")
  return text
end

---@param value string|nil
---@return string
local function format_collection_pages(value)
  local range = normalize_page_range(value)
  if range == "" then
    return ""
  end
  if range:find("–") then
    return ("pp. %s"):format(range)
  end
  return ("p. %s"):format(range)
end

---@param fields table<string, any>
---@return string
local function build_year_text(fields)
  local year = extract_year(fields)
  if year then
    return tostring(year)
  end
  local raw = fields.year or fields.date
  if type(raw) == "string" then
    return latex_to_unicode(raw)
  end
  return ""
end

---@param value string|nil
---@return string
local function latex_trim(value)
  if type(value) ~= "string" or value == "" then
    return ""
  end
  return vim.trim(latex_to_unicode(value))
end

---@param location string|nil
---@param publisher string|nil
---@return string
local function build_publisher_segment(location, publisher)
  local parts = {}
  if location and location ~= "" then
    parts[#parts + 1] = location
  end
  if publisher and publisher ~= "" then
    parts[#parts + 1] = publisher
  end
  if vim.tbl_isempty(parts) then
    return ""
  end
  return table.concat(parts, ": ")
end

---@param value string|nil
---@return string
local function ensure_link(value)
  if type(value) ~= "string" or value == "" then
    return ""
  end
  if value:match("^https?://") then
    return value
  end
  return ("https://doi.org/%s"):format(value)
end

---@param entry SnacksBibtexEntry
---@param values table
---@return string
local function build_apa_in_text(entry, values)
  local label = values.authors.in_text
  if label == "" then
    label = values.organization ~= "" and values.organization or ""
  end
  if label == "" then
    label = values.editors.in_text or values.editors.families or ""
  end
  if label == "" then
    label = entry.key or ""
  end
  local year = values.year
  if label == "" and year == "" then
    return entry.key or ""
  elseif label == "" then
    return ("(%s)"):format(year)
  elseif year == "" then
    return ("(%s)"):format(label)
  end
  return ("(%s, %s)"):format(label, year)
end

---@param entry SnacksBibtexEntry
---@param values table
---@return string
local function build_apa_reference(entry, values)
  local fields = entry.fields or {}
  local segments = {}
  local contributor = values.authors.reference
  if contributor == "" then
    contributor = values.organization
  end
  if contributor == "" then
    contributor = values.editors.reference
  end
  local year = values.year
  if contributor ~= "" then
    if year ~= "" then
      segments[#segments + 1] = ("%s (%s)."):format(contributor, year)
    else
      segments[#segments + 1] = contributor .. "."
    end
  elseif year ~= "" then
    segments[#segments + 1] = ("(%s)."):format(year)
  end

  local title = latex_trim(fields.title)
  if title ~= "" then
    if not title:match("[%.!?]$") then
      title = title .. "."
    end
    segments[#segments + 1] = title
  end

  local entry_type = (entry.type or ""):lower()
  if entry_type == "article" or entry_type == "articleinpress" then
    local journal = latex_trim(fields.journal or fields.journaltitle or "")
    if journal ~= "" then
      local journal_segment = journal
      local volume = latex_trim(fields.volume)
      local issue = latex_trim(fields.number or fields.issue or "")
      local pages = normalize_page_range(fields.pages or fields.page or "")
      if volume ~= "" then
        journal_segment = journal_segment .. ", " .. volume
        if issue ~= "" then
          journal_segment = journal_segment .. "(" .. issue .. ")"
        end
      end
      if pages ~= "" then
        journal_segment = journal_segment .. ", " .. pages
      end
      if not journal_segment:match("[%.!?]$") then
        journal_segment = journal_segment .. "."
      end
      segments[#segments + 1] = journal_segment
    end
  elseif entry_type == "incollection" or entry_type == "inbook" or entry_type == "inproceedings" then
    local editors = values.editors.collection
    local booktitle = latex_trim(fields.booktitle)
    local pages = format_collection_pages(fields.pages or fields.page or "")
    local parts = {}
    if editors ~= "" then
      local label = (#values.editors.list > 1) and "(Eds.)," or "(Ed.),"
      parts[#parts + 1] = ("In %s %s"):format(editors, label)
    elseif booktitle ~= "" then
      parts[#parts + 1] = "In"
    end
    if booktitle ~= "" then
      local book_segment = booktitle
      if pages ~= "" then
        book_segment = ("%s (%s)"):format(book_segment, pages)
        pages = ""
      end
      parts[#parts + 1] = book_segment
    end
    if pages ~= "" then
      parts[#parts + 1] = ("%s"):format(pages)
    end
    if not vim.tbl_isempty(parts) then
      local sentence = table.concat(parts, " ")
      if not sentence:match("[%.!?]$") then
        sentence = sentence .. "."
      end
      segments[#segments + 1] = sentence
    end
    local publisher_segment = build_publisher_segment(latex_trim(fields.location or fields.address or ""), latex_trim(fields.publisher))
    if publisher_segment ~= "" then
      if not publisher_segment:match("[%.!?]$") then
        publisher_segment = publisher_segment .. "."
      end
      segments[#segments + 1] = publisher_segment
    end
  else
    local publisher_segment = build_publisher_segment(latex_trim(fields.location or fields.address or ""), latex_trim(fields.publisher))
    if publisher_segment ~= "" then
      if not publisher_segment:match("[%.!?]$") then
        publisher_segment = publisher_segment .. "."
      end
      segments[#segments + 1] = publisher_segment
    end
  end

  local doi = latex_trim(fields.doi)
  local url = latex_trim(fields.url)
  local link = doi ~= "" and ensure_link(doi) or url
  if link ~= "" then
    segments[#segments + 1] = link
  end

  return table.concat(segments, " ")
end

ensure_template_values = function(entry)
  if not entry then
    return nil
  end
  if entry._sb_template_values then
    return entry._sb_template_values
  end
  local fields = entry.fields or {}
  local authors = build_person_meta(parse_name_list(fields.author))
  local editors = build_person_meta(parse_name_list(fields.editor))
  local values = {
    authors = authors,
    editors = editors,
    organization = latex_trim(fields.organization or fields.institution or fields.publisher or ""),
    year = build_year_text(fields),
    title = latex_trim(fields.title),
    journal = latex_trim(fields.journal or fields.journaltitle or ""),
    booktitle = latex_trim(fields.booktitle or ""),
    publisher = latex_trim(fields.publisher or ""),
    location = latex_trim(fields.location or fields.address or ""),
    pages = normalize_page_range(fields.pages or fields.page or ""),
    pages_collection = format_collection_pages(fields.pages or fields.page or ""),
    volume = latex_trim(fields.volume or ""),
    issue = latex_trim(fields.number or fields.issue or ""),
    doi = latex_trim(fields.doi or ""),
    url = latex_trim(fields.url or ""),
    edition = latex_trim(fields.edition or ""),
    series = latex_trim(fields.series or ""),
  }
  values.apa = {
    in_text = build_apa_in_text(entry, values),
    reference = build_apa_reference(entry, values),
  }
  entry._sb_template_values = values
  return values
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

---Open a citation command picker that applies templates, renders previews, and produces highlight-aware list rows.
---The formatter returns explicit highlight segments so Snacks renders each column safely.
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
    local sample = apply_citation_template(entry, template, resolve_default_citation_template(cfg)) or ""
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
      sample = sample,
      preview = {
        text = sample ~= "" and sample or "(empty citation)",
        ft = "text",
      },
    }
  end

  snacks.picker({
    title = display.title or "Citation commands",
    items = items,
    format = function(item)
      local parts = {}
      local function append(text, hl)
        if not text or text == "" then
          return
        end
        if #parts > 0 then
          parts[#parts + 1] = { " " }
        end
        if hl then
          parts[#parts + 1] = { text, hl }
        else
          parts[#parts + 1] = { text }
        end
      end
      if show_command then
        append(item.command.command)
      end
      if show_packages and item.packages and item.packages ~= "" then
        append(("[%s]"):format(item.packages), "Comment")
      end
      if show_template and item.template and item.template ~= "" then
        append(item.template, "String")
      end
      if show_description and item.description and item.description ~= "" then
        append(item.description, "Comment")
      end
      if item.sample and item.sample ~= "" then
        append("→ " .. item.sample, "String")
      end
      if #parts == 0 then
        append(item.command.command)
      end
      return parts
    end,
    preview = "preview",
    actions = {
      apply_citation_command = function(picker, item)
        if not item or not item.command then
          return
        end
        local text = apply_citation_template(entry, item.command.template, resolve_default_citation_template(cfg))
        insert_text(parent_picker, text)
        record_entry_usage(entry.key)
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

---Open a citation format picker that applies templates, shows live previews, and surfaces human readable metadata in the list.
---The formatter returns explicit highlight segments so Snacks renders each column safely.
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
    local sample = apply_citation_template(entry, format.template, resolve_default_citation_template(cfg)) or ""
    items[#items + 1] = {
      format = format,
      text = table.concat(lines, " · "),
      label = format.name,
      description = format.description,
      category = format.category,
      locale = format.locale,
      sample = sample,
      preview = {
        text = sample ~= "" and sample or "(empty citation)",
        ft = "text",
      },
    }
  end

  snacks.picker({
    title = "Citation formats",
    items = items,
    format = function(item)
      local parts = {}
      local function append(text, hl)
        if not text or text == "" then
          return
        end
        if #parts > 0 then
          parts[#parts + 1] = { " " }
        end
        if hl then
          parts[#parts + 1] = { text, hl }
        else
          parts[#parts + 1] = { text }
        end
      end
      append(item.label)
      if item.category and item.category ~= "" then
        append(("[%s]"):format(item.category), "Comment")
      end
      if item.locale and item.locale ~= "" then
        append(("(%s)"):format(item.locale), "Comment")
      end
      if item.description and item.description ~= "" then
        append("— " .. item.description, "Comment")
      end
      if item.sample and item.sample ~= "" then
        append("→ " .. item.sample, "String")
      end
      return parts
    end,
    preview = "preview",
    actions = {
      apply_citation_format = function(picker, item)
        if not item or not item.format then
          return
        end
        local text = apply_citation_template(entry, item.format.template, resolve_default_citation_template(cfg))
        insert_text(parent_picker, text)
        record_entry_usage(entry.key)
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

---Append a searchable segment to the combined picker text and track its offsets.
---@param builder string[]
---@param segments table[]
---@param cursor integer
---@param field string
---@param value any
---@param priority integer
---@param opts? { normalized?: boolean }
---@return integer
local function append_search_segment(builder, segments, cursor, field, value, priority, opts)
  if value == nil then
    return cursor
  end
  local text = tostring(value)
  if text == "" then
    return cursor
  end
  if cursor > 0 then
    builder[#builder + 1] = " · "
    cursor = cursor + 3
  end
  local from = cursor + 1
  builder[#builder + 1] = text
  cursor = cursor + #text
  segments[#segments + 1] = {
    field = field,
    from = from,
    to = cursor,
    priority = priority,
    normalized = opts and opts.normalized or false,
  }
  return cursor
end

---Create a picker item enriched with history, segment metadata, and field priorities.
---@param entry SnacksBibtexEntry
---@param cfg SnacksBibtexResolvedConfig
---@param now integer
---@return table
local function make_item(entry, cfg, now)
  local fields = entry.fields or {}
  local priority_meta = cfg._match_priority or { map = {}, default = math.huge }
  local builder = {}
  local segments = {}
  local cursor = 0
  local function add_segment(field, value, opts)
    local priority = priority_meta.map[field] or priority_meta.default
    cursor = append_search_segment(builder, segments, cursor, field, value, priority, opts)
  end

  add_segment("key", entry.key)

  for _, name in ipairs(cfg.search_fields or {}) do
    local field_name = name:lower()
    local value = fields[field_name]
    if value and value ~= "" then
      add_segment(field_name, value)
      local normalized = latex_to_unicode(value)
      if normalized ~= "" and normalized ~= value then
        add_segment(field_name, normalized, { normalized = true })
      end
    end
  end

  local search_text = table.concat(builder)
  if search_text == "" then
    search_text = entry.key or ""
  end

  local preview = format_template(cfg.preview_format, entry)
  if preview == "" then
    preview = entry.key
  end
  local label = preview
  if preview ~= entry.key then
    label = ("%s — %s"):format(entry.key, preview)
  end
  local history_record = get_history_entry(entry.key)
  local item = {
    key = entry.key,
    type = entry.type,
    fields = fields,
    file = entry.file,
    raw = entry.raw,
    entry = entry,
    order = entry.order or 0,
    history = history_record,
    frecency = compute_frecency(history_record, now),
    text = search_text,
    label = label,
    preview = {
      text = entry.raw,
      ft = "bib",
    },
    _sb_segments = segments,
    _sb_priority_default = priority_meta.default,
    _sb_priority_map = priority_meta.map,
    _sb_match_priority = priority_meta.default,
  }

  for _, name in ipairs(cfg.search_fields or {}) do
    local field_name = name:lower()
    if not item[field_name] and fields[field_name] then
      item[field_name] = fields[field_name]
    end
  end

  item.key = item.key or ""

  return item
end

local function to_lines(text)
  local lines = vim.split(text, "\n", { plain = true })
  if #lines > 0 and lines[#lines] == "" then
    table.remove(lines)
  end
  return lines
end

---Reset the cached match metadata for the given item.
---@param item table
local function reset_match_priority(item)
  local default_priority = item._sb_priority_default or math.huge
  item._sb_match_priority = default_priority
  item._sb_match_field = nil
  item._sb_match_offset = nil
end

---Return the segment that contains the given match position.
---@param segments table[]
---@param pos integer
---@return table|nil, integer
local function segment_for_position(segments, pos)
  for _, segment in ipairs(segments) do
    if pos >= segment.from and pos <= segment.to then
      return segment, pos - segment.from
    end
  end
  return nil, math.huge
end

---Update the cached match priority for a specific field/offset combination.
---@param item table
---@param field string
---@param offset integer
local function apply_field_match(item, field, offset)
  local default_priority = item._sb_priority_default or math.huge
  local current_priority = item._sb_match_priority or default_priority
  local current_offset = item._sb_match_offset or math.huge
  local priority_map = item._sb_priority_map or {}
  local priority = priority_map[field] or default_priority
  if priority < current_priority or (priority == current_priority and offset < current_offset) then
    item._sb_match_priority = priority
    item._sb_match_field = field
    item._sb_match_offset = offset
  end
end

---Populate the cached match priority information using the matcher results.
---@param matcher snacks.picker.Matcher
---@param item table
local function update_match_priority(matcher, item)
  if not item or not item._sb_segments then
    return
  end
  reset_match_priority(item)
  if matcher:empty() then
    return
  end
  local positions_by_field = matcher:positions(item)
  if not positions_by_field then
    return
  end
  for field, positions in pairs(positions_by_field) do
    if type(positions) == "table" and #positions > 0 then
      if field == "text" then
        local segments = item._sb_segments
        if type(segments) == "table" and #segments > 0 then
          for _, pos in ipairs(positions) do
            local segment, offset = segment_for_position(segments, pos)
            if segment and segment.field then
              apply_field_match(item, segment.field, offset)
            end
          end
        end
      else
        apply_field_match(item, field, positions[1])
      end
    end
  end
end

---@param picker snacks.Picker|nil
---@param win integer
local function restore_origin_mode(picker, win)
  if not picker or not picker._snacks_bibtex_origin_mode then
    return
  end
  local mode = picker._snacks_bibtex_origin_mode
  if not insert_modes[mode] and not replace_modes[mode] then
    return
  end
  vim.schedule(function()
    if not vim.api.nvim_win_is_valid(win) then
      return
    end
    vim.api.nvim_set_current_win(win)
    local key
    if insert_modes[mode] then
      key = "a"
    elseif replace_modes[mode] then
      key = "R"
    end
    if not key then
      return
    end
    local term = vim.api.nvim_replace_termcodes(key, true, false, true)
    vim.api.nvim_feedkeys(term, "n", false)
  end)
end

---Insert `text` into the window where the picker was launched, falling back to the
---current picker main window when the origin is no longer available and restoring
---the caller's editing mode when applicable.
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
  restore_origin_mode(picker, win)
end

---Build a quick citation command action that records usage statistics.
---@param cfg SnacksBibtexResolvedConfig
---@param command_entry SnacksBibtexCitationCommand
---@return fun(picker: snacks.Picker, item: table)
local function make_quick_command_action(cfg, command_entry)
  return function(picker, item)
    if not item then
      return
    end
    local entry = item.entry or item
    local fallback = resolve_default_citation_template(cfg)
    local text = apply_citation_template(entry, command_entry.template, fallback)
    insert_text(picker, text)
    record_entry_usage(entry.key)
    picker:close()
  end
end

---Build a quick citation format action that records usage statistics.
---@param cfg SnacksBibtexResolvedConfig
---@param format_entry SnacksBibtexCitationFormat
---@return fun(picker: snacks.Picker, item: table)
local function make_quick_format_action(cfg, format_entry)
  return function(picker, item)
    if not item then
      return
    end
    local entry = item.entry or item
    local fallback = resolve_default_citation_template(cfg)
    local text = apply_citation_template(entry, format_entry.template, fallback)
    insert_text(picker, text)
    record_entry_usage(entry.key)
    picker:close()
  end
end

local function default_mappings_for_cfg(cfg)
  local mappings = {
    ["<CR>"] = "confirm",
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

---Create picker actions, ensure confirmation inserts into the source buffer, and
---track entry usage for frecency sorting.
---@param snacks snacks.picker
---@param cfg SnacksBibtexResolvedConfig
---@return table<string, snacks.picker.Action.spec>
local function make_actions(snacks, cfg)
  local actions = {}

  local function insert_key_action(picker, item)
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
    record_entry_usage(item.key)
    picker:close()
  end

  actions.insert_key = insert_key_action
  actions.confirm = insert_key_action

  actions.insert_entry = function(picker, item)
    if not item then
      return
    end
    insert_text(picker, item.raw)
    record_entry_usage(item.key)
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
      record_entry_usage(entry.key)
      picker:close()
      return
    end
    if #commands == 1 then
      local fallback_template = resolve_default_citation_template(cfg)
      local citation = apply_citation_template(entry, commands[1].template, fallback_template)
      insert_text(picker, citation)
      record_entry_usage(entry.key)
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
      record_entry_usage(entry.key)
      picker:close()
      return
    end
    if #formats == 1 then
      local fallback_template = resolve_default_citation_template(cfg)
      local text = apply_citation_template(entry, formats[1].template, fallback_template)
      insert_text(picker, text)
      record_entry_usage(entry.key)
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
    local entry_key = item.key
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
          record_entry_usage(entry_key)
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
  local now = os.time()
  for _, entry in ipairs(entries) do
    items[#items + 1] = make_item(entry, cfg, now)
  end
  apply_sort(items, cfg)

  local actions = make_actions(Snacks, cfg)
  local base_mappings = default_mappings_for_cfg(cfg)
  local mappings = normalize_mappings(base_mappings, cfg.mappings)
  mappings = normalize_mappings(mappings, per_call_mappings)
  local list_keys, input_keys = build_keymaps(actions, mappings, cfg)

  local origin_win = vim.api.nvim_get_current_win()
  local mode_info = vim.api.nvim_get_mode()
  local origin_mode = mode_info and mode_info.mode or nil
  local matcher_opts = {}
  local user_matcher_on_match
  if picker_opts_user and picker_opts_user.matcher then
    local user_matcher = vim.deepcopy(picker_opts_user.matcher)
    user_matcher_on_match = user_matcher.on_match
    user_matcher.on_match = nil
    matcher_opts = vim.tbl_deep_extend("force", matcher_opts, user_matcher)
    picker_opts_user.matcher = nil
  end
  local existing_on_match = matcher_opts.on_match
  matcher_opts.on_match = function(matcher, item)
    update_match_priority(matcher, item)
    if existing_on_match then
      existing_on_match(matcher, item)
    end
    if user_matcher_on_match then
      user_matcher_on_match(matcher, item)
    end
  end
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
    sort = make_match_sorter(cfg),
    matcher = matcher_opts,
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
      picker._snacks_bibtex_origin_mode = origin_mode
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
