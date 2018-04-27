#!/bin/bash

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
 
 ver=$(/usr/local/bin/nems-info nemsver)
 
 # NagVis maps are stored differently in NEMS 1.0
 if [[ $ver = "" ]]; then
   echo NEMS Version data is corrupt. Did you remove files from /var/www?
   echo This can be fixed. Contact me for help in restoring your version data.
   echo Aborted.
   exit
 fi
 if [[ $ver = "1.0" ]]; then
		nagvis="maps/"
   else
		nagvis="etc/maps/"
 fi

 addpublic=''
 addprivate=''

 if (( $(awk 'BEGIN {print ("'$ver'" >= "'1.2'")}') )); then
   # Additional items to backup if version matches
   addpublic="/etc/rpimonitor \
     /etc/webmin \
   "
 fi

 if (( $(awk 'BEGIN {print ("'$ver'" >= "'1.3'")}') )); then
   # Additional items to backup if version matches
   addprivate="$addprivate \
     /var/www/certs \
   "
 fi

 service nagios3 stop

# Create the archive containing sensitive information
 privfile='/tmp/private.tar.gz'
 tar czf $privfile \
  /usr/local/share/nems/nems.conf \
  /etc/nagios3/resource.cfg \
  /var/www/nconf/config \
  /var/www/nconf/output \
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
 tar cf - \
  $privfile \
  /var/www/htpasswd \
  /etc/nagvis/$nagvis \
  /etc/nagios3/cgi.cfg \
  /etc/nagios3/htpasswd.users \
  /var/log/ \
  /etc/nagios3/Default_collector/ \
  /etc/nagios3/global/ \
  /var/lib/mysql/ \
  /etc/rc.local \
  $addpublic | /bin/gzip --no-name > /tmp/backup.nems

 service nagios3 start

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
 
fi
