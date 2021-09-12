local function change_theme(current_theme, new_theme)
   if current_theme == nil or new_theme == nil then
      print "Error: Provide current and new theme name"
      return false
   end
   if current_theme == new_theme then
      return
   end

   local file_fn = require("nvchad").file
   local project_config = vim.g.project_config
   local user_config = vim.g.nvchad_user_config
   local file = project_config .. "/lua/" .. user_config .. ".lua"
   -- store in data variable
   local data = assert(file_fn("r", file))
   -- escape characters which can be parsed as magic chars
   current_theme = current_theme:gsub("%p", "%%%0")
   new_theme = new_theme:gsub("%p", "%%%0")
   local find = "theme = .?" .. current_theme .. ".?"
   local replace = 'theme = "' .. new_theme .. '"'
   local content = string.gsub(data, find, replace)
   -- see if the find string exists in file
   if content == data then
      print("Error: Cannot change default theme with " .. new_theme .. ", edit " .. file .. " manually")
      return false
   else
      assert(file_fn("w", file, content))
   end
end

return change_theme
