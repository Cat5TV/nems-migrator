#!/bin/bash

# Send an encrypted version of your NEMS Migrator backup file to the offsite backup service.
# This only happens if you enable it.
# Learn more about how to enable the offsite backup service at https://docs.nemslinux.com/features/nems-migrator

# Load Config
hwid=`/usr/local/bin/nems-info hwid`
osbpass=$(cat /usr/local/share/nems/nems.conf | grep osbpass | printf '%s' $(cut -n -d '=' -f 2))
osbkey=$(cat /usr/local/share/nems/nems.conf | grep osbkey | printf '%s' $(cut -n -d '=' -f 2))

if [[ $osbpass == '' ]] || [[ $osbkey == '' ]]; then
  echo NEMS Migrator Offsite Backup is not currently enabled.
  exit
fi;

# Should wrap this bit in a check to the API to see if this user is authorized. No point in uploading if not.

# Encrypt the file
# Combine the user's passphrase with the OSB Key to further strenghten the entropy of the passphrase
gpg --yes --batch --passphrase="::$osbpass::$osbkey::" -c /var/www/html/backup/snapshot/backup.nems

# Upload the file
curl -F "hwid=$hwid" -F "osbkey=$osbkey" -F "backup=@/var/www/html/backup/snapshot/backup.nems.gpg" https://nemslinux.com/api/offsite-backup/
