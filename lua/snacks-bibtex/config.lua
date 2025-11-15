local M = {}

---@class SnacksBibtexConfig
---@field depth integer|nil           # directory recursion depth for local bib search
---@field files string[]|nil          # explicit list of project-local bib files
---@field global_files string[]|nil   # list of global bib files (outside project)
---@field search_fields string[]      # ordered list of fields to search (e.g. {"author","title","year","keywords"})
---@field format string               # default format for inserting citation keys / labels
---@field preview_format string       # how to format the preview line(s)
---@field citation_format? string     # template used when inserting formatted citations
---@field default_citation_format? string  # id of the default citation format template
---@field citation_format_defaults? { in_text?: string, reference?: string }
---@field citation_command_picker? { title?: string, command?: boolean, description?: boolean, packages?: boolean, template?: boolean }
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

---@field mappings table<string, SnacksBibtexMapping>|nil  # custom action mappings for the picker
---@field citation_commands SnacksBibtexCitationCommand[]  # available citation templates
---@field citation_formats SnacksBibtexCitationFormat[]    # available citation format templates
---@field locale string                                    # preferred locale for textual formats

---@alias SnacksBibtexMapping string|fun(picker: snacks.Picker, item: snacks.picker.Item)|snacks.picker.Action.spec

---@alias SnacksBibtexResolvedConfig SnacksBibtexConfig

local defaults ---@type SnacksBibtexConfig

local function deepcopy(tbl)
  return vim.deepcopy(tbl)
end

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
  assign_ids(list, function(item)
    return item.id or item.name or item.template
  end, "format")
  if not list then
    return
  end
  for _, item in ipairs(list) do
    if type(item) == "table" then
      item.locale = item.locale or "en"
    end
  end
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
    format = "%s",
    preview_format = "{{author}} ({{year}}), {{title}}",
    citation_format = "{{author}} ({{year}})",
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
    locale = "en",
    mappings = {},
    citation_commands = {
      -- LaTeX / BibTeX
      {
        command = "\\cite",
        template = "\\cite{ {{key}} }",
        description = "Generic citation (BibTeX/BibLaTeX)",
        packages = { "bibtex", "biblatex" },
        enabled = true,
      },
      {
        command = "\\Cite",
        template = "\\Cite{ {{key}} }",
        description = "Sentence-leading generic citation",
        packages = "biblatex",
        enabled = false,
      },
      {
        command = "\\cite*",
        template = "\\cite*{ {{key}} }",
        description = "Generic citation with full author list",
        packages = { "bibtex", "biblatex" },
        enabled = false,
      },
      {
        command = "\\Cite*",
        template = "\\Cite*{ {{key}} }",
        description = "Sentence-leading generic citation (full list)",
        packages = "biblatex",
        enabled = false,
      },
      -- natbib
      {
        command = "\\citet",
        template = "\\citet{ {{key}} }",
        description = "Textual citation (natbib)",
        packages = "natbib",
        enabled = true,
      },
      {
        command = "\\citet*",
        template = "\\citet*{ {{key}} }",
        description = "Textual citation with full author list",
        packages = "natbib",
        enabled = false,
      },
      {
        command = "\\Citet",
        template = "\\Citet{ {{key}} }",
        description = "Sentence-leading textual citation",
        packages = "natbib",
        enabled = false,
      },
      {
        command = "\\citep",
        template = "\\citep{ {{key}} }",
        description = "Parenthetical citation (natbib)",
        packages = "natbib",
        enabled = true,
      },
      {
        command = "\\citep*",
        template = "\\citep*{ {{key}} }",
        description = "Parenthetical citation with full author list",
        packages = "natbib",
        enabled = false,
      },
      {
        command = "\\Citep",
        template = "\\Citep{ {{key}} }",
        description = "Sentence-leading parenthetical citation",
        packages = "natbib",
        enabled = false,
      },
      {
        command = "\\citealt",
        template = "\\citealt{ {{key}} }",
        description = "Textual citation without parentheses",
        packages = "natbib",
        enabled = false,
      },
      {
        command = "\\citealt*",
        template = "\\citealt*{ {{key}} }",
        description = "Textual citation without parentheses (full list)",
        packages = "natbib",
        enabled = false,
      },
      {
        command = "\\Citealt",
        template = "\\Citealt{ {{key}} }",
        description = "Capitalized textual citation without parentheses",
        packages = "natbib",
        enabled = false,
      },
      {
        command = "\\citealp",
        template = "\\citealp{ {{key}} }",
        description = "Parenthetical citation without outer parentheses",
        packages = "natbib",
        enabled = false,
      },
      {
        command = "\\citealp*",
        template = "\\citealp*{ {{key}} }",
        description = "Parenthetical citation without outer parentheses (full list)",
        packages = "natbib",
        enabled = false,
      },
      {
        command = "\\Citealp",
        template = "\\Citealp{ {{key}} }",
        description = "Capitalized citation without outer parentheses",
        packages = "natbib",
        enabled = false,
      },
      {
        command = "\\citeauthor",
        template = "\\citeauthor{ {{key}} }",
        description = "Author(s) only",
        packages = { "natbib", "biblatex" },
        enabled = true,
      },
      {
        command = "\\citeauthor*",
        template = "\\citeauthor*{ {{key}} }",
        description = "Author(s) with full list",
        packages = { "natbib", "biblatex" },
        enabled = false,
      },
      {
        command = "\\Citeauthor",
        template = "\\Citeauthor{ {{key}} }",
        description = "Sentence-leading author citation",
        packages = "biblatex",
        enabled = false,
      },
      {
        command = "\\Citeauthor*",
        template = "\\Citeauthor*{ {{key}} }",
        description = "Sentence-leading author citation (full list)",
        packages = "biblatex",
        enabled = false,
      },
      {
        command = "\\citeyear",
        template = "\\citeyear{ {{key}} }",
        description = "Year only",
        packages = { "natbib", "biblatex" },
        enabled = true,
      },
      {
        command = "\\citeyear*",
        template = "\\citeyear*{ {{key}} }",
        description = "Year with extra detail",
        packages = { "natbib", "biblatex" },
        enabled = false,
      },
      {
        command = "\\citeyearpar",
        template = "\\citeyearpar{ {{key}} }",
        description = "Year in parentheses (natbib)",
        packages = "natbib",
        enabled = false,
      },
      {
        command = "\\citetitle",
        template = "\\citetitle{ {{key}} }",
        description = "Work title",
        packages = "biblatex",
        enabled = false,
      },
      {
        command = "\\citetitle*",
        template = "\\citetitle*{ {{key}} }",
        description = "Work title without disambiguation",
        packages = "biblatex",
        enabled = false,
      },
      {
        command = "\\Citetitle",
        template = "\\Citetitle{ {{key}} }",
        description = "Sentence-leading work title",
        packages = "biblatex",
        enabled = false,
      },
      {
        command = "\\Citetitle*",
        template = "\\Citetitle*{ {{key}} }",
        description = "Sentence-leading work title (no disambiguation)",
        packages = "biblatex",
        enabled = false,
      },
      {
        command = "\\citeurl",
        template = "\\citeurl{ {{key}} }",
        description = "URL only",
        packages = "biblatex",
        enabled = false,
      },
      {
        command = "\\citeurldate",
        template = "\\citeurldate{ {{key}} }",
        description = "URL access date",
        packages = "biblatex",
        enabled = false,
      },
      {
        command = "\\citedate",
        template = "\\citedate{ {{key}} }",
        description = "Date field",
        packages = "biblatex",
        enabled = false,
      },
      {
        command = "\\citedate*",
        template = "\\citedate*{ {{key}} }",
        description = "Date field (untruncated)",
        packages = "biblatex",
        enabled = false,
      },
      {
        command = "\\Citedate",
        template = "\\Citedate{ {{key}} }",
        description = "Sentence-leading date field",
        packages = "biblatex",
        enabled = false,
      },
      {
        command = "\\Citedate*",
        template = "\\Citedate*{ {{key}} }",
        description = "Sentence-leading date field (untruncated)",
        packages = "biblatex",
        enabled = false,
      },
      {
        command = "\\parencite",
        template = "\\parencite{ {{key}} }",
        description = "Parenthetical citation (biblatex)",
        packages = "biblatex",
        enabled = true,
      },
      {
        command = "\\Parencite",
        template = "\\Parencite{ {{key}} }",
        description = "Sentence-leading parenthetical citation",
        packages = "biblatex",
        enabled = false,
      },
      {
        command = "\\parencite*",
        template = "\\parencite*{ {{key}} }",
        description = "Parenthetical citation (full list)",
        packages = "biblatex",
        enabled = false,
      },
      {
        command = "\\Parencite*",
        template = "\\Parencite*{ {{key}} }",
        description = "Sentence-leading parenthetical citation (full list)",
        packages = "biblatex",
        enabled = false,
      },
      {
        command = "\\footcite",
        template = "\\footcite{ {{key}} }",
        description = "Footnote citation",
        packages = "biblatex",
        enabled = true,
      },
      {
        command = "\\Footcite",
        template = "\\Footcite{ {{key}} }",
        description = "Sentence-leading footnote citation",
        packages = "biblatex",
        enabled = false,
      },
      {
        command = "\\footcite*",
        template = "\\footcite*{ {{key}} }",
        description = "Footnote citation (full list)",
        packages = "biblatex",
        enabled = false,
      },
      {
        command = "\\Footcite*",
        template = "\\Footcite*{ {{key}} }",
        description = "Sentence-leading footnote citation (full list)",
        packages = "biblatex",
        enabled = false,
      },
      {
        command = "\\footcitetext",
        template = "\\footcitetext{ {{key}} }",
        description = "Footnote citation without marker",
        packages = "biblatex",
        enabled = false,
      },
      {
        command = "\\footfullcite",
        template = "\\footfullcite{ {{key}} }",
        description = "Full footnote citation",
        packages = "biblatex",
        enabled = false,
      },
      {
        command = "\\textcite",
        template = "\\textcite{ {{key}} }",
        description = "Textual citation (biblatex)",
        packages = "biblatex",
        enabled = true,
      },
      {
        command = "\\Textcite",
        template = "\\Textcite{ {{key}} }",
        description = "Sentence-leading textual citation",
        packages = "biblatex",
        enabled = false,
      },
      {
        command = "\\textcite*",
        template = "\\textcite*{ {{key}} }",
        description = "Textual citation (full list)",
        packages = "biblatex",
        enabled = false,
      },
      {
        command = "\\Textcite*",
        template = "\\Textcite*{ {{key}} }",
        description = "Sentence-leading textual citation (full list)",
        packages = "biblatex",
        enabled = false,
      },
      {
        command = "\\smartcite",
        template = "\\smartcite{ {{key}} }",
        description = "Auto style citation",
        packages = "biblatex",
        enabled = false,
      },
      {
        command = "\\Smartcite",
        template = "\\Smartcite{ {{key}} }",
        description = "Sentence-leading auto citation",
        packages = "biblatex",
        enabled = false,
      },
      {
        command = "\\smartcite*",
        template = "\\smartcite*{ {{key}} }",
        description = "Auto style citation (full list)",
        packages = "biblatex",
        enabled = false,
      },
      {
        command = "\\Smartcite*",
        template = "\\Smartcite*{ {{key}} }",
        description = "Sentence-leading auto citation (full list)",
        packages = "biblatex",
        enabled = false,
      },
      {
        command = "\\autocite",
        template = "\\autocite{ {{key}} }",
        description = "Context sensitive citation",
        packages = "biblatex",
        enabled = true,
      },
      {
        command = "\\Autocite",
        template = "\\Autocite{ {{key}} }",
        description = "Sentence-leading context citation",
        packages = "biblatex",
        enabled = false,
      },
      {
        command = "\\autocite*",
        template = "\\autocite*{ {{key}} }",
        description = "Context citation (full list)",
        packages = "biblatex",
        enabled = false,
      },
      {
        command = "\\Autocite*",
        template = "\\Autocite*{ {{key}} }",
        description = "Sentence-leading context citation (full list)",
        packages = "biblatex",
        enabled = false,
      },
      {
        command = "\\supercite",
        template = "\\supercite{ {{key}} }",
        description = "Superscript citation",
        packages = "biblatex",
        enabled = false,
      },
      {
        command = "\\Supercite",
        template = "\\Supercite{ {{key}} }",
        description = "Sentence-leading superscript citation",
        packages = "biblatex",
        enabled = false,
      },
      {
        command = "\\nocite",
        template = "\\nocite{ {{key}} }",
        description = "Add to bibliography only",
        packages = { "bibtex", "biblatex" },
        enabled = true,
      },
      {
        command = "\\fullcite",
        template = "\\fullcite{ {{key}} }",
        description = "Full citation",
        packages = "biblatex",
        enabled = true,
      },
      {
        command = "\\volcite",
        template = "\\volcite{ {{key}} }",
        description = "Volume citation",
        packages = "biblatex",
        enabled = false,
      },
      {
        command = "\\pvolcite",
        template = "\\pvolcite{ {{key}} }",
        description = "Volume citation with pages",
        packages = "biblatex",
        enabled = false,
      },
      {
        command = "\\fvolcite",
        template = "\\fvolcite{ {{key}} }",
        description = "Volume citation with floors",
        packages = "biblatex",
        enabled = false,
      },
      {
        command = "\\svolcite",
        template = "\\svolcite{ {{key}} }",
        description = "Supplementary volume citation",
        packages = "biblatex",
        enabled = false,
      },
      {
        command = "\\volcites",
        template = "\\volcites{ {{key}} }",
        description = "Multiple volume citations",
        packages = "biblatex",
        enabled = false,
      },
      {
        command = "\\pvolcites",
        template = "\\pvolcites{ {{key}} }",
        description = "Multiple volume citations with pages",
        packages = "biblatex",
        enabled = false,
      },
      {
        command = "\\fvolcites",
        template = "\\fvolcites{ {{key}} }",
        description = "Multiple volume citations with floors",
        packages = "biblatex",
        enabled = false,
      },
      {
        command = "\\svolcites",
        template = "\\svolcites{ {{key}} }",
        description = "Multiple supplementary volume citations",
        packages = "biblatex",
        enabled = false,
      },
      {
        command = "\\cites",
        template = "\\cites{ {{key}} }",
        description = "Multiple citations",
        packages = { "natbib", "biblatex" },
        enabled = false,
      },
      {
        command = "\\Cites",
        template = "\\Cites{ {{key}} }",
        description = "Sentence-leading multiple citations",
        packages = "biblatex",
        enabled = false,
      },
      {
        command = "\\parencites",
        template = "\\parencites{ {{key}} }",
        description = "Multiple parenthetical citations",
        packages = "biblatex",
        enabled = false,
      },
      {
        command = "\\Parencites",
        template = "\\Parencites{ {{key}} }",
        description = "Sentence-leading multiple parenthetical citations",
        packages = "biblatex",
        enabled = false,
      },
      {
        command = "\\footcites",
        template = "\\footcites{ {{key}} }",
        description = "Multiple footnote citations",
        packages = "biblatex",
        enabled = false,
      },
      {
        command = "\\Footcites",
        template = "\\Footcites{ {{key}} }",
        description = "Sentence-leading multiple footnote citations",
        packages = "biblatex",
        enabled = false,
      },
      {
        command = "\\textcites",
        template = "\\textcites{ {{key}} }",
        description = "Multiple textual citations",
        packages = "biblatex",
        enabled = false,
      },
      {
        command = "\\Textcites",
        template = "\\Textcites{ {{key}} }",
        description = "Sentence-leading multiple textual citations",
        packages = "biblatex",
        enabled = false,
      },
      {
        command = "\\smartcites",
        template = "\\smartcites{ {{key}} }",
        description = "Multiple auto style citations",
        packages = "biblatex",
        enabled = false,
      },
      {
        command = "\\Smartcites",
        template = "\\Smartcites{ {{key}} }",
        description = "Sentence-leading multiple auto style citations",
        packages = "biblatex",
        enabled = false,
      },
      {
        command = "\\autocites",
        template = "\\autocites{ {{key}} }",
        description = "Multiple context citations",
        packages = "biblatex",
        enabled = false,
      },
      {
        command = "\\Autocites",
        template = "\\Autocites{ {{key}} }",
        description = "Sentence-leading multiple context citations",
        packages = "biblatex",
        enabled = false,
      },
      {
        command = "\\supercites",
        template = "\\supercites{ {{key}} }",
        description = "Multiple superscript citations",
        packages = "biblatex",
        enabled = false,
      },
      {
        command = "\\Supercites",
        template = "\\Supercites{ {{key}} }",
        description = "Sentence-leading multiple superscript citations",
        packages = "biblatex",
        enabled = false,
      },
      {
        command = "\\nocites",
        template = "\\nocites{ {{key}} }",
        description = "Multiple bibliography-only entries",
        packages = "biblatex",
        enabled = false,
      },
      {
        command = "\\fullcites",
        template = "\\fullcites{ {{key}} }",
        description = "Multiple full citations",
        packages = "biblatex",
        enabled = false,
      },
      {
        command = "\\footfullcites",
        template = "\\footfullcites{ {{key}} }",
        description = "Multiple full footnote citations",
        packages = "biblatex",
        enabled = false,
      },
    },
    citation_formats = {
      {
        id = "apa7_in_text",
        name = "APA 7 (in-text, English)",
        template = "({{author}}, {{year}})",
        description = "APA 7th edition in-text citation",
        category = "in_text",
        locale = "en",
        enabled = true,
      },
      {
        id = "apa7_reference",
        name = "APA 7 (reference list, English)",
        template = "{{author}} ({{year}}). {{title}}. {{journal}}.",
        description = "APA 7th edition reference entry",
        category = "reference",
        locale = "en",
        enabled = true,
      },
      {
        id = "harvard_in_text",
        name = "Harvard (in-text, English)",
        template = "{{author}} {{year}}",
        description = "Harvard style in-text citation",
        category = "in_text",
        locale = "en",
        enabled = false,
      },
      {
        id = "harvard_reference",
        name = "Harvard (reference list, English)",
        template = "{{author}}. {{year}}. {{title}}. {{journal}}.",
        description = "Harvard style reference entry",
        category = "reference",
        locale = "en",
        enabled = false,
      },
      {
        id = "oxford_reference",
        name = "Oxford (reference list, English)",
        template = "{{author}}, {{title}} ({{publisher}}, {{year}})",
        description = "Oxford style bibliography entry",
        category = "reference",
        locale = "en",
        enabled = false,
      },
    },
  }
  normalize_citation_commands(defaults.citation_commands)
  normalize_citation_formats(defaults.citation_formats)
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
  normalize_citation_commands(merged.citation_commands)
  normalize_citation_formats(merged.citation_formats)
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
  normalize_citation_commands(merged.citation_commands)
  normalize_citation_formats(merged.citation_formats)
  return merged
end

return M
