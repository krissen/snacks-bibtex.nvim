if vim.g.loaded_snacks_bibtex then
  return
end
vim.g.loaded_snacks_bibtex = true

vim.api.nvim_create_user_command("SnacksBibtex", function(cmd_opts)
  local ok, bibtex = pcall(require, "snacks-bibtex")
  if not ok then
    vim.notify("snacks-bibtex.nvim is not available: " .. bibtex, vim.log.levels.ERROR, {
      title = "snacks-bibtex",
    })
    return
  end
  local opts = nil
  if cmd_opts.args ~= "" then
    opts = { format = cmd_opts.args }
  end
  bibtex.bibtex(opts)
end, {
  desc = "Open the Snacks BibTeX picker",
  nargs = "?",
  complete = function()
    return {}
  end,
})

