#!/bin/bash

if [[ $EUID -ne 0 ]]; then
  echo "ERROR: You must be a root" 2>&1
  exit 1
else

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

 if [ -e /var/www/html/backup/current.tar.gz ]
   then
   mv /var/www/html/backup/current.tar.gz /var/www/html/backup/previous.tar.gz
 fi
 
 mv /tmp/backup.tar.gz /var/www/html/backup/current.tar.gz
  
fi
