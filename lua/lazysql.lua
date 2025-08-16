--- *lazysql.nvim* lazysql management within Neovim
---
--- MIT License Copyright (c) 2024 Adran Carnavale

--- Summary
---
--- * |LazySql.types|
--- * |LazySql.setup|
--- * |LazySql.config|
--- * |LazySql.open|
--- * |LazySql.close|
--- * |LazySql.toggle|
--- * |LazySql.recipes|

local H = require('helpers')

---@class LazySql
---@field config LazySql.Config Module config table. See |LazySql.config|.
---@field setup fun(config?: LazySql.Config) Module Setup. See |LazySql.setup()|.
---@field open fun() Opens a new floating window with lazysql running. See |LazySql.open()|.
---@field close fun():boolean Closes the lazysql window if open. See |LazySql.close()|.
---@field toggle fun() Toggles the lazysql window open/closed. See |LazySql.toggle()|.
---
---@class LazySql.Config
---@field window LazySql.WindowConfig
---
---@class LazySql.WindowConfig
---@field settings LazySql.WindowSettings
---
---@class LazySql.WindowSettings
---@field width number Width of the floating panel, as a percentage (0 to 1) of screen width.
---@field height number Height of the floating panel, as a percentage (0 to 1) of screen height.
---@field border string Style of the floating window border. See ':h nvim_open_win'.
---@field relative string Sets the window layout relative to. See ':h nvim_open_win'.
---@tag LazySql.types

local LazySql = {}

---@param config table|nil Module config table. See |LazySql.config|.
---
---@usage >lua
---   require('lazysql').setup() -- Use default config.
---   -- OR
---   require('lazysql').setup({ window = { settings = { width = 0.8 } } }) -- Provide your own config.
--- <
---@return nil
function LazySql.setup(config)
  _G.LazySql = LazySql
  LazySql.config = H.setup_config(LazySql.config, config)
end

--- Default values (Check |LazySql.types| for details):
---@eval return MiniDoc.afterlines_to_code(MiniDoc.current.eval_section)
---@type LazySql.Config
LazySql.config = {
  window = {
    settings = {
      width = 0.9,
      height = 0.9,
      border = 'rounded',
      relative = 'editor',
    },
  },
}
--minidoc_afterlines_end

--- Opens a new floating window with lazysql running.
---
---@usage >lua
---    require('lazysql').open()
---    -- OR
---    :lua LazySql.open()
--- <
---@return nil
function LazySql.open()
  -- Prevent opening multiple instances, focus existing one
  if _G.__LazySql_Window_Handle and vim.api.nvim_win_is_valid(_G.__LazySql_Window_Handle) then
    vim.api.nvim_set_current_win(_G.__LazySql_Window_Handle)
    return
  end

  if not H.check_prerequisites() then
    return
  end

  H.stop_hanging_lazysql_job_if_active()

  local win_opts = H.get_lazysql_win_custom_config(LazySql.config.window.settings)
  local buf, win = H.create_lazysql_win_and_buffer(win_opts)
  _G.__LazySql_Window_Handle = win

  H.start_lazysql_job(win)
  H.start_lazysql_job_cleanup_autocmds(buf, win)

  vim.cmd('startinsert')
end

--- Closes the lazysql window if it's currently open.
---
---@usage >lua
---    require('lazysql').close()
---    -- OR
---    :lua LazySql.close()
--- <
---@return boolean closed True if a valid window was found and closed, false otherwise.
function LazySql.close()
  local win_handle = _G.__LazySql_Window_Handle

  if win_handle and vim.api.nvim_win_is_valid(win_handle) then
    pcall(vim.api.nvim_win_close, win_handle, true)
    _G.__LazySql_Window_Handle = nil
    return true
  end

  return false
end

--- Toggles the lazysql window open or closed.
---
--- - If the window is open (or believed to be open based on the internal handle), it calls |LazySql.close()|.
--- - If closing fails (meaning it wasn't open), it calls |LazySql.open()|.
---
--- This function is intended to be mapped by the user. See |LazySql.recipes|.
---
---@usage Map this function to a keybind in your Neovim config.
--- >lua
---    require('lazysql').toggle()
---    -- OR
---    :lua LazySql.toggle()
--- <
---@return nil
function LazySql.toggle()
  -- Attempt to close first. If close() returns false, it means
  -- the window wasn't open (or the handle was invalid), so open it.
  if not LazySql.close() then
    LazySql.open()
  end
end

--- Common configuration examples ~
---
--- # Toggle behavior ~
---
--- Since this plugin does not set any keymaps by default, you can map the
--- |LazySql.toggle()| function yourself.
---
--- >lua
---   -- It need to be setup on both `normal` and `terminal` modes because `lazysql` is run inside a terminal buffer
---   vim.keymap.set({ 'n', 't' }, '<leader>ld', '<Cmd>lua LazySql.toggle()<CR>')
--- <
---
--- Replace `<leader>ld` with your preferred key combination.
---@tag LazySql.recipes

return LazySql
