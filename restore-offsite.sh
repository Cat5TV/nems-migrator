#!/bin/bash
# NEMS Linux Migrator Off-Site Backup Restore
# By Robbie Ferguson
# nemslinux.com | baldnerd.com | category5.tv

# Load Config

# If a hardware ID override is not provided, use the current device's HWID
# (Assume restoring to same device)
if [[ $1 != '' ]]; then
  hwid=$1
else
  hwid=`/usr/local/bin/nems-info hwid`
fi
osbpass=$(cat /usr/local/share/nems/nems.conf | grep osbpass | printf '%s' $(cut -n -d '=' -f 2))
osbkey=$(cat /usr/local/share/nems/nems.conf | grep osbkey | printf '%s' $(cut -n -d '=' -f 2))
timestamp=$(/bin/date +%s)

if [[ $osbpass == '' ]] || [[ $osbkey == '' ]]; then
  echo -e "\e[41mNEMS Migrator Offsite Backup is not currently enabled.\e[0m"
  if [[ $osbpass == '' ]]; then
    echo ""
    echo You must add your Personal Encryption/Decryption Password
    echo in NEMS System Settings Tool.
  fi
  if [[ $osbkey == '' ]]; then
    echo ""
    echo You must add the NEMS Cloud Services key in NEMS System
    echo Settings Tool that matches $hwid.
  fi
  echo ""
  exit 1
fi;

if [[ -f /tmp/osb.backup.nems.gpg ]]; then
  rm /tmp/osb.backup.nems.gpg
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
BACKTITLE="NEMS Linux Migrator Off-Site Backup"
TITLE="Restore From OSB"
MENU="Choose Date:"

OPTIONS=($menu)

CHOICE=$(dialog --clear \
                --colors \
                --backtitle "\Zb\Z7$BACKTITLE\Zn" \
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
  if [[ $datarr == "4" ]]; then # Invalid credentials
    echo ""
    echo "ERROR: Unauthorized (You do not have access to $hwid)"
    echo ""
    echo "Did you enter the correct HWID, OSB Key and Decryption Password?"
    echo ""
  fi
  echo "Canceled"
  echo ""
  exit 1
fi

  counter=0
  for line in $data; do
    let counter+=1
    if [[ $CHOICE == $counter ]]; then
      datarr=(${line//::/ })
      serverdate="${datarr[0]}"
      filelocaldate="${datarr[2]}"
      echo "Downloading OSB from $filelocaldate..."
      echo ""
      curl -F "hwid=$hwid" -F "osbkey=$osbkey" -F "date=$serverdate" https://nemslinux.com/api-backend/offsite-backup-restore.php -o /tmp/osb.backup.nems.gpg
      echo ""
      echo "Attempting decryption..."
      echo ""
      gpg --yes --batch --passphrase="::$osbpass::$osbkey::" --decrypt /tmp/osb.backup.nems.gpg > /tmp/osb.backup.nems
      if [ -f /tmp/osb.backup.nems.gpg ]; then
        rm /tmp/osb.backup.nems.gpg
      fi;
      if ! tar -tf /tmp/osb.backup.nems &> /dev/null; then
        echo Error with backup.
        exit 1
      else
        echo ""
        echo "Successfully downloaded."
        echo ""
      fi
    fi
  done



