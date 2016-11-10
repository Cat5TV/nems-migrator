#!/bin/bash

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

 tar czf /tmp/backup.tar.gz \
  /var/www/html/inc/ver.txt \
  /etc/nagvis/etc/maps/ \
  /etc/nagios3/resource.cfg \
  /var/log/ \
  /var/www/nconf/output/ \
  /etc/nagios3/Default_collector/ \
  /etc/nagios3/global/

 if [ -e /var/www/html/backup/backup.nems ]
   then
   rm /var/www/html/backup/backup.nems
 fi
 
 mv /tmp/backup.tar.gz /var/www/html/backup/backup.nems

 echo "Done. You'll find the backup at /var/www/html/backup/backup.nems"

 echo ""
 echo You can access the file from your computer by navigating to http://NEMSIP/backup/
 echo ""

fi
