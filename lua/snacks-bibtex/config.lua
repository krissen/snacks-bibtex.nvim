local M = {}

---@class SnacksBibtexConfig
---@field depth integer|nil           # directory recursion depth for local bib search
---@field files string[]|nil          # explicit list of project-local bib files
---@field global_files string[]|nil   # list of global bib files (outside project)
---@field search_fields string[]      # ordered list of fields to search (e.g. {"author","title","year","keywords"})
---@field format string               # default format for inserting citation keys / labels
---@field preview_format string       # how to format the preview line(s)
---@field citation_format? string     # template used when inserting formatted citations
---@class SnacksBibtexCitationCommand
---@field command string
---@field template string
---@field description? string
---@field packages? string|string[]
---@field enabled? boolean

---@field mappings table<string, SnacksBibtexMapping>|nil  # custom action mappings for the picker
---@field citation_commands SnacksBibtexCitationCommand[]  # available citation templates

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
