local wezterm = require('wezterm')

---Zhipu GLM coding-plan usage plugin for WezTerm.
---@class GlmPlugin
---@field apply_to_config fun(config: table, opts?: table)
---@field format fun(opts?: table): table
---@field get_usage fun(opts?: table): table|nil, string|nil
---@field get_status_text fun(opts?: table): string, table|nil, string|nil
---@field invalidate fun()
local M = {}

local API_URL = 'https://open.bigmodel.cn/api/monitor/usage/quota/limit'

local state = {
   value = nil,
   error = nil,
   fetched_at = 0,
   fetching = false,
   status_registered = false,
   last_status_by_window = {},
}

---@param opts table|nil
---@param key string
---@param default any
---@return any
local function option(opts, key, default)
   if opts and opts[key] ~= nil then
      return opts[key]
   end
   return default
end

---@param opts table
---@return string|nil api_key
---@return string env_description
local function get_api_key(opts)
   local api_key = option(opts, 'api_key', nil)
   if api_key and api_key ~= '' then
      return api_key, 'api_key'
   end

   local env = option(opts, 'env', nil)
   if env then
      return os.getenv(env), env
   end

   return os.getenv('ZHIPU_API_KEY') or os.getenv('GLM_API_KEY'), 'ZHIPU_API_KEY or GLM_API_KEY'
end

---@param body string
---@return table|nil usage
---@return string|nil error
local function parse(body)
   local ok, response = pcall(wezterm.json_parse, body)
   if not ok or type(response) ~= 'table' then
      return nil, 'invalid JSON response'
   end

   if tonumber(response.code) ~= 200 or type(response.data) ~= 'table' then
      return nil, response.msg or response.message or 'GLM API error'
   end

   local limits = response.data.limits
   if type(limits) ~= 'table' then
      return nil, 'response has no limits'
   end

   for _, limit in ipairs(limits) do
      if type(limit) == 'table' and limit.type == 'TOKENS_LIMIT' then
         return {
            tokens_percentage = tonumber(limit.percentage) or 0,
            tokens_reset = tonumber(limit.nextResetTime) or 0,
         }
      end
   end

   return nil, 'response has no TOKENS_LIMIT'
end

---@param opts table
---@return table|nil usage
---@return string|nil error
local function fetch(opts)
   local api_key, env_description = get_api_key(opts)
   if not api_key or api_key == '' then
      return nil, env_description .. ' not set'
   end

   local args = {
      option(opts, 'curl_path', 'curl'),
      '-fsS',
      '--max-time', tostring(option(opts, 'timeout', 8)),
      '-H', 'Authorization: Bearer ' .. api_key,
      '-H', 'Accept: application/json',
      option(opts, 'api_url', API_URL),
   }

   local success, stdout, stderr = wezterm.run_child_process(args)
   if not success then
      return nil, (stderr and stderr ~= '') and stderr or 'curl failed'
   end
   return parse(stdout)
end

---Return GLM token usage, cached for `cache_ttl` seconds.
---@param opts table|nil
---@return table|nil usage
---@return string|nil error
function M.get_usage(opts)
   opts = opts or {}
   local now = os.time()
   local cache_ttl = math.max(0, tonumber(option(opts, 'cache_ttl', 60)) or 60)

   if state.fetched_at > 0 and (now - state.fetched_at) < cache_ttl then
      return state.value, state.error
   end
   if state.fetching then
      return state.value, state.error
   end

   state.fetching = true
   local ok, value, err = pcall(fetch, opts)
   state.fetching = false
   state.fetched_at = now

   if not ok then
      err = tostring(value)
      value = nil
   end

   state.value = value
   state.error = err
   return value, err
end

---@param reset_ms number|nil
---@return string
local function format_reset(reset_ms)
   if not reset_ms or reset_ms <= 0 then
      return '--:--'
   end

   local seconds = math.floor(reset_ms / 1000)
   if os.date('%Y%m%d') == os.date('%Y%m%d', seconds) then
      return os.date('%H:%M', seconds)
   end
   return os.date('%m-%d', seconds)
end

---@param value string
---@param max_len number
---@return string
local function truncate(value, max_len)
   if max_len <= 0 or #value <= max_len then
      return value
   end
   if max_len <= 3 then
      return value:sub(1, max_len)
   end
   return value:sub(1, max_len - 3) .. '...'
end

---Return the text used by status-bar integrations.
---@param opts table|nil
---@return string text
---@return table|nil usage
---@return string|nil error
function M.get_status_text(opts)
   opts = opts or {}
   local usage, err = M.get_usage(opts)
   local text = option(opts, 'empty_text', 'N/A')

   if usage then
      local percentage = string.format('%.0f%%', usage.tokens_percentage)
      text = percentage .. ' ↻  ' .. format_reset(usage.tokens_reset)
   elseif err and option(opts, 'show_error', true) then
      text = truncate(err, tonumber(option(opts, 'error_max_len', 24)) or 24)
   end

   return text, usage, err
end

---Return `wezterm.format` items for a custom status bar.
---@param opts table|nil
---@return table
function M.format(opts)
   opts = opts or {}
   local nf = wezterm.nerdfonts or {}
   local icon = option(opts, 'icon', nf.md_chart_bar or nf.md_chart_arc or 'GLM')
   local text = M.get_status_text(opts)

   return {
      { Foreground = { Color = option(opts, 'fg', '#a6e3a1') } },
      { Background = { Color = option(opts, 'bg', 'rgba(0, 0, 0, 0.4)') } },
      { Attribute = { Intensity = option(opts, 'intensity', 'Bold') } },
      { Text = icon .. ' ' .. text .. ' ' },
   }
end

---@param window any
---@return any
local function window_key(window)
   local ok, id = pcall(function()
      return window:window_id()
   end)
   return (ok and id) or window
end

---Register a standalone right-status handler.
---When composing multiple status providers, set `status = false` and call `format()` yourself.
---@param _config table
---@param opts table|nil
function M.apply_to_config(_config, opts)
   opts = opts or {}
   if opts.status == false or state.status_registered then
      return
   end

   state.status_registered = true
   wezterm.on('update-right-status', function(window, _pane)
      local status = wezterm.format(M.format(opts))
      local key = window_key(window)
      if state.last_status_by_window[key] ~= status then
         state.last_status_by_window[key] = status
         window:set_right_status(status)
      end
   end)
end

---Clear the cached value and error.
function M.invalidate()
   state.value = nil
   state.error = nil
   state.fetched_at = 0
end

return M
