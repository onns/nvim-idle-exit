# idle-exit.nvim

Close a Neovim instance after a configurable period without keyboard input. If any buffer has unsaved changes, the plugin keeps Neovim open and checks again later. It uses `:qa`, so normal `QuitPre` hooks still run and Neovim itself refuses to discard modified buffers.

## Install with lazy.nvim

```lua
{
  "YOUR_GITHUB_USER/nvim-idle-exit",
  opts = {
    timeout = 15 * 60, -- fifteen minutes; seconds
    check_interval = 60, -- seconds
    notify = true,
  },
}
```

If using a local checkout, replace the repository string with its local path and add `dev = true` to the lazy.nvim setup.

## Commands

- `:IdleExitStatus` shows whether the timer is enabled and the remaining time.
- `:IdleExitDisable` disables automatic exit for the current Neovim instance.
- `:IdleExitEnable` enables it again and starts a fresh idle period.

Any key received by Neovim resets the idle timer. The timer is per Neovim process, so each tmux pane running Neovim manages its own lifetime. The plugin does not stop a shared gopls daemon; that daemon's own lifecycle and timeout remain separate.
