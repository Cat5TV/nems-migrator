#!/usr/bin/env tclsh
# MOTD script original? / mod mewbies.com v.03 2013 Sep 01

# * Variables
set var(user) $env(USER)
set var(path) $env(PWD)
set var(home) $env(HOME)

# * Check if we're somewhere in /home
#if {![string match -nocase "/home*" $var(path)]} {
if {![string match -nocase "/home*" $var(path)] && ![string match -nocase "/usr/home*" $var(path)] } {
  return 0
}

# * Find NEMS Version
#set nemsver [exec -- /bin/cat /var/www/html/inc/ver.txt]
#set nemsveravail [exec -- /bin/cat /var/www/html/inc/ver-available.txt]
# NEMS 1.2
set nemsplatform [exec -- /usr/local/bin/nems-info platform-name]
set nemsver [exec -- /usr/local/bin/nems-info nemsver]
set nemsveravail [exec -- /usr/local/bin/nems-info nemsveravail]

# * Calculate last login
set lastlog [exec -- lastlog -u $var(user)]
set ll(1)  [lindex $lastlog 7]
set ll(2)  [lindex $lastlog 8]
set ll(3)  [lindex $lastlog 9]
set ll(4)  [lindex $lastlog 10]
set ll(5)  [lindex $lastlog 6]

# * Determine local IP address of NEMS Server
#set nemsip [exec -- /bin/cat /tmp/ip.nems]
set nemsip [exec -- /usr/local/bin/nems-info ip]

# * Calculate current system uptime
set uptime    [exec -- /usr/bin/cut -d. -f1 /proc/uptime]
set up(days)  [expr {$uptime/60/60/24}]
set up(hours) [expr {$uptime/60/60%24}]
set up(mins)  [expr {$uptime/60%60}]
set up(secs)  [expr {$uptime%60}]

# Disk Usage percentage...
set usage [lindex [exec -- /usr/local/bin/nems-info diskusage] 0]

# * Calculate SSH logins:
# set logins     [exec -- w -s]
# set log(c)  [lindex $logins 5]
# NEMS 1.2
set log(c) [exec -- /usr/local/bin/nems-info users]

# * Calculate processes
set psa [expr {[lindex [exec -- ps -A h | wc -l] 0]-000}]
set psu [expr {[lindex [exec -- ps U $var(user) h | wc -l] 0]-002}]
set verb are
if [expr $psu < 2] {
	if [expr $psu = 0] {
		set psu none
	} else {
		set verb is
		}
}

# * Calculate current system load
set loadavg     [exec -- /bin/cat /proc/loadavg]
set sysload(1)  [lindex $loadavg 0]
set sysload(5)  [lindex $loadavg 1]
set sysload(15) [lindex $loadavg 2]
set sysload(10080) [exec -- /usr/local/bin/nems-info loadaverageround]

# * Calculate Memory
set memory  [exec -- free -m]
set mem(t)  [lindex $memory 7]
set mem(u)  [lindex $memory 8]
set mem(f)  [lindex $memory 9]
set mem(c)  [lindex $memory 16]
set mem(s)  [lindex $memory 19]

# * Calculate disk temperature from hddtemp
#set hddtemp [lindex [exec -- /usr/bin/hddtemp /dev/sda -uf | cut -c "31-35"] 0]

# * Calculate temperature from lm-sensors
#set temperature    [exec -- sensors -f | grep °F | tr -d '+']
#set tem(0)  [lindex $temperature 2]
#set tem(m)  [lindex $temperature 4]
#set tem(c)  [lindex $temperature 15]

# * Display weather
#set weather     [exec -- /usr/share/./weather.sh]
#set wthr(t)  [lindex $weather 0]
#set wthr(d)  [lindex $weather 1]
#set wthr(e)  [lindex $weather 2]

# * ASCII head
set head {
                                 \ |  __|   \  |   __|                     
                                .  |  _|   |\/ | \__ \                     
                               _|\_| ___| _|  _| ____/                     }

set creator {
                                 BY: ROBBIE FERGUSON                       
                                    NEMSLINUX.COM                          
}

# * Print Output
puts "\033\[01;32m$head\033\[0m"
puts "\033\[01;90m$creator\033\[0m"
puts "  \033\[35mNEMS Platform....:\033\[0m \033\[36m$nemsplatform\033\[0m"
puts "  \033\[35mNEMS Version.....:\033\[0m \033\[36m$nemsver\033\[0m \033\[33m\(Current Version is $nemsveravail\)\033\[0m"
puts "  \033\[35mNEMS IP Address..:\033\[0m \033\[36m$nemsip\033\[0m"
puts "  \033\[35mLast Login.......:\033\[0m \033\[36m$ll(1) $ll(2) $ll(3) $ll(4) from\033\[0m \033\[33m$ll(5)\033\[0m"
puts "  \033\[35mUptime...........:\033\[0m \033\[36m$up(days)days $up(hours)hours $up(mins)minutes $up(secs)seconds\033\[0m"
puts "  \033\[35mLoad.............:\033\[0m \033\[36m$sysload(1) (1 minute) $sysload(5) (5 minutes) $sysload(15) (15 minutes)"
puts "                     $sysload(10080) (1 week)\033\[0m"
#puts "  \033\[35mMemory MB........:\033\[0m \033\[36m$mem(t)  Used: $mem(u)  Free: $mem(f)  Free Cached: $mem(c)  Swap In Use: $mem(s)\033\[0m"
puts "  \033\[35mMemory...........:\033\[0m \033\[36mTotal: $mem(t) MB / Used: $mem(u) MB / Free: $mem(f) MB / Cached: $mem(c) MB\033\[0m"
#puts "  \033\[35mTemperature...:\033\[0m \033\[36mCore0: $tem(0)  M/B: $tem(m)  CPU: $tem(c)  Disk: ${hddtemp}\033\[0m"
puts "  \033\[35mDisk Usage.......:\033\[0m \033\[36mYou're using ${usage}% of your SD Card space\033\[0m"
puts "  \033\[35mSSH Logins.......:\033\[0m \033\[36m$log(c) logged in\033\[0m"
puts "  \033\[35mProcesses........:\033\[0m \033\[36m$psa total running of which $psu $verb yours\033\[0m"
#puts "  \033\[35mWeather.......:\033\[0m \033\[36m$wthr(t) $wthr(d) $wthr(e)\n\033\[0m"
#puts "\033\[01;32m  ::::::::::::::::::::::::::::::::::-RULES-::::::::::::::::::::::::::::::::::"
#puts "    This is a private system that you are not to give out access to anyone"
#puts "    without permission from the admin. No illegal files or activity. Stay,"
#puts "    in your home directory, keep the system clean, and make regular backups."
#puts "     -==  DISABLE YOUR PROGRAMS FROM KEEPING SENSITIVE LOGS OR HISTORY ==-\033\[0m\n"

if {[file exists /etc/changelog]&&[file readable /etc/changelog]} {
  puts " . .. More or less important system informations:\n"
  set fp [open /etc/changelog]
  while {-1!=[gets $fp line]} {
    puts "  ..) $line"
  }
  close $fp
  puts ""
}
