#!/bin/bash

start=`date +%s`

# Don't allow the script to run if it's already running. May occur if your logs or config take longer than 5 minutes to backup.
if pidof -o %PPID -x "`basename "$0"`">/dev/null; then
    echo "Process already running"
    exit
fi


if [[ $EUID -ne 0 ]]; then
  echo "ERROR: You must be a root" 2>&1
  exit 1
else

# DO NOT run a backup as we're running in freeze mode (only used by Robbie for creating the image)
 if [ -e /tmp/nems.freeze ]
   then
   exit
 fi
 
 if [ -d /var/www/html/backup/snapshot ]
   then
   echo Saving to existing backup set at /var/www/html/backup/snapshot
   else
   # Legacy Support for NEMS 1.0 to 1.2.x (will not be in RAM)
   mkdir -p /var/www/html/backup/snapshot
   echo Created backup folder at /var/www/html/backup/snapshot
 fi
 
 ver=$(/usr/local/bin/nems-info nemsver)
 
 # NagVis maps are stored differently in NEMS 1.0
 if [[ $ver = "" ]]; then
   echo NEMS Version data is corrupt. Did you remove files from /var/www?
   echo This can be fixed. Contact me for help in restoring your version data.
   echo Aborted.
   exit
 fi
 if [[ $ver = "1.0" ]]; then
		nagvis="maps/"
   else
		nagvis="etc/maps/"
 fi

 if (( $(awk 'BEGIN {print ("'$ver'" >= "'1.2'")}') )); then
   # Additional items to backup if version matches
   add="/etc/rpimonitor \
     /etc/webmin \
   "
 fi

 if (( $(awk 'BEGIN {print ("'$ver'" >= "'1.3'")}') )); then
   # Additional items to backup if version matches
   add="/var/www/certs \
   "
 fi

 service nagios3 stop
 
 tar czf /tmp/backup.tar.gz \
  /home/pi/nems.conf \
  /var/www/htpasswd \
  /var/www/nconf/config \
  /etc/nagvis/$nagvis \
  /etc/nagios3/resource.cfg \
  /etc/nagios3/cgi.cfg \
  /etc/nagios3/htpasswd.users \
  /var/log/ \
  /var/www/nconf/output/ \
  /etc/nagios3/Default_collector/ \
  /etc/nagios3/global/ \
  /var/lib/mysql/ \
  $add

 service nagios3 start
 
 if [ -e /var/www/html/backup/snapshot/backup.nems ]
   then
   rm /var/www/html/backup/snapshot/backup.nems
 fi

 mv /tmp/backup.tar.gz /var/www/html/backup/snapshot/backup.nems

 echo "Done. You'll find the backup at /var/www/html/backup/snapshot/backup.nems"

 echo ""
 echo You can access the file from your computer by navigating to http://NEMSIP/backup/
 echo ""

 end=`date +%s`

 runtime=$((end-start))


 if [ -d /var/log/nems ]
   then
     echo $runtime > /var/log/nems/migrator-backup-runtime.log
   else
     mkdir /var/log/nems
     echo $runtime > /var/log/nems/migrator-backup-runtime.log
 fi
 
fi
