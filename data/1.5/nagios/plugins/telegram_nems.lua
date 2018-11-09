#!/usr/bin/lua
https = require('ssl.https')
local handle = io.popen("/usr/local/bin/nems-info alias")
local result = handle:read("*a")
handle:close()
local alias = string.gsub(result, "\n", "")
local telegram_url = 'https://api.telegram.org/bot' .. arg[1] .. '/sendMessage?'
local chat_id = '-' .. arg[2]

   Notification = "Notification Type: " .. arg[3] ..'\n'    --$NOTIFICATIONTYPE$
   Host = "Host: " .. arg[4] ..'\n'                         --$HOSTNAME$
   State = "State: " .. arg[5] ..'\n'                       --$HOSTSTATE$/$SERVICESTATE$
   Address = "Address: " .. arg[6] ..'\n'                   --$HOSTADDRESS$
   Info = "Info: "  .. arg[7] ..'\n'                        --$HOSTOUTPUT$/"$SERVICEOUTPUT$"
   Date_Time = "Date/Time: " .. arg[8] ..'\n'               --$LONGDATETIME$
   Alias = "Reporting NEMS Server: " .. alias .. '\n'       --NEMS Server Alias

   if (#arg == 8) then --assumes this since 8 arguments have been passed
     message = '***** NEMS Linux ***** ' ..'\n' ..'\n' .. Notification .. Host ..State .. Address .. Info .. Date_Time .. Alias
   else 
     Service = "Service: " .. arg[8] .. '\n'                  --$SERVICEDESC$
     message = '***** NEMS Linux ***** ' ..'\n' ..'\n' .. Notification .. Host  .. Service ..State .. Address .. Info .. Date_Time .. Alias
   end

local data_str = 'chat_id=' .. chat_id .. '&text=' .. message..''  
local res, code, headers, status = https.request(telegram_url, data_str)
