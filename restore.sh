#!/bin/bash
# Remove restore functionality from legacy versions of NEMS
ver=$(/usr/local/bin/nems-info nemsver)
if (( ! $(awk 'BEGIN {print ("'$ver'" >= "'1.2.1'")}') )); then
   echo "ERROR: nems-restore requires NEMS 1.2.1 or higher"
   exit
fi
if [ ! -f /var/www/htpasswd ]; then
   echo "ERROR: NEMS has not been initialized yet. Run: sudo nems-init"
   exit
fi

start=`date +%s`

# Don't allow the script to run if it's already running. May occur if your logs or config take longer than 5 minutes to backup.
if pidof -o %PPID -x "`basename "$0"`">/dev/null; then
    echo "Process already running"
    exit
fi

if [[ $1 = "" ]]; then
  echo ""
  echo "NEMS Migrator Restore - By Robbie Ferguson"
  echo ""
  echo "Local Usage: sudo nems-restore /location/of/backup.nems"
  echo "Off-Site Backup Usage: sudo nems-restore osb"
  echo ""
  echo "For local usage, you must use the full path to your backup.nems,"
  echo "even if it is in the current folder."
  echo ""
  exit
fi

if [[ $EUID -ne 0 ]]; then
  echo "ERROR: You must be a root" 2>&1
  exit 1
else

  if [[ -d /tmp/nems_migrator_restore ]]; then
    rm -rf /tmp/nems_migrator_restore
  fi
  mkdir -p /tmp/nems_migrator_restore

  # Let's grab it from Off-Site Backup instead
   if [[ ${1,,} == 'osb' ]]; then
     /root/nems/nems-migrator/restore-offsite.sh
     if [[ -f /tmp/osb.backup.nems ]]; then
       set -- "/tmp/osb.backup.nems"
     else
       echo Aborting. There is no backup downloaded.
       exit
     fi
   fi

	if [[ -e $1 ]]; then

		echo Let me be VERY clear here...
		echo This will WIPE OUT the configuration on this NEMS deployment.
		echo The configuration will be replaced with the one stored in your NEMS backup.
		echo ""
		echo Please do this on a fresh deployment of NEMS to prevent data loss.
		echo "I am not responsible for this script breaking everything you have done :)"
		echo Backup, backup, backup.

		echo ""

		read -r -p "Are you sure you want to attempt restore? [y/N] " response
    if [[ $response =~ ^([yY][eE][sS]|[yY])$ ]]; then

    cd /tmp/nems_migrator_restore
    tar -zxf $1

  # if this is an encrypted set, decrypt
  if [[ -f /tmp/nems_migrator_restore/tmp/private.tar.gz.gpg ]]; then
    printf "This backup is encrypted. Attempting to decrypt... "
    # Load Config
    hwid=`/usr/local/bin/nems-info hwid`
    osbpass=$(cat /usr/local/share/nems/nems.conf | grep osbpass | printf '%s' $(cut -n -d '=' -f 2))
    osbkey=$(cat /usr/local/share/nems/nems.conf | grep osbkey | printf '%s' $(cut -n -d '=' -f 2))
    timestamp=$(/bin/date +%s)

    if [[ $osbpass == '' ]] || [[ $osbkey == '' ]]; then
      echo NEMS Migrator Offsite Backup is not currently enabled.
      echo ""
      exit
    fi;

    /usr/bin/gpg --yes --batch --passphrase="::$osbpass::$osbkey::" --decrypt /tmp/nems_migrator_restore/tmp/private.tar.gz.gpg > /tmp/nems_migrator_restore/tmp/private.tar.gz
    rm /tmp/nems_migrator_restore/tmp/private.tar.gz.gpg

    if ! tar -tf /tmp/nems_migrator_restore/tmp/private.tar.gz &> /dev/null; then
      echo "Error with backup. Are you sure you're using the hardware and OSB Key that match this backup?"
      echo ""
      exit
    else
      echo ""
      echo "Successfully decrypted."
      echo ""
    fi


  fi

  cd /tmp/nems_migrator_restore
  tar -zxf /tmp/nems_migrator_restore/tmp/private.tar.gz
  rm /tmp/nems_migrator_restore/tmp/private.tar.gz

				# Legacy compatibility
				if [[ -f "/tmp/nems_migrator_restore/var/www/html/inc/ver.txt" ]]; then
				 backupver=$(cat "/tmp/nems_migrator_restore/var/www/html/inc/ver.txt")

				 # Current nems.conf version storage
				 elif [[ -f "/tmp/nems_migrator_restore/usr/local/share/nems/nems.conf" ]]; then
				   backupver=$(cat /tmp/nems_migrator_restore/usr/local/share/nems/nems.conf | grep version |  printf '%s' $(cut -n -d '=' -f 2))

         # NEMS 1.2.x old storage location (moved with fixes.sh)
				 elif [[ -f "/tmp/nems_migrator_restore/home/pi/nems.conf" ]]; then
				   backupver=$(cat /tmp/nems_migrator_restore/home/pi/nems.conf | grep version |  printf '%s' $(cut -n -d '=' -f 2))

				 # We don't really know the true version, but we know this is from NEMS, so set 1.2
				 elif [[ -d "/var/log/nems/" ]]; then
					 backupver=1.2

        fi

				 ver=$(/usr/local/bin/nems-info nemsver)

				 if (( ! $(awk 'BEGIN {print ("$backupver" >= "'1.0'")}') )); then
				   echo Backup file is from NEMS $backupver. Proceeding.
				   service nagios3 stop

				   # I know I warned you, but I love you too much to let you risk it.
				   /root/nems/nems-migrator/backup.sh > /dev/null 2>&1
				   cp -p /var/www/html/backup/snapshot/backup.nems /root/

				   if [[ -d "/tmp/nems_migrator_restore/etc/nagios3" ]]; then

                                         # Clobber the existing configs which will not be consolidated
                                         rm /etc/nagios3/global/timeperiods.cfg && cp /tmp/nems_migrator_restore/etc/nagios3/global/timeperiods.cfg /etc/nagios3/global/ && chown www-data:www-data /etc/nagios3/global/timeperiods.cfg
                                         # rm /etc/nagios3/parent_hosts.cfg && cp /tmp/nems_migrator_restore/etc/nagios3/parent_hosts.cfg /etc/nagios3/ && chown www-data:www-data /etc/nagios3/parent_hosts.cfg

                                         # Reconcile and clobber all other config files
                                         /root/nems/nems-migrator/data/reconcile-nagios.sh

					 # Clear MySQL database and import new consolidated configs into NConf
					 /root/nems/nems-migrator/data/nconf-import.sh

                                         # Activate default nagios monitor on all hosts
                                         /root/nems/nems-migrator/data/nconf-activate.sh

            else
                                         echo "Nagios Configuration Missing. This is a critical error."
                                         exit
           fi


					 if [[ $backupver == "1.0" ]]; then
					 	echo "Upgrading to newer version of NEMS: Please edit /etc/nagios3/resource.cfg to configure your settings."
					  elif [[ -e "/tmp/nems_migrator_restore/etc/nagios3/resource.cfg" ]]; then
							 /root/nems/nems-migrator/data/reconcile-resource.sh
						else
						  echo "Nagios Configuration Missing. This is a critical error."
							exit
					 fi


					 # NagVis maps are stored differently in NEMS 1.0
					 if [[ $backupver == "1.0" ]]; then
							nagvissrc="maps/"
						 else
							nagvissrc="etc/maps/"
					 fi
					 if [[ $ver == "1.0" ]]; then
							nagvisdest=""
						 else
							nagvisdest="etc/"
					 fi
				   if [[ -d "/tmp/nems_migrator_restore/etc/nagvis/$nagvissrc" ]]; then
						 rm -rf /etc/nagvis/$nagvisdest\maps
						 cp -Rp /tmp/nems_migrator_restore/etc/nagvis/$nagvissrc /etc/nagvis/$nagvisdest
				   else
							 echo "NagVis failed. Your NagVis data is corrupt."
					 fi

					 if [[ -d "/tmp/nems_migrator_restore/var/www/nconf/output" ]]; then
						 rm -rf /var/www/nconf/output/
						 cp -Rp /tmp/nems_migrator_restore/var/www/nconf/output /var/www/nconf/
				   else
							 echo "NConf failed. Your NConf data is corrupt."
							 echo "You should be able to re-create it."
					 fi


				   # This may cause errors, but at least it gives them the old logs.
				   cp -Rp /tmp/nems_migrator_restore/var/log/* /var/log

				   service mysql start
				   service nagios3 start

				   echo ""
				   echo I hope everything worked okay for you.
				   echo Please let me know if you had any trouble.
				   echo ""
				   echo PS - I saved a backup for you of the old config. /root/backup.nems
				   echo      ... just in case
				   echo ""

				 else
				   echo Your backup file is either invalid, or an unsupported version. Aborted.
				 fi

				 #rm -rf /tmp/nems_migrator_restore

				 end=`date +%s`
				 runtime=$((end-start))

				 if [[ -d "/var/log/nems" ]]; then
						 echo $runtime > /var/log/nems/migrator-restore-runtime.log
					 else
						 mkdir /var/log/nems
						 echo $runtime > /var/log/nems/migrator-restore-runtime.log
				 fi

		else
				echo Aborted.
		fi

	else
	  echo $1 does not exist. Aborting.
	fi

fi

