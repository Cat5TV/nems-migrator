#!/usr/bin/lua
-- Big thanks to:
--   baggins for the original development for NEMS 1.3
--   Kaganishu for helping with documentation and improvements for NEMS 1.5
--   NickTheGreek for contributing his findings to help improve functionality for NEMS 1.5

-- VERSION 1.5.6

https = require('ssl.https')
local handle = io.popen("/usr/local/bin/nems-info alias")
local result = handle:read("*a")
handle:close()
local nemsalias = string.gsub(result, "\n", "")
local telegram_url = 'https://api.telegram.org/bot' .. arg[1] .. '/sendMessage?'
local chat_id = '-' .. arg[2]:gsub('%g', '')

-- UTF-8 Emojis Based on State
if string.find(arg[3]:lower(), "problem") then
  emoji = "⚠️" -- Warning Sign
elseif string.find(arg[3]:lower(), "flappingstart") then
  emoji = "⚠️" -- Warning Sign
else
  emoji = "✅" -- White Heavy Check Mark
end
-- Extras (may use later)
-- emoji = "🚫" -- No Entry Sign
-- emoji = "❓" -- Question Mark

   Notification = "*Notification Type:*\n" .. arg[3] ..'\n\n'    --$NOTIFICATIONTYPE$
   Host = "*Host:*\n" .. arg[4] ..'\n\n'                         --$HOSTNAME$
   State = "*State:*\n" .. arg[5] ..'\n\n'                       --$HOSTSTATE$/$SERVICESTATE$
   Address = "*Address:*\n" .. arg[6] ..'\n\n'                   --$HOSTADDRESS$
   Info = "*Info:*\n"  .. arg[7] ..'\n\n'                        --$HOSTOUTPUT$/"$SERVICEOUTPUT$"
   Date_Time = "*Date/Time:*\n" .. arg[8] ..'\n\n'               --$LONGDATETIME$
   Alias = "*Reporting NEMS Server:*\n" .. nemsalias .. '\n\n'   --NEMS Server Alias

   if (#arg == 8) then --assumes this since 8 arguments have been passed
     message = emoji .. '\n\n' .. Alias .. Date_Time .. Notification .. Host ..State .. Address .. Info
   else 
     Service = "*Service:*\n" .. arg[9] .. '\n\n'                  --$SERVICEDESC$
     message = emoji .. '\n\n' .. Alias .. Date_Time .. Notification .. Host  .. Service ..State .. Address .. Info
   end

local data_str = 'parse_mode=Markdown&chat_id=' .. chat_id .. '&text=' .. message..''  
local res, code, headers, status = https.request(telegram_url, data_str)
