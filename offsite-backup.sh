#!/bin/bash

# Encrypt the file
gpg --yes --batch --passphrase="test" -c /var/www/html/backup/snapshot/backup.nems

# Load Config
hwid=`/usr/local/bin/nems-info hwid`
apikey=$(cat /usr/local/share/nems/nems.conf | grep apikey | printf '%s' $(cut -n -d '=' -f 2))

curl -F "hwid=$hwid" -F "apikey=$apikey" -F "backup=@/var/www/html/backup/snapshot/backup.nems.gpg" https://nemslinux.com/api/offsite-backup/
