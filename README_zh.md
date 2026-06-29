# wezterm-glm

[English](./README.md) | 简体中文

一个 [WezTerm 插件](https://wezterm.org/config/plugins.html)，用于在右状态栏显示智谱 GLM 编程套餐的 Token 用量和下次重置时间。

## 环境要求

- WezTerm 20230320 或更高版本
- `PATH` 中可执行 `curl`
- 环境变量 `ZHIPU_API_KEY`（或 `GLM_API_KEY`）中已配置智谱 API Key

## 安装

```lua
local wezterm = require('wezterm')
local glm = wezterm.plugin.require('https://github.com/myrootwxs/wezterm-glm')

local config = wezterm.config_builder()

glm.apply_to_config(config, {
   cache_ttl = 60,
})

return config
```

启动 WezTerm 前设置 API Key：

```powershell
# Windows PowerShell
[Environment]::SetEnvironmentVariable('ZHIPU_API_KEY', 'xxx.yyy', 'User')
```

```sh
# macOS / Linux
export ZHIPU_API_KEY=xxx.yyy
```

修改环境变量后需要重启 WezTerm。

## 自定义状态栏

`apply_to_config()` 会接管右状态栏。如果你的配置已经处理 `update-right-status`，请关闭插件的独立状态栏并自行组合输出：

```lua
glm.apply_to_config(config, { status = false })

wezterm.on('update-right-status', function(window, _pane)
   window:set_right_status(wezterm.format(glm.format({
      fg = '#a6e3a1',
      bg = 'rgba(0, 0, 0, 0.4)',
   })))
end)
```

模块还提供 `get_usage(opts)`、`get_status_text(opts)` 和 `invalidate()`。

## 配置项

| 配置项 | 默认值 | 说明 |
| --- | --- | --- |
| `env` | 依次读取 `ZHIPU_API_KEY`、`GLM_API_KEY` | 保存 API Key 的环境变量名 |
| `api_key` | — | 直接传入 API Key；使用环境变量更安全 |
| `cache_ttl` | `60` | 成功或失败请求的缓存秒数 |
| `timeout` | `8` | `curl` 超时秒数 |
| `status` | `true` | 是否注册独立右状态栏处理器 |
| `icon` | Nerd Font 图表图标 | 状态栏图标 |
| `fg` | `#a6e3a1` | 前景色 |
| `bg` | `rgba(0, 0, 0, 0.4)` | 背景色 |
| `show_error` | `true` | 是否在状态栏显示请求错误 |
| `error_max_len` | `24` | 错误信息最大显示长度 |

## 更新插件

WezTerm 不会自动更新插件。需要更新时，在调试面板中执行：

```lua
wezterm.plugin.update_all()
```

## 许可证

MIT
