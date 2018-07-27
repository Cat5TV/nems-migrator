#!/bin/bash
ver=$(/usr/local/bin/nems-info nemsver)
hwid=$(/usr/local/bin/nems-info hwid|tr -d '\n'|tr -d '[:space:]')

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
  /var/log/ \
  /var/lib/mysql/ \
  /etc/rc.local \
  "

 support="\
  /var/www/nconf/output/ \
  /var/www/html/backup/snapshot/backup.nems \
  /etc/network/ \
  /etc/ \
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


# Create the generic backup (not particularly sensitive)
 tar --ignore-failed-read -cf - \
  $support \
  $mainpub \
  $mainpriv \
  $addprivate \
  $addpublic | /bin/gzip --no-name > /tmp/support.tar.gz
  echo 'Encrypting private data using your NEMS Hardware ID.'
  /usr/bin/gpg --yes --batch --passphrase="$hwid" -c /tmp/support.tar.gz

 mv /tmp/support.tar.gz.gpg /var/www/html/backup/snapshot/support.nems

 echo "Done."
 echo ""
 echo "Please keep your support.nems file very safe as it contains easily-accessed"
 echo "private information."
 echo ""
 echo "For support, email the file to nems@category5.tv along with this string:"
 echo $hwid | cut -c1-6
 echo ""
 echo "This string is simply the first 6 digits of your HWID, to prevent sending the full key."
 echo "Robbie will use this string to find your full HWID for decryption."
 echo ""
 echo "If your support request has to do with a Community Forum thread, please also"
 echo "include the URL to the thread within the body of your email."
 echo ""
 echo You can access the support.nems file from your computer by navigating to
 echo https://NEMS.local/backup/support.nems -or- find the file on the SMB
 echo share at \\\\NEMS.local\\backup
 echo ""
 echo "The support.nems file will self-destruct in 15 minutes."
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
