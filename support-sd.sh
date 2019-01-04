#!/bin/bash
# support.nems Self-Destruct
# Simply ensures a private support.nems file doesn't get accidentally left behind on a NEMS server.
if [[ -f /var/www/html/backup/snapshot/support.nems ]]; then
  find /var/www/html/backup/snapshot/support.nems -mmin +15 -type f -exec rm -fv /var/www/html/backup/snapshot/support.nems \;
fi

if [[ -f /var/www/html/backup/snapshot/support-report.txt ]]; then
  find /var/www/html/backup/snapshot/support-report.txt -mmin +15 -type f -exec rm -fv /var/www/html/backup/snapshot/support-report.txt \;
fi

