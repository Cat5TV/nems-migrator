#!/bin/bash
# NEMS Linux Migrator Off-Site Backup Restore
# By Robbie Ferguson
# nemslinux.com | baldnerd.com | category5.tv

# Load Config
hwid=`/usr/local/bin/nems-info hwid`
osbpass=$(cat /usr/local/share/nems/nems.conf | grep osbpass | printf '%s' $(cut -n -d '=' -f 2))
osbkey=$(cat /usr/local/share/nems/nems.conf | grep osbkey | printf '%s' $(cut -n -d '=' -f 2))
timestamp=$(/bin/date +%s)

if [[ $osbpass == '' ]] || [[ $osbkey == '' ]]; then
  echo NEMS Migrator Offsite Backup is not currently enabled.
  exit
fi;

if [[ -f /tmp/osb.backup.nems ]]; then
  rm /tmp/osb.backup.nems
fi
# Load Account Data
  data=$(curl -s -F "hwid=$hwid" -F "osbkey=$osbkey" https://nemslinux.com/api-backend/offsite-backup-checkin.php)
  set -f
  menu=''
  counter=0
  NEWLINE=$'\n'
  for line in $data; do
    let counter+=1
    datarr=(${line//::/ })
    serverdate="${datarr[0]}"
    filedate="${datarr[1]}"
    filelocaldate="${datarr[2]}"
    filesize="${datarr[3]}"
    menu="$menu$counter $filelocaldate${NEWLINE}"
  done

HEIGHT=25
WIDTH=25
CHOICE_HEIGHT=25
BACKTITLE="NEMS Linux"
TITLE="Off-Site Backup"
MENU="Download Backup:"

OPTIONS=($menu)

CHOICE=$(dialog --clear \
                --backtitle "$BACKTITLE" \
                --title "$TITLE" \
                --menu "$MENU" \
                $HEIGHT $WIDTH $CHOICE_HEIGHT \
                "${OPTIONS[@]}" \
                2>&1 >/dev/tty)

if test $? -eq 0
then 
  clear
else
  clear
  echo "Canceled"
  exit
fi

  counter=0
  for line in $data; do
    let counter+=1
    if [[ $CHOICE == $counter ]]; then
      datarr=(${line//::/ })
      serverdate="${datarr[0]}"
      filelocaldate="${datarr[2]}"
      echo "Downloading NEMS Migrator Off-Site Backup Server for backup from $filelocaldate..."
      echo ""
      curl -F "hwid=$hwid" -F "osbkey=$osbkey" -F "date=$serverdate" https://nemslinux.com/api-backend/offsite-backup-restore.php -o /tmp/osb.backup.nems
      echo ""
#      echo "Attempting decryption..."
#      echo ""
#      gpg --yes --batch --passphrase="::$osbpass::$osbkey::" --decrypt /tmp/osb.backup.nems.gpg > /tmp/osb.backup.nems
#      if [ -f /tmp/osb.backup.nems.gpg ]; then
#        rm /tmp/osb.backup.nems.gpg
#      fi;
      if ! tar -tf /tmp/osb.backup.nems &> /dev/null; then
        echo Error with backup.
        exit
      else
        echo ""
        echo "Successfully downloaded."
        echo ""
      fi
    fi
  done



