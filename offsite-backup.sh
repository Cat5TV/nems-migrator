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

if [[ $1 == 'restore' ]] && [[ $2 != '' ]]; then
  printf "Checking NEMS Migrator Off-Site Backup Server for backup # $2..."
  if [ -f /tmp/backup.nems.gpg ]; then
    rm /tmp/backup.nems.gpg
  fi;
  curl -F "hwid=$hwid" -F "osbkey=$osbkey" https://nemslinux.com/api/offsite-backup/restore.php -o /tmp/backup.nems.gpg
  gpg --yes --batch --passphrase="::$osbpass::$osbkey::" --decrypt /tmp/backup.nems.gpg > /tmp/backup.nems
  if ! tar -tf /tmp/backup.nems &> /dev/null; then
    echo Error with backup.
    exit
  else
    nems-restore /tmp/backup.nems
  fi
else
  # Should wrap this bit in a check to the API to see if this user is authorized. No point in uploading if not.

  # Encrypt the file
  # Combine the user's passphrase with the OSB Key to further strenghten the entropy of the passphrase
  gpg --yes --batch --passphrase="::$osbpass::$osbkey::" -c /var/www/html/backup/snapshot/backup.nems

  # Upload the file
  response=$(curl -s -F "hwid=$hwid" -F "osbkey=$osbkey" -F "backup=@/var/www/html/backup/snapshot/backup.nems.gpg" https://nemslinux.com/api/offsite-backup/)
  if [[ $response == 1 ]]; then
    echo "`date`::$response::Success::File was accepted" >> /var/log/nems/nems-osb.log
  elif [[ $response == 0 ]]; then
    echo "`date`::$response::Failed::Upload failed" >> /var/log/nems/nems-osb.log
  elif [[ $response == 2 ]]; then
    echo "`date`::$response::Failed::File permissions issue on receiving server" >> /var/log/nems/nems-osb.log
  elif [[ $response == 3 ]]; then
    echo "`date`::$response::Failed::Could not access authentication service" >> /var/log/nems/nems-osb.log
  elif [[ $response == 4 ]]; then
    echo "`date`::$response::Failed::Invalid credentials" >> /var/log/nems/nems-osb.log
  elif [[ $response == 5 ]]; then
    echo "`date`::$response::Failed::Bad query" >> /var/log/nems/nems-osb.log
  else
    echo "`date`::-::Failed::Unknown error" >> /var/log/nems/nems-osb.log # Replace response with -- as it may be anything
  fi;
fi;
