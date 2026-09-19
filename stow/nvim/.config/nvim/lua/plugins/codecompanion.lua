return {
  "olimorris/codecompanion.nvim",
  dependencies = {
    "nvim-lua/plenary.nvim",
    "nvim-treesitter/nvim-treesitter",
  },
  opts = {
    strategies = {
      chat = { adapter = "ollama" },
      inline = { adapter = "ollama" },
    },
    adapters = {
      ollama = function()
        return require("codecompanion.adapters").use("ollama", {
          schema = {
            model = {
              default = "minicpm5-q4",
            },
          },
        })
      end,
    },
  },
  keys = {
    { "<leader>cc", "<cmd>CodeCompanionChat Toggle<cr>", desc = "Toggle CodeCompanion Chat", mode = { "n", "v" } },
    { "<leader>ca", "<cmd>CodeCompanionActions<cr>", desc = "CodeCompanion Actions", mode = { "n", "v" } },
  },
}
