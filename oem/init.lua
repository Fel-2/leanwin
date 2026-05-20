-- leanwin: Neovim config for Windows Server 2022 Build Box

-- Bootstrap lazy.nvim
local lazypath = vim.fn.stdpath("data") .. "/lazy/lazy.nvim"
if not vim.loop.fs_stat(lazypath) then
  vim.fn.system({
    "git", "clone", "--filter=blob:none",
    "https://github.com/folke/lazy.nvim.git",
    "--branch=stable", lazypath
  })
end
vim.opt.rtp:prepend(lazypath)

-- Basic options
vim.opt.number = true
vim.opt.relativenumber = true
vim.opt.tabstop = 4
vim.opt.shiftwidth = 4
vim.opt.expandtab = false
vim.opt.smartindent = true
vim.opt.mouse = "a"
vim.opt.clipboard = "unnamedplus"
vim.opt.termguicolors = true
vim.opt.ignorecase = true
vim.opt.smartcase = true
vim.opt.scrolloff = 8
vim.opt.signcolumn = "yes"
vim.opt.updatetime = 250
vim.opt.timeoutlen = 300
vim.opt.splitright = true
vim.opt.splitbelow = true
vim.opt.list = true
vim.opt.listchars = { tab = "> ", trail = ".", nbsp = "_" }
vim.opt.fillchars = { eob = " " }
vim.opt.undofile = true
vim.opt.completeopt = "menu,menuone,noselect"

-- Keymaps
local map = vim.keymap.set
map("n", "<leader>w", "<cmd>w<CR>", { desc = "Save" })
map("n", "<leader>q", "<cmd>q<CR>", { desc = "Quit" })
map("n", "<leader>e", vim.diagnostic.open_float, { desc = "Line diagnostics" })
map("n", "[d", vim.diagnostic.goto_prev, { desc = "Prev diagnostic" })
map("n", "]d", vim.diagnostic.goto_next, { desc = "Next diagnostic" })
map("n", "<leader>f", vim.lsp.buf.format, { desc = "Format" })
map("n", "<leader>rn", vim.lsp.buf.rename, { desc = "Rename" })
map("n", "gd", vim.lsp.buf.definition, { desc = "Go to definition" })
map("n", "gi", vim.lsp.buf.implementation, { desc = "Go to implementation" })
map("n", "K", vim.lsp.buf.hover, { desc = "Hover docs" })
map("n", "<leader>ca", vim.lsp.buf.code_action, { desc = "Code action" })
map("n", "<leader>sr", "<cmd>Telescope live_grep<CR>", { desc = "Search files (grep)" })
map("n", "<leader>sf", "<cmd>Telescope find_files<CR>", { desc = "Find files" })
map("n", "<leader>sb", "<cmd>Telescope buffers<CR>", { desc = "Find buffers" })
map("n", "<leader>sh", "<cmd>Telescope help_tags<CR>", { desc = "Find help" })
map("n", "<Esc>", "<cmd>nohlsearch<CR>", { desc = "Clear highlights" })

-- Plugins
require("lazy").setup({
  -- Colorscheme
  { "catppuccin/nvim", name = "catppuccin", priority = 1000 },
  -- Fuzzy finder
  {
    "nvim-telescope/telescope.nvim",
    dependencies = { "nvim-lua/plenary.nvim" },
    keys = { "<leader>s" },
    config = true,
  },
  -- LSP
  {
    "neovim/nvim-lspconfig",
    config = function()
      local on_attach = function(client, bufnr)
        if client.server_capabilities.documentFormattingProvider then
          vim.api.nvim_create_autocmd("BufWritePre", {
            buffer = bufnr,
            callback = function()
              vim.lsp.buf.format({ async = false })
            end,
          })
        end
      end

      vim.lsp.config.clangd = {
        cmd = { "clangd" },
        on_attach = on_attach,
      }

      vim.lsp.config.powershell_es = {
        on_attach = on_attach,
      }

      vim.lsp.config.lua_ls = {
        on_attach = on_attach,
      }

      vim.lsp.enable({ "clangd", "powershell_es", "lua_ls" })
    end,
  },
  -- LSP helpers
  {
    "hrsh7th/nvim-cmp",
    dependencies = {
      "hrsh7th/cmp-nvim-lsp",
      "hrsh7th/cmp-buffer",
      "hrsh7th/cmp-path",
      "L3MON4D3/LuaSnip",
    },
    config = function()
      local cmp = require("cmp")
      cmp.setup({
        snippet = {
          expand = function(args)
            require("luasnip").lsp_expand(args.body)
          end,
        },
        mapping = cmp.mapping.preset.insert({
          ["<C-b>"] = cmp.mapping.scroll_docs(-4),
          ["<C-f>"] = cmp.mapping.scroll_docs(4),
          ["<C-Space>"] = cmp.mapping.complete(),
          ["<C-e>"] = cmp.mapping.abort(),
          ["<CR>"] = cmp.mapping.confirm({ select = true }),
        }),
        sources = cmp.config.sources({
          { name = "nvim_lsp" },
          { name = "path" },
        }, {
          { name = "buffer" },
        }),
      })
    end,
  },
  -- File explorer (oil = edit filesystem as a buffer)
  {
    "stevearc/oil.nvim",
    keys = { { "-", desc = "Open parent directory" }, { "<leader>o", desc = "Oil" } },
    cmd = "Oil",
    config = function()
      require("oil").setup({
        default_file_explorer = true,
        keymaps = {
          ["<C-p>"] = false,
          ["<C-c>"] = false,
        },
      })
      vim.keymap.set("n", "-", "<cmd>Oil<CR>", { desc = "Oil: parent dir" })
      vim.keymap.set("n", "<leader>o", "<cmd>Oil --float<CR>", { desc = "Oil: float" })
    end,
  },
  -- Git signs in gutter
  {
    "lewis6991/gitsigns.nvim",
    event = "BufRead",
    config = true,
  },
  -- Which-key (shows keybind popup)
  {
    "folke/which-key.nvim",
    event = "VeryLazy",
    config = true,
  },
  -- Autopairs
  {
    "windwp/nvim-autopairs",
    event = "InsertEnter",
    config = true,
  },
})

-- Colorscheme
vim.cmd.colorscheme("catppuccin-mocha")
