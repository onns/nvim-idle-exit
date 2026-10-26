local M = {}

local defaults = {
  timeout = 60 * 15, -- fifteen minutes
  check_interval = 60, -- check once a minute
  notify = true,
}

local state = {
  timer = nil,
  last_activity = nil,
  namespace = nil,
  enabled = false,
  exiting = false,
  warned_modified = false,
  options = vim.deepcopy(defaults),
}

local function has_modified_buffers()
  for _, buf in ipairs(vim.api.nvim_list_bufs()) do
    if vim.api.nvim_buf_is_valid(buf) and vim.api.nvim_get_option_value("modified", { buf = buf }) then
      return true
    end
  end
  return false
end

local function check_idle()
  if not state.enabled or state.exiting or not state.last_activity then
    return
  end

  if os.time() - state.last_activity < state.options.timeout then
    return
  end

  vim.schedule(function()
    if not state.enabled or state.exiting or os.time() - state.last_activity < state.options.timeout then
      return
    end

    if has_modified_buffers() then
      if state.options.notify and not state.warned_modified then
        vim.notify("idle-exit: unsaved changes found; keeping Neovim open", vim.log.levels.WARN)
      end
      state.warned_modified = true
      -- Keep checking. Once the user saves, the next interval can close Neovim.
      return
    end

    state.exiting = true
    state.warned_modified = false
    if state.options.notify then
      vim.notify("idle-exit: closing Neovim after being idle")
    end
    -- :qa respects all normal quit hooks and will refuse to discard changes.
    local ok, err = pcall(vim.cmd, "qa")
    if not ok then
      state.exiting = false
      if state.options.notify then
        vim.notify("idle-exit: could not quit Neovim: " .. tostring(err), vim.log.levels.WARN)
      end
    end
  end)
end

function M.setup(opts)
  state.options = vim.tbl_deep_extend("force", vim.deepcopy(defaults), opts or {})
  assert(type(state.options.timeout) == "number" and state.options.timeout > 0, "timeout must be a positive number of seconds")
  assert(type(state.options.check_interval) == "number" and state.options.check_interval > 0, "check_interval must be a positive number of seconds")

  if state.timer then
    state.timer:stop()
    state.timer:close()
  end
  if state.namespace then
    pcall(vim.on_key, nil, state.namespace)
  end

  state.enabled = true
  state.exiting = false
  state.warned_modified = false
  state.last_activity = os.time()
  state.namespace = vim.api.nvim_create_namespace("idle-exit")
  vim.on_key(function()
    state.last_activity = os.time()
  end, state.namespace)

  state.timer = vim.uv.new_timer()
  state.timer:start(state.options.check_interval * 1000, state.options.check_interval * 1000, check_idle)

  for _, name in ipairs({ "IdleExitDisable", "IdleExitEnable", "IdleExitStatus" }) do
    pcall(vim.api.nvim_del_user_command, name)
  end
  vim.api.nvim_create_user_command("IdleExitDisable", function()
    M.disable()
  end, { desc = "Disable automatic idle exit" })
  vim.api.nvim_create_user_command("IdleExitEnable", function()
    M.enable()
  end, { desc = "Enable automatic idle exit" })
  vim.api.nvim_create_user_command("IdleExitStatus", function()
    local remaining = math.max(0, state.options.timeout - (os.time() - state.last_activity))
    vim.notify(string.format("idle-exit %s; closes in %d seconds", state.enabled and "enabled" or "disabled", remaining))
  end, { desc = "Show automatic idle exit status" })
end

function M.disable()
  state.enabled = false
  if state.timer then
    state.timer:stop()
  end
end

function M.enable()
  state.last_activity = os.time()
  state.exiting = false
  state.warned_modified = false
  state.enabled = true
  if state.timer then
    state.timer:start(state.options.check_interval * 1000, state.options.check_interval * 1000, check_idle)
  end
end

return M
