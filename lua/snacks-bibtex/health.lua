local M = {}

---Check local_bib configuration
---@param local_bib SnacksBibtexLocalBibConfig|nil
local function check_local_bib(local_bib)
  if not local_bib or not local_bib.enabled then
    vim.health.info("local_bib: disabled")
    return
  end

  vim.health.ok("local_bib: enabled")

  -- Check target resolution
  local cwd = vim.fn.getcwd()
  local target, source

  -- Try to resolve target
  if local_bib.targets and local_bib.targets[cwd] then
    target = vim.fs.normalize(vim.fs.joinpath(cwd, local_bib.targets[cwd]))
    source = "targets"
  elseif local_bib.target then
    local t = vim.fn.expand(local_bib.target)
    if not vim.startswith(t, "/") then
      t = vim.fs.joinpath(cwd, t)
    end
    target = vim.fs.normalize(t)
    source = "target"
  else
    -- Pattern auto-detect
    local patterns = local_bib.patterns or { "local.bib", "references.bib" }
    for _, pattern in ipairs(patterns) do
      local path = vim.fs.normalize(vim.fs.joinpath(cwd, pattern))
      if vim.fn.filereadable(path) == 1 then
        target = path
        source = "patterns"
        break
      end
    end
  end

  if target then
    local exists = vim.fn.filereadable(target) == 1
    if exists then
      vim.health.ok(("target: %s (via %s)"):format(target, source))
    else
      vim.health.warn(("target: %s (does not exist, via %s)"):format(target, source))
    end
  else
    vim.health.warn("target: not found (no matching file in cwd)")
  end

  -- Check create_if_missing compatibility
  if local_bib.create_if_missing then
    local has_explicit = local_bib.target ~= nil or (local_bib.targets and not vim.tbl_isempty(local_bib.targets))
    if has_explicit then
      vim.health.ok("create_if_missing: compatible (explicit target configured)")
    else
      vim.health.error("create_if_missing: requires explicit 'target' or 'targets' (patterns only match existing files)")
    end
  end

  -- Check auto_add setting
  if local_bib.auto_add then
    vim.health.info("auto_add: enabled (entries copied automatically on insert)")
  else
    vim.health.info("auto_add: disabled (use <C-l> to copy manually)")
  end
end

---Check files_exclude configuration
---@param files_exclude string[]|nil
local function check_files_exclude(files_exclude)
  if not files_exclude or #files_exclude == 0 then
    vim.health.info("files_exclude: none configured")
    return
  end

  vim.health.ok(("files_exclude: %d pattern(s) configured"):format(#files_exclude))
  for _, pattern in ipairs(files_exclude) do
    vim.health.info(("  - %s"):format(pattern))
  end
end

---Main health check function
function M.check()
  vim.health.start("snacks-bibtex")

  -- Check snacks.nvim dependency
  local has_snacks, _ = pcall(require, "snacks")
  if has_snacks then
    vim.health.ok("snacks.nvim: found")
  else
    vim.health.error("snacks.nvim: not found (required dependency)")
    return
  end

  -- Check if config module loads
  local ok, config_mod = pcall(require, "snacks-bibtex.config")
  if not ok then
    vim.health.error("config module: failed to load")
    return
  end
  vim.health.ok("config module: loaded")

  -- Get current configuration
  local cfg = config_mod.get()
  if not cfg then
    vim.health.warn("configuration: not initialized (call setup() first)")
    return
  end

  -- Check files configuration
  local files = cfg.files or {}
  local global_files = cfg.global_files or {}
  vim.health.info(("files: %d configured"):format(#files))
  vim.health.info(("global_files: %d configured"):format(#global_files))

  -- Check files_exclude
  check_files_exclude(cfg.files_exclude)

  -- Check local_bib configuration
  check_local_bib(cfg._local_bib)

  -- Check display settings
  if cfg.display then
    if cfg.display.show_source_status then
      vim.health.info("display.show_source_status: enabled")
    else
      vim.health.info("display.show_source_status: disabled")
    end
  end
end

return M
