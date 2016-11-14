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
 
 if [ -d /var/www/html/backup ]
   then
   echo Saving to existing backup set at /var/www/html/backup
   else
   mkdir /var/www/html/backup
   echo Created backup folder at /var/www/html/backup
 fi
 
 ver=$(cat "/tmp/nems_migrator_restore/var/www/html/inc/ver.txt")
 
 # NagVis maps are stored differently in NEMS 1.0
 if [[ $ver == "1.0" ]]; then
		nagvis="/etc/nagvis/maps/"
   else
		nagvis="/etc/nagvis/etc/maps/"
 fi


 service nagios3 stop
 
 tar czf /tmp/backup.tar.gz \
  /var/www/html/inc/ver.txt \
  $nagvis \
  /etc/nagios3/resource.cfg \
  /var/log/ \
  /var/www/nconf/output/ \
  /etc/nagios3/Default_collector/ \
  /etc/nagios3/global/ \
  /var/lib/mysql/

 service nagios3 start
 
 if [ -e /var/www/html/backup/backup.nems ]
   then
   rm /var/www/html/backup/backup.nems
 fi
 
 mv /tmp/backup.tar.gz /var/www/html/backup/backup.nems

 echo "Done. You'll find the backup at /var/www/html/backup/backup.nems"

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
