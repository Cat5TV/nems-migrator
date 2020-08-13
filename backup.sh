#!/bin/bash
ver=$(/usr/local/bin/nems-info nemsver)

 # NagVis maps are stored differently in NEMS 1.0
 if [[ $ver = "" ]]; then
   echo Could not detect the version of your NEMS server. Is this NEMS Linux?
   echo Cannot continue.
   exit
 fi
 if [[ $ver = "1.0" ]]; then
		nagvis="maps/"
   else
		nagvis="etc/maps/"
 fi

 # Store some board data in the Windows-readable portion of the SD card
 # As requested by Marshman: https://forum.nemslinux.com/viewtopic.php?f=10&t=566
   alias=$(/usr/local/bin/nems-info alias)
   hwid=$(/usr/local/bin/nems-info hwid)
   platformname=$(/usr/local/bin/nems-info platform-name)
   echo "NEMS Server System Information" > /boot/NEMS_SERVER.txt
   echo "------------------------------" >> /boot/NEMS_SERVER.txt
   echo "Platform:           $platformname" >> /boot/NEMS_SERVER.txt
   echo "NEMS Linux Version: $ver" >> /boot/NEMS_SERVER.txt
   echo "NEMS HWID:          $hwid" >> /boot/NEMS_SERVER.txt
   echo "NEMS Server Alias:  $alias" >> /boot/NEMS_SERVER.txt


 # Only create a backup file every 30 minutes.
 if [[ -f /var/www/html/backup/snapshot/backup.nems ]]; then
   if ! test `find "/var/www/html/backup/snapshot/backup.nems" -mmin +30`
   then
     # Current backup file is less than 30 minutes old. Abort.
     exit
   fi
 fi

 mainpriv=''
 mainpub=''

 if (( $(awk 'BEGIN {print ("'$ver'" >= "'1.4'")}') )); then
   nagios=nagios
   # Modern Configs
   mainpriv="/usr/local/nagios/etc/resource.cfg \
   "
   mainpub="    /usr/local/nagios/etc/cgi.cfg \
     /etc/nems/conf/Default_collector/ \
     /etc/nems/conf/global/ \
   "
 else
   nagios=nagios3
   # Legacy Configs
   mainpriv="/etc/nagios3/resource.cfg \
   "
   mainpub="    /etc/nagios3/cgi.cfg \
     /etc/nagios3/Default_collector/ \
     /etc/nagios3/global/ \
   "
 fi
 # Config shared among all versions
 mainpriv="$mainpriv \
    /usr/local/share/nems/nems.conf \
    /var/www/nconf/config \
    /var/www/nconf/output \
 "
 mainpub="$mainpub \
  /var/www/htpasswd \
  /etc/nagvis/$nagvis \
  /var/log/nems/ \
  /var/lib/mysql/ \
  /etc/rc.local \
  "

start=`date +%s`

# Don't allow the script to run if it's already running. May occur if your logs or config take longer than 5 minutes to backup.
if pidof -o %PPID -x "`basename "$0"`">/dev/null; then
    echo "Process already running"
    exit
fi


if [[ $EUID -ne 0 ]]; then
  echo "ERROR: You must be a root" 2>&1
  exit 1
else

# Check for any emergency patches distributed with nems-migrator
/root/nems/nems-migrator/patches.sh

# DO NOT run a backup as we're running in freeze mode (only used by Robbie for creating the image)
 if [ -e /tmp/nems.freeze ]
   then
   exit
 fi

 if [ -d /var/www/html/backup/snapshot ]
   then
   echo Saving to existing backup set at /var/www/html/backup/snapshot
   else
   # Legacy Support for NEMS 1.0 to 1.2.x (will not be in RAM)
   mkdir -p /var/www/html/backup/snapshot
   echo Created backup folder at /var/www/html/backup/snapshot
 fi

 addpublic=''
 addprivate=''

 if (( $(awk 'BEGIN {print ("'$ver'" >= "'1.2'")}') )); then
   # Additional items to backup if version matches
   addpublic="   /etc/webmin \
   "
   if [[ -d /etc/rpimonitor ]]; then # Only exists on Raspberry Pi. NEMS 1.4+ supports other platforms.
     addpublic="$addpublic \
       /etc/rpimonitor \
     "
   fi
 fi

 if (( $(awk 'BEGIN {print ("'$ver'" >= "'1.3'")}') )); then
   # Additional items to backup if version matches
   addprivate="$addprivate \
     /var/www/certs \
   "
 fi

# systemctl stop $nagios

# Create the archive containing sensitive information
 privfile='/tmp/private.tar.gz'
 printf "  "
 tar --warning=no-file-changed --ignore-failed-read -czf $privfile \
  $mainpriv \
  $addprivate

# Encrypt the private file if the user has specified a password in NEMS SST for encryption
  osbpass=$(cat /usr/local/share/nems/nems.conf | grep osbpass | printf '%s' $(cut -n -d '=' -f 2))

  if [[ $osbpass != '' ]]; then
    echo 'Encrypting private data with the password you entered in NEMS SST.'
    /usr/bin/gpg --yes --batch --passphrase="::$osbpass::291ea559-471e-4bda-bb7d-774e782f84c1::" -c $privfile
    rm $privfile
    privfile="$privfile.gpg"
  else
    echo 'Leaving all data unencrypted (no password entered in NEMS SST).'
  fi;


# Create the generic backup (not particularly sensitive)
 printf "  "
 tar --warning=no-file-changed --ignore-failed-read -cf - \
  $privfile \
  $mainpub \
  $addpublic | /bin/gzip --no-name > /tmp/backup.nems

# Log the file size
FILESIZE=$(stat -c%s "/tmp/backup.nems")
echo $FILESIZE > /var/www/html/backup/snapshot/size.log

# systemctl start $nagios

 rm $privfile

 mv /tmp/backup.nems /var/www/html/backup/snapshot/backup.nems

 echo "Done. You'll find the backup at /var/www/html/backup/snapshot/backup.nems"
 echo ""
 echo You can access the file from your computer by navigating to
 echo https://NEMS.local/backup/ -or- \\\\NEMS.local\\backup
 echo ""

 end=`date +%s`

 runtime=$((end-start))


 if [ -d /var/log/nems ]
   then
     echo $runtime > /var/log/nems/migrator-backup-runtime.log
   else
     mkdir /var/log/nems
     echo $runtime > /var/log/nems/migrator-backup-runtime.log
 fi

 # If it is owned by root, user will not be able to open it in browser.
 chown -R www-data:www-data /var/www/html/backup/snapshot

fi
