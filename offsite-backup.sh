#!/bin/bash

# Send an encrypted version of your NEMS Migrator backup file to the offsite backup service.
# This only happens if you enable it.
# Learn more about how to enable the offsite backup service at https://docs.nemslinux.com/features/nems-migrator

# Load Config
hwid=`/usr/local/bin/nems-info hwid`
apikey=$(cat /usr/local/share/nems/nems.conf | grep apikey | printf '%s' $(cut -n -d '=' -f 2))
password=$(cat /usr/local/share/nems/nems.conf | grep password | printf '%s' $(cut -n -d '=' -f 2))
obskey=$(cat /usr/local/share/nems/nems.conf | grep obskey | printf '%s' $(cut -n -d '=' -f 2))

if [[ $apikey == '' ]] || [[ $password == '' ]] || [[ $obskey == '' ]]; then
  echo NEMS Migrator Offsite Backup is not currently enabled.
  exit
fi;

# Should wrap this bit in a check to the API to see if this user is authorized. No point in uploading if not.

# Encrypt the file
gpg --yes --batch --passphrase="$password" -c /var/www/html/backup/snapshot/backup.nems

# Upload the file
curl -F "hwid=$hwid" -F "apikey=$apikey" -F "backup=@/var/www/html/backup/snapshot/backup.nems.gpg" https://nemslinux.com/api/offsite-backup/
