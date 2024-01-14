local M = {}

local get_textobject_config = function()
  return {
    select = {
      enable = true,
      -- Automatically jump forward to textobj, similar to targets.vim
      lookahead = true,
      keymaps = {
        -- You can use the capture groups defined in textobjects.scm
        ["af"] = {
          query = "@function.outer",
          desc = "Select: function.outer",
        },
        ["if"] = {
          query = "@function.inner",
          desc = "Select: function.inner",
        },
        ["ac"] = {
          query = "@class.outer",
          desc = "Select: class.outer",
        },
        ["ic"] = {
          query = "@class.inner",
          desc = "Select: class.inner",
        },
      },
    },
    swap = {
      enable = true,
      swap_next = {
        ["<leader>p"] = {
          query = "@parameter.inner",
          desc = "Swap: parameter.next",
        },
      },
      swap_previous = {
        ["<leader>P"] = {
          query = "@parameter.inner",
          desc = "Swap: parameter.prev",
        },
      },
    },
    move = {
      enable = true,
      set_jumps = true, -- whether to set jumps in the jumplist
      goto_next_start = {
        ["]m"] = "@function.outer",
        ["]]"] = "@class.outer",
        ["]s"] = "@scope",
        ["]z"] = "@fold",
      },
      goto_next_end = {
        ["]M"] = "@function.outer",
        ["]["] = "@class.outer",
      },
      goto_previous_start = {
        ["[m"] = "@function.outer",
        ["[["] = "@class.outer",
      },
      goto_previous_end = {
        ["[M"] = "@function.outer",
        ["[]"] = "@class.outer",
      },
    },
  }
end

local setup_treesitter = function()
  local ts_config = require("nvim-treesitter.configs")
  ts_config.setup({
    ensure_installed = {
      "bash",
      "c",
      "cmake",
      "comment",
      "cpp",
      "go",
      "hjson",
      "json",
      "lua",
      "markdown",
      "norg",
      "rst",
      "toml",
      "typescript",
      "vim",
      "yaml",
      "zig",
    },
    auto_install = false,
    -- FIXME: - highlight is too slow in general
    --        - to test open `~/.config/nvim/lua/options.lua` and scroll
    --          down using `j` key, which `htop` running.
    highlight = {
      enable = true,
      -- disable = function(
      --   _, --[[lang]]
      --   bufnr
      -- )
      --   return vim.api.nvim_buf_line_count(bufnr) > 2500
      -- end,
    },
    incremental_selection = {
      enable = true,
      keymaps = {
        init_selection = "<Enter>",
        node_incremental = "<Enter>",
        scope_incremental = "<C-Enter>",
        node_decremental = "<BS>",
      },
    },
    indent = { enable = true },
    textobjects = get_textobject_config(),
    autotag = { enable = true },
  })
end

M.setup = function()
  vim.defer_fn(setup_treesitter, 0)
end

return M
