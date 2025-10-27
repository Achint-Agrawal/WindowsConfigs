-- Enable Snacks.image for rendering images, PDFs, and diagrams in Neovim
-- Requires: ImageMagick, Ghostscript, mermaid-cli
-- Terminal: WezTerm with image protocol support

return {
  "folke/snacks.nvim",
  opts = {
    image = {
      enabled = true,
      -- WezTerm backend configuration
      backend = "auto", -- Will detect WezTerm automatically
      -- Optional: customize image rendering
      -- max_width = 0.8, -- 80% of window width
      -- max_height = 0.8, -- 80% of window height
      auto_close = true, -- Close explorer after opening a file
      jump = { close = true }, -- Ensures explorer closes when jumping to a file
    },
  },
}
