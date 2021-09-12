-- The following code have been taken from famiu
-- src: https://github.com/famiu/nvim-reload
local M = {}

local fn = vim.fn
local cmd = vim.cmd
local project_site = vim.g.project_site
local project_config = vim.g.project_config

local Path = require "plenary.path"
local scan_dir = require("plenary.scandir").scan_dir

-- Paths to unload Lua modules from
M.lua_reload_dirs = { project_config }

-- Paths to reload Vim files from
M.vim_reload_dirs = { project_config, project_site .. "/pack/*/start/*" }

-- External files outside the runtimepaths to source
M.files_reload_external = {}

-- External Lua modules outside the runtimepaths to unload
M.modules_reload_external = {}

-- Pre-reload hook
M.pre_reload_hook = nil
M.post_reload_hook = nil

local viml_subdirs = {
   "compiler",
   "doc",
   "keymap",
   "syntax",
   "plugin",
}

-- Escape lua string
-- @param str
local function escape_str(str)
   local patterns_to_escape = {
      "%^",
      "%$",
      "%(",
      "%)",
      "%%",
      "%.",
      "%[",
      "%]",
      "%*",
      "%+",
      "%-",
      "%?",
   }

   return string.gsub(str, string.format("([%s])", table.concat(patterns_to_escape)), "%%%1")
end

-- Check if path exists
-- @param path
local function path_exists(path)
   return Path:new(path):exists()
end
-- @param runtimepath
-- @return paths
local function get_runtime_files_in_path(runtimepath)
   -- Ignore opt plugins
   if string.match(runtimepath, "/site/pack/.-/opt") then
      return {}
   end

   local runtime_files = {}

   -- Search each subdirectory listed listed in viml_subdirs of runtimepath for files
   for _, subdir in ipairs(viml_subdirs) do
      local viml_path = string.format("%s/%s", runtimepath, subdir)

      if path_exists(viml_path) then
         local files = scan_dir(viml_path, { search_pattern = "%.n?vim$", hidden = true })

         for _, file in ipairs(files) do
            runtime_files[#runtime_files + 1] = file
         end
      end
   end

   return runtime_files
end

local function get_lua_modules_in_path(runtimepath)
   local luapath = string.format("%s/lua", runtimepath)

   if not path_exists(luapath) then
      return {}
   end

   -- Search lua directory of runtimepath for modules
   local modules = scan_dir(luapath, { search_pattern = "%.lua$", hidden = true })

   for i, module in ipairs(modules) do
      -- Remove runtimepath and file extension from module path
      module = string.match(module, string.format("%s/(.*)%%.lua", escape_str(luapath)))

      -- Changes slash in path to dot to follow lua module format
      module = string.gsub(module, "/", ".")

      -- If module ends with '.init', remove it.
      module = string.gsub(module, "%.init$", "")

      -- Override previous value with new value
      modules[i] = module
   end

   return modules
end

-- Reload all start plugins
local function reload_runtime_files()
   -- Search each runtime path for files
   for _, runtimepath_suffix in ipairs(M.vim_reload_dirs) do
      -- Expand the globs and get the result as a list
      local paths = fn.glob(runtimepath_suffix, 0, 1)

      for _, path in ipairs(paths) do
         local runtime_files = get_runtime_files_in_path(path)

         for _, file in ipairs(runtime_files) do
            cmd("source " .. file)
         end
      end
   end

   for _, file in ipairs(M.files_reload_external) do
      cmd("source " .. file)
   end
end

-- Unload all loaded Lua modules
local function unload_lua_modules()
   -- Search each runtime path for modules
   for _, runtimepath_suffix in ipairs(M.lua_reload_dirs) do
      local paths = fn.glob(runtimepath_suffix, 0, 1)

      for _, path in ipairs(paths) do
         local modules = get_lua_modules_in_path(path)

         for _, module in ipairs(modules) do
            package.loaded[module] = nil
         end
      end
   end

   for _, module in ipairs(M.modules_reload_external) do
      package.loaded[module] = nil
   end
end

-- Reload Vim configuration
function M.Reload()
   -- Run pre-reload hook
   if type(M.pre_reload_hook) == "function" then
      M.pre_reload_hook()
   end

   -- Clear highlights
   cmd "highlight clear"

   -- Stop LSP if it's configured
   if fn.exists ":LspStop" ~= 0 then
      cmd "LspStop"
   end

   -- Unload all already loaded modules
   unload_lua_modules()

   -- Source init file
   if string.match(fn.expand "$MYVIMRC", "%.lua$") then
      cmd "luafile $MYVIMRC"
   else
      cmd "source $MYVIMRC"
   end

   -- Reload start plugins
   reload_runtime_files()

   -- Run post-reload hook
   if type(M.post_reload_hook) == "function" then
      M.post_reload_hook()
   end
end

function M.set_theme()
   local theme = require("chadrc").ui.theme
   require("nvchad").reload_theme(theme)
end

-- Restart Vim without having to close and run again
function M.Restart()
   -- Reload config
   M.Reload()

   -- Manually run VimEnter autocmd to emulate a new run of Vim
   cmd "doautocmd VimEnter,BufRead,ColorScheme"
   -- Loading Config
   cmd 'lua require("core.utils").load_config()'
   -- Setting Theme
   M.set_theme()
   -- Source init files
   cmd ("luafile " .. project_config .. "/nvim/lua/chadrc.lua")
   cmd ("luafile " .. project_config .. "/nvim/lua/plugins/init.lua")
   cmd ("luafile " .. project_config .. "/nvim/lua/colors/init.lua")
   -- Installing  or Cleaning on changes
   cmd "PackerClean"
   cmd "PackerInstall"
   cmd "PackerCompile"
end

return M.Restart
