local function update()
   -- Update without "git reset --hard hash" but with "git pull --rebase"
   --    This allows user to modify any files as long as they don't cause
   --    merge conflicts with upstream changes.  Such user changes including
   --    ones on chadrc are committed in advance to local main branch.
   --
   --    This is safer since all your chadrc are in local git repo.
   --
   -- -- NOTE on git command exit code --
   -- git status >/dev/null 2>&                        ==>                       0 if git repo
   -- git commit                                                                 0 if good commit
   --                                                                            1 if nothing to commit
   -- git commit -a                                                              0 if good commit
   --                                                                            1 if nothing to commit
   -- git pull --rebase                                                          0 if successful
   --
   -- get key parameters from NvChad
   -- in all the comments below, config means user config
   local config_path = vim.fn.stdpath "config"
   local config_name = vim.g.nvchad_user_config or "chadrc"
   local config_file = config_path .. "/lua/" .. config_name .. ".lua"
   local utils = require "nvchad"
   local echo = utils.echo
   local current_config = require("core.utils").load_config()
   local update_url = current_config.options.update_url or "https://github.com/NvChad/NvChad"
   local update_branch = current_config.options.update_branch or "main"
   -- check `git status` for repository sanity -> bail out if bad repo with message
   vim.fn.system("git -C " .. config_path .. " status")
   if vim.api.nvim_get_vvar "shell_error" ~= 0 then
      echo { { "Error: '" .. config_path .. "' is not a git directory.\n", "ErrorMsg" } }
      do return end
   end
   -- commit staged data if any exist.
   vim.fn.system("git -C " .. config_path .. " commit -m 'staged data committed by NvChad'")
   if vim.api.nvim_get_vvar "shell_error" == 0 then
      -- normally no commit is expected.  so successful commit calls for warning
      echo { { "Warn: local staged changes found and committed to local '" .. update_branch .. "' branch", "WarningMsg" } }
   end
   vim.fn.system("git -C " .. config_path .. " commit -a -m 'unstaged data committed by NvChad'")
   if vim.api.nvim_get_vvar "shell_error" == 0 then
      -- normally no commit is expected.  so successful commit calls for warning
      echo { { "Warn: local UNstaged changes found and committed to local '" .. update_branch .. "' branch", "WarningMsg" } }
   end

   -- record roll-back point: NvChad_rollback
   vim.fn.system("git -C " .. config_path .. " tag NvChad_rollback" )
   if vim.api.nvim_get_vvar "shell_error" ~= 0 then
      vim.fn.system([[ [ "$(git -C ]] .. config_path ..  [[ rev-parse HEAD)" == "$(git -C ]] ..  config_path .. [[ rev-parse NvChad_rollback)" ] ]] )
      if vim.api.nvim_get_vvar "shell_error" ~= 0 then
         -- no error is expected to reach here.
         echo { { "Error: git tag 'NvChad_rollback' can't be recorded at HEAD for some reason.\n", "ErrorMsg" } }
         do return end
      end
   -- if already exist at HEAD, be happy too
   end
   -- define update_script which uses --rebase to allow merging of local modifications to non-chadrc files
   local update_script = "git pull --rebase --set-upstream " .. update_url .. " " .. update_branch

   -- define function that will executed when git commands are done
   local function update_exit(_, code)
      -- close the terminal buffer only if update was success, as in case of error, we need the error message
      if code == 0 then
         vim.cmd "bd!"
         echo { { "NvChad successfully updated with 'git pull --rebase ...'.\n", "String" } }
      else
         echo { { "Warn: NvChad Update experienced merge conflicts in '" .. update_branch .. "' branch", "WarningMsg" } }
         vim.fn.system("git -C " .. config_path .. " reset --hard NvChad_rollback")
         if vim.api.nvim_get_vvar "shell_error" ~= 0 then
            -- no error is expected to reach here.
            echo { { "Error: git reset --hard 'NvChad_rollback' exits error for some reason.\n", "ErrorMsg" } }
            do return end
         end
         echo { { "Warn: NvChad Update rolled back.  Please resolve conflict manually.", "WarningMsg" } }
      end
      vim.fn.system("git -C " .. config_path .. " tag -d NvChad_rollback")
      if vim.api.nvim_get_vvar "shell_error" ~= 0 then
         -- no error is expected to reach here.
         echo { { "Error: git tag -d 'NvChad_rollback' exits error for some reason.\n", "ErrorMsg" } }
         do return end
      end
   end

   -- open a new buffer
   vim.cmd "new"
   -- finally open the pseudo terminal buffer and run update_script in it
   vim.fn.termopen(update_script, {
      -- change dir to config path so we don't need to move in script
      cwd = config_path,
      on_exit = update_exit})
end
return update
