#!/bin/bash

# Load Config
hwid=`/usr/local/bin/nems-info hwid`
apikey=$(cat /usr/local/share/nems/nems.conf | grep apikey | printf '%s' $(cut -n -d '=' -f 2))
password=$(cat /usr/local/share/nems/nems.conf | grep password | printf '%s' $(cut -n -d '=' -f 2))
obskey=$(cat /usr/local/share/nems/nems.conf | grep obskey | printf '%s' $(cut -n -d '=' -f 2))

if [[ $apikey == '' ]] || [[ $password == '' ]] || [[ $obskey == '' ]]; then
  echo NEMS Migrator Offsite Backup is not currently enabled.
  exit
fi;

# Encrypt the file
gpg --yes --batch --passphrase="$password" -c /var/www/html/backup/snapshot/backup.nems

curl -F "hwid=$hwid" -F "apikey=$apikey" -F "backup=@/var/www/html/backup/snapshot/backup.nems.gpg" https://nemslinux.com/api/offsite-backup/
