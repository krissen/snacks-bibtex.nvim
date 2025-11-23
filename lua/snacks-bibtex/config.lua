local M = {}

---@class SnacksBibtexCitationCommand
---@field command string
---@field template string
---@field description? string
---@field packages? string|string[]
---@field enabled? boolean
---@field id? string

---@class SnacksBibtexCitationFormat
---@field id string
---@field name string
---@field template string
---@field description? string
---@field category? "in_text"|"reference"|string
---@field locale? string
---@field enabled? boolean

---@alias SnacksBibtexMapping string|fun(picker: snacks.Picker, item: snacks.picker.Item)|snacks.picker.Action.spec

---@alias SnacksBibtexResolvedConfig SnacksBibtexConfig

---@class SnacksBibtexSortSpec
---@field field string
---@field direction? "asc"|"desc"|"ascending"|"descending"

local defaults ---@type SnacksBibtexConfig

---@class SnacksBibtexMatchPriority
---@field map table<string, integer>
---@field order string[]
---@field default integer
---@field raw string[]

---@class SnacksBibtexDisplayConfig
---@field show_key boolean Whether to show the citation key in the picker list
---@field show_preview boolean Whether to show the formatted preview in the picker list
---@field key_separator string Separator between key and preview when both are shown
---@field preview_fields string[]|nil Optional list of field names to show in preview (overrides preview_format)
---@field preview_fields_separator string Separator between preview fields when preview_fields is used

---@class SnacksBibtexConfig
---@field depth integer|nil Directory recursion depth for local bib search
---@field files string[]|nil Explicit list of project-local bib files
---@field global_files string[]|nil List of global bib files (outside project)
---@field context boolean|nil Enable context-aware bibliography file detection from current buffer (default: false)
---@field context_fallback boolean|nil When context=true and no context found: true=fall back to project search, false=show no entries (default: true)
---@field search_fields string[] Ordered list of fields to search (e.g. {"author","title","year","keywords"})
---@field format string Default format for inserting citation keys or labels
---@field preview_format string Template used to format the preview line(s)
---@field citation_format? string Template used when inserting formatted citations
---@field default_citation_format? string Identifier of the default citation format template
---@field citation_format_defaults? { in_text?: string, reference?: string } Default citation format identifiers per usage
---@field match_priority string[]|nil Ordered list of fields prioritised when ranking matches
---@field citation_command_picker? { title?: string, command?: boolean, description?: boolean, packages?: boolean, template?: boolean } Citation command picker presentation settings
---@field display? SnacksBibtexDisplayConfig Display settings for picker entries
---@field mappings table<string, SnacksBibtexMapping>|nil Custom action mappings for the picker
---@field citation_commands SnacksBibtexCitationCommand[] Available citation templates
---@field citation_formats SnacksBibtexCitationFormat[] Available citation format templates
---@field locale string Preferred locale for textual formats
---@field sort SnacksBibtexSortSpec|SnacksBibtexSortSpec[]|nil Sorting rules for the initial picker entries
---@field match_sort SnacksBibtexSortSpec|SnacksBibtexSortSpec[]|nil Sorting rules applied when the query is non-empty

local function deepcopy(tbl)
  return vim.deepcopy(tbl)
end

---@param value any
---@return string|nil
local function sanitize_identifier(value)
  if type(value) ~= "string" or value == "" then
    return nil
  end
  local ident = value:gsub("\\", ""):gsub("[^%w]+", "_")
  ident = ident:gsub("^_+", ""):gsub("_+$", "")
  if ident == "" then
    return nil
  end
  return ident:lower()
end

---@param list table[]|nil
---@param get_source fun(item: table): string|nil
---@param prefix string
local function assign_ids(list, get_source, prefix)
  if not list then
    return
  end
  local seen = {} ---@type table<string, boolean>
  for index, item in ipairs(list) do
    if type(item) == "table" then
      local id = item.id
      if not id then
        id = sanitize_identifier(get_source(item) or "")
      end
      if not id or seen[id] then
        local suffix = index
        repeat
          id = ("%s_%d"):format(prefix, suffix)
          suffix = suffix + 1
        until not seen[id]
      end
      item.id = id
      seen[id] = true
    end
  end
end

local function normalize_citation_commands(list)
  assign_ids(list, function(item)
    return item.command or item.template
  end, "command")
end

local function normalize_citation_formats(list)
  if not list then
    return
  end
  assign_ids(list, function(item)
    return item.id or item.name or item.template
  end, "format")
  for _, item in ipairs(list) do
    if type(item) == "table" then
      item.locale = item.locale or "en"
    end
  end
end

---@param files string[]|nil
---@return string[]|nil
local function normalize_files(files)
  if not files then
    return nil
  end
  local ret = {}
  local seen = {} ---@type table<string, boolean>
  for _, file in ipairs(files) do
    if type(file) == "string" and file ~= "" then
      local expanded = file
      -- Expand user paths such as "~/library.bib" or "$HOME/library.bib" so uv.fs_open can resolve them.
      if expanded:find("[~$]") then
        local ok, result = pcall(vim.fn.expand, expanded)
        if ok and type(result) == "string" and result ~= "" then
          expanded = result
        end
      end
      local normalized = vim.fs.normalize(expanded)
      if not seen[normalized] then
        seen[normalized] = true
        ret[#ret + 1] = normalized
      end
    end
  end
  return ret
end

local function normalize_sort_direction(direction)
  if type(direction) ~= "string" then
    return "asc"
  end
  direction = direction:lower()
  if direction == "descending" then
    direction = "desc"
  elseif direction == "ascending" then
    direction = "asc"
  end
  if direction ~= "desc" then
    return "asc"
  end
  return direction
end

---@param sort SnacksBibtexSortSpec|SnacksBibtexSortSpec[]|nil
---@return SnacksBibtexSortSpec[]
local function normalize_sort(sort)
  if not sort then
    return {}
  end
  local list = {}
  if sort.field or sort.direction then
    list = { sort }
  elseif type(sort) == "table" then
    list = sort
  end
  local normalized = {}
  for _, item in ipairs(list) do
    if type(item) == "string" then
      normalized[#normalized + 1] = { field = item:lower(), direction = "asc" }
    elseif type(item) == "table" and item.field then
      normalized[#normalized + 1] = {
        field = item.field:lower(),
        direction = normalize_sort_direction(item.direction),
      }
    end
  end
  return normalized
end

local function ensure_match_sort(sort, base)
  local normalized = normalize_sort(sort)
  if vim.tbl_isempty(normalized) then
    normalized = vim.deepcopy(base or {})
  end
  local has_score = false
  local has_priority = false
  for _, rule in ipairs(normalized) do
    if type(rule) == "table" and rule.field == "score" then
      has_score = true
    elseif type(rule) == "table" and rule.field == "match_priority" then
      has_priority = true
    end
  end
  if not has_score then
    table.insert(normalized, 1, { field = "score", direction = "desc" })
  end
  if not has_priority then
    local insert_at = #normalized + 1
    for idx, rule in ipairs(normalized) do
      if rule.field == "score" then
        insert_at = idx + 1
        break
      end
    end
    table.insert(normalized, insert_at, { field = "match_priority", direction = "asc" })
  end
  return normalized
end

---@param list string[]|nil
---@return string[]|nil
local function normalize_field_list(list)
  if not list then
    return nil
  end
  local ret = {}
  for _, value in ipairs(list) do
    if type(value) == "string" and value ~= "" then
      ret[#ret + 1] = value:lower()
    end
  end
  return ret
end

---@param priority string[]|nil
---@param search_fields string[]|nil
---@return SnacksBibtexMatchPriority
local function normalize_match_priority(priority, search_fields)
  local order = {}
  local seen = {} ---@type table<string, boolean>
  local function add(field)
    if type(field) ~= "string" or field == "" then
      return
    end
    local key = field:lower()
    if seen[key] then
      return
    end
    seen[key] = true
    order[#order + 1] = key
  end

  add("key")
  for _, field in ipairs(priority or {}) do
    add(field)
  end
  for _, field in ipairs(search_fields or {}) do
    add(field)
  end
  add("text")

  local map = {} ---@type table<string, integer>
  for idx, field in ipairs(order) do
    map[field] = idx
  end

  return {
    map = map,
    order = order,
    default = #order + 1,
    raw = priority or {},
  }
end

---@param value any
---@param default string
---@return string
local function normalize_separator(value, default)
  return type(value) == "string" and value ~= "" and value or default
end

---@param display SnacksBibtexDisplayConfig|nil
---@return SnacksBibtexDisplayConfig
local function normalize_display(display)
  if not display then
    return {
      show_key = true,
      show_preview = true,
      key_separator = " — ",
      preview_fields = nil,
      preview_fields_separator = " — ",
    }
  end
  local normalized = {
    show_key = (display.show_key ~= nil and type(display.show_key) == "boolean") and display.show_key or true,
    show_preview = (display.show_preview ~= nil and type(display.show_preview) == "boolean") and display.show_preview
      or true,
    key_separator = normalize_separator(display.key_separator, " — "),
    preview_fields = (type(display.preview_fields) == "table") and display.preview_fields or nil,
    preview_fields_separator = normalize_separator(display.preview_fields_separator, " — "),
  }
  if normalized.preview_fields ~= nil then
    -- Filter out empty strings but preserve case for field names
    local fields = {}
    for _, field in ipairs(normalized.preview_fields) do
      if type(field) == "string" and field ~= "" then
        fields[#fields + 1] = field
      end
    end
    normalized.preview_fields = #fields > 0 and fields or nil
  end
  return normalized
end

---@param cfg SnacksBibtexConfig
local function apply_match_priority(cfg)
  cfg.search_fields = normalize_field_list(cfg.search_fields) or cfg.search_fields
  cfg.match_priority = normalize_field_list(cfg.match_priority)
  cfg._match_priority = normalize_match_priority(cfg.match_priority, cfg.search_fields)
end

---@return SnacksBibtexConfig
local function init_defaults()
  defaults = {
    depth = 1,
    files = nil,
    global_files = {},
    context = false,
    context_fallback = true,
    search_fields = { "author", "year", "title", "journal", "journaltitle", "editor" },
    match_priority = { "author", "year", "title" },
    format = "%s",
    preview_format = "{{authors.reference}} ({{year}}) — {{title}}",
    citation_format = "{{apa.in_text}}",
    default_citation_format = "apa7_in_text",
    citation_format_defaults = {
      in_text = "apa7_in_text",
      reference = "apa7_reference",
    },
    citation_command_picker = {
      title = "Citation commands",
      command = true,
      description = true,
      packages = true,
      template = false,
    },
    display = {
      show_key = true,
      show_preview = true,
      key_separator = " — ",
      preview_fields = nil,
      preview_fields_separator = " — ",
    },
    sort = {
      { field = "frecency", direction = "desc" },
      { field = "author", direction = "asc" },
      { field = "year", direction = "asc" },
      { field = "source", direction = "asc" },
    },
    match_sort = nil,
    locale = "en",
    mappings = {},
    citation_commands = {
      -- LaTeX / BibTeX
      {
        command = "\\cite",
        template = "\\cite{{{key}}}",
        description = "Generic citation (BibTeX/BibLaTeX)",
        packages = { "bibtex", "biblatex" },
        enabled = true,
      },
      {
        command = "\\Cite",
        template = "\\Cite{{{key}}}",
        description = "Sentence-leading generic citation",
        packages = "biblatex",
        enabled = false,
      },
      {
        command = "\\cite*",
        template = "\\cite*{{{key}}}",
        description = "Generic citation with full author list",
        packages = { "bibtex", "biblatex" },
        enabled = false,
      },
      {
        command = "\\Cite*",
        template = "\\Cite*{{{key}}}",
        description = "Sentence-leading generic citation (full list)",
        packages = "biblatex",
        enabled = false,
      },
      -- natbib
      {
        command = "\\citet",
        template = "\\citet{{{key}}}",
        description = "Textual citation (natbib)",
        packages = "natbib",
        enabled = true,
      },
      {
        command = "\\citet*",
        template = "\\citet*{{{key}}}",
        description = "Textual citation with full author list",
        packages = "natbib",
        enabled = false,
      },
      {
        command = "\\Citet",
        template = "\\Citet{{{key}}}",
        description = "Sentence-leading textual citation",
        packages = "natbib",
        enabled = false,
      },
      {
        command = "\\citep",
        template = "\\citep{{{key}}}",
        description = "Parenthetical citation (natbib)",
        packages = "natbib",
        enabled = true,
      },
      {
        command = "\\citep*",
        template = "\\citep*{{{key}}}",
        description = "Parenthetical citation with full author list",
        packages = "natbib",
        enabled = false,
      },
      {
        command = "\\Citep",
        template = "\\Citep{{{key}}}",
        description = "Sentence-leading parenthetical citation",
        packages = "natbib",
        enabled = false,
      },
      {
        command = "\\citealt",
        template = "\\citealt{{{key}}}",
        description = "Textual citation without parentheses",
        packages = "natbib",
        enabled = false,
      },
      {
        command = "\\citealt*",
        template = "\\citealt*{{{key}}}",
        description = "Textual citation without parentheses (full list)",
        packages = "natbib",
        enabled = false,
      },
      {
        command = "\\Citealt",
        template = "\\Citealt{{{key}}}",
        description = "Capitalized textual citation without parentheses",
        packages = "natbib",
        enabled = false,
      },
      {
        command = "\\citealp",
        template = "\\citealp{{{key}}}",
        description = "Parenthetical citation without outer parentheses",
        packages = "natbib",
        enabled = false,
      },
      {
        command = "\\citealp*",
        template = "\\citealp*{{{key}}}",
        description = "Parenthetical citation without outer parentheses (full list)",
        packages = "natbib",
        enabled = false,
      },
      {
        command = "\\Citealp",
        template = "\\Citealp{{{key}}}",
        description = "Capitalized citation without outer parentheses",
        packages = "natbib",
        enabled = false,
      },
      {
        command = "\\citeauthor",
        template = "\\citeauthor{{{key}}}",
        description = "Author(s) only",
        packages = { "natbib", "biblatex" },
        enabled = true,
      },
      {
        command = "\\citeauthor*",
        template = "\\citeauthor*{{{key}}}",
        description = "Author(s) with full list",
        packages = { "natbib", "biblatex" },
        enabled = false,
      },
      {
        command = "\\Citeauthor",
        template = "\\Citeauthor{{{key}}}",
        description = "Sentence-leading author citation",
        packages = "biblatex",
        enabled = false,
      },
      {
        command = "\\Citeauthor*",
        template = "\\Citeauthor*{{{key}}}",
        description = "Sentence-leading author citation (full list)",
        packages = "biblatex",
        enabled = false,
      },
      {
        command = "\\citeyear",
        template = "\\citeyear{{{key}}}",
        description = "Year only",
        packages = { "natbib", "biblatex" },
        enabled = true,
      },
      {
        command = "\\citeyear*",
        template = "\\citeyear*{{{key}}}",
        description = "Year with extra detail",
        packages = { "natbib", "biblatex" },
        enabled = false,
      },
      {
        command = "\\citeyearpar",
        template = "\\citeyearpar{{{key}}}",
        description = "Year in parentheses (natbib)",
        packages = "natbib",
        enabled = false,
      },
      {
        command = "\\citetitle",
        template = "\\citetitle{{{key}}}",
        description = "Work title",
        packages = "biblatex",
        enabled = false,
      },
      {
        command = "\\citetitle*",
        template = "\\citetitle*{{{key}}}",
        description = "Work title without disambiguation",
        packages = "biblatex",
        enabled = false,
      },
      {
        command = "\\Citetitle",
        template = "\\Citetitle{{{key}}}",
        description = "Sentence-leading work title",
        packages = "biblatex",
        enabled = false,
      },
      {
        command = "\\Citetitle*",
        template = "\\Citetitle*{{{key}}}",
        description = "Sentence-leading work title (no disambiguation)",
        packages = "biblatex",
        enabled = false,
      },
      {
        command = "\\citeurl",
        template = "\\citeurl{{{key}}}",
        description = "URL only",
        packages = "biblatex",
        enabled = false,
      },
      {
        command = "\\citeurldate",
        template = "\\citeurldate{{{key}}}",
        description = "URL access date",
        packages = "biblatex",
        enabled = false,
      },
      {
        command = "\\citedate",
        template = "\\citedate{{{key}}}",
        description = "Date field",
        packages = "biblatex",
        enabled = false,
      },
      {
        command = "\\citedate*",
        template = "\\citedate*{{{key}}}",
        description = "Date field (untruncated)",
        packages = "biblatex",
        enabled = false,
      },
      {
        command = "\\Citedate",
        template = "\\Citedate{{{key}}}",
        description = "Sentence-leading date field",
        packages = "biblatex",
        enabled = false,
      },
      {
        command = "\\Citedate*",
        template = "\\Citedate*{{{key}}}",
        description = "Sentence-leading date field (untruncated)",
        packages = "biblatex",
        enabled = false,
      },
      {
        command = "\\parencite",
        template = "\\parencite{{{key}}}",
        description = "Parenthetical citation (biblatex)",
        packages = "biblatex",
        enabled = true,
      },
      {
        command = "\\Parencite",
        template = "\\Parencite{{{key}}}",
        description = "Sentence-leading parenthetical citation",
        packages = "biblatex",
        enabled = false,
      },
      {
        command = "\\parencite*",
        template = "\\parencite*{{{key}}}",
        description = "Parenthetical citation (full list)",
        packages = "biblatex",
        enabled = false,
      },
      {
        command = "\\Parencite*",
        template = "\\Parencite*{{{key}}}",
        description = "Sentence-leading parenthetical citation (full list)",
        packages = "biblatex",
        enabled = false,
      },
      {
        command = "\\footcite",
        template = "\\footcite{{{key}}}",
        description = "Footnote citation",
        packages = "biblatex",
        enabled = true,
      },
      {
        command = "\\Footcite",
        template = "\\Footcite{{{key}}}",
        description = "Sentence-leading footnote citation",
        packages = "biblatex",
        enabled = false,
      },
      {
        command = "\\footcite*",
        template = "\\footcite*{{{key}}}",
        description = "Footnote citation (full list)",
        packages = "biblatex",
        enabled = false,
      },
      {
        command = "\\Footcite*",
        template = "\\Footcite*{{{key}}}",
        description = "Sentence-leading footnote citation (full list)",
        packages = "biblatex",
        enabled = false,
      },
      {
        command = "\\footcitetext",
        template = "\\footcitetext{{{key}}}",
        description = "Footnote citation without marker",
        packages = "biblatex",
        enabled = false,
      },
      {
        command = "\\footfullcite",
        template = "\\footfullcite{{{key}}}",
        description = "Full footnote citation",
        packages = "biblatex",
        enabled = false,
      },
      {
        command = "\\textcite",
        template = "\\textcite{{{key}}}",
        description = "Textual citation (biblatex)",
        packages = "biblatex",
        enabled = true,
      },
      {
        command = "\\Textcite",
        template = "\\Textcite{{{key}}}",
        description = "Sentence-leading textual citation",
        packages = "biblatex",
        enabled = false,
      },
      {
        command = "\\textcite*",
        template = "\\textcite*{{{key}}}",
        description = "Textual citation (full list)",
        packages = "biblatex",
        enabled = false,
      },
      {
        command = "\\Textcite*",
        template = "\\Textcite*{{{key}}}",
        description = "Sentence-leading textual citation (full list)",
        packages = "biblatex",
        enabled = false,
      },
      {
        command = "\\smartcite",
        template = "\\smartcite{{{key}}}",
        description = "Auto style citation",
        packages = "biblatex",
        enabled = false,
      },
      {
        command = "\\Smartcite",
        template = "\\Smartcite{{{key}}}",
        description = "Sentence-leading auto citation",
        packages = "biblatex",
        enabled = false,
      },
      {
        command = "\\smartcite*",
        template = "\\smartcite*{{{key}}}",
        description = "Auto style citation (full list)",
        packages = "biblatex",
        enabled = false,
      },
      {
        command = "\\Smartcite*",
        template = "\\Smartcite*{{{key}}}",
        description = "Sentence-leading auto citation (full list)",
        packages = "biblatex",
        enabled = false,
      },
      {
        command = "\\autocite",
        template = "\\autocite{{{key}}}",
        description = "Context sensitive citation",
        packages = "biblatex",
        enabled = true,
      },
      {
        command = "\\Autocite",
        template = "\\Autocite{{{key}}}",
        description = "Sentence-leading context citation",
        packages = "biblatex",
        enabled = false,
      },
      {
        command = "\\autocite*",
        template = "\\autocite*{{{key}}}",
        description = "Context citation (full list)",
        packages = "biblatex",
        enabled = false,
      },
      {
        command = "\\Autocite*",
        template = "\\Autocite*{{{key}}}",
        description = "Sentence-leading context citation (full list)",
        packages = "biblatex",
        enabled = false,
      },
      {
        command = "\\supercite",
        template = "\\supercite{{{key}}}",
        description = "Superscript citation",
        packages = "biblatex",
        enabled = false,
      },
      {
        command = "\\Supercite",
        template = "\\Supercite{{{key}}}",
        description = "Sentence-leading superscript citation",
        packages = "biblatex",
        enabled = false,
      },
      {
        command = "\\nocite",
        template = "\\nocite{{{key}}}",
        description = "Add to bibliography only",
        packages = { "bibtex", "biblatex" },
        enabled = true,
      },
      {
        command = "\\fullcite",
        template = "\\fullcite{{{key}}}",
        description = "Full citation",
        packages = "biblatex",
        enabled = true,
      },
      {
        command = "\\volcite",
        template = "\\volcite{{{key}}}",
        description = "Volume citation",
        packages = "biblatex",
        enabled = false,
      },
      {
        command = "\\pvolcite",
        template = "\\pvolcite{{{key}}}",
        description = "Volume citation with pages",
        packages = "biblatex",
        enabled = false,
      },
      {
        command = "\\fvolcite",
        template = "\\fvolcite{{{key}}}",
        description = "Volume citation with floors",
        packages = "biblatex",
        enabled = false,
      },
      {
        command = "\\svolcite",
        template = "\\svolcite{{{key}}}",
        description = "Supplementary volume citation",
        packages = "biblatex",
        enabled = false,
      },
      {
        command = "\\volcites",
        template = "\\volcites{{{key}}}",
        description = "Multiple volume citations",
        packages = "biblatex",
        enabled = false,
      },
      {
        command = "\\pvolcites",
        template = "\\pvolcites{{{key}}}",
        description = "Multiple volume citations with pages",
        packages = "biblatex",
        enabled = false,
      },
      {
        command = "\\fvolcites",
        template = "\\fvolcites{{{key}}}",
        description = "Multiple volume citations with floors",
        packages = "biblatex",
        enabled = false,
      },
      {
        command = "\\svolcites",
        template = "\\svolcites{{{key}}}",
        description = "Multiple supplementary volume citations",
        packages = "biblatex",
        enabled = false,
      },
      {
        command = "\\cites",
        template = "\\cites{{{key}}}",
        description = "Multiple citations",
        packages = { "natbib", "biblatex" },
        enabled = false,
      },
      {
        command = "\\Cites",
        template = "\\Cites{{{key}}}",
        description = "Sentence-leading multiple citations",
        packages = "biblatex",
        enabled = false,
      },
      {
        command = "\\parencites",
        template = "\\parencites{{{key}}}",
        description = "Multiple parenthetical citations",
        packages = "biblatex",
        enabled = false,
      },
      {
        command = "\\Parencites",
        template = "\\Parencites{{{key}}}",
        description = "Sentence-leading multiple parenthetical citations",
        packages = "biblatex",
        enabled = false,
      },
      {
        command = "\\footcites",
        template = "\\footcites{{{key}}}",
        description = "Multiple footnote citations",
        packages = "biblatex",
        enabled = false,
      },
      {
        command = "\\Footcites",
        template = "\\Footcites{{{key}}}",
        description = "Sentence-leading multiple footnote citations",
        packages = "biblatex",
        enabled = false,
      },
      {
        command = "\\textcites",
        template = "\\textcites{{{key}}}",
        description = "Multiple textual citations",
        packages = "biblatex",
        enabled = false,
      },
      {
        command = "\\Textcites",
        template = "\\Textcites{{{key}}}",
        description = "Sentence-leading multiple textual citations",
        packages = "biblatex",
        enabled = false,
      },
      {
        command = "\\smartcites",
        template = "\\smartcites{{{key}}}",
        description = "Multiple auto style citations",
        packages = "biblatex",
        enabled = false,
      },
      {
        command = "\\Smartcites",
        template = "\\Smartcites{{{key}}}",
        description = "Sentence-leading multiple auto style citations",
        packages = "biblatex",
        enabled = false,
      },
      {
        command = "\\autocites",
        template = "\\autocites{{{key}}}",
        description = "Multiple context citations",
        packages = "biblatex",
        enabled = false,
      },
      {
        command = "\\Autocites",
        template = "\\Autocites{{{key}}}",
        description = "Sentence-leading multiple context citations",
        packages = "biblatex",
        enabled = false,
      },
      {
        command = "\\supercites",
        template = "\\supercites{{{key}}}",
        description = "Multiple superscript citations",
        packages = "biblatex",
        enabled = false,
      },
      {
        command = "\\Supercites",
        template = "\\Supercites{{{key}}}",
        description = "Sentence-leading multiple superscript citations",
        packages = "biblatex",
        enabled = false,
      },
      {
        command = "\\nocites",
        template = "\\nocites{{{key}}}",
        description = "Multiple bibliography-only entries",
        packages = "biblatex",
        enabled = false,
      },
      {
        command = "\\fullcites",
        template = "\\fullcites{{{key}}}",
        description = "Multiple full citations",
        packages = "biblatex",
        enabled = false,
      },
      {
        command = "\\footfullcites",
        template = "\\footfullcites{{{key}}}",
        description = "Multiple full footnote citations",
        packages = "biblatex",
        enabled = false,
      },
      -- Typst
      {
        command = "@key",
        template = "@{{key}}",
        description = "Basic citation (Typst)",
        packages = "typst",
        enabled = true,
      },
      {
        command = "@key[supplement]",
        template = "@{{key}}[]",
        description = "Citation with supplement (Typst)",
        packages = "typst",
        enabled = true,
      },
    },
    citation_formats = {
      {
        id = "apa7_in_text",
        name = "APA 7 (in-text, English)",
        template = "{{apa.in_text}}",
        description = "APA 7th edition in-text citation",
        category = "in_text",
        locale = "en",
        enabled = true,
      },
      {
        id = "apa7_reference",
        name = "APA 7 (reference list, English)",
        template = "{{apa.reference}}",
        description = "APA 7th edition reference entry",
        category = "reference",
        locale = "en",
        enabled = true,
      },
      {
        id = "harvard_in_text",
        name = "Harvard (in-text, English)",
        template = "{{authors.in_text}} {{year}}",
        description = "Harvard style in-text citation",
        category = "in_text",
        locale = "en",
        enabled = true,
      },
      {
        id = "harvard_reference",
        name = "Harvard (reference list, English)",
        template = "{{authors.reference}}. {{year}}. {{title}}. {{journal}}.",
        description = "Harvard style reference entry",
        category = "reference",
        locale = "en",
        enabled = true,
      },
      {
        id = "oxford_reference",
        name = "Oxford (reference list, English)",
        template = "{{authors.reference}}, {{title}} ({{publisher}}, {{year}})",
        description = "Oxford style bibliography entry",
        category = "reference",
        locale = "en",
        enabled = true,
      },
    },
  }
  normalize_citation_commands(defaults.citation_commands)
  normalize_citation_formats(defaults.citation_formats)
  defaults.sort = normalize_sort(defaults.sort)
  defaults.match_sort = ensure_match_sort(defaults.match_sort, defaults.sort)
  apply_match_priority(defaults)
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
  merged.display = normalize_display(merged.display)
  normalize_citation_commands(merged.citation_commands)
  normalize_citation_formats(merged.citation_formats)
  merged.sort = normalize_sort(merged.sort)
  merged.match_sort = ensure_match_sort(merged.match_sort, merged.sort)
  apply_match_priority(merged)
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
  merged.display = normalize_display(merged.display)
  normalize_citation_commands(merged.citation_commands)
  normalize_citation_formats(merged.citation_formats)
  merged.sort = normalize_sort(merged.sort)
  merged.match_sort = ensure_match_sort(merged.match_sort, merged.sort)
  apply_match_priority(merged)
  return merged
end

---Expose the identifier normaliser so callers extending commands or formats can
---reuse snacks-bibtex's naming rules.
---@type fun(value: any): string|nil
M.sanitize_identifier = sanitize_identifier

return M
