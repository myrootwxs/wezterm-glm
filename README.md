# wezterm-glm

A [WezTerm plugin](https://wezterm.org/config/plugins.html) that shows Zhipu GLM coding-plan token usage and its next reset time in the right status bar.

## Requirements

- WezTerm 20230320 or newer
- `curl` available on `PATH`
- A Zhipu API key in `ZHIPU_API_KEY` (or `GLM_API_KEY`)

## Installation

```lua
local wezterm = require('wezterm')
local glm = wezterm.plugin.require('https://github.com/myrootwxs/wezterm-glm')

local config = wezterm.config_builder()

glm.apply_to_config(config, {
   cache_ttl = 60,
})

return config
```

Set the API key before starting WezTerm:

```powershell
# Windows PowerShell
[Environment]::SetEnvironmentVariable('ZHIPU_API_KEY', 'xxx.yyy', 'User')
```

```sh
# macOS / Linux
export ZHIPU_API_KEY=xxx.yyy
```

Restart WezTerm after changing the environment variable.

## Custom status bars

`apply_to_config()` owns the right status bar. If your configuration already handles `update-right-status`, compose the plugin output yourself:

```lua
glm.apply_to_config(config, { status = false })

wezterm.on('update-right-status', function(window, _pane)
   window:set_right_status(wezterm.format(glm.format({
      fg = '#a6e3a1',
      bg = 'rgba(0, 0, 0, 0.4)',
   })))
end)
```

The module also exposes `get_usage(opts)`, `get_status_text(opts)`, and `invalidate()`.

## Options

| Option | Default | Purpose |
| --- | --- | --- |
| `env` | `ZHIPU_API_KEY`, then `GLM_API_KEY` | Environment variable containing the API key |
| `api_key` | — | API key value; using `env` is safer |
| `cache_ttl` | `60` | Cache successful and failed requests for this many seconds |
| `timeout` | `8` | `curl` timeout in seconds |
| `status` | `true` | Register the standalone right-status handler |
| `icon` | Nerd Font chart | Status icon |
| `fg` | `#a6e3a1` | Foreground color |
| `bg` | `rgba(0, 0, 0, 0.4)` | Background color |
| `show_error` | `true` | Display request errors in the status bar |
| `error_max_len` | `24` | Maximum displayed error length |

## Updating

WezTerm does not update plugins automatically. Run this in the debug overlay when needed:

```lua
wezterm.plugin.update_all()
```

## License

MIT
