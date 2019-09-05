#!/usr/bin/lua
-- Big thanks to:
--   baggins for the original development for NEMS 1.3
--   Kaganishu for helping with documentation and improvements for NEMS 1.5
--   NickTheGreek for contributing his findings to help improve functionality for NEMS 1.5

-- VERSION 1.5.3

https = require('ssl.https')
local handle = io.popen("/usr/local/bin/nems-info alias")
local result = handle:read("*a")
handle:close()
local nemsalias = string.gsub(result, "\n", "")
local telegram_url = 'https://api.telegram.org/bot' .. arg[1] .. '/sendMessage?'
local chat_id = '-' .. arg[2]:gsub('%g', '')

-- UTF-8 Emojis Based on State
if string.find(arg[3]:lower(), "problem") then
  scolor = "⚠️" -- Warning Sign
elseif string.find(arg[3]:lower(), "flappingstart") then
  scolor = "⚠️" -- Warning Sign
else
  scolor = "✅" -- White Heavy Check Mark
end
-- Extras (may use later)
-- scolor = "🚫" -- No Entry Sign
-- scolor = "❓" -- Question Mark

   Notification = "Notification Type: " .. arg[3] ..'\n'    --$NOTIFICATIONTYPE$
   Host = "Host: " .. arg[4] ..'\n'                         --$HOSTNAME$
   State = "State: " .. arg[5] ..'\n'                       --$HOSTSTATE$/$SERVICESTATE$
   Address = "Address: " .. arg[6] ..'\n'                   --$HOSTADDRESS$
   Info = "Info: "  .. arg[7] ..'\n'                        --$HOSTOUTPUT$/"$SERVICEOUTPUT$"
   Date_Time = "Date/Time: " .. arg[8] ..'\n'               --$LONGDATETIME$
   Alias = "Reporting NEMS Server: " .. nemsalias .. '\n'   --NEMS Server Alias

   if (#arg == 8) then --assumes this since 8 arguments have been passed
     message = scolor .. '\n' .. '\n' .. Notification .. Host ..State .. Address .. Info .. Date_Time .. Alias
   else 
     Service = "Service: " .. arg[8] .. '\n'                  --$SERVICEDESC$
     message = scolor .. '\n' .. '\n' .. '***** NEMS Linux ***** ' ..'\n' ..'\n' .. Notification .. Host  .. Service ..State .. Address .. Info .. Date_Time .. Alias
   end

local data_str = 'chat_id=' .. chat_id .. '&text=' .. message..''  
local res, code, headers, status = https.request(telegram_url, data_str)
