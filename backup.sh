#!/bin/bash

tar czvf /tmp/backup.tar.gz \
 /var/www/html/inc/ver.txt \
 /etc/nagvis/etc/maps/ \
 /etc/nagios3/resource.cfg \
 /var/log/ \
 /var/www/nconf/output/ \
 /etc/nagios3/Default_collector/ \
 /etc/nagios3/global/
 


if [ -e /root/backup/current.tar.gz ]
  then
  mv /root/backup/current.tar.gz /root/backup/previous.tar.gz
fi
mv /tmp/backup.tar.gz /root/backup/current.tar.gz
