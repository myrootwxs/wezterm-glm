local calls = 0
local response = 'ok'
local handler = nil

local wezterm = {
   nerdfonts = {},
   json_parse = function(body)
      if body == 'ok' then
         return {
            code = 200,
            data = {
               limits = {
                  { type = 'TIME_LIMIT', percentage = 1 },
                  { type = 'TOKENS_LIMIT', percentage = 7.4, nextResetTime = 0 },
               },
            },
         }
      end
      if body == 'api-error' then
         return { code = 401, msg = 'invalid API key' }
      end
      error('bad JSON')
   end,
   run_child_process = function(_args)
      calls = calls + 1
      return true, response, ''
   end,
   on = function(name, callback)
      assert(name == 'update-right-status')
      handler = callback
   end,
   format = function(items)
      local text = ''
      for _, item in ipairs(items) do
         text = text .. (item.Text or '')
      end
      return text
   end,
}

package.loaded.wezterm = wezterm
local plugin = dofile('plugin/init.lua')

local usage = assert(plugin.get_usage({ api_key = 'test' }))
assert(usage.tokens_percentage == 7.4)
assert(usage.tokens_reset == 0)
assert(calls == 1)

assert(plugin.get_usage({ api_key = 'test' }))
assert(calls == 1, 'successful responses must be cached')

local text = plugin.get_status_text({ api_key = 'test' })
assert(text == '7% ↻  --:--')

plugin.invalidate()
response = 'api-error'
local value, err = plugin.get_usage({ api_key = 'test' })
assert(value == nil and err == 'invalid API key')
assert(calls == 2)
plugin.get_usage({ api_key = 'test' })
assert(calls == 2, 'errors must be cached')

plugin.invalidate()
response = 'ok'
plugin.apply_to_config({}, { api_key = 'test' })
assert(type(handler) == 'function')
local window = {
   window_id = function() return 1 end,
   set_right_status = function(self, status) self.status = status end,
}
handler(window, {})
assert(window.status == 'GLM 7% ↻  --:-- ')

print('wezterm-glm tests passed')
